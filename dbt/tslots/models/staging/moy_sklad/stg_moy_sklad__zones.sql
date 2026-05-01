-- stg_moy_sklad__zones.sql — справочник зон хранения.
-- Зерно: zone_id. Incremental merge по updated.
-- Источник: entity = 'store' → jsonb_array_elements(zones.rows).
-- Инкрементальный фильтр применяется к store.updated — зоны вложены в склад, store.updated >= zone.updated.
{{ config(materialized='incremental', unique_key='zone_id', incremental_strategy='merge') }}

WITH stores AS (
    SELECT
        raw_json->>'id' AS store_id,
        raw_json
    FROM {{ source('moysklad', 'raw') }}
    WHERE entity = 'store'
    {% if is_incremental() %}
        AND (raw_json->>'updated')::timestamp > COALESCE((SELECT MAX(updated) FROM {{ this }}), '1970-01-01'::timestamp)
    {% endif %}
)

SELECT
    zone->>'id'                                 AS zone_id,
    s.store_id,
    zone->>'name'                               AS name,
    (zone->>'updated')::timestamp               AS updated
FROM stores s,
     jsonb_array_elements(
         COALESCE(s.raw_json->'zones'->'rows', '[]'::jsonb)
     ) AS zone
