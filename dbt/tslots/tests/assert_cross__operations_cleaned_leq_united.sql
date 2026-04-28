-- Таблицы: int_prep__operations_filtered_3pl vs int_prep__operations_all
-- Инвариант: количество строк в filtered не превышает количество строк в all —
--   фильтрация только убирает строки, но не дублирует их.
-- Ответственность: гарантирует что JOIN с аудитом и items не порождает лишних строк.
-- При нарушении: проверить что int_prep__audit_all_latest не содержит дублей по doc_id
--   (тест assert_audit_no_duplicate_doc_id должен поймать это раньше).
SELECT
    c.cnt AS filtered_count
    , u.cnt AS all_count
    , c.cnt - u.cnt AS diff
FROM (SELECT COUNT(*) AS cnt FROM {{ ref('int_prep__operations_filtered_3pl') }}) c
CROSS JOIN (SELECT COUNT(*) AS cnt FROM {{ ref('int_prep__operations_all') }}) u
WHERE c.cnt > u.cnt
