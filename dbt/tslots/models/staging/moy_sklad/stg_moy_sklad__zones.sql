{{ config(materialized='incremental', unique_key='zone_id', incremental_strategy='merge') }}

with stores as (
    select
        raw_json->>'id'     as store_id,
        raw_json
    from {{ source('moysklad', 'raw') }}
    where entity = 'store'
    -- если выполняется
    {% if is_incremental() %}
    -- то приклеить к основному запросу это
        and (raw_json->>'updated')::timestamp > (select max(updated) from {{ this }})
    {% endif %}
)

select
    zone->>'id'                                 as zone_id,
    s.store_id,
    zone->>'name'                               as name,
    (zone->>'updated')::timestamp             as updated
from stores s,
     jsonb_array_elements(
         coalesce(s.raw_json->'zones'->'rows', '[]'::jsonb)
     ) as zone
