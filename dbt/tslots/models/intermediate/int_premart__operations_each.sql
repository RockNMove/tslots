-- int_premart__operations_each.sql — операции с денормализованными атрибутами позиций, ячеек и контрагентов.
-- INNER JOIN на int_enrich__items_united_extended намеренно отфильтровывает услуги, наборы
-- и прочие сущности МойСклад, которые не загружаются в справочник товаров.
-- store_name берётся из документа (через store_id), а не из ячейки —
-- это позволяет корректно показывать склад даже когда ячейка не указана.
-- open/close_total_balance — нарастающий остаток по товару (item_id), все склады вместе; move не учитывается.
-- open/close_slot_balance  — нарастающий остаток по товару в ячейке (item_id, slot_id, store_id); операции без slot_id не учитываются.
-- items_in_slot            — кол-во различных товаров в ячейке на дату операции.
SELECT
	o.item_id
	, o.slot_id
	, s.store_id
	, o.agent_id
	, i.depositor_id
	, i.expected_bin_qty
	, s.name AS store_name
	, se.zone_name
	, o.doc_type
	, o.number AS doc_name
	, o.moment
	, o.moment::date AS moment_day
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
	, a.name AS agent_name
	, a.inn AS agent_inn
	, i.depositor_name
	, i.depositor_inn
	, COUNT(*) OVER(PARTITION BY o.item_id, o.moment::date, o.slot_id) AS items_in_slot
FROM {{ ref('int_enrich__operations_united') }} o
INNER JOIN {{ ref('int_enrich__items_united_extended') }} i ON o.item_id=i.item_id     -- lot, mfg_date, uom, depositor и др.
LEFT JOIN {{ ref('int_enrich__slots_extended') }} se ON o.slot_id=se.slot_id          -- slot_name, zone_name; NULL если ячейка не указана
LEFT JOIN {{ ref('stg_moy_sklad__agents') }} a ON o.agent_id=a.agent_id       -- agent_name/inn из документа (demand, supply)
LEFT JOIN {{ ref('stg_moy_sklad__stores') }} s ON o.store_id=s.store_id       -- store_name из документа, не из ячейки
