SELECT 
	variant_id AS item_id
	, CONCAT(p.name, ' (',v.lot,',',v.mfg_date,')') AS name
	, v.updated
	, p.name AS product
	, v.lot
	, v.mfg_date
	, v.barcodes
	, p.article
	, p.weight
	, p.volume
	, u.name AS uom
	, a.name depositor
FROM {{ ref('stg_moy_sklad__variants') }} v
LEFT JOIN {{ ref('stg_moy_sklad__products') }} p USING(product_id)
LEFT JOIN {{ ref('stg_moy_sklad__uoms') }} u ON p.uom_id=u.uom_id
LEFT JOIN {{ ref('stg_moy_sklad__agents') }} a ON p.depositor_id=a.agent_id

UNION ALL

SELECT
	product_id
	, p.name
	, p.updated
	, NULL
	, NULL
	, NULL
	, NULL
	, p.article
	, p.weight
	, p.volume
	, u.name
	, a.name
FROM {{ ref('stg_moy_sklad__products') }} p
LEFT JOIN {{ ref('stg_moy_sklad__uoms') }} u ON p.uom_id=u.uom_id
LEFT JOIN {{ ref('stg_moy_sklad__agents') }} a ON p.depositor_id=a.agent_id
