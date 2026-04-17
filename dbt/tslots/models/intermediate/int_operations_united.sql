-- int_operations_united.sql — все операционные документы в единой таблице позиций.
-- Объединяет 5 staging-таблиц: demand, supply, loss, enter, move.
-- move даёт по 2 строки на позицию (op_type=out из sourceSlot, op_type=in в targetSlot).
-- Ключ строки: doc_id + position_id + op_type — уникален даже когда один товар в документе в нескольких строках.

SELECT * FROM {{ ref('stg_moy_sklad__demand') }}
UNION ALL
SELECT * FROM {{ ref('stg_moy_sklad__supply') }}
UNION ALL
SELECT * FROM {{ ref('stg_moy_sklad__loss') }}
UNION ALL
SELECT * FROM {{ ref('stg_moy_sklad__enter') }}
UNION ALL
SELECT * FROM {{ ref('stg_moy_sklad__move') }}
ORDER BY moment, number
