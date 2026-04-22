SELECT
    slot_errors
	, moment_day
	, slot_name
	, doc_name
	, item_name
	, op_type 
	, open_slot_balance
	, quantity
	, close_slot_balance
	, expected_bin_qty
	, items_in_slot
	, doc_type
	, store_name
	, agent_name
	, depositor_name
FROM {{ ref('int_operations_with_balance__agent_slot_item') }}
WHERE slot_errors IS NOT NULL