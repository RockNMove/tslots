-- Таблицы: int_balance__slot_item_daily_spine ← int_operations_with_balance__slot_item
-- Инвариант: quantity в spine равен сумме quantity из operations
--   для одного зерна (slot_id, item_id, moment_day, store_id).
-- Ответственность: корректность дневной агрегации операций в spine.
--   daily_agg CTE суммирует все операции одного зерна за день. Итог должен совпадать
--   с тем что лежит в operations — без потерь и без дублей.
--   Тест проверяет только дни присутствующие в spine (is_used != 0).
-- При нарушении: ошибка в GROUP BY daily_agg CTE spine-модели или несоответствие
--   условий JOIN между grid и daily_agg (store_id, NULL-обработка slot_id).
SELECT
    a.id                  AS spine_id
    , a.slot_id
    , a.item_id
    , a.moment_day
    , a.store_id
    , a.quantity          AS spine_qty
    , SUM(o.quantity)     AS ops_sum_qty
FROM {{ ref('int_balance__slot_item_daily_spine') }} a
JOIN {{ ref('int_operations_with_balance__slot_item') }} o
    ON  a.slot_id    = o.slot_id
    AND a.item_id    = o.item_id
    AND a.moment_day = o.moment_day
    AND a.store_id   = o.store_id
GROUP BY a.id, a.slot_id, a.item_id, a.moment_day, a.store_id, a.quantity
HAVING a.quantity != SUM(o.quantity)
