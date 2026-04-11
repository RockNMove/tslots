"""
api_to_gold.py — единственный flow проекта tslots.

Запускается по расписанию каждый день в 00:00 МСК.
Четыре шага выполняются строго последовательно.

Запуск вручную через Prefect UI:
    Deployments → tslots-daily → Run → Quick Run
"""

# INIT

import json
import os
import subprocess
from datetime import datetime, timezone

import pandas as pd
import requests
from sqlalchemy import create_engine
from sqlalchemy.dialects.postgresql import JSONB
from prefect import flow, task, get_run_logger
from prefect.variables import Variable

MS_TOKEN = os.environ["MS_TOKEN"]
DB_HOST = os.environ["DB_HOST"]
DB_USER = os.environ["DB_USER"]
DB_PASS = os.environ["DB_PASSWORD"]
DB_NAME = os.environ["DB_NAME"]

BASE_URL = "https://api.moysklad.ru/api/remap/1.2/entity"
LIMIT = 100
HEADERS = {
    "Authorization": f"Bearer {MS_TOKEN}",
    "Accept-Encoding": "gzip",
    "Content-Type": "application/json",
}
ENGINE = create_engine(f"postgresql+pg8000://{DB_USER}:{DB_PASS}@{DB_HOST}/{DB_NAME}")

DBT_PROJECT_DIR = "/app/dbt/tslots"
DBT_PROFILES_DIR = "/app/dbt/tslots"

# HELPERS


def fetch(endpoint: str, params: dict) -> list[dict]:
    """Обходит все страницы API, возвращает плоский список записей."""
    rows, offset = [], 0
    while True:
        response = requests.get(
            f"{BASE_URL}/{endpoint}",
            headers=HEADERS,
            params={**params, "offset": offset},
            timeout=30,
        )
        response.raise_for_status()
        page = response.json().get("rows", [])
        rows.extend(page)
        if len(page) < LIMIT:
            break
        offset += LIMIT
    return rows

# TASKS


@task(name="ingest")
def ingest():
    logger = get_run_logger()

    start = Variable.get("last_successful_sync", default=None)
    stop = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    if start:
        logger.info(f"Инкрементальный: {start} → {stop}")
        date_filter = f"updated>={start};updated<{stop}"
        in_out_filter = f"updated>={start};updated<{stop};applicable=true"
    else:
        logger.warning("Холодный старт — загружаем всё")
        date_filter = None
        in_out_filter = "applicable=true"

    endpoints = {
        "store":        {"expand": "zones,slots.zone",                          "filter": date_filter,   "limit": LIMIT},
        "uom":          {"filter": date_filter,   "limit": LIMIT},
        "product":      {"expand": "uom,attributes.value",                      "filter": date_filter,   "limit": LIMIT},
        "variant":      {"expand": "product",                                   "filter": date_filter,   "limit": LIMIT},
        "counterparty": {"filter": date_filter,   "limit": LIMIT},
        "demand":       {"expand": "positions.slot,positions.assortment,agent", "filter": in_out_filter, "limit": LIMIT},
        "supply":       {"expand": "positions.slot,positions.assortment,agent", "filter": in_out_filter, "limit": LIMIT},
        "loss":         {"expand": "positions.slot,positions.assortment,agent", "filter": in_out_filter, "limit": LIMIT},
        "enter":        {"expand": "positions.slot,positions.assortment,agent", "filter": in_out_filter, "limit": LIMIT},
        "move":         {"expand": "positions.targetSlot,positions.sourceSlot", "filter": in_out_filter, "limit": LIMIT},
    }

    records = []
    for endpoint, params in endpoints.items():
        rows = fetch(endpoint, params)
        for row in rows:
            records.append({"entity": endpoint, "raw_json": json.dumps(row, ensure_ascii=False)})
        logger.info(f"{endpoint}: {len(rows)}")

    if not records:
        logger.warning("Нет данных от API — пропускаем запись в БД")
        return

    pd.DataFrame(records).to_sql(
        "raw", ENGINE,
        schema="layer_raw",
        if_exists="replace",
        index=False,
        method="multi",
        chunksize=500,
        dtype={"raw_json": JSONB},
    )

    Variable.set("last_successful_sync", stop, overwrite=True)
    logger.info(f"✅ last_successful_sync → {stop}")


@task(name="dbt", retries=1, retry_delay_seconds=30)
def dbt_run(layer: str) -> None:
    """
    Запускает dbt run + dbt test для указанного слоя.
    layer — название папки в dbt/models/ : staging | intermediate | marts
    """
    logger = get_run_logger()

    for command in ["run", "test"]:
        cmd = [
            "dbt", command,
            "--project-dir",  DBT_PROJECT_DIR,
            "--profiles-dir", DBT_PROFILES_DIR,
            "--select", layer,
        ]
        logger.info(f"dbt {command} --select {layer}")

        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if result.returncode != 0:
            raise RuntimeError(
                f"dbt {command} --select {layer} завершился с ошибкой "
                f"(code={result.returncode})\n{result.stdout}"
            )

# FLOW


@flow(
    name="api-to-gold",
    description="tslots: ежедневный pipeline — API → layer_raw → bronze → silver → gold",
)
def api_to_gold():
    logger = get_run_logger()

    logger.info("Шаг 1/4 — ингестация...")
    ingest()

    logger.info("Шаг 2/4 — bronze (staging)...")
    dbt_run("staging")

    logger.info("Шаг 3/4 — silver (intermediate)...")
    dbt_run("intermediate")

    logger.info("Шаг 4/4 — gold (marts)...")
    dbt_run("marts")

    logger.info("✅ Pipeline завершён успешно")
