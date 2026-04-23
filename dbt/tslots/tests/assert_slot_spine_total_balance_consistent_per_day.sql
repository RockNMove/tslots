-- Модель: int_balance__slot_item_daily_spine
-- Инвариант: close_total_balance одинаков для всех слотов одного (item, day).
-- Ответственность: корректность RANGE-окна для суммарного баланса по товару без агента.
--   Один товар может лежать в нескольких ячейках. close_total_balance — нарастающий
--   итог real-движений по товару (PARTITION BY item_id) — должен быть одинаков
--   для всех слотов, потому что RANGE BETWEEN включает все строки одного дня в одно окно.
-- При нарушении: то же что в agent_spine — ROWS вместо RANGE даёт разные
--   итоги для каждого слота. Проверяй RANGE BETWEEN в int_balance__slot_item_daily_spine.
SELECT
    item_id
    , moment_day
    , COUNT(DISTINCT close_total_balance) AS distinct_total_values
    , MIN(close_total_balance)            AS min_total
    , MAX(close_total_balance)            AS max_total
FROM {{ ref('int_balance__slot_item_daily_spine') }}
GROUP BY item_id, moment_day
HAVING COUNT(DISTINCT close_total_balance) > 1
