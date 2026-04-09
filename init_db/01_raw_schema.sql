-- =============================================================================
-- RAW LAYER — tslots
-- Сырые JSON-ответы от МойСклад API.
-- Принцип: храним всё как есть, ничего не теряем.
-- dbt потом вытащит нужные поля через JSONB-операторы.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS raw_moysklad;

-- STORES — склады со списком зон и ячеек
CREATE TABLE IF NOT EXISTS raw_moysklad.stores (
    ms_id        TEXT        NOT NULL,
    raw_json     JSONB       NOT NULL,
    loaded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_batch   TIMESTAMPTZ NOT NULL,
    CONSTRAINT stores_pkey PRIMARY KEY (ms_id)
);
CREATE INDEX IF NOT EXISTS stores_loaded_at_idx ON raw_moysklad.stores (loaded_at);
CREATE INDEX IF NOT EXISTS stores_raw_gin       ON raw_moysklad.stores USING GIN (raw_json);

-- UOM — единицы измерения
CREATE TABLE IF NOT EXISTS raw_moysklad.uoms (
    ms_id        TEXT        NOT NULL,
    raw_json     JSONB       NOT NULL,
    loaded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_batch   TIMESTAMPTZ NOT NULL,
    CONSTRAINT uoms_pkey PRIMARY KEY (ms_id)
);
CREATE INDEX IF NOT EXISTS uoms_loaded_at_idx ON raw_moysklad.uoms (loaded_at);

-- PRODUCTS — товары
CREATE TABLE IF NOT EXISTS raw_moysklad.products (
    ms_id        TEXT        NOT NULL,
    raw_json     JSONB       NOT NULL,
    loaded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_batch   TIMESTAMPTZ NOT NULL,
    CONSTRAINT products_pkey PRIMARY KEY (ms_id)
);
CREATE INDEX IF NOT EXISTS products_loaded_at_idx ON raw_moysklad.products (loaded_at);
CREATE INDEX IF NOT EXISTS products_raw_gin       ON raw_moysklad.products USING GIN (raw_json);

-- VARIANTS — модификации товаров (партии, даты выработки)
CREATE TABLE IF NOT EXISTS raw_moysklad.variants (
    ms_id        TEXT        NOT NULL,
    raw_json     JSONB       NOT NULL,
    loaded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_batch   TIMESTAMPTZ NOT NULL,
    CONSTRAINT variants_pkey PRIMARY KEY (ms_id)
);
CREATE INDEX IF NOT EXISTS variants_loaded_at_idx ON raw_moysklad.variants (loaded_at);
CREATE INDEX IF NOT EXISTS variants_raw_gin       ON raw_moysklad.variants USING GIN (raw_json);

-- AGENTS — контрагенты (поклажедатели)
CREATE TABLE IF NOT EXISTS raw_moysklad.agents (
    ms_id        TEXT        NOT NULL,
    raw_json     JSONB       NOT NULL,
    loaded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_batch   TIMESTAMPTZ NOT NULL,
    CONSTRAINT agents_pkey PRIMARY KEY (ms_id)
);
CREATE INDEX IF NOT EXISTS agents_loaded_at_idx ON raw_moysklad.agents (loaded_at);

-- DEMANDS — отгрузки (товар уходит со склада)
CREATE TABLE IF NOT EXISTS raw_moysklad.demands (
    ms_id        TEXT        NOT NULL,
    raw_json     JSONB       NOT NULL,
    loaded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_batch   TIMESTAMPTZ NOT NULL,
    CONSTRAINT demands_pkey PRIMARY KEY (ms_id)
);
CREATE INDEX IF NOT EXISTS demands_loaded_at_idx ON raw_moysklad.demands (loaded_at);
CREATE INDEX IF NOT EXISTS demands_moment_idx    ON raw_moysklad.demands ((raw_json->>'moment'));

-- SUPPLIES — приёмки (товар приходит на склад)
CREATE TABLE IF NOT EXISTS raw_moysklad.supplies (
    ms_id        TEXT        NOT NULL,
    raw_json     JSONB       NOT NULL,
    loaded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_batch   TIMESTAMPTZ NOT NULL,
    CONSTRAINT supplies_pkey PRIMARY KEY (ms_id)
);
CREATE INDEX IF NOT EXISTS supplies_loaded_at_idx ON raw_moysklad.supplies (loaded_at);
CREATE INDEX IF NOT EXISTS supplies_moment_idx    ON raw_moysklad.supplies ((raw_json->>'moment'));

-- LOSSES — списания
CREATE TABLE IF NOT EXISTS raw_moysklad.losses (
    ms_id        TEXT        NOT NULL,
    raw_json     JSONB       NOT NULL,
    loaded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_batch   TIMESTAMPTZ NOT NULL,
    CONSTRAINT losses_pkey PRIMARY KEY (ms_id)
);
CREATE INDEX IF NOT EXISTS losses_loaded_at_idx ON raw_moysklad.losses (loaded_at);

-- ENTERS — оприходования
CREATE TABLE IF NOT EXISTS raw_moysklad.enters (
    ms_id        TEXT        NOT NULL,
    raw_json     JSONB       NOT NULL,
    loaded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_batch   TIMESTAMPTZ NOT NULL,
    CONSTRAINT enters_pkey PRIMARY KEY (ms_id)
);
CREATE INDEX IF NOT EXISTS enters_loaded_at_idx ON raw_moysklad.enters (loaded_at);

-- MOVES — перемещения между ячейками
CREATE TABLE IF NOT EXISTS raw_moysklad.moves (
    ms_id        TEXT        NOT NULL,
    raw_json     JSONB       NOT NULL,
    loaded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_batch   TIMESTAMPTZ NOT NULL,
    CONSTRAINT moves_pkey PRIMARY KEY (ms_id)
);
CREATE INDEX IF NOT EXISTS moves_loaded_at_idx ON raw_moysklad.moves (loaded_at);

-- Аудит запусков Prefect — история синхронизаций
CREATE TABLE IF NOT EXISTS raw_moysklad.sync_log (
    id              SERIAL PRIMARY KEY,
    flow_run_id     TEXT,
    started_at      TIMESTAMPTZ NOT NULL,
    finished_at     TIMESTAMPTZ,
    is_cold_start   BOOLEAN     NOT NULL DEFAULT FALSE,
    status          TEXT        NOT NULL DEFAULT 'running',
    rows_inserted   JSONB,
    error_message   TEXT
);
