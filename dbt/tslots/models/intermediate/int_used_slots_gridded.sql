WITH 
	-- 1. Определяем диапазон дат и уникальные слоты
	dates AS (
	    SELECT 
	    	generate_series(min(moment::date), max(moment::date), '1 day'::interval)::date AS moment_day
	    FROM {{ ref('int_operations_extended') }}
	),
	slots AS (
	    SELECT DISTINCT 
		slot_id
		, slot_name
	    FROM {{ ref('int_operations_extended') }}
		WHERE slot_id IS NOT NULL
	),
	-- 2. Создаем "сетку": каждый слот на каждый день
	grid AS (
	    SELECT 
		    d.moment_day
		    , s.slot_id
			, s.slot_name
	    FROM dates d
	    CROSS JOIN slots s
	),
	-- 3. Читаем изменения за каждый день
	daily_agg AS(	
		SELECT 
			moment::date
			, slot_id
			, slot_name
			, sum(quantity) AS daily_change
		FROM {{ ref('int_operations_extended') }}
		WHERE slot_id IS NOT NULL
		GROUP BY moment::date, slot_id, slot_name
	),
	-- 4. Вешаем на сетку ежедневные изменения и считаем нарастающий итог
	history AS (
		SELECT 
		    g.moment_day
		    , g.slot_id
			, g.slot_name
		    , COALESCE(SUM(da.daily_change) 
		    	OVER (
			    	PARTITION BY g.slot_id 
			    	ORDER BY g.moment_day
			    	ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING -- От начала до "1-й предшествующей"
		    	),
		    0) AS open_balance
		    , COALESCE(da.daily_change,0) AS daily_change
		FROM grid g
		LEFT JOIN daily_agg da ON g.moment_day = da.moment AND g.slot_id = da.slot_id
	)
-- Итоговая ведомость
SELECT 
	moment_day
	, slot_id
	, slot_name
	, open_balance
	, daily_change
	, CASE 
		WHEN open_balance=0 AND daily_change=0
		THEN 0
		
		WHEN (open_balance + daily_change)<0
		THEN NULL 
		
		ELSE 1
	END AS is_used
FROM history
ORDER BY slot_id, moment_day
