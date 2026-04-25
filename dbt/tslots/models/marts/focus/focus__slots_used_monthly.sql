-- focus__slots_used_monthly.sql — агрегат занятости ячеек по месяцам в разрезе агентов и поклажедателей.
-- Строится на основе int_balance__agent_slot_item_daily_spine (только is_used != 0).
-- slots_used — кол-во уникальных ячеек занятых за месяц.

SELECT
	MAX(depositor_name)                   AS depositor_name
	, TO_CHAR(moment_day, 'YYYY-MM')        AS moment_month
	, COUNT(DISTINCT slot_id)               AS slots_used
FROM {{ ref('int_balance__agent_slot_item_daily_spine') }}
GROUP BY depositor_id, TO_CHAR(moment_day, 'YYYY-MM')
ORDER BY depositor_name, moment_month