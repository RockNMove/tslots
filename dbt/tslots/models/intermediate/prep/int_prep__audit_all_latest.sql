-- int_prep__audit_all_latest.sql — актуальный статус документов по данным аудита.
-- Объединяет два staging-аудита (deleted + restored) через UNION ALL.
-- Оставляет только последнее событие по каждому doc_id (ORDER BY moment DESC).
-- Итоговый статус: puttorecyclebin → 'deleted', restorefromrecyclebin → 'active'.
-- Используется в int_operations_with_balance для LEFT JOIN — проставить статус документу.

WITH united AS (
    SELECT * FROM {{ ref('stg_moy_sklad__audit_deleted') }}
    UNION ALL
    SELECT * FROM {{ ref('stg_moy_sklad__audit_restored') }}
),
latest AS (
    SELECT DISTINCT ON (doc_id)
        doc_id
        , entity_type
        , event_type
        , moment
        , name
    FROM united
    ORDER BY doc_id, moment DESC
)
SELECT
    ROW_NUMBER() OVER (ORDER BY doc_id) AS id
    , doc_id
    , entity_type
    , event_type
    , moment
    , name
    , CASE
        WHEN event_type = 'puttorecyclebin'      THEN 'deleted'
        WHEN event_type = 'restorefromrecyclebin' THEN 'active'
      END AS status
FROM latest
