-- Модель: int_balance__agent_slot_item_daily_spine
-- Инвариант: quantity = real_in + real_out + move_in + move_out для каждой строки.
-- Ответственность: целостность декомпозиции движений.
--   quantity — суммарное движение за день. Оно должно полностью раскладываться
--   на составные части: real_in (физический приход), real_out (физический расход),
--   move_in (memo-приход), move_out (memo-расход). Потеря данных при агрегации
--   в daily_agg CTE приводит к расхождению.
-- При нарушении: одно из полей агрегируется некорректно в daily_agg CTE,
--   либо в источнике есть операция с типом не попадающим ни в одну из четырёх категорий.
SELECT
    id
    , slot_id
    , agent_id
    , item_id
    , moment_day
    , quantity
    , real_in
    , real_out
    , move_in
    , move_out
    , (real_in + real_out + move_in + move_out) AS parts_sum
FROM {{ ref('int_balance__agent_slot_item_daily_spine') }}
WHERE quantity != real_in + real_out + move_in + move_out
