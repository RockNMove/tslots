-- warehouse__balance_daily.sql — витрина занятых ячеек по дням (слот × товар × день).
-- Строится на основе int_balance__slot_item_daily_spine (только строки с is_used != 0).
-- Содержит балансы по ячейке (slot) и суммарные по товару (total), разбивку оборота на real/move.
-- Материализована как view: вычисления уже выполнены в intermediate (silver), дублировать таблицу нет смысла.
{{ config(materialized='view') }}
SELECT
    id
    , depositor_name
    , item_name
    , store_name
    , slot_name
    , moment_day
    , open_slot_balance
    , quantity
    , close_slot_balance
    , open_total_balance
    , close_total_balance
    , real_in
    , move_in
    , real_out
    , move_out
    , depositor_inn
    , zone_name
    , article
    , product
    , lot
    , mfg_date
FROM {{ ref('int_balance__slot_item_daily_spine') }}
ORDER BY item_name, store_name, slot_name, moment_day
