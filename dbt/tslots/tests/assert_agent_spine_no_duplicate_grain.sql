-- Модель: int_balance__agent_slot_item_daily_spine
-- Инвариант: каждая комбинация (slot_id, agent_id, item_id, moment_day) встречается ровно один раз.
-- Ответственность: уникальность зерна spine.
--   Зерно определено как slot × agent × item × day. Дублирование строк означает
--   что generate_series породил дублирующийся ряд дат или grain CTE вернул
--   дублирующиеся тройки зерна — скорее всего из-за некорректного GROUP BY в daily_agg.
-- При нарушении: проверить GROUP BY в daily_agg и grain CTE,
--   а также убедиться что LEFT JOIN в daily_balances не порождает дублей.
SELECT
    slot_id
    , agent_id
    , item_id
    , moment_day
    , COUNT(*) AS duplicate_count
FROM {{ ref('int_balance__agent_slot_item_daily_spine') }}
GROUP BY slot_id, agent_id, item_id, moment_day
HAVING COUNT(*) > 1
