SELECT
	id AS id_operations_with_balance__agent_slot_item
	, store_name
    , slot_oper_errors
	, moment_day
	, doc_name
	, doc_type
	, op_type
	, slot_name
	, item_name
	, open_slot_balance
	, quantity
	, close_slot_balance
FROM {{ ref('int_operations_with_balance__agent_slot_item') }}
WHERE slot_oper_errors != ''
ORDER BY slot_oper_errors, moment_day, slot_name
