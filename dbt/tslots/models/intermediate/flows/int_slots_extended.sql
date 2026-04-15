SELECT 
	slt.slot_id
	, st.name AS store_name
	, zn.name AS zone_name
	, slt.name
	, slt.updated
FROM {{ ref('stg_moy_sklad__slots') }} slt
LEFT JOIN {{ ref('stg_moy_sklad__zones') }} zn
    ON slt.zone_id = zn.zone_id
LEFT JOIN {{ ref('stg_moy_sklad__stores') }} st
    ON slt.store_id = st.store_id