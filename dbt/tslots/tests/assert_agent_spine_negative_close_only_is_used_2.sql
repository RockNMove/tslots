-- Модель: int_balance__slot_item_daily_spine
-- Инвариант: close_slot_balance < 0 только при is_used = 2.
-- Ответственность: согласованность флага is_used с фактическим значением баланса.
--   is_used = 2 означает ошибку данных (отрицательный остаток). По определению
--   это единственный случай когда close_slot_balance может быть отрицательным.
--   Если close < 0 при is_used = 1 — флаг присвоен неверно.
-- При нарушении: проверить CASE-логику daily_with_flag CTE в spine-модели,
--   убедиться что условие close_slot_balance < 0 → is_used = 2 выполняется первым в CASE.
SELECT
    id
    , slot_id
    , item_id
    , moment_day
    , close_slot_balance
    , open_slot_balance
    , quantity
    , is_used
FROM {{ ref('int_balance__slot_item_daily_spine') }}
WHERE close_slot_balance < 0 AND is_used != 2
