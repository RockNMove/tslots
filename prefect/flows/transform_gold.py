"""
transform_gold.py — dbt marts слой (gold).

Читает из silver.*, создаёт таблицы в схеме gold:
    mart_billing      — начисления по поклажедателям
    mart_slot_status  — текущее состояние склада
"""

import os
import subprocess
from prefect import flow, task, get_run_logger

DBT_PROJECT_DIR  = os.environ.get("DBT_PROJECT_DIR",  "/app/dbt/tslots")
DBT_PROFILES_DIR = os.environ.get("DBT_PROFILES_DIR", "/app/dbt/tslots")


@task(name="dbt-run-gold", retries=1, retry_delay_seconds=30)
def run_dbt_gold(command: str) -> str:
    logger = get_run_logger()
    cmd = [
        "dbt", command,
        "--project-dir",  DBT_PROJECT_DIR,
        "--profiles-dir", DBT_PROFILES_DIR,
        "--select", "marts",
    ]
    logger.info(f"Запускаем: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        logger.info(f"dbt stdout:\n{result.stdout}")
    if result.stderr:
        logger.warning(f"dbt stderr:\n{result.stderr}")
    if result.returncode != 0:
        raise RuntimeError(f"dbt {command} gold завершился с ошибкой (code={result.returncode})")
    return result.stdout


@flow(
    name="tslots-gold",
    description="tslots: dbt marts → gold (mart_billing, mart_slot_status)",
)
def tslots_gold_flow():
    logger = get_run_logger()
    logger.info("Запускаем dbt gold (marts)...")
    run_dbt_gold("run")
    run_dbt_gold("test")
    logger.info("✅ Gold завершён")
