-- Модель: int_prep__audit_united_enriched
-- Инвариант: каждый doc_id встречается ровно один раз — дедупликация по latest event отработала корректно.
-- Ответственность: гарантирует что LEFT JOIN в int_prep__operations_united_cleaned не порождает дубли строк.
-- При нарушении: проверить DISTINCT ON (doc_id) ORDER BY doc_id, moment DESC в audit_united_enriched.
SELECT
    doc_id
    , COUNT(*) AS duplicate_count
FROM {{ ref('int_prep__audit_united_enriched') }}
GROUP BY doc_id
HAVING COUNT(*) > 1
