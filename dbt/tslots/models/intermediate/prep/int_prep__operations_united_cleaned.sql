-- int_prep__operations_united_cleaned.sql — операции без удалённых документов.
-- Берёт int_prep__operations_united (raw UNION ALL) и исключает документы помещённые в корзину МойСклад.
-- Документы без записи в аудите и восстановленные из корзины считаются активными и остаются.
-- Используется как источник для всех downstream-моделей вместо int_prep__operations_united.

SELECT
    u.*
FROM {{ ref('int_prep__operations_united') }} u
LEFT JOIN {{ ref('int_prep__audit_united_enriched') }} a ON u.doc_id = a.doc_id
WHERE a.status IS NULL OR a.status = 'active'
