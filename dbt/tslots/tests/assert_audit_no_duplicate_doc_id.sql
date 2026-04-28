-- Модель: int_prep__audit_all_latest
-- Инвариант: каждый doc_id встречается ровно один раз — дедупликация по latest event отработала корректно.
-- Ответственность: гарантирует что LEFT JOIN в int_prep__operations_filtered_3pl не порождает дубли строк.
-- При нарушении: проверить DISTINCT ON (doc_id) ORDER BY doc_id, moment DESC в int_prep__audit_all_latest.
SELECT
    doc_id
    , COUNT(*) AS duplicate_count
FROM {{ ref('int_prep__audit_all_latest') }}
GROUP BY doc_id
HAVING COUNT(*) > 1
