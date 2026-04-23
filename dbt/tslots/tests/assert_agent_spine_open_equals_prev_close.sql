-- Модель: int_balance__agent_slot_item_daily_spine
-- Инвариант: open_slot_balance[day N] = close_slot_balance[day N-1] для каждой тройки (slot, agent, item).
-- Ответственность: временна́я непрерывность цепочки дат.
--   Spine строит сплошной ряд дат через generate_series. Открытие каждого дня
--   должно совпадать с закрытием предыдущего — так обеспечивается связность ряда.
--   Тест проверяет только соседние дни где обе строки присутствуют (is_used != 0).
-- При нарушении: разрыв в накоплении — скорее всего пропущен день в generate_series,
--   либо ошибка в ROWS BETWEEN при расчёте open_slot_balance.
SELECT
    a.id                      AS id_current_day
    , b.id                    AS id_prev_day
    , a.slot_id
    , a.agent_id
    , a.item_id
    , b.moment_day            AS prev_day
    , a.moment_day            AS current_day
    , b.close_slot_balance    AS prev_close
    , a.open_slot_balance     AS current_open
FROM {{ ref('int_balance__agent_slot_item_daily_spine') }} a
JOIN {{ ref('int_balance__agent_slot_item_daily_spine') }} b
    ON  a.slot_id  = b.slot_id
    AND a.agent_id IS NOT DISTINCT FROM b.agent_id
    AND a.item_id  = b.item_id
    AND a.moment_day = b.moment_day + INTERVAL '1 day'
WHERE a.open_slot_balance != b.close_slot_balance
