-- stg_moy_sklad__enter.sql — позиции документов «Оприходование».
-- Каждая строка = одна позиция документа. Товар приходит на склад (op_type = in).

{{ config(materialized='incremental', unique_key=['doc_id', 'item_id', 'op_type'], incremental_strategy='merge') }}

SELECT
    e.raw_json->>'id'                                       AS doc_id,
    (e.raw_json->>'moment')::timestamptz                    AS moment,
    e.raw_json->>'name'                                     AS number,
    coalesce(e.raw_json->'agent'->>'id', NULL)              AS agent_id,
    pos->'assortment'->>'id'                                AS item_id,
    (pos->>'quantity')::numeric                             AS quantity,
    pos->'slot'->>'id'                                      AS slot_id,
    (e.raw_json->>'updated')::timestamptz                   AS updated,
    'enter'::text                                           AS doc_type,
    'in'::text                                              AS op_type
FROM {{ source('moysklad', 'raw') }} e,
    jsonb_array_elements(
        coalesce(e.raw_json->'positions'->'rows', '[]'::jsonb)
    ) AS pos
WHERE e.entity = 'enter'
  AND pos->'slot'->>'id' IS NOT NULL
  AND pos->'assortment'->>'id' IS NOT NULL
{% if is_incremental() %}
  AND (e.raw_json->>'updated')::timestamptz > (SELECT MAX(updated) FROM {{ this }})
{% endif %}
