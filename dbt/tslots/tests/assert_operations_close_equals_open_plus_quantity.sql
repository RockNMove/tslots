-- Модель: int_operations_with_balance__agent_slot_item
-- Инвариант: close_slot_balance = open_slot_balance + quantity для каждой операции.
-- Ответственность: базовая арифметика нарастающего баланса по ячейке.
--   open — накопленное количество до текущей операции, quantity — движение этой операции,
--   close — накопленное количество включая текущую операцию. Эти три поля образуют
--   замкнутую систему: если close != open + quantity, баланс сломан.
-- При нарушении: ошибка в оконных функциях tab_with_balance CTE (ROWS BETWEEN),
--   либо некорректный знак quantity в staging-модели.
SELECT
    id
    , slot_id
    , agent_id
    , item_id
    , moment
    , open_slot_balance
    , quantity
    , close_slot_balance
FROM {{ ref('int_operations_with_balance__agent_slot_item') }}
WHERE close_slot_balance != open_slot_balance + quantity
