-- models/staging/stg_stores.sql
{{ config(materialized='view') }}

with stores as (
    select
        ms_id                               as store_id,
        raw_json->>'name'                   as name,
        (raw_json->>'updated')::timestamptz as updated
    from {{ source('moysklad', 'stores') }}
),

zones as (
    select
        zone->>'id'                         as zone_id,
        s.ms_id                             as store_id,
        zone->>'name'                       as name,
        (zone->>'updated')::timestamptz     as updated
    from raw_moysklad.stores s,
         jsonb_array_elements(
             coalesce(s.raw_json->'zones'->'rows', '[]'::jsonb)
         ) as zone
),

slots as (
    select
        slot->>'id'                         as slot_id,
        s.ms_id                             as store_id,
        slot->'zone'->>'id'                 as zone_id,
        slot->>'name'                       as name,
        (slot->>'updated')::timestamptz     as updated
    from raw_moysklad.stores s,
         jsonb_array_elements(
             coalesce(s.raw_json->'slots'->'rows', '[]'::jsonb)
         ) as slot
)

select
    sl.slot_id,
    sl.store_id,
    sl.zone_id,
    sl.name                                 as slot_name,
    z.name                                  as zone_name,
    st.name                                 as store_name,
    sl.updated
from slots sl
left join zones  z  on z.zone_id   = sl.zone_id
left join stores st on st.store_id = sl.store_id
