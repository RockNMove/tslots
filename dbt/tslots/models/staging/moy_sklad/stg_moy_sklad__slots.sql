-- stg_moy_sklad__slots.sql — справочник ячеек хранения.
-- Зерно: slot_id. Incremental merge по updated.
-- Источник: entity = 'store' → jsonb_array_elements(slots.rows).
{{ config(materialized='incremental', unique_key='slot_id', incremental_strategy='merge') }}

SELECT
    slot->>'id'                                 AS slot_id,
    raw_json->>'id'                             AS store_id,
    slot->'zone'->>'id'                         AS zone_id,
    slot->>'name'                               AS name,
    (slot->>'updated')::timestamp               AS updated
FROM {{ source('moysklad', 'raw') }},
     jsonb_array_elements(
         COALESCE(raw_json->'slots'->'rows', '[]'::jsonb)
     ) AS slot
WHERE entity = 'store'
-- если выполняется
{% if is_incremental() %}
-- то приклеить к основному запросу это
    AND (slot->>'updated')::timestamp > COALESCE((SELECT MAX(updated) FROM {{ this }}), '1970-01-01'::timestamp)
{% endif %}
