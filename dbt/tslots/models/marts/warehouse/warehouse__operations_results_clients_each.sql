-- warehouse__operations_results_clients_each.sql — полная витрина всех движений по складу с остатками и диагностикой ячеек.
-- Строится на основе int_premart__operations_each. Включает все типы операций, в том числе move.
-- open/close_slot_balance — остаток в конкретной ячейке; open/close_total_balance — по товару в целом.
-- slot_errors — текстовый флаг проблем: отрицательный остаток, несколько товаров, неожиданный остаток.
-- Группируем в оконных функциях только по agent_id, item_id, slot_id, т.к. к item уже привязан depositor, а к slot - store
WITH
	tab AS(
		SELECT
			agent_name
			, depositor_name
			, item_name
			, store_name
			, slot_name
			, doc_name
			, moment_day
			, doc_type
			, op_type 
			, COALESCE(
				SUM(CASE WHEN slot_id is NULL then 0 else quantity END) OVER(
					PARTITION BY agent_id, item_id, slot_id
					ORDER BY moment
					ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
				),
			0) AS open_slot_balance
			, quantity
			, COALESCE(
				SUM(CASE WHEN slot_id is NULL then 0 else quantity END) OVER(
					PARTITION BY agent_id, item_id, slot_id
					ORDER BY moment
					ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
				),
			0) AS close_slot_balance
			, COALESCE(
				SUM(CASE WHEN doc_type='move' THEN 0 ELSE quantity END) OVER(
					PARTITION BY agent_id, item_id
					ORDER BY moment
					ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
				),
			0) AS open_total_balance
			, COALESCE(
				SUM(CASE WHEN doc_type='move' THEN 0 ELSE quantity END) OVER(
					PARTITION BY agent_id, item_id
					ORDER BY moment
					ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
				),
			0) AS close_total_balance
			, uom
			, expected_bin_qty
			, items_in_slot
			, moment
			, article 
			, product 
			, lot
			, mfg_date 
			, weight 
			, volume 
			, barcodes 
			, zone_name
			, agent_inn
			, depositor_inn
		FROM {{ ref('int_premart__operations_each') }}
	)
SELECT
	agent_name
	, depositor_name
	, item_name
	, store_name
	, slot_name
	, doc_name
	, moment_day
	, doc_type
	, op_type 
	, open_slot_balance
	, quantity
	, close_slot_balance
	, open_total_balance
	, close_total_balance
	, uom
	, expected_bin_qty
	, items_in_slot
	, CASE 
		WHEN close_slot_balance<0 THEN 'ERROR: slot overdraft'
		WHEN items_in_slot >1 THEN 'ERROR: slot has > 1 items' 
		WHEN close_slot_balance != expected_bin_qty THEN 'WARNING: unexpected slot balance'
		ELSE NULL 
	END AS slot_errors
	, moment
	, article 
	, product 
	, lot
	, mfg_date 
	, weight 
	, volume 
	, barcodes 
	, zone_name
	, agent_inn
	, depositor_inn
FROM tab
ORDER BY agent_name, depositor_name, item_name, store_name, slot_name, moment