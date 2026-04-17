-- stg_moy_sklad__supply.sql — позиции документов «Приёмка».
-- Каждая строка = одна позиция документа. Товар приходит на склад (op_type = in).

{{ config(materialized='incremental', unique_key=['doc_id', 'position_id', 'op_type'], incremental_strategy='merge') }}

SELECT
    s.raw_json->>'id'                                       AS doc_id,
    pos->>'id'                                              AS position_id,
    (s.raw_json->>'moment')::timestamp                    AS moment,
    s.raw_json->>'name'                                     AS number,
    s.raw_json->'agent'->>'id'                              AS agent_id,
    s.raw_json->'store'->>'id'                              AS store_id,
    pos->'assortment'->>'id'                                AS item_id,
    (pos->>'quantity')::numeric                             AS quantity,
    pos->'slot'->>'id'                                      AS slot_id,
    (s.raw_json->>'updated')::timestamp                   AS updated,
    'supply'::text                                          AS doc_type,
    'in'::text                                              AS op_type
FROM {{ source('moysklad', 'raw') }} s,
    jsonb_array_elements(
        coalesce(s.raw_json->'positions'->'rows', '[]'::jsonb)
    ) AS pos
WHERE s.entity = 'supply'
-- если выполняется
{% if is_incremental() %}
-- то приклеить к основному запросу это
  AND (s.raw_json->>'updated')::timestamp > (SELECT MAX(updated) FROM {{ this }})
{% endif %}
