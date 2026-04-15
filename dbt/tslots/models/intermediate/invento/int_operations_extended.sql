SELECT 
	o.moment
	, o.item_id
	, o.slot_id
	, se.store_name
	, se.zone_name
	, o.doc_type
	, o.number AS doc_name
	, o.op_type 
	, se.name AS slot_name
	, o.quantity
	, i.uom
	, i.name AS item_name
	, i.product 
	, i.lot
	, i.mfg_date 
	, i.article 
	, i.weight 
	, i.volume 
	, i.barcodes 
	, a.name AS client_name
	, a.inn AS client_inn
	, i.depositor  
FROM {{ ref('int_operations_united') }} o
LEFT JOIN {{ ref('int_slots_extended') }} se ON o.slot_id=se.slot_id
LEFT JOIN {{ ref('int_items_united') }} i ON o.item_id=i.item_id
LEFT JOIN {{ ref('stg_moy_sklad__agents') }} a ON o.agent_id=a.agent_id
ORDER BY o.item_id, o.slot_id, o.moment