WITH 
  spine AS (
    SELECT
        id AS slot_item_daily_spine_id
        , store_name
        , slot_balance_errors
        , moment_day
        , slot_name
        , item_name
        , close_slot_balance
        , expected_bin_qty
        , MAX(moment_day) OVER () AS max_day
    FROM {{ ref('int_balance__slot_item_daily_spine') }}
    WHERE slot_balance_errors != ''
      AND close_slot_balance != 0
  )
SELECT
  slot_item_daily_spine_id
  , store_name
  , slot_balance_errors
  , moment_day
  , slot_name
  , item_name
  , close_slot_balance
  , expected_bin_qty
FROM spine
WHERE moment_day = max_day
ORDER BY slot_balance_errors, slot_name
