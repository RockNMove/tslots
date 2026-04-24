-- stg_moy_sklad__audit_deleted.sql — документы помещённые в корзину МойСклад.
-- Каждая строка = одно событие puttorecyclebin для одного документа.
-- Зерно: doc_id + event_type + moment (один документ может быть удалён несколько раз).

{{ config(materialized='incremental', unique_key=['doc_id', 'event_type', 'moment'], incremental_strategy='merge') }}

SELECT
    raw_json->>'doc_id'      AS doc_id,
    raw_json->>'entity_type' AS entity_type,
    raw_json->>'event_type'  AS event_type,
    raw_json->>'name'        AS name,
    (raw_json->>'moment')::timestamp AS moment
FROM {{ source('moysklad', 'raw') }}
WHERE entity = 'audit_deleted'
{% if is_incremental() %}
  AND (raw_json->>'moment')::timestamp > (SELECT MAX(moment) FROM {{ this }})
{% endif %}
