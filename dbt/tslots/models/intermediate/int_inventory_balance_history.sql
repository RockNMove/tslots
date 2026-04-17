-- int_inventory_balance_history.sql — ежедневная ведомость остатков в разрезе (слот, поклажедатель).
-- Учитывает дни без движений: товар продолжает занимать ячейку пока остаток > 0.
-- Логика: строим сетку (слот × поклажедатель × каждый день их диапазона), вешаем на неё
-- агрегированные операции за день, считаем нарастающий итог оконной функцией.
-- Перемещения считаются отдельно (move_in/move_out) — чтобы не задваивать занятость
-- в день когда товар просто перекладывают из ячейки в ячейку.

WITH
	-- 1. Уникальные пары (слот, поклажедатель) и диапазон их существования.
	-- seek_start/seek_end — первая и последняя операция пары: сетка строится именно в этом окне.
	-- Берём напрямую из int_operations_extended, а не через отдельный CTE filtered_ops
	-- (он ниже определён но не используется — можно удалить).
	slot_depositors AS (
	    SELECT
	        slot_id
	        , depositor_id
	        , MAX(slot_name)      AS slot_name
	        , MAX(depositor_name) AS depositor_name
	        , MAX(depositor_inn)  AS depositor_inn
	        , MIN(moment::date)   AS seek_start
	        , MAX(moment::date)   AS seek_end
	    FROM {{ ref('int_operations_extended') }}
	    WHERE slot_id IS NOT NULL
	      AND depositor_id IS NOT NULL
		GROUP BY slot_id, depositor_id
	),
	-- 2. Сетка дней: каждая пара (слот, поклажедатель) × каждый день своего диапазона.
	-- generate_series гарантирует строку даже в дни без операций — иначе нарастающий итог будет с дырами.
	grid AS (
		SELECT
			slot_id
			, depositor_id
			, slot_name
			, depositor_name
			, depositor_inn
			-- Генерируем даты от старта до конца с шагом в 1 день
			, generate_series(
				seek_start, 
				seek_end, 
				'1 day'::interval
			)::date AS moment_day
		FROM slot_depositors
	),
	-- 3. Агрегат операций за день по паре (слот, поклажедатель).
	-- daily_change — нетто за день (все операции, включая перемещения).
	-- real_in/out  — только реальные операции (supply/enter/demand/loss), без move.
	-- move_in/out  — только перемещения. Разделение нужно для is_used:
	--               если товар только переложили (move_out = real_in + move_in = close_balance=0),
	--               ячейка всё равно считается использованной в этот день.
	daily_agg AS (
	    SELECT
	        moment::date AS moment_day
	        , slot_id
	        , depositor_id
	        , SUM(quantity) AS daily_change
	        , SUM(CASE WHEN doc_type != 'move' and quantity>0 THEN quantity ELSE 0 END) AS real_in
	        , SUM(CASE WHEN doc_type != 'move' and quantity<0 THEN quantity ELSE 0 END) AS real_out
	        , SUM(CASE WHEN doc_type = 'move' and quantity>0 THEN quantity ELSE 0 END) AS move_in
	        , SUM(CASE WHEN doc_type = 'move' and quantity<0 THEN quantity ELSE 0 END) AS move_out
	    FROM {{ ref('int_operations_extended') }}
	    WHERE slot_id IS NOT NULL
	      AND depositor_id IS NOT NULL
	    GROUP BY moment::date, slot_id, depositor_id
	),

	-- 4. Нарастающий итог: вешаем daily_agg на сетку дней через LEFT JOIN.
	-- open_balance  — сумма daily_change за все дни ДО текущего (PRECEDING).
	-- close_balance — сумма включая текущий день (CURRENT ROW).
	-- Дни без операций: daily_agg не даёт строку → LEFT JOIN → NULL → COALESCE → 0.
	history AS (
		SELECT
			g.slot_id
			, g.depositor_id
			, g.depositor_inn
			, g.depositor_name
			, g.moment_day
			, g.slot_name
			, COALESCE(
				SUM(da.daily_change) OVER (
					PARTITION BY g.slot_id, g.depositor_id
					ORDER BY g.moment_day
					ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
				),
			0) AS open_balance
			, COALESCE(da.daily_change, 0) AS daily_change
			, COALESCE(
				SUM(da.daily_change) OVER (
					PARTITION BY g.slot_id, g.depositor_id
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
			AND g.slot_id = da.slot_id
			AND g.depositor_id = da.depositor_id
		ORDER BY depositor_id, slot_id, moment_day
	)

-- is_used: была ли ячейка физически занята этим поклажедателем в этот день.
-- close_balance > 0                              → занята (товар есть на конец дня).
-- open+real_in+move_in = -real_out, real_out≠0   → занята: всё что было + пришло = ушло в тот же день
--                                                   (нетто=0, но оборот был; -real_out т.к. real_out отрицательный).
-- close_balance < 0                              → NULL: ошибка данных, отрицательный остаток.
-- иначе                                          → 0: пусто.
SELECT
	slot_id
	, depositor_id
	, depositor_inn
	, depositor_name
	, moment_day
	, slot_name
    , open_balance
	, daily_change
	, close_balance
	, real_in
	, move_in
	, real_out
	, move_out
	, CASE
		WHEN close_balance > 0									THEN 1
		WHEN (open_balance + real_in + move_in) = -real_out
			AND real_out!=0								 		THEN 1
		WHEN close_balance < 0									THEN NULL
		ELSE 0
	  END AS is_used
FROM history
ORDER BY depositor_id, slot_id, moment_day