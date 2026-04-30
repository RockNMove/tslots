-- stg_moy_sklad__variants.sql — справочник вариантов товаров (партия + дата выработки).
-- Зерно: variant_id. Incremental merge по updated.
-- lot и mfg_date извлекаются из characteristics через jsonb_path_query_first.
{{ config(materialized='incremental', unique_key='variant_id', incremental_strategy='merge') }}

SELECT
    raw_json->>'id'                                                     AS variant_id,
    raw_json->'product'->>'id'                                          AS product_id,
    jsonb_path_query_first(
        raw_json,
        '$.characteristics[*] ? (@.name == "Партия товара").value'
    ) #>> '{}'                                                          AS lot,
    jsonb_path_query_first(
        raw_json,
        '$.characteristics[*] ? (@.name == "Дата выработки").value'
    ) #>> '{}'                                                          AS mfg_date,
    (raw_json->>'updated')::timestamp                                   AS updated
FROM {{ source('moysklad', 'raw') }}
WHERE entity = 'variant'
  AND raw_json->>'id' IS NOT NULL
  AND raw_json->'product'->>'id' IS NOT NULL
-- если выполняется
{% if is_incremental() %}
-- то приклеить к основному запросу это
    AND (raw_json->>'updated')::timestamp > COALESCE((SELECT MAX(updated) FROM {{ this }}), '1970-01-01'::timestamp)
{% endif %}
