-- int_enrich__slots_extended.sql — справочник ячеек с денормализованными названиями склада и зоны.
-- В raw ячейка хранит только zone_id и store_id — без имён.
-- Эта модель делает JOIN один раз, чтобы витрины и int_premart__operations_each не повторяли его.

SELECT
	slt.slot_id
	, slt.store_id
	, slt.zone_id
	, slt.name
	, st.name AS store_name
	, zn.name AS zone_name
	, slt.updated
FROM {{ ref('stg_moy_sklad__slots') }} slt
LEFT JOIN {{ ref('stg_moy_sklad__stores') }} st
    ON slt.store_id = st.store_id
LEFT JOIN {{ ref('stg_moy_sklad__zones') }} zn
    ON slt.zone_id = zn.zone_id