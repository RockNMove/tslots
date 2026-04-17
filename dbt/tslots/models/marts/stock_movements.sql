-- stock_movements.sql — витрина движений товаров с нарастающим остатком.
-- Строится на основе int_operations_extended.
-- Перемещения (move) исключены — только реальный приход и расход товара.
-- open_balance / close_balance — нарастающий остаток в разрезе (depositor_id, item_id).
SELECT
	depositor_name
	, depositor_inn
	, article
    , item_name
	, lot
	, mfg_date 
	, moment as doc_time
    , doc_type
	, doc_name
    , COALESCE( 
        SUM(quantity) OVER (
            PARTITION BY depositor_id, item_id 
            ORDER BY moment
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ),
    0) AS open_balance
	, quantity
    , COALESCE( 
        SUM(quantity) OVER (
            PARTITION BY depositor_id, item_id 
            ORDER BY moment
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
    0) AS close_balance
FROM {{ ref('int_operations_extended') }}
WHERE doc_type !='move'
ORDER BY depositor_name, item_name, doc_time