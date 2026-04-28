-- int_operations_with_balance__agent_slot_item.sql — операции с денормализованными атрибутами и нарастающими балансами.
-- Зерно: одна строка на операцию (agent × slot × item).
-- INNER JOIN на int_prep__items_all отфильтровывает услуги, наборы и прочие сущности без товарной карточки.
-- store_name берётся из документа (через store_id), а не из ячейки —
-- это позволяет корректно показывать склад даже когда ячейка не указана.
-- Операции без slot_id (ячейка не указана в документе МойСклад) получают slot_id = 'off_slot',
-- slot_name = 'off_slot', zone_name = 'off_slot'. Они образуют отдельную партицию и не влияют
-- на остатки реальных слотов. В поле slot_oper_errors такие строки получают OPER_WARNING: Out-of-slot operation.
-- open/close_total_balance — нарастающий остаток по товару (item_id), все склады вместе; move не учитывается.
-- open/close_slot_balance  — нарастающий остаток по товару в ячейке (item_id, slot_id); off_slot считается отдельно.
-- slot_oper_errors         — операционные аномалии: OPER_ERROR slot overdraft, OPER_WARNING Out-of-slot operation.
WITH
	tab AS(
		SELECT
			o.id
			, o.item_id
			, o.slot_id
			, o.store_id
			, o.agent_id
			, i.depositor_id
			, i.expected_bin_qty
			, s.name AS store_name
			, COALESCE(sz.zone_name, 'off_zone') AS zone_name
			, o.doc_type
			, o.number AS doc_name
			, o.moment
			, o.moment::date AS moment_day
			, o.op_type 
			, COALESCE(sz.slot_name, 'off_slot') AS slot_name
			, o.quantity
			, CASE WHEN o.doc_type != 'move' AND o.quantity > 0 THEN o.quantity ELSE 0 END AS real_in
			, CASE WHEN o.doc_type != 'move' AND o.quantity < 0 THEN o.quantity ELSE 0 END AS real_out
			, CASE WHEN o.doc_type  = 'move' AND o.quantity > 0 THEN o.quantity ELSE 0 END AS move_in
			, CASE WHEN o.doc_type  = 'move' AND o.quantity < 0 THEN o.quantity ELSE 0 END AS move_out
			, i.uom
			, i.name AS item_name
			, i.product 
			, i.lot
			, i.mfg_date 
			, i.article 
			, i.weight 
			, i.volume 
			, a.name AS agent_name
			, a.inn AS agent_inn
			, i.depositor_name
			, i.depositor_inn
		FROM {{ ref('int_prep__operations_filtered_3pl') }} o
		LEFT JOIN {{ ref('int_prep__items_all') }} i ON o.item_id=i.item_id     -- lot, mfg_date, uom, depositor и др.
		LEFT JOIN {{ ref('int_prep__slots_all') }} sz ON o.slot_id=sz.slot_id          -- slot_name, zone_name; NULL если ячейка не указана
		LEFT JOIN {{ ref('stg_moy_sklad__agents') }} a ON o.agent_id=a.agent_id       -- agent_name/inn из документа (demand, supply)
		LEFT JOIN {{ ref('stg_moy_sklad__stores') }} s ON o.store_id=s.store_id       -- store_name из документа, не из ячейки
	),
	tab_with_balance AS(	
		SELECT
		*
		, COALESCE(
			SUM(quantity) OVER(
				PARTITION BY store_id, slot_id, item_id -- store_id включен в группировку, потому что операция может быть без слота
				ORDER BY moment, id
				ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
			),
		0) AS open_slot_balance
		, COALESCE(
			SUM(quantity) OVER(
				PARTITION BY store_id, slot_id, item_id -- store_id включен в группировку, потому что операция может быть без слота
				ORDER BY moment, id
				ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
			),
		0) AS close_slot_balance
		, COALESCE(
			SUM(real_in+real_out) OVER(
				PARTITION BY item_id
				ORDER BY moment, id
				ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
			),
		0) AS open_total_balance
		, COALESCE(
			SUM(real_in+real_out) OVER(
				PARTITION BY item_id
				ORDER BY moment, id
				ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
			),
		0) AS close_total_balance
		FROM tab
	)
SELECT
    *
    , CONCAT_WS(
	' | '
	, CASE WHEN close_slot_balance<0 THEN 'OPER_ERROR: slot overdraft' ELSE NULL END
	, CASE WHEN slot_id = 'off_slot' THEN 'OPER_WARNING: Out-of-slot operation' ELSE NULL END
) AS slot_oper_errors
FROM tab_with_balance
