-- focus__slots_used_monthly.sql — агрегат занятости ячеек по месяцам в разрезе агентов и поклажедателей.
-- Строится на основе int_premart__slots_balance_daily_grid (только is_used != 0).
-- slots_used — кол-во уникальных ячеек занятых за месяц.

SELECT
	MAX(agent_name)       AS agent_name
	, MAX(depositor_name) AS depositor_name
	, TO_CHAR(moment_day, 'YYYY MONTH') AS moment_month
	, COUNT(DISTINCT slot_id) as slots_used
FROM {{ ref('int_premart__slots_balance_daily_grid') }}
GROUP BY agent_id, depositor_id, TO_CHAR(moment_day, 'YYYY MONTH')
ORDER BY agent_name, depositor_name, moment_month