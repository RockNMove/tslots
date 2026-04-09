"""
transform_silver.py — dbt intermediate слой (silver).

Читает из bronze.*, создаёт таблицу в схеме silver:
    int_slot_occupancy — интервалы занятости ячеек
"""

import os
import subprocess
from prefect import flow, task, get_run_logger

DBT_PROJECT_DIR  = os.environ.get("DBT_PROJECT_DIR",  "/app/dbt/tslots")
DBT_PROFILES_DIR = os.environ.get("DBT_PROFILES_DIR", "/app/dbt/tslots")


@task(name="dbt-run-silver", retries=1, retry_delay_seconds=30)
def run_dbt_silver(command: str) -> str:
    logger = get_run_logger()
    cmd = [
        "dbt", command,
        "--project-dir",  DBT_PROJECT_DIR,
        "--profiles-dir", DBT_PROFILES_DIR,
        "--select", "intermediate",
    ]
    logger.info(f"Запускаем: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        logger.info(f"dbt stdout:\n{result.stdout}")
    if result.stderr:
        logger.warning(f"dbt stderr:\n{result.stderr}")
    if result.returncode != 0:
        raise RuntimeError(f"dbt {command} silver завершился с ошибкой (code={result.returncode})")
    return result.stdout


@flow(
    name="tslots-silver",
    description="tslots: dbt intermediate → silver (int_slot_occupancy)",
)
def tslots_silver_flow():
    logger = get_run_logger()
    logger.info("Запускаем dbt silver (intermediate)...")
    run_dbt_silver("run")
    run_dbt_silver("test")
    logger.info("✅ Silver завершён")
