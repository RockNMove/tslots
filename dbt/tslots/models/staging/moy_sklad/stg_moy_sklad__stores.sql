-- stg_moy_sklad__stores.sql — справочник складов.
-- Зерно: store_id. Incremental merge по updated.
{{ config(materialized='incremental', unique_key='store_id', incremental_strategy='merge') }}

SELECT
    raw_json->>'id'                             AS store_id,
    raw_json->>'name'                           AS name,
    (raw_json->>'updated')::timestamp           AS updated
FROM {{ source('moysklad', 'raw') }}
WHERE entity = 'store'
  AND raw_json->>'id' IS NOT NULL
-- если выполняется
{% if is_incremental() %}
-- то приклеить к основному запросу это
    AND (raw_json->>'updated')::timestamp > COALESCE((SELECT MAX(updated) FROM {{ this }}), '1970-01-01'::timestamp)
{% endif %}
