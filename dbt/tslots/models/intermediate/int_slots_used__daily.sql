-- int_slots_used__daily.sql — уникальные занятые ячейки (паллето-места) по поклажедателям за день.
-- Зерно: поклажедатель × день.
-- Источник: int_balance__slot_item_daily_spine (только is_used = 1, off_slot исключён).
-- Используется для биллинга: warehouse__slots_used_daily (полная история), focus__slots_used_monthly (агрегат).
SELECT
	depositor_id
	, MAX(depositor_name) AS depositor_name
	, moment_day
	, COUNT(DISTINCT slot_id) AS slots_used_day
FROM {{ ref('int_balance__slot_item_daily_spine') }}
WHERE is_used = 1 AND slot_id != 'off_slot'
GROUP BY depositor_id, moment_day