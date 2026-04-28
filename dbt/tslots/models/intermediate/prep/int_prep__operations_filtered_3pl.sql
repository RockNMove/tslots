-- int_prep__operations_filtered_3pl.sql — операции готовые к аналитике: проведённые, активные, только 3PL-товары.
-- Источник: int_prep__operations_all. Фильтры: applicable, аудит (не deleted), INNER JOIN на items, depositor != 'not_3pl'.
-- Используется как единственный источник для всех downstream-моделей.

SELECT
    o.*
FROM {{ ref('int_prep__operations_all') }} o
INNER JOIN {{ ref('int_prep__items_all') }} i ON o.item_id = i.item_id
LEFT JOIN {{ ref('int_prep__audit_all_latest') }} a ON o.doc_id = a.doc_id
WHERE o.applicable = true
    AND i.depositor_name != 'not_3pl'
    AND (a.status IS NULL OR a.status = 'active')

