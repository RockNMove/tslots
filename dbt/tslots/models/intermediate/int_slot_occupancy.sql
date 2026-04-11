-- int_slot_occupancy.sql — интервалы занятости ячеек. Ключевая бизнес-модель.
--
-- ЗАДАЧА: МойСклад хранит события (приход/уход товара), нам нужны интервалы.
-- Для каждой пары (ячейка + товар) склеиваем in-событие с ближайшим out-событием.
-- Результат: [occupied_from, freed_at]. Если freed_at = NULL — ячейка занята сейчас.
--
-- АЛГОРИТМ:
--   1. Разделяем события на in (supply, enter, move_in) и out (demand, loss, move_out).
--   2. Нумеруем каждую группу через ROW_NUMBER() по (slot_id, prod_id, date).
--   3. LEFT JOIN по номеру: первый in → первый out, второй in → второй out и т.д.
--   4. LEFT JOIN: если out ещё не было → freed_at = NULL (открытый интервал).
--   5. Обогащаем данными о товаре, варианте и поклажедателе.

{{ config(materialized='table') }}

with ops as (
    -- Берём все операции из staging, только с заполненной ячейкой.
    select * from {{ ref('stg_operations') }}
    where slot_id is not null
),

ins as (
    -- In-события: приход товара в ячейку.
    -- ROW_NUMBER нумерует каждое in-событие по порядку для данной ячейки и товара.
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
    -- Out-события: уход товара из ячейки.
    -- ROW_NUMBER нумерует каждое out-событие так же как ins.
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

intervals as (
    -- Склеиваем: первый in → первый out, второй in → второй out (по rn).
    -- LEFT JOIN: если out ещё нет → freed_at = NULL → ячейка занята сейчас.
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
    -- Обогащаем интервалы данными о ячейке, товаре и поклажедателе.
    select
        iv.slot_id,
        sl.slot_name,
        sl.zone_name,
        sl.store_name,
        sl.store_id,

        iv.prod_id,
        va.variant_id,
        -- Товар может быть variant (у него есть product_id) или product напрямую.
        coalesce(pr.name,    pr2.name)    as product_name,
        coalesce(pr.article, pr2.article) as article,
        va.lot,
        va.mfg_date,

        -- Поклажедатель: сначала из атрибута товара, потом из агента документа.
        coalesce(pr.depositor_id, pr2.depositor_id, iv.op_agent_id) as depositor_id,
        ag.name                           as depositor_name,
        ag.inn                            as depositor_inn,

        iv.occupied_from,
        iv.freed_at,

        -- Длительность в сутках. Для открытых интервалов считаем до текущего момента.
        extract(
            epoch from (coalesce(iv.freed_at, now()) - iv.occupied_from)
        ) / 86400.0                       as days_occupied,

        -- Признак что ячейка занята прямо сейчас (нет события out).
        (iv.freed_at is null)             as is_currently_occupied,

        iv.in_doc_id,
        iv.in_doc_type,
        iv.out_doc_id,
        iv.out_doc_type,
        iv.quantity

    from intervals iv
    left join {{ ref('stg_stores') }}   sl  on sl.slot_id    = iv.slot_id
    left join {{ ref('stg_variants') }} va  on va.variant_id = iv.prod_id
    left join {{ ref('stg_products') }} pr  on pr.product_id = va.product_id
    left join {{ ref('stg_products') }} pr2 on pr2.product_id = iv.prod_id
    left join {{ ref('stg_agents') }}   ag
           on ag.agent_id = coalesce(pr.depositor_id, pr2.depositor_id, iv.op_agent_id)
)

select * from enriched
order by depositor_name, occupied_from
