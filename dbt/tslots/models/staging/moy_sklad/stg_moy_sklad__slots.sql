{{ config(materialized='incremental', unique_key='slot_id', incremental_strategy='merge') }}

select
    slot->>'id'                                 as slot_id,
    raw_json->>'id'                             as store_id,
    slot->'zone'->>'id'                         as zone_id,
    slot->>'name'                               as name,
    (slot->>'updated')::timestamp             as updated
from {{ source('moysklad', 'raw') }},
     jsonb_array_elements(
         coalesce(raw_json->'slots'->'rows', '[]'::jsonb)
     ) as slot
where entity = 'store'
-- если выполняется
{% if is_incremental() %}
-- то приклеить к основному запросу это
    and (slot->>'updated')::timestamp > (select max(updated) from {{ this }})
{% endif %}
