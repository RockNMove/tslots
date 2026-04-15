-- stg_moy_sklad__loss.sql — позиции документов «Списание».
-- Каждая строка = одна позиция документа. Товар убывает со склада (op_type = out).

{{ config(materialized='incremental', unique_key=['doc_id', 'item_id', 'op_type'], incremental_strategy='merge') }}

SELECT
    l.raw_json->>'id'                                       AS doc_id,
    (l.raw_json->>'moment')::timestamptz                    AS moment,
    l.raw_json->>'name'                                     AS number,
    coalesce(l.raw_json->'agent'->>'id', NULL)              AS agent_id,
    pos->'assortment'->>'id'                                AS item_id,
    (pos->>'quantity')::numeric * -1                        AS quantity,
    pos->'slot'->>'id'                                      AS slot_id,
    (l.raw_json->>'updated')::timestamptz                   AS updated,
    'loss'::text                                            AS doc_type,
    'out'::text                                             AS op_type
FROM {{ source('moysklad', 'raw') }} l,
    jsonb_array_elements(
        coalesce(l.raw_json->'positions'->'rows', '[]'::jsonb)
    ) AS pos
WHERE l.entity = 'loss'
  AND pos->'slot'->>'id' IS NOT NULL
  AND pos->'assortment'->>'id' IS NOT NULL
{% if is_incremental() %}
  AND (l.raw_json->>'updated')::timestamptz > (SELECT MAX(updated) FROM {{ this }})
{% endif %}
