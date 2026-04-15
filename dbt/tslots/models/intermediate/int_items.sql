SELECT 
	variant_id AS item_id
	, CONCAT(p.name, '(',v.lot,',',v.mfg_date,')') AS name
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
FROM {{ ref('stg_variants') }} v
LEFT JOIN {{ ref('stg_products') }} p USING(product_id)
LEFT JOIN {{ ref('stg_uoms') }} u ON p.uom_id=u.uom_id
LEFT JOIN {{ ref('stg_agents') }} a ON p.depositor_id=a.agent_id

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
FROM {{ ref('stg_products') }} p
LEFT JOIN {{ ref('stg_uoms') }} u ON p.uom_id=u.uom_id
LEFT JOIN {{ ref('stg_agents') }} a ON p.depositor_id=a.agent_id
