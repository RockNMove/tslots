-- Таблицы: int_prep__operations_united_cleaned vs int_prep__operations_united
-- Инвариант: количество строк в cleaned не превышает количество строк в united —
--   фильтрация удалённых документов только убирает строки, но не дублирует их.
-- Ответственность: гарантирует что LEFT JOIN с аудитом не порождает лишних строк.
-- При нарушении: проверить что int_prep__audit_united_enriched не содержит дублей по doc_id
--   (тест assert_audit_no_duplicate_doc_id должен поймать это раньше).
SELECT
    c.cnt AS cleaned_count
    , u.cnt AS united_count
    , c.cnt - u.cnt AS diff
FROM (SELECT COUNT(*) AS cnt FROM {{ ref('int_prep__operations_united_cleaned') }}) c
CROSS JOIN (SELECT COUNT(*) AS cnt FROM {{ ref('int_prep__operations_united') }}) u
WHERE c.cnt > u.cnt
