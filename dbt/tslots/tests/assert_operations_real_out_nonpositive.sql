-- Модель: int_operations_with_balance__agent_slot_item
-- Инвариант: real_out <= 0 для каждой операции.
-- Ответственность: корректность знака физического расхода со склада.
--   real_out вычисляется как CASE WHEN doc_type != 'move' AND quantity < 0 THEN quantity ELSE 0 END.
--   По определению может быть только 0 или отрицательным. Положительное значение
--   означает ошибку в CASE-логике или нестандартный знак quantity в исходных данных.
-- При нарушении: проверить CASE-выражение для real_out в tab CTE,
--   либо найти документ с doc_type != 'move' и положительным quantity в поле real_out.
SELECT
    id
    , slot_id
    , agent_id
    , item_id
    , moment
    , doc_type
    , quantity
    , real_out
FROM {{ ref('int_operations_with_balance__agent_slot_item') }}
WHERE real_out > 0
