-- int_prep__slots_and_zones.sql — справочник ячеек с названием зоны.
-- store_name не включён — берётся из документа через store_id,
-- чтобы склад был корректен когда операция содержит склад, но ячейка не указана.

SELECT
	s.slot_id
	, s.zone_id
	, s.name AS slot_name
	, z.name AS zone_name
FROM {{ ref('stg_moy_sklad__slots') }} s
LEFT JOIN {{ ref('stg_moy_sklad__zones') }} z
    ON s.zone_id = z.zone_id