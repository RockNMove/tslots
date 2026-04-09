"""
transform.py — Prefect flow: запускает dbt трансформации.

Локальный запуск:
    pipenv run python prefect/flows/transform.py

Или только отдельный слой:
    pipenv run python prefect/flows/transform.py --select staging
"""

import os
import subprocess
from dotenv import load_dotenv
from prefect import flow, task, get_run_logger

load_dotenv()

DBT_PROJECT_DIR  = os.environ.get("DBT_PROJECT_DIR",  "dbt/tslots")
DBT_PROFILES_DIR = os.environ.get("DBT_PROFILES_DIR", "dbt/tslots")


@task(name="dbt-run", retries=1, retry_delay_seconds=30)
def run_dbt(command: str, select: str = None) -> str:
    logger = get_run_logger()

    cmd = [
        "dbt", command,
        "--project-dir",  DBT_PROJECT_DIR,
        "--profiles-dir", DBT_PROFILES_DIR,
    ]
    if select:
        cmd += ["--select", select]

    logger.info(f"Запускаем: {' '.join(cmd)}")

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.stdout:
        logger.info(f"dbt stdout:\n{result.stdout}")
    if result.stderr:
        logger.warning(f"dbt stderr:\n{result.stderr}")

    if result.returncode != 0:
        raise RuntimeError(f"dbt {command} завершился с ошибкой (code={result.returncode})")

    return result.stdout


@flow(
    name="tslots-transform",
    description="tslots: dbt staging → intermediate → marts",
)
def tslots_transform_flow(select: str = None):
    logger = get_run_logger()
    logger.info("Запускаем dbt трансформации...")
    run_dbt("run",  select=select)
    run_dbt("test", select=select)
    logger.info("✅ dbt трансформации завершены")


if __name__ == "__main__":
    tslots_transform_flow()
