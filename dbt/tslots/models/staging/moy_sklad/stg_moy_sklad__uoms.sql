{{ config(materialized='incremental', unique_key='uom_id', incremental_strategy='merge') }}

select
    raw_json->>'id'                                 as uom_id,
    raw_json->>'name'                               as name,
    (raw_json->>'updated')::timestamptz             as updated
from {{ source('moysklad', 'raw') }}
where entity = 'uom'
  and raw_json->>'id' is not null
{% if is_incremental() %}
    and (raw_json->>'updated')::timestamptz > (select max(updated) from {{ this }})
{% endif %}
