-- int_prep__operations_all.sql — все операционные документы в единой таблице позиций.
-- Объединяет 5 staging-таблиц: demand, supply, loss, enter, move.
-- move даёт по 2 строки на позицию (op_type=out из sourceSlot, op_type=in в targetSlot).
WITH united_operations AS (
    SELECT doc_id, applicable, moment, number, agent_id, store_id, item_id, quantity, slot_id, updated, doc_type, op_type FROM {{ ref('stg_moy_sklad__demand') }}
    UNION ALL
    SELECT doc_id, applicable, moment, number, agent_id, store_id, item_id, quantity, slot_id, updated, doc_type, op_type FROM {{ ref('stg_moy_sklad__supply') }}
    UNION ALL
    SELECT doc_id, applicable, moment, number, agent_id, store_id, item_id, quantity, slot_id, updated, doc_type, op_type FROM {{ ref('stg_moy_sklad__loss') }}
    UNION ALL
    SELECT doc_id, applicable, moment, number, agent_id, store_id, item_id, quantity, slot_id, updated, doc_type, op_type FROM {{ ref('stg_moy_sklad__enter') }}
    UNION ALL
    SELECT doc_id, applicable, moment, number, agent_id, store_id, item_id, quantity, slot_id, updated, doc_type, op_type FROM {{ ref('stg_moy_sklad__move') }}
)
SELECT
    ROW_NUMBER() OVER (ORDER BY doc_id, item_id, op_type) AS id
    , doc_id
    , applicable
    , moment
    , number
    , agent_id
    , store_id
    , item_id
    , quantity
    , COALESCE (slot_id, 'off_slot') AS slot_id
    , updated
    , doc_type
    , op_type
FROM united_operations o
