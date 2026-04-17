-- slots_using.sql — минимальная витрина занятости ячеек по дням.
-- Строится на основе int_inventory_balance_history.
-- Только 4 колонки нужные для тепловых карт и графиков занятости в Grafana.
-- is_used: 1 — занято, 0 — пусто, NULL — ошибка данных (отрицательный остаток).

SELECT
	depositor_name
	, moment_day
	, slot_name
FROM {{ ref('int_inventory_balance_history') }}
WHERE is_used=1