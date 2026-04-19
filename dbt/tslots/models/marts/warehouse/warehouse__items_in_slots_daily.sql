-- warehouse__items_in_slots_daily.sql — нарастающий остаток товара в ячейке по дням.
-- Строится на основе int_premart__slots_balance_daily_grid.
-- Агрегирует quantity по (moment_day, slot_id, item_id), затем считает нарастающий остаток.
-- Выводит только строки где balance != 0.
WITH
	tab_quantity AS(		
		SELECT
			moment_day
			, MAX(item_name) AS item_name
			, MAX(store_name) AS store_name
			, MAX(slot_name) AS slot_name
			, COALESCE(SUM(quantity), 0) AS quantity
		FROM {{ ref('int_premart__slots_balance_daily_grid') }}
		GROUP BY moment_day, slot_id, item_id
	),
	tab_balance AS(
		SELECT
			store_name
			, moment_day
			, item_name
			, slot_name
			, SUM(quantity) OVER(PARTITION BY item_name, slot_name ORDER BY moment_day ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS balance
		FROM tab_quantity
	)
SELECT
	store_name
	, moment_day
	, item_name
	, slot_name
	, balance
FROM tab_balance
WHERE balance !=0
ORDER BY moment_day, item_name, slot_name