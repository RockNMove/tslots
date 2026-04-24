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
            , MAX(store_name)     AS store_name
            , MAX(zone_name)      AS zone_name
            , MAX(slot_name)      AS slot_name
            , MAX(item_name)      AS item_name
            , SUM(quantity)       AS quantity
            , SUM(real_in)        AS real_in
            , SUM(real_out)       AS real_out
            , SUM(move_in)        AS move_in
            , SUM(move_out)       AS move_out
        FROM {{ ref('int_balance__agent_slot_item_daily_spine') }}
        GROUP BY slot_id, item_id, moment_day, store_id
    )

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
