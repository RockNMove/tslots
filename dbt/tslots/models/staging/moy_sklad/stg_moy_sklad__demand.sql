-- stg_moy_sklad__demand.sql — позиции документов «Реализация».
-- Каждая строка = одна позиция документа. Товар уходит со склада (op_type = out).

{{ config(materialized='incremental', unique_key=['doc_id', 'item_id', 'op_type'], incremental_strategy='merge') }}

SELECT
    d.raw_json->>'id'                                       AS doc_id,
    (d.raw_json->>'moment')::timestamp                    AS moment,
    d.raw_json->>'name'                                     AS number,
    d.raw_json->'agent'->>'id'                              AS agent_id,
    d.raw_json->'store'->>'id'                              AS store_id,
    pos->'assortment'->>'id'                                AS item_id,
    (pos->>'quantity')::numeric * -1                        AS quantity,
    pos->'slot'->>'id'                                      AS slot_id,
    (d.raw_json->>'updated')::timestamp                   AS updated,
    'demand'::text                                          AS doc_type,
    'out'::text                                             AS op_type
FROM {{ source('moysklad', 'raw') }} d,
    jsonb_array_elements(
        coalesce(d.raw_json->'positions'->'rows', '[]'::jsonb)
    ) AS pos
WHERE d.entity = 'demand'
-- если выполняется
{% if is_incremental() %}
-- то приклеить к основному запросу это
  AND (d.raw_json->>'updated')::timestamp > (SELECT MAX(updated) FROM {{ this }})
{% endif %}
