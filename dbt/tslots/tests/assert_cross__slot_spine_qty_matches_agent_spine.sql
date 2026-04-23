-- Таблицы: int_balance__slot_item_daily_spine ← int_balance__agent_slot_item_daily_spine
-- Инвариант: quantity в slot_spine равен сумме quantity по всем агентам из agent_spine
--   для одного (slot_id, item_id, moment_day, store_id).
-- Ответственность: арифметическая корректность roll-up агент→слот.
--   slot_spine строится через GROUP BY поверх agent_spine с SUM(quantity).
--   Если сумма не совпадает — GROUP BY захватывает лишние строки или теряет часть данных.
-- При нарушении: проверить daily_by_slot CTE в int_balance__slot_item_daily_spine,
--   убедиться что GROUP BY включает все измерения зерна (slot_id, item_id, moment_day, store_id).
SELECT
    s.id                  AS slot_spine_id
    , s.slot_id
    , s.item_id
    , s.moment_day
    , s.store_id
    , s.quantity          AS slot_spine_qty
    , SUM(a.quantity)     AS agent_spine_sum_qty
FROM {{ ref('int_balance__slot_item_daily_spine') }} s
JOIN {{ ref('int_balance__agent_slot_item_daily_spine') }} a
    ON  s.slot_id    = a.slot_id
    AND s.item_id    = a.item_id
    AND s.moment_day = a.moment_day
    AND s.store_id   = a.store_id
GROUP BY s.id, s.slot_id, s.item_id, s.moment_day, s.store_id, s.quantity
HAVING s.quantity != SUM(a.quantity)
