"""
deploy.py — регистрирует tslots pipeline в Prefect с расписанием.

Запускается автоматически при старте prefect-worker контейнера.
Расписание только у pipeline — остальные flow запускаются из него.
"""

from prefect.client.schemas.schedules import CronSchedule

from pipeline import tslots_pipeline_flow

FLOWS_DIR = "/app/prefect/flows"


def main():
    print("Регистрируем pipeline deployment в Prefect...")

    tslots_pipeline_flow.from_source(
        source=FLOWS_DIR,
        entrypoint="pipeline.py:tslots_pipeline_flow",
    ).deploy(
        name="tslots-daily-pipeline",
        work_pool_name="default-agent-pool",
        schedules=[CronSchedule(cron="0 3 * * *", timezone="Europe/Moscow")],
        description="Ежедневный полный цикл: raw → bronze → silver → gold (03:00 МСК)",
        tags=["tslots", "production"],
    )

    print("✅ Deployment зарегистрирован успешно")


if __name__ == "__main__":
    main()
