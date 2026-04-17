-- int_slots_extended.sql — справочник ячеек с денормализованными названиями склада и зоны.
-- В raw ячейка хранит только zone_id и store_id — без имён.
-- Эта модель делает JOIN один раз, чтобы витрины и int_operations_extended не повторяли его.

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