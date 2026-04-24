{{ config(tags=['cross_layer']) }}
-- Таблицы: warehouse__operations_with_balance vs int_operations_with_balance__agent_slot_item
-- Инвариант: количество строк в витрине warehouse__operations_with_balance равно
--   количеству строк в источнике int_operations_with_balance__agent_slot_item.
-- Ответственность: полнота mart-слоя — витрина не фильтрует и не дублирует строки.
--   warehouse__operations_with_balance строится как SELECT выбранных колонок
--   из int_operations без дополнительных WHERE-условий.
--   Расхождение означает что в mart добавился фильтр или потерян JOIN.
-- При нарушении: проверить FROM и WHERE в warehouse__operations_with_balance,
--   убедиться что нет лишних JOIN которые могут порождать дубли или потери строк.
WITH warehouse AS (
    SELECT COUNT(*) AS cnt
    FROM {{ ref('warehouse__operations_with_balance') }}
),
int_ops AS (
    SELECT COUNT(*) AS cnt
    FROM {{ ref('int_operations_with_balance__agent_slot_item') }}
)
SELECT
    w.cnt    AS warehouse_count
    , o.cnt  AS int_operations_count
    , w.cnt - o.cnt AS diff
FROM warehouse w
CROSS JOIN int_ops o
WHERE w.cnt != o.cnt
