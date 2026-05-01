-- Таблицы: int_balance__slot_item_daily_spine ← int_operations_with_balance__slot_item
-- Инвариант: real_in и real_out в spine равны суммам real_in и real_out из operations
--   для одного зерна (slot_id, item_id, moment_day, store_id).
-- Ответственность: сохранность реальных физических движений при переходе от операций к дням.
--   real_in/real_out — основа для расчёта close_total_balance и флага is_used.
--   Если суммы расходятся, total_balance и is_used вычисляются на искажённых данных.
--   Тест проверяет только дни присутствующие в spine (is_used != 0).
-- При нарушении: проверить агрегацию real_in/real_out в daily_agg CTE spine-модели.
SELECT
    a.id                  AS spine_id
    , a.slot_id
    , a.item_id
    , a.moment_day
    , a.store_id
    , a.real_in           AS spine_real_in
    , SUM(o.real_in)      AS ops_sum_real_in
    , a.real_out          AS spine_real_out
    , SUM(o.real_out)     AS ops_sum_real_out
FROM {{ ref('int_balance__slot_item_daily_spine') }} a
JOIN {{ ref('int_operations_with_balance__slot_item') }} o
    ON  a.slot_id    = o.slot_id
    AND a.item_id    = o.item_id
    AND a.moment_day = o.moment_day
    AND a.store_id   = o.store_id
GROUP BY a.id, a.slot_id, a.item_id, a.moment_day, a.store_id, a.real_in, a.real_out
HAVING a.real_in != SUM(o.real_in) OR a.real_out != SUM(o.real_out)
