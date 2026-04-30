-- warehouse__balance_daily_no_slots.sql — остатки и оборот по товарам без разбивки по ячейкам.
-- Агрегирует int_balance__slot_item_daily_spine по зерну товар × день (без слота).
-- Используется для сводного отчёта по поклажедателям без детализации до ячейки.
{{ config(materialized='view') }}
SELECT
    MAX(depositor_name)        AS depositor_name
    , MAX(item_name)           AS item_name
    , moment_day
    , MAX(open_total_balance)  AS open_total_balance
    , SUM(real_in + real_out)  AS real_quantity
    , MAX(close_total_balance) AS close_total_balance
    , MAX(depositor_inn)       AS depositor_inn
    , MAX(article)             AS article
    , MAX(product)             AS product
    , MAX(lot)                 AS lot
    , MAX(mfg_date)            AS mfg_date
FROM {{ ref('int_balance__slot_item_daily_spine') }}
GROUP BY item_id, moment_day
ORDER BY item_name, moment_day
