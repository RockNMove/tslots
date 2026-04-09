-- models/staging/stg_operations.sql
--
-- Разворачивает сырые JSONB из 5 типов документов в единую таблицу позиций.
-- SQL-аналог твоего pandas json_normalize + filter_and_rename_columns.
--
-- jsonb_array_elements() = record_path=['positions','rows'] в pd.json_normalize
-- raw_json->'agent'->>'id' = безопасное извлечение: NULL если поля нет, не ошибка

{{ config(materialized='view') }}

with demand_positions as (
    select
        d.ms_id                                          as doc_id,
        d.raw_json->>'moment'                            as doc_moment,
        d.raw_json->>'name'                              as doc_name,
        d.raw_json->'agent'->>'id'                       as agent_id,
        pos->>'id'                                       as prod_id,
        (pos->>'quantity')::numeric                      as quantity,
        pos->'slot'->>'id'                               as slot_id,
        d.raw_json->>'updated'                           as doc_updated,
        'demand'                                         as meta_type,
        'out'                                            as op_type
    from {{ source('moysklad', 'demands') }} d,
         jsonb_array_elements(
             coalesce(d.raw_json->'positions'->'rows', '[]'::jsonb)
         ) as pos
    where pos->'slot'->>'id' is not null
),

supply_positions as (
    select
        s.ms_id                                          as doc_id,
        s.raw_json->>'moment'                            as doc_moment,
        s.raw_json->>'name'                              as doc_name,
        s.raw_json->'agent'->>'id'                       as agent_id,
        pos->>'id'                                       as prod_id,
        (pos->>'quantity')::numeric                      as quantity,
        pos->'slot'->>'id'                               as slot_id,
        s.raw_json->>'updated'                           as doc_updated,
        'supply'                                         as meta_type,
        'in'                                             as op_type
    from {{ source('moysklad', 'supplies') }} s,
         jsonb_array_elements(
             coalesce(s.raw_json->'positions'->'rows', '[]'::jsonb)
         ) as pos
    where pos->'slot'->>'id' is not null
),

loss_positions as (
    select
        l.ms_id                                          as doc_id,
        l.raw_json->>'moment'                            as doc_moment,
        l.raw_json->>'name'                              as doc_name,
        coalesce(l.raw_json->'agent'->>'id', null)       as agent_id,
        pos->>'id'                                       as prod_id,
        (pos->>'quantity')::numeric                      as quantity,
        pos->'slot'->>'id'                               as slot_id,
        l.raw_json->>'updated'                           as doc_updated,
        'loss'                                           as meta_type,
        'out'                                            as op_type
    from {{ source('moysklad', 'losses') }} l,
         jsonb_array_elements(
             coalesce(l.raw_json->'positions'->'rows', '[]'::jsonb)
         ) as pos
    where pos->'slot'->>'id' is not null
),

enter_positions as (
    select
        e.ms_id                                          as doc_id,
        e.raw_json->>'moment'                            as doc_moment,
        e.raw_json->>'name'                              as doc_name,
        coalesce(e.raw_json->'agent'->>'id', null)       as agent_id,
        pos->>'id'                                       as prod_id,
        (pos->>'quantity')::numeric                      as quantity,
        pos->'slot'->>'id'                               as slot_id,
        e.raw_json->>'updated'                           as doc_updated,
        'enter'                                          as meta_type,
        'in'                                             as op_type
    from {{ source('moysklad', 'enters') }} e,
         jsonb_array_elements(
             coalesce(e.raw_json->'positions'->'rows', '[]'::jsonb)
         ) as pos
    where pos->'slot'->>'id' is not null
),

-- MOVE порождает две строки на позицию: out из sourceSlot, in в targetSlot
move_out as (
    select
        m.ms_id                                          as doc_id,
        m.raw_json->>'moment'                            as doc_moment,
        m.raw_json->>'name'                              as doc_name,
        null::text                                       as agent_id,
        pos->>'id'                                       as prod_id,
        (pos->>'quantity')::numeric                      as quantity,
        pos->'sourceSlot'->>'id'                         as slot_id,
        m.raw_json->>'updated'                           as doc_updated,
        'move'                                           as meta_type,
        'out'                                            as op_type
    from {{ source('moysklad', 'moves') }} m,
         jsonb_array_elements(
             coalesce(m.raw_json->'positions'->'rows', '[]'::jsonb)
         ) as pos
    where pos->'sourceSlot'->>'id' is not null
),

move_in as (
    select
        m.ms_id                                          as doc_id,
        m.raw_json->>'moment'                            as doc_moment,
        m.raw_json->>'name'                              as doc_name,
        null::text                                       as agent_id,
        pos->>'id'                                       as prod_id,
        (pos->>'quantity')::numeric                      as quantity,
        pos->'targetSlot'->>'id'                         as slot_id,
        m.raw_json->>'updated'                           as doc_updated,
        'move'                                           as meta_type,
        'in'                                             as op_type
    from {{ source('moysklad', 'moves') }} m,
         jsonb_array_elements(
             coalesce(m.raw_json->'positions'->'rows', '[]'::jsonb)
         ) as pos
    where pos->'targetSlot'->>'id' is not null
)

select doc_id, doc_moment::timestamptz as date, doc_name as number,
       agent_id, meta_type as type, op_type,
       prod_id, quantity, slot_id, doc_updated::timestamptz as updated
from demand_positions

union all
select doc_id, doc_moment::timestamptz, doc_name, agent_id,
       meta_type, op_type, prod_id, quantity, slot_id, doc_updated::timestamptz
from supply_positions

union all
select doc_id, doc_moment::timestamptz, doc_name, agent_id,
       meta_type, op_type, prod_id, quantity, slot_id, doc_updated::timestamptz
from loss_positions

union all
select doc_id, doc_moment::timestamptz, doc_name, agent_id,
       meta_type, op_type, prod_id, quantity, slot_id, doc_updated::timestamptz
from enter_positions

union all
select doc_id, doc_moment::timestamptz, doc_name, agent_id,
       meta_type, op_type, prod_id, quantity, slot_id, doc_updated::timestamptz
from move_out

union all
select doc_id, doc_moment::timestamptz, doc_name, agent_id,
       meta_type, op_type, prod_id, quantity, slot_id, doc_updated::timestamptz
from move_in

order by date, number
