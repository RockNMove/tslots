-- warehouse__operations_with_balance.sql — полная витрина всех движений по складу с остатками и диагностикой ячеек.
-- Строится на основе int_operations_with_balance__agent_slot_item. Включает все типы операций, в том числе move.
-- open/close_slot_balance — остаток в конкретной ячейке; open/close_total_balance — по товару в целом.
-- slot_oper_errors — операционные аномалии: OPER_ERROR slot overdraft, OPER_WARNING Out-of-slot operation.

SELECT
	id
	, agent_name
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
	, real_in
	, move_in
	, real_out
	, move_out
	, uom
	, expected_bin_qty
	, slot_oper_errors
	, moment
	, article 
	, product 
	, lot
	, mfg_date 
	, weight 
	, volume 
	, zone_name
	, agent_inn
	, depositor_inn
FROM {{ ref('int_operations_with_balance__agent_slot_item') }}
ORDER BY agent_name, depositor_name, item_name, store_name, slot_name, moment