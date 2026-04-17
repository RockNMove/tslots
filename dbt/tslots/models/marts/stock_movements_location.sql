-- stock_movements_location.sql — полная витрина движений товаров с привязкой к локации.
-- Строится на основе int_operations_extended. Включает все типы операций, в том числе move.
-- Содержит полный набор атрибутов: партия, локация, контрагент, вес, объём, штрихкоды.
-- Используется в Grafana для детального анализа движений по слоту и зоне.
SELECT
	doc_type
	, moment as doc_time
	, client_name
	, client_inn
	, depositor_name
	, depositor_inn
	, doc_name
	, store_name
	, zone_name
	, op_type
	, slot_name
	, quantity
	, uom
	, item_name
	, product 
	, lot
	, mfg_date 
	, article 
	, weight
	, volume 
	, barcodes 
FROM {{ ref('int_operations_extended') }}