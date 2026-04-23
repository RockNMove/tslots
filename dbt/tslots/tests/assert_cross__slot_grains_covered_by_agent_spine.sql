-- Таблицы: int_balance__slot_item_daily_spine vs int_balance__agent_slot_item_daily_spine
-- Инвариант: каждое зерно (slot_id, item_id, moment_day) из slot_spine
--   присутствует хотя бы в одной строке agent_spine.
-- Ответственность: полнота roll-up — данные в slot_spine всегда прослеживаются до конкретного агента.
--   slot_spine строится GROUP BY поверх agent_spine, поэтому любой (slot, item, day)
--   в slot_spine обязан иметь источник в agent_spine. Нарушение означает что
--   roll-up захватил данные из источника, не связанного с agent_spine.
-- При нарушении: проверить FROM в daily_by_slot CTE — источник должен быть
--   int_balance__agent_slot_item_daily_spine, а не другая таблица.
SELECT
    s.id          AS slot_spine_id
    , s.slot_id
    , s.item_id
    , s.moment_day
    , s.store_id
FROM {{ ref('int_balance__slot_item_daily_spine') }} s
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ ref('int_balance__agent_slot_item_daily_spine') }} a
    WHERE a.slot_id    = s.slot_id
      AND a.item_id    = s.item_id
      AND a.moment_day = s.moment_day
      AND a.store_id   = s.store_id
)
