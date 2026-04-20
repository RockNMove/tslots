-- warehouse__balance_daily_atomic_grid.sql — витрина занятых ячеек по дням (слот × агент × товар × день).
-- Строится на основе int_premart__balance_daily_atomic_grid (только строки с is_used != 0).
-- Содержит балансы по ячейке (slot) и суммарные по товару+агенту (total), разбивку оборота на real/move.
-- Материализована как view: вычисления уже выполнены в int_premart (silver), дублировать таблицу нет смысла.
{{ config(materialized='view') }}
SELECT
	agent_name
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
	, agent_inn
	, zone_name
	, article
	, product
	, lot
	, mfg_date
FROM {{ ref('int_premart__balance_daily_atomic_grid') }}
ORDER BY  agent_name, depositor_name, item_name, store_name, slot_name, moment_day
