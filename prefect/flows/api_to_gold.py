"""
api_to_gold.py — единственный flow проекта tslots.

Запускается по расписанию каждый день в 00:00 МСК.
Четыре шага выполняются строго последовательно.

Запуск вручную через Prefect UI:
    Deployments → tslots-daily → Run → Quick Run
"""

# INIT

import os
import subprocess
from datetime import timedelta
import pandas as pd
import requests
from sqlalchemy import create_engine, text
from sqlalchemy.dialects.postgresql import JSONB
from prefect import flow, task, get_run_logger

MS_TOKEN = os.environ["MS_TOKEN"]
DB_HOST = os.environ["DB_HOST"]
DB_USER = os.environ["DB_USER"]
DB_PASS = os.environ["DB_PASSWORD"]
DB_NAME = os.environ["DB_NAME"]

BASE_URL  = "https://api.moysklad.ru/api/remap/1.2/entity"
AUDIT_URL = "https://api.moysklad.ru/api/remap/1.2/audit"
LIMIT = 100
HEADERS = {
    "Authorization": f"Bearer {MS_TOKEN}",
    "Accept-Encoding": "gzip",
    "Content-Type": "application/json",
}
ENGINE = create_engine(f"postgresql+pg8000://{DB_USER}:{DB_PASS}@{DB_HOST}/{DB_NAME}")

DBT_PROJECT_DIR = os.environ["DBT_PROJECT_DIR"]

# HELPERS


def get_max_updated(table: str) -> str | None:
    """
    Возвращает MAX(updated) + 1 millisecond из bronze-таблицы в виде строки 'YYYY-MM-DD HH:MM:SS.mmm'.
    Миллисекунды важны: без них запись с .490 проходит фильтр updated>HH:MM:SS каждый раз.
    Возвращает None если таблица не существует, пуста или поле updated отсутствует.
    """
    try:
        with ENGINE.connect() as conn:
            row = conn.execute(
                text(f"SELECT MAX(updated) FROM bronze.{table}")
            ).fetchone()
        if row and row[0] is not None:
            return (row[0] + timedelta(milliseconds=1)).isoformat(sep=' ', timespec='milliseconds')
        return None
    except Exception:
        return None


def fetch(endpoint: str, params: dict) -> list[dict]:
    """Обходит все страницы API, возвращает плоский список записей."""
    rows, offset = [], 0
    while True:
        response = requests.get(
            f"{BASE_URL}/{endpoint}",
            headers=HEADERS,
            params={**params, "offset": offset},
            timeout=120,
        )
        response.raise_for_status()
        page = response.json().get("rows", [])
        rows.extend(page)
        if len(page) < LIMIT:
            break
        offset += LIMIT
    return rows

def get_max_audit_moment() -> str | None:
    """MAX(moment) + 1ms из audit-бронзы. None если таблица пуста или не существует."""
    try:
        with ENGINE.connect() as conn:
            row = conn.execute(
                text("SELECT MAX(moment) FROM bronze.stg_moy_sklad__audit_deleted")
            ).fetchone()
        if row and row[0] is not None:
            return (row[0] + timedelta(milliseconds=1)).isoformat(sep=' ', timespec='milliseconds')
        return None
    except Exception:
        return None


def get_min_operations_moment() -> str | None:
    """MIN(moment) из operations — стартовая точка для первой выкачки аудита."""
    try:
        with ENGINE.connect() as conn:
            row = conn.execute(
                text("SELECT MIN(moment) FROM silver.int_prep__operations_united")
            ).fetchone()
        if row and row[0] is not None:
            return row[0].isoformat(sep=' ', timespec='milliseconds')
        return None
    except Exception:
        return None


def fetch_audit_doc_ids(event_type: str, since: str) -> list[dict]:
    """Выкачивает аудит двухуровнево: контексты → события.
    Возвращает плоский список {doc_id, entity_type, event_type, moment, name}.
    Фильтрует только puttorecyclebin и restorefromrecyclebin — лишние event_type отбрасываются.
    """
    AUDIT_EVENT_TYPES = {'puttorecyclebin', 'restorefromrecyclebin'}
    params = {
        "filter": f"eventType={event_type};moment>={since}",
        "limit": LIMIT,
    }
    contexts, offset = [], 0
    while True:
        r = requests.get(AUDIT_URL, headers=HEADERS, params={**params, "offset": offset}, timeout=120)
        r.raise_for_status()
        page = r.json().get("rows", [])
        contexts.extend(page)
        if len(page) < LIMIT:
            break
        offset += LIMIT

    result = []
    for ctx in contexts:
        r = requests.get(f"{AUDIT_URL}/{ctx['id']}/events", headers=HEADERS, timeout=120)
        r.raise_for_status()
        for ev in r.json().get("rows", []):
            if ev.get("eventType") not in AUDIT_EVENT_TYPES:
                continue
            href = ev.get("entity", {}).get("meta", {}).get("href", "")
            result.append({
                "doc_id":      href.split("/")[-1] if href else None,
                "entity_type": ev.get("entityType"),
                "event_type":  ev.get("eventType"),
                "moment":      ctx.get("moment"),
                "name":        ev.get("name"),
            })
    return result


# TASKS


@task(name="ingest", retries=2, retry_delay_seconds=60)
def ingest():
    logger = get_run_logger()

    # params     — параметры API-запроса
    # aim_table  — bronze-таблица для чтения max(updated) и инкрементальной фильтрации
    endpoints = {
        "store":        {"params": {"expand": "zones,slots.zone",                                               "limit": LIMIT}, "aim_table": "stg_moy_sklad__stores"},
        "uom":          {"params": {"limit": LIMIT}, "aim_table": "stg_moy_sklad__uoms"},
        "product":      {"params": {"expand": "uom,attributes.value",                                          "limit": LIMIT}, "aim_table": "stg_moy_sklad__products"},
        "variant":      {"params": {"expand": "product",                                                       "limit": LIMIT}, "aim_table": "stg_moy_sklad__variants"},
        "counterparty": {"params": {"limit": LIMIT}, "aim_table": "stg_moy_sklad__agents"},
        "demand":       {"params": {"expand": "positions.slot,positions.assortment,agent,store",                     "filter": "applicable=true", "limit": LIMIT}, "aim_table": "stg_moy_sklad__demand"},
        "supply":       {"params": {"expand": "positions.slot,positions.assortment,agent,store",                     "filter": "applicable=true", "limit": LIMIT}, "aim_table": "stg_moy_sklad__supply"},
        "loss":         {"params": {"expand": "positions.slot,positions.assortment,agent,store",                     "filter": "applicable=true", "limit": LIMIT}, "aim_table": "stg_moy_sklad__loss"},
        "enter":        {"params": {"expand": "positions.slot,positions.assortment,agent,store",                     "filter": "applicable=true", "limit": LIMIT}, "aim_table": "stg_moy_sklad__enter"},
        "move":         {"params": {"expand": "positions.targetSlot,positions.sourceSlot,positions.assortment,sourceStore,targetStore", "filter": "applicable=true", "limit": LIMIT}, "aim_table": "stg_moy_sklad__move"},
    }

    records = []
    for endpoint, cfg in endpoints.items():
        params = dict(cfg["params"])

        # Инкрементальная фильтрация: строгий > работает не во всех endpoint.
        # Используем updated>=(max_date + 1 millisecond), за это отвечат функция get_max_updated
        # Запись с updated = max_updated уже загружена в прошлом запуске и есть в bronze.
        since = get_max_updated(cfg["aim_table"])
        if since:
            existing = params.get("filter", "")
            params["filter"] = f"{existing};updated>={since}" if existing else f"updated>={since}"
            logger.info(f"{endpoint}: инкрементально с {since}")
        else:
            logger.info(f"{endpoint}: полная загрузка")

        rows = fetch(endpoint, params)
        for row in rows:
            records.append({"entity": endpoint, "raw_json": row})
        logger.info(f"{endpoint}: {len(rows)} записей")

    # --- Аудит удалений и восстановлений ---
    # Холодный запуск (нет операций) — пропускаем: удалённых документов всё равно нет в bronze.
    # Первый запуск аудита (audit-бронза пуста, но операции есть) — выкачиваем с MIN(moment) операций.
    # Тёплый запуск — инкрементально с MAX(moment) audit-бронзы + 1ms.
    audit_since = get_max_audit_moment() or get_min_operations_moment()
    if audit_since is None:
        logger.info("audit: операций нет — пропускаем")
    else:
        logger.info(f"audit: инкрементально с {audit_since}")
        for event_type, entity_name in [
            ("puttorecyclebin",      "audit_deleted"),
            ("restorefromrecyclebin","audit_restored"),
        ]:
            rows = fetch_audit_doc_ids(event_type, audit_since)
            for row in rows:
                records.append({"entity": entity_name, "raw_json": row})
            logger.info(f"{entity_name}: {len(rows)} записей")

    if not records:
        logger.warning("Нет данных от API — пропускаем запись в БД")
        return

    with ENGINE.connect() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS layer_raw"))
        conn.commit()

    pd.DataFrame(records).to_sql(
        "raw", ENGINE,
        schema="layer_raw",
        if_exists="replace",
        index=False,
        method="multi",
        chunksize=500,
        dtype={"raw_json": JSONB},
    )
    logger.info("✅ Данные записаны в layer_raw.raw")


def _dbt(logger, *args: str) -> None:
    cmd = ["dbt", *args]
    logger.info(" ".join(cmd))
    result = subprocess.run(cmd, capture_output=True, text=True, check=False, cwd=DBT_PROJECT_DIR)
    if result.returncode != 0:
        raise RuntimeError(f"dbt {' '.join(args)} завершился с ошибкой\n{result.stdout}")


@task(name="dbt_run", retries=1, retry_delay_seconds=30)
def dbt_run(layer: str) -> None:
    """Собирает и тестирует указанный слой: staging | intermediate | marts.
    Кросс-слойные тесты (tag:cross_layer) исключаются — они запускаются отдельно в конце."""
    logger = get_run_logger()
    _dbt(logger, "run",  "--select", layer)
    _dbt(logger, "test", "--select", layer, "--exclude", "tag:cross_layer")


@task(name="dbt_test_cross_layer", retries=1, retry_delay_seconds=30)
def dbt_test_cross_layer() -> None:
    """Кросс-слойные тесты (silver vs gold) — запускаются после всех трёх слоёв."""
    logger = get_run_logger()
    _dbt(logger, "test", "--select", "tag:cross_layer")

# FLOW


@flow(
    name="api-to-gold",
    description="tslots: ежедневный pipeline — API → layer_raw → bronze → silver → gold",
)
def api_to_gold():
    logger = get_run_logger()

    logger.info("Шаг 1/5 — ингестация...")
    ingest()

    logger.info("Шаг 2/5 — bronze (staging)...")
    dbt_run("staging")

    logger.info("Шаг 3/5 — silver (intermediate)...")
    dbt_run("intermediate")

    logger.info("Шаг 4/5 — gold (marts)...")
    dbt_run("marts")

    logger.info("Шаг 5/5 — кросс-слойные тесты...")
    dbt_test_cross_layer()

    logger.info("✅ Pipeline завершён успешно")
