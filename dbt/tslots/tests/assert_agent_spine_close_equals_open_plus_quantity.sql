-- Модель: int_balance__agent_slot_item_daily_spine
-- Инвариант: close_slot_balance = open_slot_balance + quantity для каждой строки.
-- Ответственность: базовая арифметика нарастающего баланса по ячейке.
--   open — накопленное количество до текущего дня, quantity — движение за день,
--   close — накопленное количество включая текущий день. Эти три поля образуют
--   замкнутую систему: если close != open + quantity, баланс сломан.
-- При нарушении: ошибка в оконных функциях daily_balances CTE (ROWS BETWEEN),
--   либо некорректная агрегация quantity в daily_agg.
SELECT
    id
    , slot_id
    , agent_id
    , item_id
    , moment_day
    , open_slot_balance
    , quantity
    , close_slot_balance
FROM {{ ref('int_balance__agent_slot_item_daily_spine') }}
WHERE close_slot_balance != open_slot_balance + quantity
