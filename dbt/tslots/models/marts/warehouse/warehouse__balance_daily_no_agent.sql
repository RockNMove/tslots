-- warehouse__balance_daily_no_agent.sql — остаток товара в ячейке по дням (слот × товар × день, без агента).
-- Строится на основе int_balance__slot_item_daily_spine.
-- Выводит только строки где close_slot_balance != 0.
SELECT
    store_name
    , moment_day
    , item_name
    , slot_name
    , close_slot_balance
FROM {{ ref('int_balance__slot_item_daily_spine') }}
WHERE close_slot_balance != 0
ORDER BY moment_day, item_name, slot_name
