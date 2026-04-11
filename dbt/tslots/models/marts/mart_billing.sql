-- mart_billing.sql — ежемесячные начисления по поклажедателям.
--
-- Отвечает на вопрос: сколько должен поклажедатель за хранение?
-- Формула: ячейко-дни × тариф за ячейко-день.
--
-- Тариф задаётся через dbt переменную rate_per_slot_day (по умолчанию 50 руб).
-- Изменить без правки кода:
--   dbt run --vars '{"rate_per_slot_day": 75}'
--
-- Источник: int_slot_occupancy — только записи с известным поклажедателем.
-- Группировка: по месяцу, поклажедателю и складу.

{{ config(materialized='table') }}

-- Подставляем тариф из переменной dbt. Если не задана — используем 50 руб.
{% set rate = var('rate_per_slot_day', 50) %}

with occupancy as (
    -- Берём только интервалы с известным поклажедателем.
    -- Записи без depositor_id не включаем в начисления.
    select *
    from {{ ref('int_slot_occupancy') }}
    where depositor_id is not null
),

monthly as (
    -- Агрегируем по месяцу, поклажедателю и складу.
    -- Считаем уникальные ячейки, суммарные ячейко-дни и итоговую сумму.
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
    -- Метка периода для удобного отображения в Grafana (например "2026-04").
    to_char(billing_month, 'YYYY-MM')               as period_label
from monthly
order by billing_month desc, amount_rub desc
