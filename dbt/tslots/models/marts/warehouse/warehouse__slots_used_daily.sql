-- warehouse__slots_used_daily.sql — полная история занятости ячеек (паллето-мест) по поклажедателям.
-- Зерно: поклажедатель × день. Строится на основе int_slots_used__daily.
-- Используется для биллинга и как детализация к focus__slots_used_monthly.
SELECT
	*
FROM {{ ref('int_slots_used__daily') }}
ORDER BY depositor_name, moment_day