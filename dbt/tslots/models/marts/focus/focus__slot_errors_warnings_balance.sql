SELECT
    id AS slot_item_daily_spine_id
    , store_name
    , slot_balance_errors
    , moment_day
    , slot_name
    , item_name
    , close_slot_balance
    , expected_bin_qty
FROM {{ ref('int_balance__slot_item_daily_spine') }}
WHERE slot_balance_errors != ''
  AND moment_day = (SELECT MAX(moment_day) FROM {{ ref('int_balance__slot_item_daily_spine') }})
  AND close_slot_balance != 0
ORDER BY slot_balance_errors, slot_name
