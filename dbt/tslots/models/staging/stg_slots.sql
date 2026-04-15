{{ config(materialized='incremental', unique_key='slot_id', incremental_strategy='merge') }}

select
    slot->>'id'                                 as slot_id,
    raw_json->>'id'                             as store_id,
    slot->'zone'->>'id'                         as zone_id,
    slot->>'name'                               as name,
    (slot->>'updated')::timestamptz             as updated
from {{ source('moysklad', 'raw') }},
     jsonb_array_elements(
         coalesce(raw_json->'slots'->'rows', '[]'::jsonb)
     ) as slot
where entity = 'store'
{% if is_incremental() %}
    and (slot->>'updated')::timestamptz > (select max(updated) from {{ this }})
{% endif %}
