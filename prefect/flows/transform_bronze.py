"""
transform_bronze.py — dbt staging слой (bronze).

Читает из raw_moysklad.*, создаёт views в схеме bronze:
    stg_operations, stg_stores, stg_products, stg_variants, stg_agents
"""

import os
import subprocess
from prefect import flow, task, get_run_logger

DBT_PROJECT_DIR  = os.environ.get("DBT_PROJECT_DIR",  "/app/dbt/tslots")
DBT_PROFILES_DIR = os.environ.get("DBT_PROFILES_DIR", "/app/dbt/tslots")


@task(name="dbt-run-bronze", retries=1, retry_delay_seconds=30)
def run_dbt_bronze(command: str) -> str:
    logger = get_run_logger()
    cmd = [
        "dbt", command,
        "--project-dir",  DBT_PROJECT_DIR,
        "--profiles-dir", DBT_PROFILES_DIR,
        "--select", "staging",
    ]
    logger.info(f"Запускаем: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        logger.info(f"dbt stdout:\n{result.stdout}")
    if result.stderr:
        logger.warning(f"dbt stderr:\n{result.stderr}")
    if result.returncode != 0:
        raise RuntimeError(f"dbt {command} bronze завершился с ошибкой (code={result.returncode})")
    return result.stdout


@flow(
    name="tslots-bronze",
    description="tslots: dbt staging → bronze (stg_*)",
)
def tslots_bronze_flow():
    logger = get_run_logger()
    logger.info("Запускаем dbt bronze (staging)...")
    run_dbt_bronze("run")
    run_dbt_bronze("test")
    logger.info("✅ Bronze завершён")
