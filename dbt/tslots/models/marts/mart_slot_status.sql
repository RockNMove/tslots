-- mart_slot_status.sql — текущее состояние склада.
--
-- Показывает только ячейки занятые прямо сейчас (is_currently_occupied = true).
-- Это все интервалы у которых freed_at = NULL — товар ещё не ушёл.
--
-- Используется Grafana для отображения карты занятости склада
-- и панели "Занято ячеек сейчас".

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
    -- Сколько дней ячейка занята непрерывно — для сортировки и алертов.
    round(
        extract(epoch from (now() - occupied_from)) / 86400.0,
        1
    )                   as days_since_in,
    in_doc_id,
    in_doc_type
from {{ ref('int_slot_occupancy') }}
where is_currently_occupied = true
order by store_name, zone_name, slot_name
