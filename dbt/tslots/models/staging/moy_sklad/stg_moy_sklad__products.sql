-- stg_moy_sklad__products.sql — справочник товаров с атрибутами поклажедателя.
-- Зерно: product_id. Incremental merge по updated.
-- depositor_id и expected_bin_qty извлекаются из дополнительных полей через jsonb_path_query_first.
{{ config(materialized='incremental', unique_key='product_id', incremental_strategy='merge') }}

SELECT
    raw_json->>'id'                                                     AS product_id,
    raw_json->>'name'                                                   AS name,
    raw_json->>'article'                                                AS article,
    (raw_json->>'weight')::numeric                                      AS weight,
    (raw_json->>'volume')::numeric                                      AS volume,
    raw_json->'uom'->>'id'                                              AS uom_id,
    jsonb_path_query_first(
        raw_json,
        '$.attributes[*] ? (@.name == "Поклажедатель").value.id'
    ) #>> '{}'                                                          AS depositor_id,
    (jsonb_path_query_first(
        raw_json,
        '$.attributes[*] ? (@.name == "Кол-во в ячейке").value'
    ) #>> '{}')::numeric                                                AS expected_bin_qty,
    (raw_json->>'updated')::timestamp                                   AS updated
FROM {{ source('moysklad', 'raw') }}
WHERE entity = 'product'
  AND raw_json->>'id' IS NOT NULL
-- если выполняется
{% if is_incremental() %}
-- то приклеить к основному запросу это
    AND (raw_json->>'updated')::timestamp > COALESCE((SELECT MAX(updated) FROM {{ this }}), '1970-01-01'::timestamp)
{% endif %}
