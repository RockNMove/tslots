-- partners__nrb_stock_movements.sql — отчёт движений товаров с нарастающим остатком (для партнёров).
-- Строится на основе int_operations_with_balance__agent_slot_item.
-- Перемещения (move) исключены — только реальный приход и расход.
-- open_balance / close_balance — нарастающий остаток по товару по всем складам; move не учитывается.
WITH tab AS (
	SELECT
		agent_name
		, agent_inn
		, article
		, item_name
		, lot
		, mfg_date
		, moment AS doc_time
		, doc_type
		, doc_name
		, COALESCE(
			SUM(CASE WHEN doc_type = 'move' THEN 0 ELSE quantity END) OVER (
				PARTITION BY item_id
				ORDER BY moment
				ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
			),
		0) AS open_balance
		, quantity
		, COALESCE(
			SUM(CASE WHEN doc_type = 'move' THEN 0 ELSE quantity END) OVER (
				PARTITION BY item_id
				ORDER BY moment
				ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
			),
		0) AS close_balance
	FROM {{ ref('int_operations_with_balance__agent_slot_item') }}
)
SELECT *
FROM tab
WHERE doc_type != 'move'
ORDER BY agent_name, item_name, doc_time