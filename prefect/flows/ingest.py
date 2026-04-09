"""
ingest.py — Prefect flow: МойСклад API → PostgreSQL raw layer.

Запускается через Prefect UI:
    Deployments → tslots-daily-ingest → Run → Quick Run
"""

import os
import json
from datetime import datetime, timezone
from typing import Optional

import requests
import psycopg2
import psycopg2.extras
from prefect import flow, task, get_run_logger
from prefect.variables import Variable
from prefect.context import get_run_context

# ---------------------------------------------------------------------------
# Конфигурация
# ---------------------------------------------------------------------------
MS_TOKEN   = os.environ["MS_TOKEN"]
DB_DSN     = os.environ["DB_DSN"]
MS_API_URL = "https://api.moysklad.ru/api/remap/1.2/entity"
LIMIT      = 100

HEADERS = {
    "Authorization": f"Bearer {MS_TOKEN}",
    "Accept-Encoding": "gzip",
    "Content-Type": "application/json",
}


# ---------------------------------------------------------------------------
# Вспомогательные функции
# ---------------------------------------------------------------------------

def _build_filter(last_sync: Optional[str], extra: str = "") -> str:
    parts = []
    if last_sync:
        parts.append(f"updated>={last_sync}")
    if extra:
        parts.append(extra)
    return ";".join(parts) if parts else ""


def _fetch_all_pages(url: str, params: dict, logger) -> list[dict]:
    """
    Постраничный обход API МойСклад.
    Лимит API = 100 записей за запрос.
    Крутим offset пока rows не станет пустым.
    """
    all_rows = []
    offset = 0

    while True:
        current_params = {**params, "limit": LIMIT, "offset": offset}
        resp = requests.get(url, headers=HEADERS, params=current_params, timeout=30)

        if resp.status_code == 401:
            raise RuntimeError("Ошибка авторизации МойСклад. Проверь MS_TOKEN в .env")
        if resp.status_code != 200:
            raise RuntimeError(
                f"API вернул {resp.status_code} для {url}:\n{resp.text[:300]}"
            )

        data = resp.json()
        rows = data.get("rows", [])

        if not rows:
            break

        all_rows.extend(rows)
        total = data.get("meta", {}).get("size", "?")
        logger.info(f"  Получено {len(all_rows)} / {total}")

        if len(rows) < LIMIT:
            break

        offset += LIMIT

    return all_rows


def _upsert_rows(conn, table: str, rows: list[dict], sync_batch: datetime) -> int:
    """
    INSERT ... ON CONFLICT DO UPDATE — безопасный повторный запуск (idempotent).
    Если запись с таким ms_id уже есть — перезаписываем JSON актуальной версией.
    """
    if not rows:
        return 0

    records = [
        (row["id"], json.dumps(row, ensure_ascii=False), sync_batch)
        for row in rows
    ]

    with conn.cursor() as cur:
        psycopg2.extras.execute_batch(
            cur,
            f"""
            INSERT INTO raw_moysklad.{table} (ms_id, raw_json, sync_batch)
            VALUES (%s, %s::jsonb, %s)
            ON CONFLICT (ms_id) DO UPDATE
              SET raw_json   = EXCLUDED.raw_json,
                  loaded_at  = NOW(),
                  sync_batch = EXCLUDED.sync_batch
            """,
            records,
            page_size=500,
        )
    conn.commit()
    return len(records)


# ---------------------------------------------------------------------------
# Prefect tasks
# ---------------------------------------------------------------------------

@task(name="fetch-entity", retries=3, retry_delay_seconds=10)
def fetch_entity(
    entity: str,
    last_sync: Optional[str],
    extra_filter: str = "",
    extra_params: dict = None,
) -> list[dict]:
    logger = get_run_logger()
    url = f"{MS_API_URL}/{entity}"

    params = extra_params or {}
    filter_str = _build_filter(last_sync, extra_filter)
    if filter_str:
        params["filter"] = filter_str

    logger.info(f"Забираем [{entity}] | filter: {filter_str or 'без ограничений'}")
    rows = _fetch_all_pages(url, params, logger)
    logger.info(f"Итого [{entity}]: {len(rows)} записей")
    return rows


@task(name="save-to-raw", retries=2, retry_delay_seconds=5)
def save_to_raw(rows: list[dict], table: str, sync_batch: datetime) -> int:
    logger = get_run_logger()
    if not rows:
        logger.info(f"[{table}] нет данных — пропускаем")
        return 0
    with psycopg2.connect(DB_DSN) as conn:
        count = _upsert_rows(conn, table, rows, sync_batch)
    logger.info(f"[{table}] записано: {count} строк")
    return count


@task(name="log-sync-start")
def log_sync_start(is_cold: bool, sync_batch: datetime, flow_run_id: str) -> int:
    with psycopg2.connect(DB_DSN) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO raw_moysklad.sync_log
                    (flow_run_id, started_at, is_cold_start, status)
                VALUES (%s, %s, %s, 'running')
                RETURNING id
                """,
                (flow_run_id, sync_batch, is_cold),
            )
            log_id = cur.fetchone()[0]
        conn.commit()
    return log_id


@task(name="log-sync-finish")
def log_sync_finish(
    log_id: int,
    rows_stats: dict,
    status: str = "success",
    error: str = None,
):
    with psycopg2.connect(DB_DSN) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE raw_moysklad.sync_log
                SET finished_at   = NOW(),
                    status        = %s,
                    rows_inserted = %s::jsonb,
                    error_message = %s
                WHERE id = %s
                """,
                (status, json.dumps(rows_stats), error, log_id),
            )
        conn.commit()


# ---------------------------------------------------------------------------
# Main Flow
# ---------------------------------------------------------------------------

@flow(
    name="tslots-ingest",
    description="tslots: забирает данные из МойСклад → PostgreSQL raw layer",
)
def tslots_ingest_flow():
    logger = get_run_logger()

    ctx = get_run_context()
    flow_run_id = str(ctx.flow_run.id) if ctx else "manual"

    # Читаем метку последней успешной синхронизации.
    # None → холодный старт → забираем всё без фильтра по дате.
    last_sync_raw = Variable.get("last_successful_sync", default=None)
    is_cold_start = last_sync_raw is None
    sync_batch    = datetime.now(timezone.utc)

    if is_cold_start:
        logger.warning(
            "⚠️  ХОЛОДНЫЙ СТАРТ: last_successful_sync не задана. "
            "Забираем все данные без ограничений по дате."
        )
        last_sync = None
    else:
        last_sync = last_sync_raw
        logger.info(f"Инкрементальный запуск. Данные с: {last_sync}")

    log_id     = log_sync_start(is_cold=is_cold_start, sync_batch=sync_batch, flow_run_id=flow_run_id)
    rows_stats = {}

    try:
        store_rows = fetch_entity(
            "store", last_sync=last_sync,
            extra_params={"expand": "zones,slots.zone"},
        )
        rows_stats["stores"] = save_to_raw(store_rows, "stores", sync_batch)

        uom_rows = fetch_entity("uom", last_sync=None)
        rows_stats["uoms"] = save_to_raw(uom_rows, "uoms", sync_batch)

        product_rows = fetch_entity(
            "product", last_sync=last_sync,
            extra_params={"expand": "uom,attributes.value"},
        )
        rows_stats["products"] = save_to_raw(product_rows, "products", sync_batch)

        variant_rows = fetch_entity(
            "variant", last_sync=last_sync,
            extra_params={"expand": "product"},
        )
        rows_stats["variants"] = save_to_raw(variant_rows, "variants", sync_batch)

        agent_rows = fetch_entity("counterparty", last_sync=last_sync)
        rows_stats["agents"] = save_to_raw(agent_rows, "agents", sync_batch)

        doc_expand = "positions.slot,positions.assortment,agent"
        doc_filter = "applicable=true"

        for entity, table in [
            ("demand", "demands"),
            ("supply", "supplies"),
            ("loss",   "losses"),
            ("enter",  "enters"),
        ]:
            rows = fetch_entity(
                entity, last_sync=last_sync,
                extra_filter=doc_filter,
                extra_params={"expand": doc_expand},
            )
            rows_stats[table] = save_to_raw(rows, table, sync_batch)

        move_rows = fetch_entity(
            "move", last_sync=last_sync,
            extra_filter="applicable=true",
            extra_params={"expand": "positions.targetSlot,positions.sourceSlot"},
        )
        rows_stats["moves"] = save_to_raw(move_rows, "moves", sync_batch)

        # Фиксируем время НАЧАЛА батча — не конца.
        # Если во время загрузки в МойСклад пришли новые документы,
        # они попадут в следующий инкрементальный запуск.
        new_sync_ts = sync_batch.strftime("%Y-%m-%d %H:%M:%S")
        Variable.set("last_successful_sync", new_sync_ts, overwrite=True)

        logger.info(f"✅ Готово. last_successful_sync → {new_sync_ts}")
        logger.info(f"   Статистика: {rows_stats}")
        log_sync_finish(log_id, rows_stats, status="success")

    except Exception as exc:
        # НЕ обновляем last_successful_sync → следующий запуск повторит период
        error_msg = str(exc)
        logger.error(f"❌ Flow упал: {error_msg}")
        log_sync_finish(log_id, rows_stats, status="failed", error=error_msg)
        raise
