{{ config(materialized='incremental', unique_key='store_id', incremental_strategy='merge') }}

select
    raw_json->>'id'                             as store_id,
    raw_json->>'name'                           as name,
    (raw_json->>'updated')::timestamp         as updated
from {{ source('moysklad', 'raw') }}
where entity = 'store'
  and raw_json->>'id' is not null
-- если выполняется
{% if is_incremental() %}
-- то приклеить к основному запросу это
    and (raw_json->>'updated')::timestamp > COALESCE((select max(updated) from {{ this }}), '1970-01-01'::timestamp)
{% endif %}
