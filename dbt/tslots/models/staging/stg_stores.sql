{{ config(materialized='incremental', unique_key='store_id', incremental_strategy='merge') }}

select
    raw_json->>'id'                             as store_id,
    raw_json->>'name'                           as name,
    (raw_json->>'updated')::timestamptz         as updated
from {{ source('moysklad', 'raw') }}
where entity = 'store'
  and raw_json->>'id' is not null
{% if is_incremental() %}
    and (raw_json->>'updated')::timestamptz > (select max(updated) from {{ this }})
{% endif %}
