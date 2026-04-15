{{ config(materialized='incremental', unique_key='agent_id', incremental_strategy='merge') }}

select
    raw_json->>'id'                                 as agent_id,
    raw_json->>'name'                               as name,
    raw_json->>'inn'                                as inn,
    (raw_json->>'updated')::timestamptz             as updated
from {{ source('moysklad', 'raw') }}
where entity = 'counterparty'
  and raw_json->>'id' is not null
{% if is_incremental() %}
    and (raw_json->>'updated')::timestamptz > (select max(updated) from {{ this }})
{% endif %}
