-- Модель: int_balance__agent_slot_item_daily_spine
-- Инвариант: close_total_balance одинаков для всех слотов одного (agent, item, day).
-- Ответственность: корректность RANGE-окна для суммарного баланса по товару у агента.
--   Один агент может держать один товар в нескольких ячейках. close_total_balance —
--   нарастающий итог real-движений по товару у агента — должен быть одинаков
--   для всех слотов одного дня, потому что RANGE BETWEEN включает все строки
--   с одинаковым moment_day в одно окно.
-- При нарушении: используется ROWS вместо RANGE (каждый слот получает свой
--   накопленный итог), либо PARTITION BY total-окна не совпадает с зерном spine.
SELECT
    agent_id
    , item_id
    , moment_day
    , COUNT(DISTINCT close_total_balance) AS distinct_total_values
    , MIN(close_total_balance)            AS min_total
    , MAX(close_total_balance)            AS max_total
FROM {{ ref('int_balance__agent_slot_item_daily_spine') }}
GROUP BY agent_id, item_id, moment_day
HAVING COUNT(DISTINCT close_total_balance) > 1
