-- int_prep__slots_all.sql — справочник ячеек с названием зоны.
-- store_name не включён — берётся из документа через store_id,
-- чтобы склад был корректен когда операция содержит склад, но ячейка не указана.

SELECT
    ROW_NUMBER() OVER (ORDER BY s.slot_id) AS id
    , s.slot_id
    , s.name AS slot_name
    , z.name AS zone_name
FROM {{ ref('stg_moy_sklad__slots') }} s
LEFT JOIN {{ ref('stg_moy_sklad__zones') }} z
    ON s.zone_id = z.zone_id