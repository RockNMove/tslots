# tslots — Учёт занятости ячеек ответственного хранения

## Описание проекта

МойСклад не хранит историю операций по ячейкам. tslots решает эту задачу:
забирает документы из МойСклад API, строит историю занятости каждой ячейки
и считает сколько каждый поклажедатель должен за услуги ответственного хранения.

---

## Карта инфраструктуры

```
┌─────────────────────────────────────────────────────────────────┐
│                   Docker (локально или Яндекс Клауд)            │
│                                                                  │
│  ┌──────────────┐     ┌─────────────────┐     ┌─────────────┐  │
│  │   postgres   │◄────│ prefect-worker  │     │   grafana   │  │
│  │   :5432      │◄────│ prefect-server  │     │   :3000     │  │
│  └──────────────┘     │   :4200         │     └──────┬──────┘  │
│         ▲             └─────────────────┘            │          │
│         └────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
          │                     │                    │
    localhost:5432        localhost:4200        localhost:3000
  (VS Code, DBeaver)     (Prefect UI)          (Grafana UI)

МойСклад API ──► prefect-worker (ingest.py) ──► postgres (raw)
                 prefect-worker (dbt run)    ──► postgres (bronze/silver/gold)
                                                      │
                                                  grafana
```

### Контейнеры

| Контейнер | Образ | Порт | Роль |
|---|---|---|---|
| tslots-postgres | postgres:16-alpine | 5432 | База данных |
| tslots-prefect-server | prefecthq/prefect:3-python3.11 | 4200 | UI и API Prefect |
| tslots-prefect-worker | prefect/Dockerfile (custom) | — | Выполняет flows и dbt |
| tslots-grafana | grafana/grafana:10.4.0 | 3000 | Дашборды |

### Volumes и хранение данных

| Что | Где хранится | При `docker-compose down` | При `docker-compose down -v` |
|---|---|---|---|
| Данные PostgreSQL | Docker volume `postgres_data` | Сохранятся | **Удалятся** |
| Дашборды Grafana | `grafana/provisioning/*.json` (в git) | Сохранятся | Сохранятся |
| Служебные данные Grafana | Docker volume `grafana_data` | Сохранятся | **Удалятся** |
| Код и модели | Папка `tslots/` на компе (в git) | Сохранятся | Сохранятся |
| Секреты | `.env` на компе (не в git) | Сохранятся | Сохранятся |

### Монтирование папок (volumes)

```
Твой комп                          Контейнер
──────────────────────────────     ──────────────────────────────
tslots/                      →     /app/              (prefect-worker)
tslots/grafana/provisioning/ →     /etc/grafana/provisioning/ (grafana)
Docker volume postgres_data  →     /var/lib/postgresql/data   (postgres)
Docker volume grafana_data   →     /var/lib/grafana           (grafana)
```

Ты редактируешь файлы в VS Code → prefect-worker видит изменения сразу, без перезапуска.

### Внутренняя сеть Docker

Контейнеры общаются по имени сервиса:
- Worker → PostgreSQL: `postgres:5432`
- Worker → Prefect Server: `prefect-server:4200`
- Grafana → PostgreSQL: `postgres:5432`

---

## Схема данных

```
МойСклад API
     │
     ▼
raw_moysklad.*     ← сырые JSON (Prefect ingest.py)
     │
     ▼
bronze.*           ← stg_operations, stg_stores, stg_products,
     │                stg_variants, stg_agents (dbt views)
     ▼
silver.*           ← int_slot_occupancy — интервалы занятости ячеек (dbt table)
     │
     ▼
gold.*             ← mart_billing, mart_slot_status (dbt table)
     │
     ▼
Grafana дашборды
```

### Слои PostgreSQL

| Схема | Кто создаёт | Тип объектов | Назначение |
|---|---|---|---|
| `raw_moysklad` | `init_db.py` | tables | Сырые JSON от API |
| `bronze` | dbt | views | Очищенные плоские таблицы |
| `silver` | dbt | tables | Бизнес-логика (интервалы занятости) |
| `gold` | dbt | tables | Витрины для Grafana |

---

## Схема raw_moysklad

Все таблицы слоя имеют одинаковую структуру:

| Колонка | Тип | Ограничения | Описание |
|---|---|---|---|
| ms_id | TEXT | PRIMARY KEY, NOT NULL | ID объекта из МойСклад |
| raw_json | JSONB | NOT NULL | Весь JSON-ответ от API как есть |
| loaded_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Время физической записи строки в базу. Используется dbt для freshness check |
| sync_batch | TIMESTAMPTZ | NOT NULL | Время старта flow. Одинаковое для всех записей одного запуска |

Таблицы: `stores`, `uoms`, `products`, `variants`, `agents`, `demands`, `supplies`, `losses`, `enters`, `moves`

### sync_log — аудит запусков

| Колонка | Тип | Ограничения | Описание |
|---|---|---|---|
| id | SERIAL | PRIMARY KEY | Автоинкремент |
| flow_run_id | TEXT | — | ID запуска из Prefect |
| started_at | TIMESTAMPTZ | NOT NULL | Когда flow стартовал |
| finished_at | TIMESTAMPTZ | — | Когда завершился (NULL пока идёт) |
| is_cold_start | BOOLEAN | NOT NULL, DEFAULT FALSE | TRUE если LAST_SUCCESSFUL_SYNC не задана — flow забрал весь архив |
| status | TEXT | NOT NULL, DEFAULT 'running' | running / success / failed |
| rows_inserted | JSONB | — | {"demands": 42, "supplies": 10, ...} |
| error_message | TEXT | — | Текст ошибки если упало |

---

## Структура проекта

```
tslots/
├── .env.example               ← шаблон — скопируй в .env и заполни
├── .env                       ← секреты (не в git)
├── .gitignore
├── Pipfile                    ← зависимости Python для подсветки синтаксиса в VS Code (проект запускается только в Docker)
├── docker-compose.yml         ← вся инфраструктура
├── README.md
│
├── notebooks/                 ← Jupyter ноутбуки для исследования данных
│
├── init_db/
│   └── 01_raw_schema.sql      ← DDL схемы raw_moysklad
│
├── prefect/
│   ├── Dockerfile             ← образ worker (prefect + dbt + зависимости)
│   └── flows/
│       ├── ingest.py          ← flow: МойСклад API → PostgreSQL raw
│       ├── transform.py       ← flow: запускает dbt
│       └── deploy.py          ← регистрирует расписание в Prefect
│
├── dbt/
│   └── tslots/
│       ├── dbt_project.yml
│       ├── profiles.yml
│       ├── macros/
│       │   └── generate_schema_name.sql
│       └── models/
│           ├── staging/       ← bronze: stg_operations, stg_stores...
│           ├── intermediate/  ← silver: int_slot_occupancy
│           └── marts/         ← gold: mart_billing, mart_slot_status
│
└── grafana/
    └── provisioning/
        ├── datasources/
        │   └── postgres.yml   ← подключение к PostgreSQL
        └── dashboards/
            ├── dashboards.yml
            └── warehouse.json ← дашборд (в git, не потеряется)
```

---

## Установка с нуля

Одинаковая процедура для локальной машины и Яндекс Клауда.
Единственное отличие — содержимое `.env`.

### Требования

- Docker и Docker Compose
- Git

### Шаг 1 — Клонируй репозиторий

```bash
git clone <url репозитория>
cd tslots
```

### Шаг 2 — Создай .env

```bash
# Windows:
copy .env.example .env

# Linux / Mac:
cp .env.example .env
```

Открой `.env` и заполни:
- `MS_TOKEN` — токен из МойСклад (Настройки → Безопасность → Токены)
- Пароли можно оставить как есть для локальной установки

### Шаг 3 — Собери и запусти контейнеры

```bash
docker-compose up -d --build
```

`--build` нужен при первом запуске — собирает образ prefect-worker из `prefect/Dockerfile`.
При последующих запусках достаточно `docker-compose up -d`.

Проверить что все контейнеры запустились:
```bash
docker-compose ps
```

Все четыре должны быть в статусе `running`.

При первом запуске PostgreSQL автоматически выполнит `init_db/01_raw_schema.sql`
и создаст схему `raw_moysklad` со всеми таблицами — ничего делать вручную не нужно.

### Шаг 4 — Первая ингестация (холодный старт)

Через Prefect UI http://localhost:4200:
Flows → tslots-ingest → Run → Confirm

Или через терминал:
```bash
docker exec tslots-prefect-worker python /app/prefect/flows/ingest.py
```

Prefect заберёт все данные из МойСклад без ограничений по дате.
Следи за логами: Prefect UI → Flow Runs → последний запуск → Logs.

### Шаг 5 — dbt трансформации

Через Prefect UI: Flows → tslots-transform → Run

Или через терминал:
```bash
docker exec tslots-prefect-worker sh -c "
  dbt run --project-dir /app/dbt/tslots --profiles-dir /app/dbt/tslots
"
```

### Шаг 6 — Проверь результат

```bash
docker exec -it tslots-postgres psql -U tslots -d tslots -c "
  SELECT depositor_name, period_label, amount_rub
  FROM gold.mart_billing
  ORDER BY billing_month DESC, amount_rub DESC
  LIMIT 20;
"
```

### Шаг 7 — Grafana

Открой http://localhost:3000
Логин: значения `GRAFANA_USER` и `GRAFANA_PASSWORD` из `.env`

---

## Установка на сервере (Яндекс Клауд)

Процедура идентична локальной. Отличия:

**`.env`** — боевые пароли и токены, не локальные.

**Адреса** — вместо `localhost` используй IP сервера:
- Prefect UI: `http://<IP>:4200`
- Grafana: `http://<IP>:3000`

**Firewall** — открой порты 4200 и 3000 в настройках группы безопасности Яндекс Клауда.

```bash
git clone <url репозитория>
cd tslots
cp .env.example .env
nano .env
docker-compose up -d --build
# Схема raw_moysklad создаётся автоматически при первом старте PostgreSQL
# Дальше через Prefect UI на http://<IP>:4200
```

---

## Расписание автоматических запусков

| Flow | Расписание | Действие |
|---|---|---|
| tslots-daily-ingest | 03:00 UTC ежедневно | МойСклад API → PostgreSQL raw |
| tslots-daily-transform | 03:30 UTC ежедневно | dbt raw → bronze → silver → gold |

Управление: Prefect UI → Deployments.

---

## Полезные команды

### Статус контейнеров
```bash
docker-compose ps
```

### Логи контейнера
```bash
docker-compose logs -f prefect-worker
docker-compose logs -f postgres
```

### Остановить (данные сохранятся)
```bash
docker-compose down
```

### Удалить всё включая данные БД
```bash
docker-compose down -v
```

### Универсальная команда — работает всегда
```bash
docker-compose up -d --build --force-recreate
```
Пересобирает образы и пересоздаёт контейнеры. Данные в PostgreSQL и Grafana не затрагиваются — volumes сохраняются. Используй когда не уверен какой именно флаг нужен.

> ⚠️ Данные удаляются только при явном `docker-compose down -v`

### Пересобрать worker после изменения Dockerfile
```bash
docker-compose up -d --build prefect-worker
```

### Сбросить холодный старт
```bash
# Через Prefect UI: Variables → LAST_SUCCESSFUL_SYNC → Delete
# Или:
docker exec tslots-prefect-worker prefect variable delete LAST_SUCCESSFUL_SYNC
```

### Запустить конкретную dbt модель
```bash
docker exec tslots-prefect-worker sh -c "
  dbt run --select mart_billing \
  --project-dir /app/dbt/tslots \
  --profiles-dir /app/dbt/tslots
"
```

### Изменить тариф хранения
```bash
docker exec tslots-prefect-worker sh -c "
  dbt run \
  --project-dir /app/dbt/tslots \
  --profiles-dir /app/dbt/tslots \
  --vars '{\"rate_per_slot_day\": 75}'
"
```

### История синхронизаций
```bash
docker exec -it tslots-postgres psql -U tslots -d tslots -c "
  SELECT started_at, finished_at, is_cold_start, status, rows_inserted
  FROM raw_moysklad.sync_log
  ORDER BY started_at DESC LIMIT 10;
"
```

### Зайти внутрь контейнера
```bash
docker exec -it tslots-prefect-worker bash
docker exec -it tslots-postgres bash
docker exec -it tslots-grafana bash
```

---

## Порядок тестирования

```
1. git clone + cd tslots
2. copy .env.example .env        ← заполнить MS_TOKEN
3. docker-compose up -d --build  ← все контейнеры запущены, схема БД создана автоматически
4. запустить ingest flow         ← данные из API → raw (холодный старт)
5. запустить transform flow      ← raw → bronze → silver → gold
6. SELECT из mart_billing        ← видим начисления
7. открыть Grafana :3000         ← видим дашборды
```

---

## Смена паролей по умолчанию

Все пароли и секреты хранятся в одном месте — файл `.env`.
Менять что-то в коде или конфигах не нужно.

### Какие пароли есть и где используются

| Переменная | Где используется |
|---|---|
| `DB_PASSWORD` | PostgreSQL, Prefect Server, Prefect Worker, dbt |
| `GRAFANA_PASSWORD` | Grafana UI |
| `MS_TOKEN` | МойСклад API |

### Смена GRAFANA_PASSWORD

1. Измени значение в `.env`
2. Перезапусти контейнер:
```bash
docker-compose restart grafana
```

### Смена MS_TOKEN

1. Измени значение в `.env`
2. Перезапусти worker:
```bash
docker-compose restart prefect-worker
```

### Смена DB_PASSWORD

Это сложнее — пароль уже записан внутри PostgreSQL.
Нужно поменять его и там, и в `.env`:

1. Смени пароль внутри PostgreSQL:
```bash
docker exec -it tslots-postgres psql -U tslots -d tslots -c "
  ALTER USER tslots PASSWORD 'новый_пароль';
"
```
2. Обнови `.env` — поставь тот же новый пароль везде где встречается `DB_PASSWORD`
3. Перезапусти контейнеры которые используют БД:
```bash
docker-compose restart prefect-server prefect-worker grafana
```

Данные в PostgreSQL при этом не затрагиваются.
