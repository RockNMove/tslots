-- stg_moy_sklad__supply.sql — позиции документов «Приёмка».
-- Каждая строка = одна позиция документа. Товар приходит на склад (op_type = in).

{{ config(materialized='incremental', unique_key=['doc_id', 'item_id', 'op_type'], incremental_strategy='merge') }}

SELECT
    s.raw_json->>'id'                                       AS doc_id,
    (s.raw_json->>'moment')::timestamptz                    AS moment,
    s.raw_json->>'name'                                     AS number,
    s.raw_json->'agent'->>'id'                              AS agent_id,
    pos->'assortment'->>'id'                                AS item_id,
    (pos->>'quantity')::numeric                             AS quantity,
    pos->'slot'->>'id'                                      AS slot_id,
    (s.raw_json->>'updated')::timestamptz                   AS updated,
    'supply'::text                                          AS doc_type,
    'in'::text                                              AS op_type
FROM {{ source('moysklad', 'raw') }} s,
    jsonb_array_elements(
        coalesce(s.raw_json->'positions'->'rows', '[]'::jsonb)
    ) AS pos
WHERE s.entity = 'supply'
  AND pos->'slot'->>'id' IS NOT NULL
  AND pos->'assortment'->>'id' IS NOT NULL
{% if is_incremental() %}
  AND (s.raw_json->>'updated')::timestamptz > (SELECT MAX(updated) FROM {{ this }})
{% endif %}
