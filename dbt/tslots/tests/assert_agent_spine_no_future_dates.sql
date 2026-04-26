-- Модель: int_balance__slot_item_daily_spine
-- Инвариант: moment_day <= CURRENT_DATE для каждой строки.
-- Ответственность: корректность верхней границы generate_series.
--   Spine строится от даты первой операции до CURRENT_DATE включительно.
--   Будущие даты означают что generate_series получил дату после сегодня в качестве
--   верхней границы — вероятно из-за ошибки в данных или в выражении границы диапазона.
-- При нарушении: проверить выражение верхней границы generate_series в grid CTE,
--   либо найти строку в grain CTE с seek_start > CURRENT_DATE.
SELECT
    id
    , slot_id
    , item_id
    , moment_day
    , CURRENT_DATE AS today
FROM {{ ref('int_balance__slot_item_daily_spine') }}
WHERE moment_day > CURRENT_DATE
