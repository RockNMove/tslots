-- Модель: int_balance__slot_item_daily_spine
-- Инвариант: close_slot_balance = open_slot_balance + quantity для каждой строки.
-- Ответственность: базовая арифметика нарастающего баланса на уровне (slot × item × day).
--   Аналог теста для agent_spine, применяется к roll-up модели без агента.
--   Агрегация по всем агентам не должна нарушать баланс: если quantity суммируется
--   корректно, а оконные функции считают нарастающее правильно — close = open + quantity.
-- При нарушении: ошибка в агрегации daily_by_slot CTE или в оконных функциях
--   нарастающего баланса в int_balance__slot_item_daily_spine.
SELECT
    id
    , slot_id
    , item_id
    , moment_day
    , open_slot_balance
    , quantity
    , close_slot_balance
FROM {{ ref('int_balance__slot_item_daily_spine') }}
WHERE close_slot_balance != open_slot_balance + quantity
