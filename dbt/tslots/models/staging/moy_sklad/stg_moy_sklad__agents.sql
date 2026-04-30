-- stg_moy_sklad__agents.sql — справочник контрагентов (агенты и поклажедатели).
-- Зерно: agent_id. Incremental merge по updated.
{{ config(materialized='incremental', unique_key='agent_id', incremental_strategy='merge') }}

SELECT
    raw_json->>'id'                                 AS agent_id,
    raw_json->>'name'                               AS name,
    raw_json->>'inn'                                AS inn,
    (raw_json->>'updated')::timestamp               AS updated
FROM {{ source('moysklad', 'raw') }}
WHERE entity = 'counterparty'
  AND raw_json->>'id' IS NOT NULL
-- если выполняется
{% if is_incremental() %}
-- то приклеить к основному запросу это
    AND (raw_json->>'updated')::timestamp > COALESCE((SELECT MAX(updated) FROM {{ this }}), '1970-01-01'::timestamp)
{% endif %}
