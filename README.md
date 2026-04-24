# tslots — Учёт занятости ячеек ответственного хранения

МойСклад не хранит историю операций по ячейкам. tslots решает эту задачу: забирает документы из МойСклад API, строит историю занятости каждой ячейки и считает ежедневный остаток по каждому слоту.

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

**tslots:** `focus__errors_warnings` — отфильтрованные строки с полем `slot_errors`. Поверх этой витрины можно настроить алерты в Metabase.

---

## Полезные команды

### Управление контейнерами

```bash
# Поднять всё
docker-compose up -d --build

# Статус контейнеров
docker-compose ps

# Остановить (данные сохранятся)
docker-compose down

# Удалить всё включая данные БД и дашборды Metabase
docker-compose down -v
```

### Локальные тесты

```bash
# Запустить все тесты через `pipenv` (из корня проекта)
pipenv run dbt test --project-dir dbt/tslots --profiles-dir dbt/tslots
```

### Логи

```bash
docker-compose logs -f prefect-worker
docker-compose logs -f postgres
docker-compose logs -f metabase
docker-compose logs -f nginx
```

### Зайти внутрь контейнера

```bash
docker exec -it tslots-prefect-worker bash
docker exec -it tslots-postgres bash
docker exec -it tslots-metabase bash
docker exec -it tslots-nginx sh
```

### Запустить конкретную dbt модель

```bash
docker exec -it tslots-prefect-worker bash -c "cd /app/dbt/tslots && dbt run --select stg_moy_sklad__demand"
```

### Пересобрать модель с нуля (--full-refresh)

```bash
docker exec -it tslots-prefect-worker bash -c "cd /app/dbt/tslots && dbt run --full-refresh --select stg_moy_sklad__slots"
```

### Смена паролей

Все секреты хранятся в `.env`. Менять что-то в коде не нужно.

#### Проверка — не попал ли .env в git

`.env` есть в `.gitignore`, но на всякий случай проверь историю:
```bash
git log --all --oneline -- .env
```
Если вывод пустой — всё чисто. Если есть коммиты — ротируй токен МойСклад: Настройки → Безопасность → Токены доступа.

| Переменная | Где используется |
|---|---|
| `DB_PASSWORD` | PostgreSQL, Prefect Server, Prefect Worker, dbt, Metabase |
| `MS_TOKEN` | МойСклад API |
| `PREFECT_USER` | Basic Auth в Nginx перед Prefect UI |
| `PREFECT_PASSWORD` | Basic Auth в Nginx перед Prefect UI |
| `SERVER_HOST` | Prefect UI — адрес API для браузера (`localhost` локально, IP сервера на сервере) |

#### Смена MS_TOKEN

1. Измени значение в `.env`
2. Перезапусти worker:
```bash
docker-compose restart prefect-worker
```

#### Смена DB_PASSWORD

1. Смени пароль внутри PostgreSQL:
```bash
docker exec -it tslots-postgres psql -U <DB_USER из .env> -d <DB_NAME из .env> -c "
  ALTER USER <DB_USER из .env> PASSWORD 'новый_пароль';
"
```
2. Обнови `.env`
3. Перезапусти зависимые контейнеры:
```bash
docker-compose restart prefect-server prefect-worker metabase
```

---

## Установка с нуля

### Шаг 1 — Установи Docker

**Windows** — установи [Docker Desktop](https://www.docker.com/products/docker-desktop/). После установки запусти его и убедись что в трее появился значок Docker (он должен быть запущен перед любой командой ниже).

**Linux (сервер Ubuntu):**
```bash
curl -fsSL https://get.docker.com | sh
```

### Шаг 2 — Склонируй репозиторий

Склонируй репозиторий в удобную папку. На сервере рекомендуем `/opt/tslots`:

```bash
# Локально (Windows — выполняй в терминале рядом с Docker Desktop):
# Сначала перейди в папку где хочешь разместить проект, например:
cd C:\Users\<имя>\Desktop
git clone <url репозитория>
cd tslots

# На сервере:
cd /opt
git clone <url репозитория>
cd tslots
```

### Шаг 3 — Создай и заполни .env

```bash
# Локально (Windows):
copy .env.example .env

# Linux / Mac / сервер:
cp .env.example .env
```

**На сервере** отредактируй файл через nano:
```bash
nano .env
```
Управление в nano: редактируй текст как обычно → `Ctrl+O` сохранить → `Enter` подтвердить → `Ctrl+X` выйти.

Что заполнить:

| Переменная | Локально | На сервере |
|---|---|---|
| `MS_TOKEN` | токен из МойСклад | токен из МойСклад |
| `DB_USER` | любое | не `admin`, `postgres`, `user` — смени на что-то нестандартное |
| `DB_PASSWORD` | любое | надёжный пароль — единственная защита от перебора |
| `DB_NAME` | `tslots` | `tslots` |
| `DB_PORT` | `5432` | нестандартный порт из диапазона `49152–65535`, например `58432` |
| `PREFECT_PORT` | `4200` | нестандартный порт, например `54200` |
| `METABASE_PORT` | `3000` | нестандартный порт, например `53000` |
| `SERVER_HOST` | `localhost` | внешний IP или домен сервера |
| `PREFECT_USER` | придумай логин | придумай логин |
| `PREFECT_PASSWORD` | придумай пароль | надёжный пароль |

> **Безопасность PostgreSQL на сервере.** Порт 5432 постоянно сканируется ботами. Нестандартное имя пользователя и порт из диапазона `49152–65535` убирают 99% автоматических атак — боты перебирают стандартные порты и дефолтные логины (`admin`, `postgres`, `user`). Единственная реальная защита — надёжный пароль.

Токен МойСклад: Настройки → Безопасность → Токены доступа.

### Шаг 4 — Открой порты (только на сервере)

```bash
ufw allow <PREFECT_PORT из .env>   # Prefect UI
ufw allow <METABASE_PORT из .env>  # Metabase
ufw allow <DB_PORT из .env>        # PostgreSQL
```

Если сервер в облаке (Hetzner, DigitalOcean, Yandex Cloud) — дополнительно открой эти же порты в панели управления облака в настройках сети/файрвола.

### Шаг 5 — Запусти контейнеры

```bash
docker-compose up -d --build
```

`--build` нужен при первом запуске — собирает образ prefect-worker. При последующих запусках достаточно `docker-compose up -d`.

Проверь что все контейнеры запустились:
```bash
docker-compose ps
```

Все пять должны быть в статусе `running`: postgres, prefect-server, prefect-worker, nginx, metabase.

### Шаг 6 — Настрой Metabase (первый раз)

Открой в браузере:
- Локально: `http://localhost:<METABASE_PORT из .env>`
- На сервере: `http://<IP>:<METABASE_PORT из .env>`

Выбери язык → заполни имя, email, пароль и название организации (данные хранятся только локально, можно вводить любые).

Затем подключи PostgreSQL:

| Поле | Значение |
|---|---|
| Host | `postgres` |
| Port | `5432` |
| Database name | значение `DB_NAME` из `.env` |
| Username | значение `DB_USER` из `.env` |
| Password | значение `DB_PASSWORD` из `.env` |

Нажми **Test connection** → **Save**.

> Это однократная настройка — состояние хранится в PostgreSQL. `docker-compose down` без `-v` сохраняет всё. `docker-compose down -v` удаляет данные — потребуется пройти мастер заново.

#### Добавление пользователей

Кто прошёл мастер настройки — тот администратор. Самостоятельная регистрация закрыта. Чтобы дать доступ другому человеку:

Settings → People → Invite someone → введи email и имя → Save.

Письмо **не отправляется** — передай логин (email) и пароль вручную. Пользователь сможет сменить пароль после входа.

### Шаг 7 — Запусти pipeline

Открой Prefect UI:
- Локально: `http://localhost:<PREFECT_PORT из .env>`
- На сервере: `http://<IP>:<PREFECT_PORT из .env>`

Введи логин и пароль из `.env` (`PREFECT_USER` / `PREFECT_PASSWORD`).

Deployments → tslots_daily_deploy → Run → Quick Run.

Flow выполнит 5 шагов: ingest → bronze → silver → gold → кросс-слойные тесты. Следи за логами: Flow Runs → последний запуск → Logs.

### Подключение к PostgreSQL через DBeaver

`Database → New Database Connection → PostgreSQL`

| Поле | Локально | На сервере |
|---|---|---|
| Host | `localhost` | IP сервера |
| Port | значение `DB_PORT` из `.env` | значение `DB_PORT` из `.env` |
| Database | значение `DB_NAME` из `.env` | значение `DB_NAME` из `.env` |
| Username | значение `DB_USER` из `.env` | значение `DB_USER` из `.env` |
| Password | значение `DB_PASSWORD` из `.env` | значение `DB_PASSWORD` из `.env` |

> На сервере используй надёжный пароль — порт открыт публично.

---

## CI/CD — автодеплой через GitHub Actions

При каждом `git push` в ветку `main` GitHub автоматически заходит на сервер и применяет изменения.

### Как это работает

```
git push → GitHub → Actions runner (Ubuntu VM) → SSH → сервер → git pull + docker-compose up -d
```

1. Ты пушишь в `main` — GitHub видит событие и запускает workflow
2. GitHub поднимает чистую виртуальную машину (runner)
3. Runner берёт SSH-ключ из зашифрованного хранилища Secrets и подключается к серверу
4. На сервере выполняется `git pull` и `docker-compose up -d`
5. Runner уничтожается — следующий деплой получит чистую машину

Секреты (ключ, IP, пользователь) хранятся только на стороне GitHub, в коде не появляются.

### Настройка (один раз)

**1. На сервере** — сгенерируй SSH-ключ специально для GitHub Actions:
```bash
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github_actions
cat ~/.ssh/github_actions.pub >> ~/.ssh/authorized_keys
cat ~/.ssh/github_actions  # скопируй вывод — это приватный ключ
```

**2. В GitHub** — добавь Secrets: репозиторий → Settings → Secrets and variables → Actions → New repository secret:

| Secret | Значение |
|---|---|
| `SSH_PRIVATE_KEY` | приватный ключ из шага 1 (весь текст включая `-----BEGIN...`) |
| `SSH_HOST` | IP сервера |
| `SSH_USER` | пользователь на сервере — узнать командой `whoami` на сервере |

**3. Активируй workflow** — файл `deploy.yml` уже готов, но пока отключён: папка называется `.github_disabled/workflows/` вместо `.github/workflows/`. GitHub ищет workflow-файлы только в `.github/workflows/` — папки с другим именем игнорирует.

Чтобы активировать:
- Переименуй папку `.github_disabled` → `.github` и закоммить
- Убедись что у Personal Access Token (которым пушишь) включён scope **workflow**: GitHub → Settings → Developer settings → Personal access tokens → Edit → поставить галочку `workflow`

После этого каждый `git push` в `main` деплоит на сервер автоматически. Статус запуска виден в GitHub → Actions.

> `.env` не в git — изменения в нём вносятся на сервере вручную через `nano /opt/tslots/.env` и применяются отдельным `docker-compose up -d`.

---

## Бэкап базы данных

Все данные хранятся в Docker volume `postgres_data`. Потеря диска без бэкапа = потеря всего.

### Как работает бэкап

Скрипт `scripts/backup.sh` делает `pg_dump` внутри контейнера и сохраняет дамп в `/var/backups/tslots/`. Дампы старше `BACKUP_KEEP_DAYS` дней удаляются автоматически.

### Настройка (один раз на сервере)

**1. Сделай скрипт исполняемым:**
```bash
chmod +x /opt/tslots/scripts/backup.sh
```

**2. Добавь в cron** (запуск каждый день в 03:00):
```bash
crontab -e
```
Добавь строку:
```
0 3 * * * /opt/tslots/scripts/backup.sh >> /opt/tslots/scripts/backup.log 2>&1
```

**3. Проверь что работает:**
```bash
/opt/tslots/scripts/backup.sh
ls /var/backups/tslots/
```

### Восстановление из дампа

```bash
# Скопируй нужный дамп в контейнер и восстанови
docker cp /var/backups/tslots/<файл>.dump tslots-postgres:/tmp/restore.dump
docker exec -it tslots-postgres pg_restore -U <DB_USER из .env> -d <DB_NAME из .env> -c /tmp/restore.dump
```

### Параметры ротации

| Параметр | Значение по умолчанию | Где менять |
|---|---|---|
| Папка бэкапов | `/var/backups/tslots/` | `scripts/backup.sh` → `BACKUP_DIR` |
| Хранить дней | `7` | `.env` → `BACKUP_KEEP_DAYS` |
| Время запуска | `03:00` | `crontab -e` |

---

## Бизнес-тесты

### Что такое бизнес-тест в dbt

Тест — это SQL-файл в `dbt/tslots/tests/` с именем вида `assert_*.sql`. Запрос внутри файла должен возвращать строки, **нарушающие** некоторый инвариант. Логика инвертирована: если всё в порядке — запрос вернёт ноль строк, тест пройден. Любые строки в результате означают нарушение, тест падает.

### Алгоритм написания нового теста

**1. Определи инвариант** — сформулируй утверждение, которое должно быть истинным для любой строки данных. Хорошие источники инвариантов:

- **Арифметика** — `close = open + quantity` (баланс всегда равен сумме движений)
- **Временна́я непрерывность** — открытие следующего дня равно закрытию текущего
- **Консистентность агрегатов** — total по товару одинаков во всех строках одного дня
- **Допустимые значения** — флаг принимает только ожидаемые значения
- **Фильтрация** — отброшенные строки не должны пробраться в финальную витрину

**2. Напиши SQL-запрос на нарушение** — пишешь `WHERE close != open + quantity`, а не `WHERE close = open + quantity`. Используй `{{ ref('имя_модели') }}` вместо прямого названия таблицы — dbt сам подставит нужную схему.

```sql
-- Пример: close_slot_balance должен равняться open_slot_balance + quantity
SELECT slot_id, agent_id, item_id, moment_day
FROM {{ ref('int_balance__agent_slot_item_daily_spine') }}
WHERE close_slot_balance != open_slot_balance + quantity
```

**3. Сохрани файл** в `dbt/tslots/tests/assert_<что_проверяет>.sql`. Название файла — это название теста, который появится в выводе `dbt test`.

**4. Проверь локально** (перед тем как коммитить):
```bash
cd dbt/tslots
pipenv run dbt test --profiles-dir . --select assert_<имя_теста>
```

### Текущие тесты

**Операционная модель** (`int_operations_with_balance__agent_slot_item`):

| Тест | Что проверяет |
|---|---|
| `assert_operations_close_equals_open_plus_quantity` | `close_slot_balance = open_slot_balance + quantity` на уровне каждой операции (до агрегации по дням) |
| `assert_operations_real_in_nonnegative` | `real_in >= 0` — физический приход никогда не отрицателен |
| `assert_operations_real_out_nonpositive` | `real_out <= 0` — физический расход никогда не положителен |
| `assert_operations_total_balance_continuity` | `open_total_balance` каждой строки равен `close_total_balance` предыдущей в той же партиции `(agent_id, item_id)` — нарастающий остаток без разрывов |
| `assert_operations_depositor_id_not_null` | `depositor_id` не `NULL` ни в одной операции — критично для биллинга ответственного хранения |

**Ежедневный spine по агентам** (`int_balance__agent_slot_item_daily_spine`):

| Тест | Что проверяет |
|---|---|
| `assert_agent_spine_close_equals_open_plus_quantity` | `close_slot_balance = open_slot_balance + quantity` по каждой тройке (slot, agent, item, day) |
| `assert_agent_spine_open_equals_prev_close` | открытие следующего дня равно закрытию предыдущего (временна́я непрерывность) |
| `assert_agent_spine_total_balance_consistent_per_day` | `close_total_balance` одинаков для всех слотов одного `(agent, item, day)` — проверяет корректность RANGE-окна |
| `assert_agent_spine_is_used_valid_values` | `is_used` принимает только значения 1 или 2 (0 отфильтрован на уровне модели) |
| `assert_agent_spine_quantity_equals_parts` | `quantity = real_in + real_out + move_in + move_out` — декомпозиция движений не теряет данных |
| `assert_agent_spine_move_directions_valid` | `move_in >= 0` и `move_out <= 0` — направление memo-перемещений соответствует знаку |
| `assert_agent_spine_no_future_dates` | `moment_day <= CURRENT_DATE` — generate_series не уходит в будущее |
| `assert_agent_spine_negative_close_only_is_used_2` | отрицательный `close_slot_balance` допустим только при `is_used = 2` (ошибка данных) |
| `assert_agent_spine_no_duplicate_grain` | каждая комбинация (slot, agent, item, day) встречается ровно один раз |

**Ежедневный spine без агента** (`int_balance__slot_item_daily_spine`):

| Тест | Что проверяет |
|---|---|
| `assert_slot_spine_close_equals_open_plus_quantity` | `close_slot_balance = open_slot_balance + quantity` для spine без агента |
| `assert_slot_spine_open_equals_prev_close` | открытие следующего дня равно закрытию предыдущего (для spine без агента) |
| `assert_slot_spine_total_balance_consistent_per_day` | `close_total_balance` одинаков для всех слотов одного `(item, day)` |

**Витрины** (gold):

| Тест | Что проверяет |
|---|---|
| `assert_warehouse_balance_daily_no_zero_is_used` | строки с `is_used = 0` не должны попасть в финальную витрину |
| `assert_errors_warnings_no_null_slot_errors` | в витрине `focus__errors_warnings` нет строк с `NULL` в поле `slot_errors` |
| `assert_partners_no_move_doc_type` | в `partners__nrb_stock_movements` нет строк с `doc_type = 'move'` (memo-перемещения исключены) |

**Кросс-табличные** (целостность потока данных между слоями):

| Тест | Что проверяет |
|---|---|
| `assert_audit_no_duplicate_doc_id` | каждый `doc_id` встречается в `int_prep__audit_united_enriched` ровно один раз — дедупликация по последнему событию корректна |
| `assert_cross__operations_cleaned_leq_united` | количество строк в `int_prep__operations_united_cleaned` не превышает `int_prep__operations_united` — фильтрация удалённых только убирает строки, не дублирует |
| `assert_cross__united_count_matches_staging` | количество строк в `int_prep__operations_united` равно сумме строк во всех 5 staging-таблицах — UNION ALL не теряет и не дублирует операции |
| `assert_cross__agent_spine_qty_matches_operations` | `quantity` в `int_balance__agent_slot_item_daily_spine` равна сумме `quantity` из `int_operations_with_balance__agent_slot_item` по зерну (slot, agent, item, day) |
| `assert_cross__agent_spine_real_matches_operations` | `real_in` и `real_out` в agent_spine равны суммам из operations по зерну — физические движения не искажаются при агрегации по дням |
| `assert_cross__slot_spine_qty_matches_agent_spine` | `quantity` в `int_balance__slot_item_daily_spine` равна сумме `quantity` из agent_spine по зерну (slot, item, day) — roll-up по агентам не теряет данных |
| `assert_cross__slot_grains_covered_by_agent_spine` | каждое зерно (slot, item, day) из slot_spine присутствует хотя бы в одной строке agent_spine — данные в slot_spine всегда прослеживаются до конкретного агента |
| `assert_cross__warehouse_ops_count_matches_int_operations` | количество строк в `warehouse__operations_with_balance` равно количеству строк в `int_operations_with_balance__agent_slot_item` — витрина не фильтрует и не дублирует строки |
| `assert_cross__partners_count_matches_ops_non_move` | количество строк в `partners__nrb_stock_movements` равно количеству строк в int_operations с фильтром `doc_type != 'move'` — memo-перемещения корректно исключены |
| `assert_cross__operations_slot_id_exists_in_slots` | каждый `slot_id` в операциях (кроме `off_slot`) присутствует в справочнике ячеек — нет ссылок на удалённые ячейки |

### Запуск тестов

**В Docker** (production-окружение):
```bash
# все тесты
docker exec -it tslots-prefect-worker bash -c "cd /app/dbt/tslots && dbt test"

# только бизнес-тесты из папки tests/
docker exec -it tslots-prefect-worker bash -c "cd /app/dbt/tslots && dbt test --select test_type:singular"

# только intermediate-слой
docker exec -it tslots-prefect-worker bash -c "cd /app/dbt/tslots && dbt test --select intermediate"
```

**Локально** (если dbt установлен через `pipenv`):
```bash
# все тесты (из корня проекта)
pipenv run dbt test --project-dir dbt/tslots --profiles-dir dbt/tslots

# только бизнес-тесты из папки tests/
pipenv run dbt test --project-dir dbt/tslots --profiles-dir dbt/tslots --select test_type:singular

# один конкретный тест
pipenv run dbt test --project-dir dbt/tslots --profiles-dir dbt/tslots --select assert_agent_spine_close_equals_open_plus_quantity
```

`--profiles-dir .` нужен потому что `profiles.yml` лежит в папке проекта, а не в стандартном `~/.dbt/`.

> **Важно:** перед запуском тестов локально убедись что модели пересчитаны свежим `dbt run`. Тесты проверяют данные которые уже лежат в базе — если модели не обновлялись после изменений в SQL, тесты проверяют устаревшие данные.

### Когда запускаются автоматически

Flow вызывает `dbt run + dbt test` для каждого слоя последовательно. Тесты на intermediate-модели запускаются в шаге `[3]`, тесты на золотой слой — в шаге `[4]`. Кросс-слойные тесты (сравнение gold vs silver) выделены в отдельный шаг `[5]` — они корректны только после того как все три слоя пересобраны.

Если тест не проходит — flow завершается с ошибкой, следующие шаги не выполняются. Данные при этом уже пересчитаны (`dbt run` прошёл успешно), но pipeline сигнализирует о нарушении бизнес-логики. Смотреть детали: Prefect UI → Flow Runs → последний запуск → Logs.

---

## Описание проекта

Этот раздел — полный технический и бизнес-контекст для разработчика или языковой модели, которой нужно разобраться в проекте с нуля: что откуда берётся, как преобразуется, что означают конкретные поля и почему бизнес-логика реализована именно так.

### Инфраструктура

```
┌─────────────────────────────────────────────────────────────────┐
│                   Docker (локально или сервер)                   │
│                                                                  │
│  ┌──────────────┐     ┌─────────────────┐     ┌─────────────┐  │
│  │   postgres   │◄────│ prefect-worker  │     │  metabase   │  │
│  │   :5432      │◄────│ prefect-server  │     │   :3000     │  │
│  └──────────────┘     │   (internal)    │     └──────┬──────┘  │
│         ▲             └────────┬────────┘            │          │
│         │                     ▼                      │          │
│         │              ┌─────────────┐               │          │
│         │              │    nginx    │               │          │
│         │              │   :4200     │               │          │
│         │              └─────────────┘               │          │
│         └────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
          │                     │                    │
  localhost:<DB_PORT>      localhost:<PREFECT_PORT>   localhost:<METABASE_PORT>
  (VS Code, DBeaver)     (Prefect UI, Basic Auth)   (Metabase UI)
                    (порты из .env)

МойСклад API ──► prefect-worker (ingest) ──► postgres (layer_raw)
                 prefect-worker (dbt)    ──► postgres (bronze/silver/gold)
                                                      │
                                                  metabase
```

#### Контейнеры

| Контейнер | Образ | Порт | Роль |
|---|---|---|---|
| tslots-postgres | postgres:16-alpine | 5432 | База данных |
| tslots-prefect-server | prefecthq/prefect:3-python3.11 | — | UI и API Prefect (только внутри Docker-сети) |
| tslots-nginx | nginx:stable-alpine (custom) | PREFECT_PORT из .env | Basic Auth перед Prefect UI |
| tslots-prefect-worker | prefect/Dockerfile (custom) | — | Выполняет flow и dbt |
| tslots-metabase | metabase/metabase:v0.58.13 | METABASE_PORT из .env | BI-дашборды поверх PostgreSQL |

#### Volumes и хранение данных

| Что | Где хранится | `docker-compose down` | `docker-compose down -v` |
|---|---|---|---|
| Данные PostgreSQL | Docker volume `postgres_data` | Сохранятся | **Удалятся** |
| Дашборды Metabase | В PostgreSQL (`postgres_data`) | Сохранятся | **Удалятся** |
| Код и модели | `tslots/` (в git) | Сохранятся | Сохранятся |
| Секреты | `.env` (не в git) | Сохранятся | Сохранятся |

> **Важно:** Metabase хранит все дашборды, вопросы и пользователей в PostgreSQL, а не в файлах. `docker-compose down` без флага `-v` сохраняет всё состояние. При `down -v` потребуется повторить первоначальную настройку Metabase.

#### Монтирование папок

```
Твой комп                          Контейнер
──────────────────────────────     ──────────────────────────────
tslots/                      →     /app/                (prefect-worker)
Docker volume postgres_data  →     /var/lib/postgresql/data   (postgres)
```

Ты редактируешь файлы в VS Code → prefect-worker видит изменения сразу, без перезапуска. Metabase монтирование не требует.

---

### Pipeline

Один flow `api-to-gold` — 5 шагов строго последовательно:

```
МойСклад API
     │
     ▼  [1] ingest — Python/pandas → pg8000
layer_raw.raw          ← одна таблица: entity + raw_json (JSONB)
     │
     ▼  [2] dbt run + test --select staging
bronze.*               ← stg_moy_sklad__stores, stg_moy_sklad__zones,
     │                    stg_moy_sklad__slots,  stg_moy_sklad__uoms,
     │                    stg_moy_sklad__products, stg_moy_sklad__variants,
     │                    stg_moy_sklad__agents,
     │                    stg_moy_sklad__demand, stg_moy_sklad__supply,
     │                    stg_moy_sklad__loss,   stg_moy_sklad__enter, stg_moy_sklad__move,
     │                    stg_moy_sklad__audit_deleted, stg_moy_sklad__audit_restored
     ▼  [3] dbt run + test --select intermediate
silver.*               ← prep: int_prep__operations_united,
     │                         int_prep__audit_united_enriched,
     │                         int_prep__operations_united_cleaned,
     │                         int_prep__items_united_enriched,
     │                         int_prep__slots_and_zones
     │                    int_operations_with_balance__agent_slot_item,
     │                    int_balance__agent_slot_item_daily_spine,
     │                    int_balance__slot_item_daily_spine
     ▼  [4] dbt run + test --select marts
gold.*                 ← warehouse: warehouse__operations_with_balance,
     │                              warehouse__balance_daily,
     │                              warehouse__balance_daily_no_agent
     │                    partners: partners__nrb_stock_movements
     │                    focus:    focus__slots_used_monthly,
     │                              focus__errors_warnings
     ▼  [5] dbt test --select tag:cross_layer
кросс-слойные тесты    ← warehouse vs int_operations, partners vs int_operations non-move
     ▼
Metabase дашборды
```

Расписание: каждый день в 00:00 МСК (CronSchedule в `deploy.py`).

Запуск вручную: Prefect UI → Deployments → tslots_daily_deploy → Run → Quick Run.

---

### Требования к аккаунту МойСклад

#### Обязательные дополнительные поля у товаров

Для корректной работы tslots у каждого товара в МойСклад должны быть настроены два дополнительных поля с точными названиями:

| Поле | Тип | Описание |
|---|---|---|
| `Поклажедатель` | Справочник [Контрагент] | Контрагент, которому принадлежит товар. Если товар собственный — поклажедатель совпадает с агентом. Поле 1:1 к товару — один товар всегда принадлежит одному поклажедателю. |
| `Кол-во в ячейке` | Число целое | Ориентировочное количество единиц товара в одной ячейке. Используется для диагностики: если фактический остаток в ячейке отличается от этого значения — в отчёте появится `WARNING: unexpected slot balance`. |

Поля создаются в МойСклад: Настройки → Дополнительные поля → Товары.

#### С какими сущностями работает tslots

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

#### Что tslots не обрабатывает

- Цены, себестоимость, финансовые документы (счета, платежи, договоры)
- Заказы покупателей и поставщикам
- Сборочные задания, производственные операции
- **Услуги и наборы** — позиции таких типов отфильтровываются на уровне `int_operations_with_balance__agent_slot_item` через INNER JOIN на справочник товаров

tslots отслеживает исключительно **движение товаров в разрезе ячеек, контрагентов и поклажедателей**. Всё что не является товаром (`product` или `variant`) в аналитику не попадает.

---

### Слой layer_raw

Одна таблица `layer_raw.raw`, создаётся Prefect при каждом запуске (`if_exists=replace`). Схема `layer_raw` создаётся автоматически (`CREATE SCHEMA IF NOT EXISTS`) в начале flow — до первой записи данных.

| Колонка | Тип | Описание |
|---|---|---|
| entity | TEXT | Тип объекта МойСклад: store, uom, product, variant, counterparty, demand, supply, loss, enter, move, audit_deleted, audit_restored |
| raw_json | JSONB | Полный JSON объекта из API |

---

### Слой bronze — staging

#### Модели

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
| stg_moy_sklad__audit_deleted | entity = 'audit_deleted' | doc_id + event_type + moment | Документы помещённые в корзину МойСклад |
| stg_moy_sklad__audit_restored | entity = 'audit_restored' | doc_id + event_type + moment | Документы восстановленные из корзины МойСклад |

Все операционные модели — инкрементальные (MERGE по unique_key). Ключ MERGE использует `position_id` (UUID позиции из МойСклад) — позволяет корректно обрабатывать документы где один товар стоит в нескольких строках. Остальные модели — таблицы.

#### Ключевые поля движений

Каждая операционная модель содержит поля `quantity`, `doc_type`, `op_type`. Из них в intermediate-слое производятся `real_in`, `real_out`, `move_in`, `move_out`. Понимание их различий принципиально для всей бизнес-логики:

| Поле | Что содержит | Условие |
|---|---|---|
| `quantity` | Чистое количество операции (всегда равно real_in + real_out + move_in + move_out) | Все документы |
| `real_in` | Физический приход на склад | `doc_type != 'move'` AND `quantity > 0` |
| `real_out` | Физический расход со склада | `doc_type != 'move'` AND `quantity < 0` |
| `move_in` | Memo-приход (товар переехал в ячейку) | `doc_type = 'move'` AND `quantity > 0` |
| `move_out` | Memo-расход (товар переехал из ячейки) | `doc_type = 'move'` AND `quantity < 0` |

Разделение на real и move важно потому что внутренние перемещения (`move`) — это не реальное движение товара на/со склада, а его переезд между ячейками. При суммировании по всем ячейкам склада `move_in` и `move_out` взаимно погашаются — товар остался на складе. Поля `real_in`/`real_out` отражают только физический приход от клиента и отгрузку клиенту.

---

### Слой silver — intermediate

| Модель | Описание |
|---|---|
| int_prep__operations_united | UNION ALL из 5 staging-таблиц операций |
| int_prep__audit_united_enriched | Актуальный статус документов из аудита МойСклад. UNION deleted + restored, берётся последнее событие по doc_id |
| int_prep__operations_united_cleaned | Операции без удалённых документов. Исключает строки чьи doc_id помечены как 'deleted' в аудите |
| int_prep__items_united_enriched | Единый справочник позиций: варианты + товары, с uom, lot, expected_bin_qty |
| int_prep__slots_and_zones | Ячейки с денормализованными названиями зоны |
| int_operations_with_balance__agent_slot_item | Операции с атрибутами, балансами и slot_errors. INNER JOIN отфильтровывает услуги и наборы |
| int_balance__agent_slot_item_daily_spine | Ежедневная сетка (agent × slot × item × день). Непрерывный ряд дат. Только строки с is_used != 0 |
| int_balance__slot_item_daily_spine | Ежедневная сетка (slot × item × день) без агента. Roll-up поверх agent-spine |

Все модели — таблицы.

#### Операционная модель с балансами

`int_operations_with_balance__agent_slot_item` — каждая строка одна операция. Здесь считаются нарастающие балансы по операции (не по дням):

- `open_slot_balance` — накопленное количество в ячейке строго до текущей операции (`ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING`, упорядочено по моменту операции)
- `close_slot_balance` — после текущей операции (`CURRENT ROW`)
- `open_total_balance` и `close_total_balance` — то же самое, но суммарно по товару у агента (`PARTITION BY agent_id, item_id`), только по real-движениям

**off_slot.** Если в документе МойСклад не указана ячейка, операция получает `slot_id = 'off_slot'`, `slot_name = 'off_slot'`, `zone_name = 'off_slot'`. Это виртуальная «мусорная» ячейка: она образует собственную партицию в оконных функциях, поэтому её баланс никак не смешивается с реальными слотами. В поле `slot_errors` такие строки автоматически получают `WARNING: Out-of-slot operation`. Фильтровать off_slot в витринах можно по `slot_id != 'off_slot'` или по отсутствию этого предупреждения в `slot_errors`.

Здесь же рассчитывается `slot_errors` — диагностическое поле. Формируется через `CONCAT_WS(' | ', ...)` — одна строка может содержать несколько предупреждений одновременно, разделённых ` | `. Пустая строка `''` означает отсутствие аномалий.

| Значение | Условие | Смысл |
|---|---|---|
| `ERROR: slot overdraft` | `close_slot_balance < 0` | Отрицательный остаток в ячейке — расход превысил приход. Как правило, признак пропущенной операции или ошибки в документе. |
| `WARNING: slot has > 1 items` | `items_in_slot > 1` | В одной ячейке одновременно зафиксированы операции по нескольким разным товарам в этот день. |
| `WARNING: unexpected slot balance` | `close_slot_balance != expected_bin_qty` | Остаток в ячейке не совпадает с ожидаемым (`Кол-во в ячейке` из карточки товара). |
| `WARNING: Out-of-slot operation` | `slot_id = 'off_slot'` | Операция проведена без указания ячейки. Такие операции группируются в условную ячейку `off_slot` и не влияют на остатки реальных слотов. |
| `''` (пустая строка) | Всё в норме | Аномалий не обнаружено. |

#### Ежедневный spine — ключевая модель проекта

`int_balance__agent_slot_item_daily_spine` строит **непрерывный ряд дат** по каждой тройке (slot × agent × item) — от первой операции до сегодня. Дни без операций заполняются нулями. Это позволяет считать ячейко-дни для выставления счетов.

Алгоритм построения внутри модели:

1. **daily_agg** — агрегирует операции по зерну (slot, agent, item, store, day): суммирует quantity, real_in, real_out, move_in, move_out
2. **grain** — уникальные тройки зерна с датой первой операции (`MIN(moment_day)`)
3. **grid** — декартово произведение: каждая тройка × каждый день от первой даты до сегодня (`generate_series`)
4. **daily_balances** — LEFT JOIN grid с daily_agg, считает нарастающие балансы через оконные функции; дни без операций дают NULL от JOIN, который закрывается через COALESCE
5. **daily_with_flag** — добавляет `is_used`
6. Финальный SELECT — JOIN с таблицами атрибутов (агенты, ячейки, товары); WHERE отбрасывает строки с `is_used = 0`

**Почему RANGE, а не ROWS для total_balance.** Оконные функции `open_total_balance` и `close_total_balance` используют `RANGE BETWEEN`, а не `ROWS BETWEEN`. Это принципиально: когда у одного (agent, item) на один день приходится несколько слотов, `ROWS BETWEEN` обрабатывает строки по одной и каждый слот получает разный накопленный итог. `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` включает все строки с одинаковым `moment_day` в одно окно — все слоты одного дня получают одинаковый `close_total_balance`. Для `open_total_balance` используется `RANGE BETWEEN UNBOUNDED PRECEDING AND INTERVAL '1 day' PRECEDING` — всё строго до текущей даты при ORDER BY по date.

**Флаг is_used** определяет, считать ли ячейку физически занятой в данный день:

| Значение | Условие | Смысл |
|---|---|---|
| `1` | `close_slot_balance > 0` | Товар присутствует в ячейке на конец дня |
| `1` | `(open_slot_balance + real_in + move_in) = -real_out` AND `real_out != 0` | Реальный оборот за один день: товар пришёл и ушёл по реальным операциям. Нетто = 0, но ячейка была физически занята |
| `2` | `close_slot_balance < 0` | Ошибка данных — отрицательный остаток. Строка попадает в витрину для диагностики |
| `0` | Иначе | Ячейка пуста — строка отбрасывается в WHERE финального SELECT |

`int_balance__slot_item_daily_spine` — roll-up поверх agent-spine. GROUP BY (slot × item × day), суммируя по всем агентам. Балансы пересчитываются на новом зерне. Используется для витрины без разбивки по агенту.

---

### Слой gold — marts

| Папка | Модель | Источник | Описание |
|---|---|---|---|
| warehouse | warehouse__operations_with_balance | int_operations_with_balance__agent_slot_item | Все движения с open/close балансами по ячейке и total, диагностика slot_errors |
| warehouse | warehouse__balance_daily | int_balance__agent_slot_item_daily_spine | Занятые ячейки по дням: балансы и real/move in/out по агенту и поклажедателю |
| warehouse | warehouse__balance_daily_no_agent | int_balance__slot_item_daily_spine | Остаток товара в ячейке по дням без разбивки по агенту, только ненулевые строки |
| partners | partners__nrb_stock_movements | int_operations_with_balance__agent_slot_item | Движения без move, с нарастающим остатком — для поклажедателей |
| focus | focus__slots_used_monthly | int_balance__agent_slot_item_daily_spine | Агрегат занятости ячеек по месяцам в разрезе агентов и поклажедателей |
| focus | focus__errors_warnings | int_operations_with_balance__agent_slot_item | Операции с аномалиями (slot_errors IS NOT NULL) — для мониторинга в Metabase |

Все модели — таблицы.

---

### Структура проекта

```
tslots/
├── .env.example               ← шаблон — скопируй в .env и заполни
├── .env                       ← секреты (не в git)
├── .gitignore
├── docker-compose.yml         ← вся инфраструктура
├── README.md
│
├── nginx/
│   ├── Dockerfile             ← образ nginx с apache2-utils для htpasswd
│   └── nginx.conf             ← Basic Auth перед Prefect UI
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
│       ├── macros/
│       │   └── generate_schema_name.sql  ← схемы без префиксов: bronze/silver/gold
│       ├── tests/
│       │   └── assert_*.sql   ← бизнес-тесты на инварианты
│       └── models/
│           ├── staging/
│           │   └── moy_sklad/   ← bronze: stg_moy_sklad__*
│           ├── intermediate/    ← silver:
│           │   ├── prep/           int_prep__operations_united,
│           │   │                   int_prep__audit_united_enriched,
│           │   │                   int_prep__operations_united_cleaned,
│           │   │                   int_prep__items_united_enriched,
│           │   │                   int_prep__slots_and_zones
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
└── test_notebooks/
    └── get_jsons.py           ← отладка: запрашивает все сущности API и сохраняет JSON в temp/raw_json/
```
