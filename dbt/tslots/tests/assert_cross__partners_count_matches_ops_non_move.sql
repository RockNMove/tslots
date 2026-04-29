{{ config(tags=['cross_layer']) }}
-- Таблицы: partners__nrb_stock_movements vs int_operations_with_balance__slot_item
-- Инвариант: количество строк в partners__nrb_stock_movements равно количеству строк
--   в int_operations_with_balance__slot_item с фильтром WHERE doc_type != 'move'.
-- Ответственность: корректность фильтрации memo-перемещений в витрине для партнёров.
--   partners строится из operations с единственным фильтром doc_type != 'move'.
--   Расхождение означает что фильтр применён неверно — либо move-строки просочились,
--   либо часть реальных операций потеряна.
-- При нарушении: проверить WHERE условие в partners__nrb_stock_movements.
WITH partners AS (
    SELECT COUNT(*) AS cnt
    FROM {{ ref('partners__nrb_stock_movements') }}
),
ops_non_move AS (
    SELECT COUNT(*) AS cnt
    FROM {{ ref('int_operations_with_balance__slot_item') }}
    WHERE doc_type != 'move'
)
SELECT
    p.cnt    AS partners_count
    , o.cnt  AS operations_non_move_count
    , p.cnt - o.cnt AS diff
FROM partners p
CROSS JOIN ops_non_move o
WHERE p.cnt != o.cnt
