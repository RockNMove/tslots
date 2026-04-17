-- int_operations_extended.sql — операции с денормализованными атрибутами.
-- store_name берётся из документа (через store_id), а не из ячейки —
-- это позволяет корректно показывать склад даже когда ячейка не указана.

SELECT
	o.moment
	, o.item_id
	, o.slot_id
	, o.agent_id
	, i.depositor_id
	, s.name AS store_name
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
	, i.depositor_name
	, i.depositor_inn
FROM {{ ref('int_operations_united') }} o
LEFT JOIN {{ ref('int_slots_extended') }} se ON o.slot_id=se.slot_id          -- slot_name, zone_name; NULL если ячейка не указана
LEFT JOIN {{ ref('int_items_united_extended') }} i ON o.item_id=i.item_id     -- lot, mfg_date, uom, depositor и др.
LEFT JOIN {{ ref('stg_moy_sklad__agents') }} a ON o.agent_id=a.agent_id       -- client_name/inn из документа (demand, supply)
LEFT JOIN {{ ref('stg_moy_sklad__stores') }} s ON o.store_id=s.store_id       -- store_name из документа, не из ячейки
ORDER BY o.item_id, o.slot_id, o.moment