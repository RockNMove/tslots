-- stg_moy_sklad__audit_restored.sql — документы восстановленные из корзины МойСклад.
-- Каждая строка = одно событие restorefromrecyclebin для одного документа.
-- Зерно: doc_id + event_type + moment (один документ может быть восстановлен несколько раз).

{{ config(materialized='incremental', unique_key=['doc_id', 'event_type', 'moment'], incremental_strategy='merge') }}

SELECT
    raw_json->>'doc_id'      AS doc_id,
    raw_json->>'entity_type' AS entity_type,
    raw_json->>'event_type'  AS event_type,
    raw_json->>'name'        AS name,
    (raw_json->>'moment')::timestamp AS moment
FROM {{ source('moysklad', 'raw') }}
WHERE entity = 'audit_restored'
{% if is_incremental() %}
  AND (raw_json->>'moment')::timestamp > COALESCE((SELECT MAX(moment) FROM {{ this }}), '1970-01-01'::timestamp)
{% endif %}
