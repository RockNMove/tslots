# tslots — Учёт занятости ячеек ответственного хранения

## Описание проекта

МойСклад не хранит историю операций по ячейкам. tslots решает эту задачу:
забирает документы из МойСклад API, строит историю занятости каждой ячейки
и считает ежедневный остаток по каждому слоту.

---

## Карта инфраструктуры

```
┌─────────────────────────────────────────────────────────────────┐
│                   Docker (локально или сервер)                   │
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

МойСклад API ──► prefect-worker (ingest) ──► postgres (layer_raw)
                 prefect-worker (dbt)    ──► postgres (bronze/silver/gold)
                                                      │
                                                  grafana
```

### Контейнеры

| Контейнер | Образ | Порт | Роль |
|---|---|---|---|
| tslots-postgres | postgres:16-alpine | 5432 | База данных |
| tslots-prefect-server | prefecthq/prefect:3-python3.11 | 4200 | UI и API Prefect |
| tslots-prefect-worker | prefect/Dockerfile (custom) | — | Выполняет flow и dbt |
| tslots-grafana | grafana/grafana:10.4.0 | 3000 | Дашборды |

### Volumes и хранение данных

| Что | Где хранится | `docker-compose down` | `docker-compose down -v` |
|---|---|---|---|
| Данные PostgreSQL | Docker volume `postgres_data` | Сохранятся | **Удалятся** |
| Дашборды Grafana | `grafana/provisioning/` (в git) | Сохранятся | Сохранятся |
| Служебные данные Grafana | Docker volume `grafana_data` | Сохранятся | **Удалятся** |
| Код и модели | `tslots/` (в git) | Сохранятся | Сохранятся |
| Секреты | `.env` (не в git) | Сохранятся | Сохранятся |

### Монтирование папок

```
Твой комп                          Контейнер
──────────────────────────────     ──────────────────────────────
tslots/                      →     /app/                (prefect-worker)
tslots/grafana/provisioning/ →     /etc/grafana/provisioning/ (grafana)
Docker volume postgres_data  →     /var/lib/postgresql/data   (postgres)
Docker volume grafana_data   →     /var/lib/grafana           (grafana)
```

Ты редактируешь файлы в VS Code → prefect-worker видит изменения сразу, без перезапуска.

---

## Pipeline

Один flow `api-to-gold` — 4 шага строго последовательно:

```
МойСклад API
     │
     ▼  [1] ingest — Python/pandas → pg8000
layer_raw.raw          ← одна таблица: entity + raw_json (JSONB)
     │
     ▼  [2] dbt run --select staging
layer_bronze.*         ← stg_moy_sklad__stores, stg_moy_sklad__zones,
     │                    stg_moy_sklad__slots,  stg_moy_sklad__uoms,
     │                    stg_moy_sklad__products, stg_moy_sklad__variants,
     │                    stg_moy_sklad__agents,
     │                    stg_moy_sklad__demand, stg_moy_sklad__supply,
     │                    stg_moy_sklad__loss,   stg_moy_sklad__enter, stg_moy_sklad__move
     ▼  [3] dbt run --select intermediate
layer_silver.*         ← int_operations,
     │                    int_items_union, int_slots_extended,
     │                    int_operations_extended, int_occupancy
     ▼
Grafana дашборды
```

### Расписание

Каждый день в 00:00 МСК (CronSchedule в `deploy.py`).

Запуск вручную: Prefect UI → Deployments → tslots_daily_deploy → Run → Quick Run

---

## Схема layer_raw

Одна таблица `layer_raw.raw`, создаётся Prefect при каждом запуске (`if_exists=replace`):

| Колонка | Тип | Описание |
|---|---|---|
| entity | TEXT | Тип объекта МойСклад: store, uom, product, variant, counterparty, demand, supply, loss, enter, move |
| raw_json | JSONB | Полный JSON объекта из API |

---

## Модели dbt

### layer_bronze — staging

| Модель | Источник в raw | Ключ | Описание |
|---|---|---|---|
| stg_moy_sklad__stores | entity = 'store' | store_id | Склады |
| stg_moy_sklad__zones | entity = 'store' → zones.rows | zone_id | Зоны хранения |
| stg_moy_sklad__slots | entity = 'store' → slots.rows | slot_id | Ячейки хранения |
| stg_moy_sklad__uoms | entity = 'uom' | uom_id | Единицы измерения |
| stg_moy_sklad__products | entity = 'product' | product_id | Номенклатура |
| stg_moy_sklad__variants | entity = 'variant' | variant_id | Варианты (партия, дата) |
| stg_moy_sklad__agents | entity = 'counterparty' | agent_id | Контрагенты / поклажедатели |
| stg_moy_sklad__demand | entity = 'demand' | doc_id + item_id + op_type | Реализации (расход) |
| stg_moy_sklad__supply | entity = 'supply' | doc_id + item_id + op_type | Приёмки (приход) |
| stg_moy_sklad__loss | entity = 'loss' | doc_id + item_id + op_type | Списания (расход) |
| stg_moy_sklad__enter | entity = 'enter' | doc_id + item_id + op_type | Оприходования (приход) |
| stg_moy_sklad__move | entity = 'move' | doc_id + item_id + op_type | Перемещения (две строки на позицию: out + in) |

Все операционные модели — инкрементальные (MERGE по unique_key). Остальные — таблицы.

### layer_silver — intermediate

| Модель | Папка | Описание |
|---|---|---|
| int_operations | general | Единая таблица операций: UNION ALL из 5 staging-таблиц |
| int_items_union | flows | Единый справочник позиций: варианты + товары без вариантов |
| int_slots_extended | flows | Ячейки с денормализованными названиями склада и зоны |
| int_operations_extended | flows | Операции с денормализованными атрибутами позиций и контрагентов |
| int_occupancy | grid | Ежедневная ведомость остатков по ячейкам |

Все модели — таблицы.

---

## Структура проекта

```
tslots/
├── .env.example               ← шаблон — скопируй в .env и заполни
├── .env                       ← секреты (не в git)
├── .gitignore
├── docker-compose.yml         ← вся инфраструктура
├── README.md
│
├── init_db/
│   └── 01_raw_schema.sql      ← создаёт схему layer_raw при первом старте PostgreSQL
│
├── prefect/
│   ├── Dockerfile             ← образ worker: prefect + dbt + зависимости
│   └── flows/
│       ├── api_to_gold.py     ← единственный flow: ingest + dbt
│       └── deploy.py          ← регистрирует deployment и расписание в Prefect
│
├── dbt/
│   └── tslots/
│       ├── dbt_project.yml    ← конфиг проекта, схемы слоёв
│       ├── profiles.yml       ← подключение к PostgreSQL
│       └── models/
│           ├── staging/
│           │   └── moy_sklad/   ← layer_bronze: stg_moy_sklad__*
│           ├── intermediate/
│           │   ├── general/     ← layer_silver: int_operations
│           │   ├── flows/       ← layer_silver: int_items_union, int_slots_extended, int_operations_extended
│           │   └── grid/        ← layer_silver: int_occupancy
│           └── marts/           ← зарезервировано, пусто
│
├── grafana/
│   └── provisioning/
│       ├── datasources/
│       │   └── postgres.yml   ← подключение к PostgreSQL
│       └── dashboards/
│           ├── dashboards.yml
│           └── *.json         ← дашборды (в git, не потеряются)
│
└── test_notebooks/            ← Jupyter для исследования данных
```

---

## Установка с нуля

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

### Шаг 3 — Запусти контейнеры

```bash
docker-compose up -d --build
```

`--build` нужен при первом запуске — собирает образ prefect-worker.
При последующих запусках достаточно `docker-compose up -d`.

При первом запуске PostgreSQL автоматически выполнит `init_db/01_raw_schema.sql`
и создаст схему `layer_raw` — ничего делать вручную не нужно.

Проверь что все контейнеры запустились:
```bash
docker-compose ps
```

Все четыре должны быть в статусе `running`.

### Шаг 4 — Запусти pipeline

Prefect UI → http://localhost:4200 → Deployments → tslots_daily_deploy → Run → Quick Run

Flow выполнит 4 шага: ingest → bronze → silver → gold.
Следи за логами: Flow Runs → последний запуск → Logs.

### Шаг 5 — Grafana

Открой http://localhost:3000
Логин: значения `GRAFANA_USER` и `GRAFANA_PASSWORD` из `.env`

---

## Установка на сервере

Процедура идентична локальной. Отличия:

**`.env`** — боевые пароли и токены.

**Адреса** — вместо `localhost` используй IP сервера:
- Prefect UI: `http://<IP>:4200`
- Grafana: `http://<IP>:3000`

**Firewall** — открой порты 4200 и 3000.

```bash
git clone <url репозитория>
cd tslots
cp .env.example .env
nano .env
docker-compose up -d --build
```

---

## Полезные команды

### Статус контейнеров
```bash
docker-compose ps
```

### Логи
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

### Поднять весь проект
```bash
docker-compose up -d --build
```

### Пересобрать worker после изменений
```bash
docker-compose up -d --build prefect-worker
```

### Запустить конкретную dbt модель
```bash
docker exec -it tslots-prefect-worker bash -c "
  dbt run --select stg_operations \
  --project-dir /app/dbt/tslots \
  --profiles-dir /app/dbt/tslots
"
```

### Пересобрать модель с нуля (--full-refresh)
```bash
docker exec -it tslots-prefect-worker bash -c "
  dbt run --full-refresh --select stg_slots \
  --project-dir /app/dbt/tslots \
  --profiles-dir /app/dbt/tslots
"
```

### Зайти внутрь контейнера
```bash
docker exec -it tslots-prefect-worker bash
docker exec -it tslots-postgres bash
```

---

## Смена паролей

Все секреты хранятся в `.env`. Менять что-то в коде не нужно.

| Переменная | Где используется |
|---|---|
| `DB_PASSWORD` | PostgreSQL, Prefect Server, Prefect Worker, dbt |
| `GRAFANA_PASSWORD` | Grafana UI |
| `MS_TOKEN` | МойСклад API |

### Смена MS_TOKEN или GRAFANA_PASSWORD

1. Измени значение в `.env`
2. Перезапусти нужный контейнер:
```bash
docker-compose restart prefect-worker   # для MS_TOKEN
docker-compose restart grafana          # для GRAFANA_PASSWORD
```

### Смена DB_PASSWORD

1. Смени пароль внутри PostgreSQL:
```bash
docker exec -it tslots-postgres psql -U tslots -d tslots -c "
  ALTER USER tslots PASSWORD 'новый_пароль';
"
```
2. Обнови `.env`
3. Перезапусти зависимые контейнеры:
```bash
docker-compose restart prefect-server prefect-worker grafana
```
