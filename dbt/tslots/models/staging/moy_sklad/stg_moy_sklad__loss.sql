-- stg_moy_sklad__loss.sql — позиции документов «Списание».
-- Каждая строка = одна позиция документа. Товар убывает со склада (op_type = out).

{{ config(materialized='incremental', unique_key=['doc_id', 'item_id', 'op_type'], incremental_strategy='merge') }}

SELECT
    l.raw_json->>'id'                                       AS doc_id,
    (l.raw_json->>'moment')::timestamp                    AS moment,
    l.raw_json->>'name'                                     AS number,
    coalesce(l.raw_json->'agent'->>'id', NULL)              AS agent_id,
    l.raw_json->'store'->>'id'                              AS store_id,
    pos->'assortment'->>'id'                                AS item_id,
    (pos->>'quantity')::numeric * -1                        AS quantity,
    pos->'slot'->>'id'                                      AS slot_id,
    (l.raw_json->>'updated')::timestamp                   AS updated,
    'loss'::text                                            AS doc_type,
    'out'::text                                             AS op_type
FROM {{ source('moysklad', 'raw') }} l,
    jsonb_array_elements(
        coalesce(l.raw_json->'positions'->'rows', '[]'::jsonb)
    ) AS pos
WHERE l.entity = 'loss'
-- если выполняется
{% if is_incremental() %}
-- то приклеить к основному запросу это
  AND (l.raw_json->>'updated')::timestamp > (SELECT MAX(updated) FROM {{ this }})
{% endif %}
