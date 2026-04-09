"""
pipeline.py — главный flow: запускает все шаги последовательно.

Запускается через Prefect UI:
    Deployments → tslots-daily-pipeline → Run → Quick Run

Порядок:
    1. tslots_ingest_flow   — МойСклад API → PostgreSQL raw
    2. tslots_bronze_flow   — dbt staging → bronze
    3. tslots_silver_flow   — dbt intermediate → silver
    4. tslots_gold_flow     — dbt marts → gold
"""

from prefect import flow, get_run_logger

from ingest import tslots_ingest_flow
from transform_bronze import tslots_bronze_flow
from transform_silver import tslots_silver_flow
from transform_gold import tslots_gold_flow


@flow(
    name="tslots-pipeline",
    description="tslots: полный цикл — ингестация + bronze + silver + gold",
)
def tslots_pipeline_flow():
    logger = get_run_logger()

    logger.info("Шаг 1/4 — ингестация МойСклад → raw...")
    tslots_ingest_flow()

    logger.info("Шаг 2/4 — dbt bronze (staging)...")
    tslots_bronze_flow()

    logger.info("Шаг 3/4 — dbt silver (intermediate)...")
    tslots_silver_flow()

    logger.info("Шаг 4/4 — dbt gold (marts)...")
    tslots_gold_flow()

    logger.info("✅ Pipeline завершён успешно")
