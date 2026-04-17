-- stg_moy_sklad__enter.sql — позиции документов «Оприходование».
-- Каждая строка = одна позиция документа. Товар приходит на склад (op_type = in).

{{ config(materialized='incremental', unique_key=['doc_id', 'position_id', 'op_type'], incremental_strategy='merge') }}

SELECT
    e.raw_json->>'id'                                       AS doc_id,
    pos->>'id'                                              AS position_id,
    (e.raw_json->>'moment')::timestamp                    AS moment,
    e.raw_json->>'name'                                     AS number,
    coalesce(e.raw_json->'agent'->>'id', NULL)              AS agent_id,
    e.raw_json->'store'->>'id'                              AS store_id,
    pos->'assortment'->>'id'                                AS item_id,
    (pos->>'quantity')::numeric                             AS quantity,
    pos->'slot'->>'id'                                      AS slot_id,
    (e.raw_json->>'updated')::timestamp                   AS updated,
    'enter'::text                                           AS doc_type,
    'in'::text                                              AS op_type
FROM {{ source('moysklad', 'raw') }} e,
    jsonb_array_elements(
        coalesce(e.raw_json->'positions'->'rows', '[]'::jsonb)
    ) AS pos
WHERE e.entity = 'enter'
-- если выполняется
{% if is_incremental() %}
-- то приклеить к основному запросу это
  AND (e.raw_json->>'updated')::timestamp > (SELECT MAX(updated) FROM {{ this }})
{% endif %}
