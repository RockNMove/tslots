-- models/marts/mart_slot_status.sql
-- Текущее состояние склада: какие ячейки заняты прямо сейчас.
{{ config(materialized='table') }}

select
    slot_id,
    slot_name,
    zone_name,
    store_name,
    store_id,
    product_name,
    article,
    lot,
    mfg_date,
    depositor_name,
    depositor_inn,
    quantity,
    occupied_from,
    round(
        extract(epoch from (now() - occupied_from)) / 86400.0,
        1
    )                   as days_since_in,
    in_doc_id,
    in_doc_type
from {{ ref('int_slot_occupancy') }}
where is_currently_occupied = true
order by store_name, zone_name, slot_name
