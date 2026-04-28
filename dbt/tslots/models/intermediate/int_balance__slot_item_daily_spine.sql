-- Атомарная ежедневная сетка: слот × товар × день.
-- Строит непрерывный ряд дат по каждой паре зерна, считает нарастающие балансы,
-- проставляет флаг физической занятости ячейки (is_used). Строки с is_used = 0 исключаются.
-- is_used: 1 — занято, 2 — ошибка данных (close_balance < 0).
-- items_in_slot — кол-во товаров с ненулевым остатком в ячейке на дату.
-- slot_balance_errors — балансовые аномалии ячейки (BALANCE_WARNING).
-- Обогащение атрибутами (ячейки, товары) — последний шаг, только на отфильтрованных строках.

WITH
    -- Дневной агрегат движений по зерну (слот, товар, день, склад).
    -- real_in/out и move_in/out уже разделены в int_operations_with_balance__agent_slot_item.
    -- Идёт первым — grain и spine выводятся из него, чтобы не сканировать исходник дважды.
    daily_agg AS (
        SELECT
            store_id
            , slot_id
            , item_id
            , moment_day
            , SUM(quantity)  AS quantity
            , SUM(real_in)   AS real_in
            , SUM(move_in)   AS move_in
            , SUM(real_out)  AS real_out
            , SUM(move_out)  AS move_out
        FROM {{ ref('int_operations_with_balance__agent_slot_item') }}
        GROUP BY moment_day, store_id, slot_id, item_id -- store_id включен в группировку, потому что операция может быть без слота
    ),

    -- Уникальные пары зерна (слот, товар, склад) и дата первой операции.
    -- Выводится из daily_agg — избегаем повторного скана исходной таблицы.
    grain AS (
        SELECT
            store_id
            , slot_id
            , item_id
            , MIN(moment_day) AS seek_start
        FROM daily_agg
        GROUP BY store_id, slot_id, item_id -- store_id включен в группировку, потому что операция может быть без слота
    ),

    -- Сетка дат: каждая пара зерна × каждый день от seek_start до сегодня (fan-out).
    grid AS (
        SELECT
            generate_series(seek_start, CURRENT_DATE, '1 day'::interval)::date AS moment_day
            , store_id
            , slot_id
            , item_id
        FROM grain
    ),

    -- Нарастающие балансы по сетке. Атрибуты не подтягиваются — только цифры.
    -- open_balance  — накопленное количество строго до текущего дня (PRECEDING).
    -- close_balance — накопленное количество включая текущий день (CURRENT ROW).
    -- Дни без операций: daily_agg → NULL → COALESCE → 0.
    daily_balances AS (
        SELECT
            g.store_id
            , g.slot_id
            , g.item_id
            , g.moment_day
            , COALESCE(
                SUM(da.quantity) OVER (
                    PARTITION BY g.store_id, g.slot_id, g.item_id -- store_id включен в группировку, потому что операция может быть без слота
                    ORDER BY g.moment_day
                    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                ),
            0) AS open_slot_balance
            , COALESCE(da.quantity, 0) AS quantity
            , COALESCE(
                SUM(da.quantity) OVER (
                    PARTITION BY g.store_id, g.slot_id, g.item_id -- store_id включен в группировку, потому что операция может быть без слота
                    ORDER BY g.moment_day
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                ),
            0) AS close_slot_balance
            , COALESCE(
                SUM(da.real_in+da.real_out) OVER(
                    PARTITION BY g.item_id
                    ORDER BY g.moment_day
                    RANGE BETWEEN UNBOUNDED PRECEDING AND INTERVAL '1 day' PRECEDING
                ),
            0) AS open_total_balance
            , COALESCE(
                SUM(da.real_in+da.real_out) OVER(
                    PARTITION BY g.item_id
                    ORDER BY g.moment_day
                    RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                ),
            0) AS close_total_balance
            , COALESCE(da.real_in,  0) AS real_in
            , COALESCE(da.move_in,  0) AS move_in
            , COALESCE(da.real_out, 0) AS real_out
            , COALESCE(da.move_out, 0) AS move_out
        FROM grid g
        LEFT JOIN daily_agg da
            ON g.store_id   = da.store_id
            AND g.slot_id    = da.slot_id
            AND g.item_id    = da.item_id
            AND  g.moment_day = da.moment_day
    ),

    -- Флаг занятости. Фильтрация здесь — до JOIN'ов обогащения ниже.
    -- is_used = 1: товар физически присутствует (close_balance > 0),
    --              либо полный оборот за один день: всё что было + пришло = ушло (real_out ≠ 0).
    -- is_used = 2: ошибка данных — отрицательный остаток.
    daily_with_flag AS (
        SELECT
            *
            , CASE
                WHEN close_slot_balance > 0                    THEN 1
                WHEN close_slot_balance < 0                    THEN 2
                WHEN close_slot_balance = 0 AND real_out != 0  THEN 1
                ELSE 0
            END AS is_used
        FROM daily_balances
    ),

    daily_with_items_in_slot AS (
        SELECT
            *
            , SUM(CASE WHEN close_slot_balance > 0 AND slot_id != 'off_slot' THEN 1 ELSE 0 END) OVER (
                PARTITION BY moment_day, store_id, slot_id -- store_id включен в группировку, потому что операция может быть без слота
            ) AS items_in_slot
        FROM daily_with_flag
    )

-- Обогащение атрибутами только на отфильтрованном наборе строк (is_used != 0).
SELECT
    ROW_NUMBER() OVER (ORDER BY b.store_id, b.slot_id, b.item_id, b.moment_day) AS id
    , b.store_id
    , b.slot_id
    , b.item_id
    , i.depositor_id
    , b.moment_day
    , s.name           AS store_name
    , COALESCE(sz.zone_name, 'off_zone') AS zone_name
    , COALESCE(sz.slot_name, 'off_slot') AS slot_name
    , i.name           AS item_name
    , i.depositor_inn
    , i.depositor_name
    , i.article
    , i.product
    , i.lot
    , i.mfg_date
    , i.expected_bin_qty
    , b.open_slot_balance
    , b.quantity
    , b.close_slot_balance
    , b.open_total_balance
    , b.close_total_balance
    , b.real_in
    , b.move_in
    , b.real_out
    , b.move_out
    , b.items_in_slot
    , CONCAT_WS(
        ' | '
        , CASE WHEN b.items_in_slot > 1 THEN 'BALANCE_WARNING: slot has > 1 items' ELSE NULL END
        , CASE WHEN b.close_slot_balance > 0 AND b.close_slot_balance != i.expected_bin_qty THEN 'BALANCE_WARNING: unexpected slot balance' ELSE NULL END
    ) AS slot_balance_errors
    , b.is_used
FROM daily_with_items_in_slot b
LEFT JOIN {{ ref('int_prep__slots_all') }}               sz   ON b.slot_id = sz.slot_id
LEFT JOIN {{ ref('stg_moy_sklad__stores') }}            s    ON b.store_id = s.store_id
LEFT JOIN {{ ref('int_prep__items_all') }}              i    ON b.item_id = i.item_id
WHERE b.is_used != 0
