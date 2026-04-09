-- models/marts/mart_billing.sql
{{ config(materialized='table') }}

{% set rate = var('rate_per_slot_day', 50) %}

with occupancy as (
    select *
    from {{ ref('int_slot_occupancy') }}
    where depositor_id is not null
),

monthly as (
    select
        date_trunc('month', occupied_from)::date    as billing_month,
        depositor_id,
        depositor_name,
        depositor_inn,
        store_name,
        count(distinct slot_id)                     as unique_slots_used,
        sum(days_occupied)                          as total_slot_days,
        round(sum(days_occupied) * {{ rate }}, 2)   as amount_rub,
        count(*)                                    as operations_count
    from occupancy
    group by 1, 2, 3, 4, 5
)

select
    billing_month,
    depositor_id,
    depositor_name,
    depositor_inn,
    store_name,
    unique_slots_used,
    round(total_slot_days::numeric, 2)              as total_slot_days,
    amount_rub,
    operations_count,
    to_char(billing_month, 'YYYY-MM')               as period_label
from monthly
order by billing_month desc, amount_rub desc
