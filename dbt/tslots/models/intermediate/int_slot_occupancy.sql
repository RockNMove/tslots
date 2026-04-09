-- models/intermediate/int_slot_occupancy.sql
--
-- Ключевая бизнес-модель: интервалы занятости ячеек.
-- Для каждой пары (ячейка + товар) склеиваем in-событие с ближайшим out-событием.
-- Если out ещё не было → freed_at = NULL (ячейка занята прямо сейчас).

{{ config(materialized='table') }}

with ops as (
    select * from {{ ref('stg_operations') }}
    where slot_id is not null
),

ins as (
    select
        slot_id,
        prod_id,
        date                        as occupied_from,
        doc_id                      as in_doc_id,
        type                        as in_doc_type,
        quantity,
        agent_id                    as op_agent_id,
        row_number() over (
            partition by slot_id, prod_id
            order by date
        )                           as rn
    from ops
    where op_type = 'in'
),

outs as (
    select
        slot_id,
        prod_id,
        date                        as freed_at,
        doc_id                      as out_doc_id,
        type                        as out_doc_type,
        row_number() over (
            partition by slot_id, prod_id
            order by date
        )                           as rn
    from ops
    where op_type = 'out'
),

-- Склеиваем: первый in → первый out, второй in → второй out и т.д.
-- LEFT JOIN: если out ещё нет → freed_at = NULL (открытый интервал)
intervals as (
    select
        i.slot_id,
        i.prod_id,
        i.occupied_from,
        o.freed_at,
        i.in_doc_id,
        i.in_doc_type,
        o.out_doc_id,
        o.out_doc_type,
        i.quantity,
        i.op_agent_id
    from ins i
    left join outs o
           on o.slot_id = i.slot_id
          and o.prod_id  = i.prod_id
          and o.rn       = i.rn
),

enriched as (
    select
        iv.slot_id,
        sl.slot_name,
        sl.zone_name,
        sl.store_name,
        sl.store_id,

        iv.prod_id,
        va.variant_id,
        coalesce(pr.name,  pr2.name)    as product_name,
        coalesce(pr.article, pr2.article) as article,
        va.lot,
        va.mfg_date,

        -- Поклажедатель: сначала из атрибута товара, потом из агента документа
        coalesce(pr.depositor_id, pr2.depositor_id, iv.op_agent_id) as depositor_id,
        ag.name                         as depositor_name,
        ag.inn                          as depositor_inn,

        iv.occupied_from,
        iv.freed_at,

        -- Длительность в сутках; для открытых интервалов считаем до текущего момента
        extract(
            epoch from (coalesce(iv.freed_at, now()) - iv.occupied_from)
        ) / 86400.0                     as days_occupied,

        (iv.freed_at is null)           as is_currently_occupied,

        iv.in_doc_id,
        iv.in_doc_type,
        iv.out_doc_id,
        iv.out_doc_type,
        iv.quantity

    from intervals iv
    left join {{ ref('stg_stores') }}   sl on sl.slot_id    = iv.slot_id
    left join {{ ref('stg_variants') }} va on va.variant_id = iv.prod_id
    left join {{ ref('stg_products') }} pr on pr.product_id = va.product_id
    left join {{ ref('stg_products') }} pr2 on pr2.product_id = iv.prod_id
    left join {{ ref('stg_agents') }}   ag
           on ag.agent_id = coalesce(pr.depositor_id, pr2.depositor_id, iv.op_agent_id)
)

select * from enriched
order by depositor_name, occupied_from
