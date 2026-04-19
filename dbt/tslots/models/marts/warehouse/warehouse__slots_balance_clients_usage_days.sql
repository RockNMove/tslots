-- warehouse__slots_balance_clients_usage_days.sql — витрина занятых ячеек по дням (слот × поклажедатель × товар × день).
-- Строится на основе int_premart__slots_balance_daily_grid: только строки с is_used != 0.
-- Содержит нарастающие остатки (open/close/quantity) и разбивку оборота по типу операций.
SELECT
	agent_name
	, depositor_name
	, item_name
	, store_name
	, slot_name
	, moment_day
	, open_balance
	, quantity
	, close_balance
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
FROM {{ ref('int_premart__slots_balance_daily_grid') }}
ORDER BY  agent_name, depositor_name, item_name, store_name, slot_name, moment_day
