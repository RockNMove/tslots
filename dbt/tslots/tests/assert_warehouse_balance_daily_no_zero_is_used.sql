-- Модель: int_balance__agent_slot_item_daily_spine (основа для warehouse__balance_daily)
-- Инвариант: строк с is_used = 0 не существует в модели после фильтрации.
-- Ответственность: гарантия что пустые ячейки не попадают в аналитику.
--   is_used = 0 означает что ячейка в этот день не была занята. Такие строки
--   создаются в daily_with_flag CTE и должны быть отброшены в WHERE финального SELECT.
--   Без этой фильтрации витрины содержали бы тысячи строк с нулевыми балансами.
-- При нарушении: фильтр WHERE b.is_used != 0 удалён или обойдён в модели,
--   либо is_used вычисляется неверно и ненулевые строки маркируются как 0.
SELECT
    id
    , slot_id
    , agent_id
    , item_id
    , moment_day
    , is_used
    , close_slot_balance
    , open_slot_balance
FROM {{ ref('int_balance__agent_slot_item_daily_spine') }}
WHERE is_used = 0
