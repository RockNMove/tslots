"""
deploy.py — регистрирует flow в Prefect с расписанием.

Запускается автоматически при старте prefect-worker контейнера.
"""

# ==============================================================================
# ПОЯСНЕНИЕ:
# 1. api_to_gold — это объект Flow, импортированный из api_to_gold.py.
#    Поскольку он обернут в декоратор @flow, он обладает встроенными методами Prefect.
#
# 2. .from_source(...) — метод, указывающий серверу, где физически лежит код.
#    entrypoint задает путь к файлу и имя функции-стартера внутри контейнера.
#
# 3. .deploy(...) — метод, который регистрирует расписание (Cron) на сервере Prefect.
#    Это не запускает код немедленно, а создает задачу в Work Pool, которую
#    подхватит воркер в указанное время.
# ==============================================================================

import asyncio
from api_to_gold import api_to_gold
from prefect.client.schemas.schedules import CronSchedule
from prefect.client.orchestration import get_client

# Путь к папке с flow-файлами внутри контейнера.
FLOWS_DIR = "/app/prefect/flows"
WORK_POOL_NAME = "default-agent-pool"


async def ensure_work_pool():
    async with get_client() as client:
        try:
            await client.read_work_pool(WORK_POOL_NAME)
            print(f"Work pool '{WORK_POOL_NAME}' уже существует")
        except Exception:
            await client.create_work_pool(
                work_pool={"name": WORK_POOL_NAME, "type": "process"}
            )
            print(f"Work pool '{WORK_POOL_NAME}' создан")


def main():
    asyncio.run(ensure_work_pool())
    print("Регистрируем deployment в Prefect...")

    api_to_gold.from_source(
        source=FLOWS_DIR,
        entrypoint="api_to_gold.py:api_to_gold",
    ).deploy(
        name="tslots_daily_deploy",
        work_pool_name="default-agent-pool",
        # Каждый день в 00:00 по Москве.
        schedules=[CronSchedule(cron="0 0 * * *", timezone="Europe/Moscow")],
        description="Ежедневный pipeline: API → raw → bronze → silver → gold (00:00 МСК)",
    )

    print("✅ Deployment зарегистрирован успешно")


if __name__ == "__main__":
    main()
