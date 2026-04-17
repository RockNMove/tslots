-- slots_balance.sql — витрина остатков товаров по ячейкам и поклажедателям.
-- Строится на основе int_inventory_balance_history: слот × поклажедатель × день.
-- Содержит нарастающие остатки (open/close/daily) и разбивку оборота:
-- real_in/out — реальные операции (supply/enter/demand/loss), move_in/out — перемещения.
SELECT
	depositor_inn
	, depositor_name
	, moment_day
	, slot_name
    , open_balance
	, daily_change
	, close_balance
	, real_in
	, move_in
	, real_out
	, move_out
	, is_used
FROM {{ ref('int_inventory_balance_history') }}