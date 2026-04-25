-- int_balance__slot_item_daily_spine.sql — ежедневная сетка с зерном слот × товар × день (без агента).
-- Roll-up поверх int_balance__agent_slot_item_daily_spine:
-- суммируем движения по всем агентам, пересчитываем балансы на новом зерне.
-- Атрибуты агента не включены — на этом уровне агент не имеет смысла.

WITH
    -- Агрегация движений по зерну слот × товар × день (суммируем по всем агентам).
    daily_by_slot AS (
        SELECT
            store_id
            , slot_id
            , item_id
            , moment_day
            , MAX(store_name)           AS store_name
            , MAX(zone_name)            AS zone_name
            , MAX(slot_name)            AS slot_name
            , MAX(item_name)            AS item_name
            , MAX(expected_bin_qty)     AS expected_bin_qty
            , SUM(quantity)             AS quantity
            , SUM(real_in)              AS real_in
            , SUM(real_out)             AS real_out
            , SUM(move_in)              AS move_in
            , SUM(move_out)             AS move_out
        FROM {{ ref('int_balance__agent_slot_item_daily_spine') }}
        GROUP BY moment_day, store_id, slot_id, item_id  -- store_id включен в группировку потому что операция может быть слота
    ),
    daily_by_slot_with_balance as (
-- Нарастающие балансы на новом зерне.
        SELECT
            ROW_NUMBER() OVER () AS id
            , *
            , COALESCE(
                SUM(quantity) OVER (
                    PARTITION BY store_id, slot_id, item_id
                    ORDER BY moment_day
                    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                ),
            0) AS open_slot_balance
            , COALESCE(
                SUM(quantity) OVER (
                    PARTITION BY store_id, slot_id, item_id
                    ORDER BY moment_day
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                ),
            0) AS close_slot_balance
            , COALESCE(
                SUM(real_in+real_out) OVER(
                    PARTITION BY item_id
                    ORDER BY moment_day
                    RANGE BETWEEN UNBOUNDED PRECEDING AND INTERVAL '1 day' PRECEDING
                ),
            0) AS open_total_balance
            , COALESCE(
                SUM(real_in+real_out) OVER(
                    PARTITION BY item_id
                    ORDER BY moment_day
                    RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                ),
            0) AS close_total_balance
        FROM daily_by_slot
    ),
    daily_by_slot_with_balance_and_items_in_slot AS(
        SELECT
        *
        , SUM(CASE WHEN close_slot_balance > 0 THEN 1 ELSE 0 END) OVER(PARTITION BY moment_day, store_id, slot_id) AS items_in_slot
        FROM daily_by_slot_with_balance
    )
SELECT
*
, CONCAT_WS(
    ' | '
    , CASE WHEN items_in_slot >1 THEN 'BALANCE_WARNING: slot has > 1 items' ELSE NULL END
    , CASE WHEN close_slot_balance != expected_bin_qty THEN 'BALANCE_WARNING: unexpected slot balance' ELSE NULL END
) AS slot_balance_errors
FROM daily_by_slot_with_balance_and_items_in_slot


