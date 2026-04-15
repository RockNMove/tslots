{{ config(materialized='incremental', unique_key='zone_id', incremental_strategy='merge') }}

with stores as (
    select
        raw_json->>'id'     as store_id,
        raw_json
    from {{ source('moysklad', 'raw') }}
    where entity = 'store'
    {% if is_incremental() %}
        and (raw_json->>'updated')::timestamptz > (select max(updated) from {{ this }})
    {% endif %}
)

select
    zone->>'id'                                 as zone_id,
    s.store_id,
    zone->>'name'                               as name,
    (zone->>'updated')::timestamptz             as updated
from stores s,
     jsonb_array_elements(
         coalesce(s.raw_json->'zones'->'rows', '[]'::jsonb)
     ) as zone
