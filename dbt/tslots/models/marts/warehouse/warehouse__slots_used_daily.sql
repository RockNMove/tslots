SELECT
	*
FROM {{ ref('int_slots_used__daily') }}
ORDER BY depositor_name, moment_day