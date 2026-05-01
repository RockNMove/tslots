-- partners__nrb_stock_movements.sql — отчёт движений товаров с нарастающим остатком (для партнёров).
-- Строится на основе int_operations_with_balance__slot_item.
-- Перемещения (move) исключены — только реальный приход и расход.
-- open_balance / close_balance — нарастающий остаток по товару по всем складам; move не учитывается.
WITH tab AS (
	SELECT
		depositor_name
		, depositor_inn
		, article
		, item_name
		, product
		, lot
		, mfg_date
		, moment AS doc_time
		, doc_type
		, doc_name
		, open_total_balance AS open_balance
		, quantity
		, close_total_balance  AS close_balance
	FROM {{ ref('int_operations_with_balance__slot_item') }}
)
SELECT *
FROM tab
WHERE doc_type != 'move'
ORDER BY depositor_name, item_name, doc_time