# tslots — Учёт занятости ячеек ответственного хранения

## Описание проекта

МойСклад не хранит историю операций по ячейкам. tslots решает эту задачу:
забирает документы из МойСклад API, строит историю занятости каждой ячейки
и считает ежедневный остаток по каждому слоту.

---

## Какие боли закрывает проект

МойСклад — удобный инструмент для оперативного учёта, но его аналитические возможности ограничены. Ниже — конкретные проблемы складов ответственного хранения и то, как tslots их решает.

### 1. Нет единого отчёта по движению товара с нарастающими остатками

В МойСклад каждый тип операции живёт в отдельном разделе: приёмки, реализации, перемещения, списания, оприходования. Чтобы отследить путь товара и найти причину расхождения, нужно одновременно смотреть несколько разделов и сопоставлять данные вручную. Кроме того, ни в одном из этих разделов нет возможности видеть рядом с каждой операцией входящий остаток, движение и исходящий остаток — как в стандартной карточке складского учёта.

**tslots:** `warehouse__operations_with_balance` — единая таблица всех движений по всем типам документов. Каждая строка содержит `open_slot_balance`, `quantity`, `close_slot_balance` (по конкретной ячейке) и `open_total_balance`, `close_total_balance` (суммарно по товару у агента). Полная картина движений в одном запросе.

### 2. Нельзя построить отчёт по истории занятости ячеек

МойСклад хранит историю операций по ячейкам, но отображает остаток только на конкретную дату — каждый раз вручную. Построить отчёт за период — сколько дней ячейка была занята, каким товаром и каким поклажедателем — невозможно никакими встроенными средствами.

Это критично для ответственного хранения: чтобы выставить клиенту счёт за посуточное хранение в ячейках, нужно знать точное количество ячейко-дней по каждому поклажедателю. Дополнительная сложность — перемещения: когда товар перекладывают из ячейки в ячейку, занятость в день транзита требует отдельной кастомной логики подсчёта, чтобы не исказить итоговый счёт.

**tslots:** `int_balance__agent_slot_item_daily_spine` строит непрерывный ряд дат по каждой тройке (ячейка × агент × товар) с флагом `is_used` и раздельными полями `real_in/out` и `move_in/out`. `warehouse__balance_daily` и `focus__slots_used_monthly` дают готовые отчёты по занятости и агрегаты по месяцам — основу для выставления счетов поклажедателям.

### 3. Нет SQL-доступа к данным

МойСклад предоставляет только REST API для интеграций и экспорт отчётов в Excel. Писать произвольные SQL-запросы к своим данным невозможно.

**tslots:** все данные хранятся в PostgreSQL. Полный SQL-доступ через DBeaver, VS Code или любой другой клиент. Можно строить любые ad-hoc запросы, JOIN-ить витрины между собой, подключать BI-инструменты напрямую к базе.

### 4. Нет механизма предупреждений об аномалиях

В МойСклад нет возможности задать условия для предупреждений об аномальных ситуациях — система не сигнализирует об отрицательном остатке в ячейке, о нескольких разных товарах в одной ячейке или о расхождении фактического остатка с ожидаемым.

**tslots:** `focus__errors_warnings` — отфильтрованные строки с полем `slot_errors`. Поверх этой витрины можно настроить алерты в Lightdash.

---

## Диагностика и предупреждения

### Аномалии операций — поле `slot_errors`

Поле вычисляется в `int_operations_with_balance__agent_slot_item` и присутствует в витринах `warehouse__operations_with_balance` и `focus__errors_warnings`. Вычисляется по каждой операции:

| Значение | Условие | Смысл |
|---|---|---|
| `ERROR: slot overdraft` | `close_slot_balance < 0` | Отрицательный остаток в ячейке — расход превысил приход. Как правило, признак пропущенной операции или ошибки в документе. |
| `WARNING: slot has > 1 items` | `items_in_slot > 1` | В одной ячейке одновременно зафиксированы операции по нескольким разным товарам в этот день. |
| `WARNING: unexpected slot balance` | `close_slot_balance != expected_bin_qty` | Остаток в ячейке не совпадает с ожидаемым (`Кол-во в ячейке` из карточки товара). |
| `NULL` | Всё в норме | Аномалий не обнаружено. |

### Флаг занятости — поле `is_used`

Поле вычисляется в `int_balance__agent_slot_item_daily_spine` и определяет, считается ли ячейка физически занятой в данный день. В финальные витрины попадают только строки с `is_used != 0`.

| Значение | Условие | Смысл |
|---|---|---|
| `1` | `close_slot_balance > 0` | Товар присутствует в ячейке на конец дня. |
| `1` | `(open + real_in + move_in) = -real_out` AND `real_out != 0` | Реальный оборот за один день: товар пришёл и ушёл по реальным операциям (supply/enter/demand/loss), не через внутреннее перемещение. Нетто = 0, но ячейка была физически занята. |
| `2` | `close_slot_balance < 0` | Ошибка данных: отрицательный остаток. Строка попадает в результат для диагностики. |
| `0` | Иначе | Ячейка пуста, строка отбрасывается. |

---

## Требования к аккаунту МойСклад

### Обязательные дополнительные поля у товаров

Для корректной работы tslots у каждого товара в МойСклад должны быть настроены два дополнительных поля с точными названиями:

| Поле | Тип | Описание |
|---|---|---|
| `Поклажедатель` | Справочник [Контрагент] | Контрагент, которому принадлежит товар. Если товар собственный — поклажедатель совпадает с агентом. Поле 1:1 к товару — один товар всегда принадлежит одному поклажедателю. |
| `Кол-во в ячейке` | Число целое | Ориентировочное количество единиц товара в одной ячейке. Используется для диагностики: если фактический остаток в ячейке отличается от этого значения — в отчёте появится `WARNING: unexpected slot balance`. |

Поля создаются в МойСклад: Настройки → Дополнительные поля → Товары.

### С какими сущностями работает tslots

tslots забирает через API и обрабатывает следующие сущности МойСклад:

**Справочники:**

| Сущность | Описание | Поля |
|---|---|---|
| `store` | Склады и их структура (зоны, ячейки) | store_id, name; zone_id, name; slot_id, zone_id, name |
| `uom` | Единицы измерения | uom_id, name |
| `product` | Товары | product_id, name, article, weight, volume, uom_id, **Поклажедатель**, **Кол-во в ячейке** |
| `variant` | Варианты товаров (партия + дата выработки) | variant_id, product_id, lot, mfg_date, barcodes |
| `counterparty` | Контрагенты и поклажедатели | agent_id, name, inn |

**Операционные документы:**

| Документ МойСклад | Описание | Направление |
|---|---|---|
| `supply` | Приёмка | Приход (+) |
| `demand` | Реализация | Расход (−) |
| `enter` | Оприходование | Приход (+) |
| `loss` | Списание | Расход (−) |
| `move` | Перемещение | Две строки на позицию: out (−) из sourceSlot + in (+) в targetSlot |

### Что tslots не обрабатывает

- Цены, себестоимость, финансовые документы (счета, платежи, договоры)
- Заказы покупателей и поставщикам
- Сборочные задания, производственные операции
- **Услуги и наборы** — позиции таких типов отфильтровываются на уровне `int_prep__operations_each` через INNER JOIN на справочник товаров

tslots отслеживает исключительно **движение товаров в разрезе ячеек, контрагентов и поклажедателей**. Всё что не является товаром (`product` или `variant`) в аналитику не попадает.

---

## Карта инфраструктуры

```
┌─────────────────────────────────────────────────────────────────┐
│                   Docker (локально или сервер)                   │
│                                                                  │
│  ┌──────────────┐     ┌─────────────────┐     ┌─────────────┐  │
│  │   postgres   │◄────│ prefect-worker  │     │  lightdash  │  │
│  │   :5432      │◄────│ prefect-server  │     │   :8080     │  │
│  └──────────────┘     │   :4200         │     └──────┬──────┘  │
│         ▲             └─────────────────┘            │          │
│         └────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
          │                     │                    │
    localhost:5432        localhost:4200        localhost:8080
  (VS Code, DBeaver)     (Prefect UI)          (Lightdash UI)

МойСклад API ──► prefect-worker (ingest) ──► postgres (layer_raw)
                 prefect-worker (dbt)    ──► postgres (bronze/silver/gold)
                                                      │
                                                  lightdash
```

### Контейнеры

| Контейнер | Образ | Порт | Роль |
|---|---|---|---|
| tslots-postgres | postgres:16-alpine | 5432 | База данных |
| tslots-prefect-server | prefecthq/prefect:3-python3.11 | 4200 | UI и API Prefect |
| tslots-prefect-worker | prefect/Dockerfile (custom) | — | Выполняет flow и dbt |
| tslots-lightdash | lightdash/lightdash:latest | 8080 | BI-дашборды поверх dbt-моделей |

### Volumes и хранение данных

| Что | Где хранится | `docker-compose down` | `docker-compose down -v` |
|---|---|---|---|
| Данные PostgreSQL | Docker volume `postgres_data` | Сохранятся | **Удалятся** |
| Дашборды Lightdash | В PostgreSQL (`postgres_data`) | Сохранятся | **Удалятся** |
| Кэш Lightdash | Docker volume `lightdash_volume` | Сохранятся | **Удалятся** |
| Код и модели | `tslots/` (в git) | Сохранятся | Сохранятся |
| Секреты | `.env` (не в git) | Сохранятся | Сохранятся |

> **Важно:** Lightdash хранит все дашборды, чарты и сохранённые запросы в PostgreSQL, а не в файлах. `docker-compose down` без флага `-v` сохраняет всё состояние. При `down -v` потребуется повторить первоначальную настройку Lightdash.

### Монтирование папок

```
Твой комп                          Контейнер
──────────────────────────────     ──────────────────────────────
tslots/                      →     /app/                (prefect-worker)
tslots/dbt/                  →     /usr/app/dbt/        (lightdash)
Docker volume postgres_data  →     /var/lib/postgresql/data   (postgres)
Docker volume lightdash_vol  →     /home/lightdash/.lightdash (lightdash)
```

Ты редактируешь файлы в VS Code → prefect-worker и lightdash видят изменения сразу, без перезапуска.

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
layer_silver.*         ← prep: int_prep__operations_united,
     │                         int_prep__items_united_enriched, int_prep__slots_enriched
     │                    int_operations_with_balance__agent_slot_item,
     │                    int_balance__agent_slot_item_daily_spine,
     │                    int_balance__slot_item_daily_spine
     ▼  [4] dbt run --select marts
layer_gold.*           ← warehouse: warehouse__operations_with_balance,
     │                              warehouse__balance_daily,
     │                              warehouse__balance_daily_no_agent
     │                    partners: partners__nrb_stock_movements
     │                    focus:    focus__slots_used_monthly,
     │                              focus__errors_warnings
     ▼
Lightdash дашборды
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
| stg_moy_sklad__demand | entity = 'demand' | doc_id + position_id + op_type | Реализации (расход) |
| stg_moy_sklad__supply | entity = 'supply' | doc_id + position_id + op_type | Приёмки (приход) |
| stg_moy_sklad__loss | entity = 'loss' | doc_id + position_id + op_type | Списания (расход) |
| stg_moy_sklad__enter | entity = 'enter' | doc_id + position_id + op_type | Оприходования (приход) |
| stg_moy_sklad__move | entity = 'move' | doc_id + position_id + op_type | Перемещения (две строки на позицию: out + in) |

Все операционные модели — инкрементальные (MERGE по unique_key). Ключ MERGE использует `position_id` (UUID позиции из МойСклад) — позволяет корректно обрабатывать документы где один товар стоит в нескольких строках. Остальные модели — таблицы.

### layer_silver — intermediate

| Модель | Описание |
|---|---|
| int_prep__operations_united | UNION ALL из 5 staging-таблиц операций |
| int_prep__items_united_enriched | Единый справочник позиций: варианты + товары, с uom, lot, expected_bin_qty, barcodes |
| int_prep__slots_enriched | Ячейки с денормализованными названиями склада и зоны |
| int_operations_with_balance__agent_slot_item | Операции с атрибутами, балансами и slot_errors. INNER JOIN отфильтровывает услуги и наборы |
| int_balance__agent_slot_item_daily_spine | Ежедневная сетка (agent × slot × item × день). Непрерывный ряд дат. Только строки с is_used != 0 |
| int_balance__slot_item_daily_spine | Ежедневная сетка (slot × item × день) без агента. Roll-up поверх agent-spine |

Все модели — таблицы.

### layer_gold — marts

| Папка | Модель | Источник | Описание |
|---|---|---|---|
| warehouse | warehouse__operations_with_balance | int_operations_with_balance__agent_slot_item | Все движения с open/close балансами по ячейке и total, диагностика slot_errors |
| warehouse | warehouse__balance_daily | int_balance__agent_slot_item_daily_spine | Занятые ячейки по дням: балансы и real/move in/out по агенту и поклажедателю |
| warehouse | warehouse__balance_daily_no_agent | int_balance__slot_item_daily_spine | Остаток товара в ячейке по дням без разбивки по агенту, только ненулевые строки |
| partners | partners__nrb_stock_movements | int_operations_with_balance__agent_slot_item | Движения без move, с нарастающим остатком — для поклажедателей |
| focus | focus__slots_used_monthly | int_balance__agent_slot_item_daily_spine | Агрегат занятости ячеек по месяцам в разрезе агентов и поклажедателей |
| focus | focus__errors_warnings | int_operations_with_balance__agent_slot_item | Операции с аномалиями (slot_errors IS NOT NULL) — для мониторинга в Lightdash |

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
│           ├── intermediate/    ← layer_silver:
│           │   ├── prep/           int_prep__operations_united, int_prep__items_united_enriched,
│           │   │                   int_prep__slots_enriched
│           │   └── (корень)        int_operations_with_balance__agent_slot_item,
│           │                       int_balance__agent_slot_item_daily_spine,
│           │                       int_balance__slot_item_daily_spine
│           └── marts/
│               ├── warehouse/   ← warehouse__operations_with_balance,
│               │                   warehouse__balance_daily,
│               │                   warehouse__balance_daily_no_agent
│               ├── partners/    ← partners__nrb_stock_movements
│               └── focus/       ← focus__slots_used_monthly,
│                                   focus__errors_warnings
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
- `LIGHTDASH_SECRET` — любая случайная строка минимум 32 символа
- Пароли PostgreSQL можно оставить как есть для локальной установки

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

### Шаг 5 — Настрой Lightdash (первый раз)

Открой http://localhost:8080

#### 5.1 — Аккаунт и организация

Заполни имя, email, пароль и название организации.

> Эти данные хранятся только в локальной PostgreSQL, никуда не отправляются — можно вводить любые, в том числе несуществующие.

Способ подключения — выбери **Manually**.

#### 5.2 — Подключение к PostgreSQL (Warehouse connection)

Все значения берутся из `.env`:

| Поле | Значение |
|---|---|
| Host | `DB_HOST` из `.env` |
| User | `DB_USER` из `.env` |
| Password | `DB_PASSWORD` из `.env` |
| DB name | `DB_NAME` из `.env` |

Раскрой **Advanced configuration options** → **SSL mode: `disable`**

> SSL отключается потому что Lightdash и PostgreSQL находятся в одной внутренней Docker-сети и общаются напрямую — шифровать внутренний трафик не нужно. PostgreSQL контейнер по умолчанию не настроен на SSL, поэтому попытка подключиться с SSL вызовет ошибку.

#### 5.3 — Подключение к dbt (dbt connection)

| Поле | Значение |
|---|---|
| Type | `dbt local server` |
| dbt version | `v1.10` |
| Target name | оставь пустым — подхватится из `profiles.yml` |
| Schema | `layer_gold` |

> Поле Schema — это схема по умолчанию для новых запросов в Lightdash. Указываем `layer_gold` потому что там находятся финальные витрины (marts) — данные которые используются для отчётов. Модели из других схем (silver, bronze) тоже будут доступны через dbt-манифест.

Нажми **Test & compile project** — Lightdash запустит `dbt compile` и прочитает все модели из проекта.

#### 5.4 — Выбор моделей для проекта

После компиляции Lightdash покажет опции для включения в проект dbt-моделей. Выбери какие из них будут доступны в проекте для построения чартов и дашбордов.

> Это однократная настройка. При последующих `docker-compose up` Lightdash стартует сразу без мастера — состояние хранится в PostgreSQL.
>
> `docker-compose down` без флага `-v` сохраняет всё состояние. `docker-compose down -v` удаляет данные — потребуется пройти мастер заново.

---

## Установка на сервере

Процедура идентична локальной. Отличия:

**`.env`** — боевые пароли, токены и уникальный `LIGHTDASH_SECRET`.

**Адреса** — вместо `localhost` используй IP сервера:
- Prefect UI: `http://<IP>:4200`
- Lightdash: `http://<IP>:8080`

Также обнови `SITE_URL` в `.env` (если добавишь его отдельной переменной) или в `docker-compose.yml`:
```yaml
SITE_URL: http://<IP>:8080
```

**Firewall** — открой порты 4200 и 8080.

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
docker-compose logs -f lightdash
```

### Остановить (данные сохранятся)
```bash
docker-compose down
```

### Удалить всё включая данные БД и дашборды Lightdash
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
  dbt run --select stg_moy_sklad__demand \
  --project-dir /app/dbt/tslots \
  --profiles-dir /app/dbt/tslots
"
```

### Пересобрать модель с нуля (--full-refresh)
```bash
docker exec -it tslots-prefect-worker bash -c "
  dbt run --full-refresh --select stg_moy_sklad__slots \
  --project-dir /app/dbt/tslots \
  --profiles-dir /app/dbt/tslots
"
```

### Зайти внутрь контейнера
```bash
docker exec -it tslots-prefect-worker bash
docker exec -it tslots-postgres bash
docker exec -it tslots-lightdash bash
```

---

## Смена паролей

Все секреты хранятся в `.env`. Менять что-то в коде не нужно.

| Переменная | Где используется |
|---|---|
| `DB_PASSWORD` | PostgreSQL, Prefect Server, Prefect Worker, dbt, Lightdash |
| `LIGHTDASH_SECRET` | Подпись JWT-токенов Lightdash |
| `MS_TOKEN` | МойСклад API |

### Смена MS_TOKEN

1. Измени значение в `.env`
2. Перезапусти worker:
```bash
docker-compose restart prefect-worker
```

### Смена LIGHTDASH_SECRET

1. Измени значение в `.env`
2. Перезапусти Lightdash:
```bash
docker-compose restart lightdash
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
docker-compose restart prefect-server prefect-worker lightdash
```
