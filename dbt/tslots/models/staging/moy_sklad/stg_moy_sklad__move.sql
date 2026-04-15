-- stg_moy_sklad__move.sql — позиции документов «Перемещение».
-- Каждая позиция порождает ДВЕ строки:
--   out — товар покидает sourceSlot (ячейка освобождается)
--   in  — товар занимает targetSlot (ячейка занимается)

{{ config(materialized='incremental', unique_key=['doc_id', 'item_id', 'op_type'], incremental_strategy='merge') }}

WITH

move_out AS (
    SELECT
        m.raw_json->>'id'                                   AS doc_id,
        (m.raw_json->>'moment')::timestamptz                AS moment,
        m.raw_json->>'name'                                 AS number,
        NULL::text                                          AS agent_id,
        pos->'assortment'->>'id'                            AS item_id,
        (pos->>'quantity')::numeric * -1                    AS quantity,
        pos->'sourceSlot'->>'id'                            AS slot_id,
        (m.raw_json->>'updated')::timestamptz               AS updated,
        'move'::text                                        AS doc_type,
        'out'::text                                         AS op_type
    FROM {{ source('moysklad', 'raw') }} m,
        jsonb_array_elements(
            coalesce(m.raw_json->'positions'->'rows', '[]'::jsonb)
        ) AS pos
    WHERE m.entity = 'move'
      AND pos->'sourceSlot'->>'id' IS NOT NULL
      AND pos->'assortment'->>'id' IS NOT NULL
    {% if is_incremental() %}
      AND (m.raw_json->>'updated')::timestamptz > (SELECT MAX(updated) FROM {{ this }})
    {% endif %}
),

move_in AS (
    SELECT
        m.raw_json->>'id'                                   AS doc_id,
        (m.raw_json->>'moment')::timestamptz                AS moment,
        m.raw_json->>'name'                                 AS number,
        NULL::text                                          AS agent_id,
        pos->'assortment'->>'id'                            AS item_id,
        (pos->>'quantity')::numeric                         AS quantity,
        pos->'targetSlot'->>'id'                            AS slot_id,
        (m.raw_json->>'updated')::timestamptz               AS updated,
        'move'::text                                        AS doc_type,
        'in'::text                                          AS op_type
    FROM {{ source('moysklad', 'raw') }} m,
        jsonb_array_elements(
            coalesce(m.raw_json->'positions'->'rows', '[]'::jsonb)
        ) AS pos
    WHERE m.entity = 'move'
      AND pos->'targetSlot'->>'id' IS NOT NULL
      AND pos->'assortment'->>'id' IS NOT NULL
    {% if is_incremental() %}
      AND (m.raw_json->>'updated')::timestamptz > (SELECT MAX(updated) FROM {{ this }})
    {% endif %}
)

SELECT * FROM move_out
UNION ALL
SELECT * FROM move_in
