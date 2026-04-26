-- Модель: int_balance__slot_item_daily_spine
-- Инвариант: move_in >= 0 и move_out <= 0 для каждой строки.
-- Ответственность: корректность знака memo-перемещений.
--   move_in — приход товара в ячейку по документу перемещения, всегда >= 0.
--   move_out — расход товара из ячейки по документу перемещения, всегда <= 0.
--   Знаки фиксированы CASE-логикой в операционной модели и сохраняются при агрегации.
--   Нарушение означает ошибку в CASE-выражениях move_in/move_out или некорректные данные в move-документах.
-- При нарушении: проверить CASE-выражения в int_operations_with_balance__agent_slot_item
--   и агрегацию move_in/move_out в daily_agg CTE spine-модели.
SELECT
    id
    , slot_id
    , item_id
    , moment_day
    , move_in
    , move_out
FROM {{ ref('int_balance__slot_item_daily_spine') }}
WHERE move_in < 0 OR move_out > 0
