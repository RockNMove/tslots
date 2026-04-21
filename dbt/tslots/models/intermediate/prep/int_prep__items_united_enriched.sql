-- int_enrich__items_united_extended.sql — единый справочник позиций (товары и варианты).
-- В МойСклад операции могут ссылаться как на product_id, так и на variant_id.
-- Эта модель объединяет оба типа под общим item_id с денормализованными атрибутами:
-- uom, depositor, lot, mfg_date — готово для JOIN в int_operations_with_balance__agent_slot_item.

-- Часть 1: варианты (товары с партией и датой выработки).
-- item_id = variant_id. name собирается как "товар (партия, дата)" для читаемости.
-- lot, mfg_date — атрибуты варианта; uom, article, weight, volume — от родителя-product.
SELECT
	variant_id AS item_id
	, p.depositor_id
	, p.expected_bin_qty
	, CONCAT(p.name, ' (',v.lot,',',v.mfg_date,')') AS name
	, v.updated
	, p.name AS product
	, v.lot
	, v.mfg_date
	, p.article
	, p.weight
	, p.volume
	, u.name AS uom
	, a.name AS depositor_name
	, a.inn AS depositor_inn
FROM {{ ref('stg_moy_sklad__variants') }} v
LEFT JOIN {{ ref('stg_moy_sklad__products') }} p ON v.product_id=p.product_id
LEFT JOIN {{ ref('stg_moy_sklad__uoms') }} u ON p.uom_id=u.uom_id
LEFT JOIN {{ ref('stg_moy_sklad__agents') }} a ON p.depositor_id=a.agent_id

UNION ALL

-- Часть 2: товары без вариантов.
-- item_id = product_id. lot/mfg_date = NULL — у простых товаров их нет.
SELECT
	product_id
	, p.depositor_id
	, p.expected_bin_qty
	, p.name
	, p.updated
	, NULL  -- product (сам же и есть товар, нет родителя)
	, NULL  -- lot
	, NULL  -- mfg_date
	, p.article
	, p.weight
	, p.volume
	, u.name
	, a.name
	, a.inn
FROM {{ ref('stg_moy_sklad__products') }} p
LEFT JOIN {{ ref('stg_moy_sklad__uoms') }} u ON p.uom_id=u.uom_id
LEFT JOIN {{ ref('stg_moy_sklad__agents') }} a ON p.depositor_id=a.agent_id
