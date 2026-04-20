-- warehouse__items_in_slots_daily.sql — остаток товара в ячейке по дням (слот × товар × день).
-- Строится на основе int_premart__slots_balance_daily_by_slot.
-- Выводит только строки где close_balance != 0.
SELECT
    store_name
    , moment_day
    , item_name
    , slot_name
    , close_slot_balance
FROM {{ ref('int_premart__balance_daily_by_slot_grid') }}
WHERE close_slot_balance != 0
ORDER BY moment_day, item_name, slot_name
