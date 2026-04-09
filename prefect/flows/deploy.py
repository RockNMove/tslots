"""
deploy.py — регистрирует tslots flows в Prefect с расписанием.

Запускается однократно при старте prefect-worker контейнера.
После регистрации deployments worker запускается отдельно.
"""

import time
from dotenv import load_dotenv
from prefect.client.schemas.schedules import CronSchedule

load_dotenv()

from ingest import tslots_ingest_flow
from transform import tslots_transform_flow


def main():
    print("Регистрируем deployments в Prefect...")

    ingest_deployment = tslots_ingest_flow.to_deployment(
        name="tslots-daily-ingest",
        schedules=[CronSchedule(cron="0 3 * * *", timezone="UTC")],
        description="Ежедневная загрузка из МойСклад → PostgreSQL raw (03:00 UTC)",
        tags=["tslots", "production", "ingest"],
    )

    transform_deployment = tslots_transform_flow.to_deployment(
        name="tslots-daily-transform",
        schedules=[CronSchedule(cron="30 3 * * *", timezone="UTC")],
        description="Ежедневный dbt run: staging → intermediate → marts (03:30 UTC)",
        tags=["tslots", "production", "transform"],
    )

    # Применяем deployments к серверу
    ingest_deployment.apply()
    transform_deployment.apply()

    print("✅ Deployments зарегистрированы успешно")


if __name__ == "__main__":
    main()
