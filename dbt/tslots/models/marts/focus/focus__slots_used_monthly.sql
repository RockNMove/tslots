SELECT
	MAX(depositor_name) AS depositor_name
	, TO_CHAR(moment_day, 'YYYY-MM') AS moment_month
	, SUM(slots_used_day) AS slots_used_month
FROM {{ ref('int_slots_used__daily') }}
GROUP BY depositor_id, TO_CHAR(moment_day, 'YYYY-MM')
ORDER BY depositor_name, moment_month