-- int_premart__slots_balance_daily_grid.sql — ежедневная ведомость остатков в разрезе (слот × агент × товар).
-- seek_end = CURRENT_DATE — сетка всегда идёт до сегодня, даже без свежих операций.
-- Финальный SELECT отдаёт только строки где is_used != 0 (пустые дни без движений отброшены).
-- is_used: 1 — занято, 2 — ошибка данных (close_balance < 0), 0 — пусто (в результат не попадает).
-- Учитывает дни без движений: товар продолжает занимать ячейку пока остаток > 0.
-- Логика: строим сетку (slot × depositor × item × каждый день), вешаем агрегат за день, считаем нарастающий итог.
-- Атрибуты агента, ячейки и товара денормализованы через JOIN в CTE history (agents, int_enrich__slots_extended, int_enrich__items_united_extended).
-- Перемещения считаются отдельно (move_in/move_out) — чтобы не задваивать занятость
-- в день когда товар просто перекладывают из ячейки в ячейку.

WITH
	-- 1. Уникальные пары (слот, поклажедатель) и диапазон их существования.
	-- seek_start/seek_end — первая и последняя операция пары: сетка строится именно в этом окне.
	-- Берём напрямую из int_premart_operations_each.
	slot_depositors AS (
	    SELECT
	        agent_id
	        , slot_id
			, item_id
	        , MIN(moment_day)   	AS seek_start
	    FROM {{ ref('int_premart__operations_each') }}
		GROUP BY agent_id, slot_id, item_id
	),
	-- 2. Сетка дней: каждая пара (слот, поклажедатель) × каждый день своего диапазона.
	-- generate_series гарантирует строку даже в дни без операций — иначе нарастающий итог будет с дырами.
	grid AS (
		SELECT
			-- Генерируем даты от старта до конца с шагом в 1 день.
			-- Развертывание плоской таблицы в историческую сетку (Fan-out):
			-- Для каждой записи генерируется непрерывный ряд дат от seek_start до текущего дня.
			generate_series(
				seek_start, 
				CURRENT_DATE, 
				'1 day'::interval
			)::date AS moment_day

			, agent_id
	        , slot_id
			, item_id
		FROM slot_depositors
	),
	-- 3. Агрегат операций за день по (moment_day, depositor_id, slot_id, item_id).
	-- quantity — нетто за день (все операции, включая перемещения).
	-- real_in/out  — только реальные операции (supply/enter/demand/loss), без move.
	-- move_in/out  — только перемещения. Разделение нужно для is_used:
	--               если товар только переложили (move_out = real_in + move_in = close_balance=0),
	--               ячейка всё равно считается использованной в этот день.
	daily_agg AS (
	    SELECT
			agent_id
	        , slot_id
			, item_id
	        , moment_day
	        , SUM(quantity) AS quantity
	        , SUM(CASE WHEN doc_type != 'move' and quantity>0 THEN quantity ELSE 0 END) AS real_in
	        , SUM(CASE WHEN doc_type != 'move' and quantity<0 THEN quantity ELSE 0 END) AS real_out
	        , SUM(CASE WHEN doc_type = 'move' and quantity>0 THEN quantity ELSE 0 END) AS move_in
	        , SUM(CASE WHEN doc_type = 'move' and quantity<0 THEN quantity ELSE 0 END) AS move_out 
	    FROM {{ ref('int_premart__operations_each') }}
	    GROUP BY moment_day, agent_id, slot_id, item_id
	),

	-- 4. Нарастающий итог: вешаем daily_agg на сетку дней через LEFT JOIN.
	-- open_balance  — сумма quantity за все дни ДО текущего (PRECEDING).
	-- close_balance — сумма включая текущий день (CURRENT ROW).
	-- Дни без операций: daily_agg не даёт строку → LEFT JOIN → NULL → COALESCE → 0.
	history AS (
		SELECT
			g.agent_id
			, g.slot_id
			, g.item_id
			, i.depositor_id
			, g.moment_day
			, a.inn AS agent_inn
			, a.name AS agent_name
			, s.store_name
			, s.zone_name
			, s.name AS slot_name
			, i.name AS item_name
			, i.depositor_inn
			, i.depositor_name
			, i.article
	        , i.product
	        , i.lot
	        , i.mfg_date
			, COALESCE(
				SUM(da.quantity) OVER (
					PARTITION BY g.slot_id, g.agent_id, g.item_id
					ORDER BY g.moment_day
					ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
				),
			0) AS open_balance
			, COALESCE(da.quantity, 0) AS quantity
			, COALESCE(
				SUM(da.quantity) OVER (
					PARTITION BY g.slot_id, g.agent_id, g.item_id
					ORDER BY g.moment_day
					ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
				),
			0) AS close_balance
			, COALESCE(da.real_in, 0) AS real_in
			, COALESCE(da.move_in, 0) AS move_in
			, COALESCE(da.real_out, 0) AS real_out
			, COALESCE(da.move_out, 0) AS move_out
		FROM grid g
		LEFT JOIN daily_agg da
			ON g.moment_day = da.moment_day
			AND g.agent_id IS NOT DISTINCT FROM da.agent_id
			AND g.slot_id  IS NOT DISTINCT FROM da.slot_id
			AND g.item_id = da.item_id
		LEFT JOIN {{ ref('stg_moy_sklad__agents') }} a ON g.agent_id = a.agent_id
		LEFT JOIN {{ ref('int_enrich__slots_extended') }} s ON g.slot_id = s.slot_id
		LEFT JOIN {{ ref('int_enrich__items_united_extended') }} i ON g.item_id = i.item_id
		
	),
	history_with_slots_using AS(
		-- is_used: была ли ячейка физически занята этим поклажедателем в этот день.
		-- close_balance > 0                              → занята (товар есть на конец дня).
		-- open+real_in+move_in = -real_out, real_out≠0   → занята: всё что было + пришло = ушло в тот же день
		--                                                   (нетто=0, но оборот был; -real_out т.к. real_out отрицательный).
		-- close_balance < 0                              → NULL: ошибка данных, отрицательный остаток.
		-- иначе                                          → 0: пусто.
		SELECT
			agent_id
			, slot_id
			, item_id
			, depositor_id
			, moment_day
			, agent_inn
			, agent_name
			, store_name
			, zone_name
			, slot_name
			, item_name
			, depositor_inn
			, depositor_name
			, article
	        , product
	        , lot
	        , mfg_date
			, open_balance
			, quantity
			, close_balance
			, real_in
			, move_in
			, real_out
			, move_out
			, CASE
				WHEN close_balance > 0									THEN 1
				WHEN (open_balance + real_in + move_in) = -real_out
					AND real_out!=0								 		THEN 1
				WHEN close_balance < 0									THEN 2
				ELSE 0
			END AS is_used
		FROM history
	)
SELECT
	agent_id
	, slot_id
	, item_id
	, depositor_id
	, moment_day
	, agent_inn
	, agent_name
	, store_name
	, zone_name
	, slot_name
	, item_name
	, depositor_inn
	, depositor_name
	, article
	, product
	, lot
	, mfg_date
	, open_balance
	, quantity
	, close_balance
	, real_in
	, move_in
	, real_out
	, move_out
FROM history_with_slots_using
WHERE is_used!=0



