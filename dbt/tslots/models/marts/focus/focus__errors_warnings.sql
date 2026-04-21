SELECT
	moment_day
	, store_name
	, agent_name
	, depositor_name
	, doc_type
	, doc_name
	, item_name
	, op_type 
	, slot_name
	, open_slot_balance
	, quantity
	, close_slot_balance
	, items_in_slot
	, expected_bin_qty
    , slot_errors
FROM {{ ref('int_operations_with_balance__agent_slot_item') }}
WHERE slot_errors IS NOT NULL