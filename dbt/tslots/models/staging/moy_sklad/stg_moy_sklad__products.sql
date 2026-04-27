{{ config(materialized='incremental', unique_key='product_id', incremental_strategy='merge') }}

select
    raw_json->>'id'                                                     as product_id,
    raw_json->>'name'                                                   as name,
    raw_json->>'article'                                                as article,
    (raw_json->>'weight')::numeric                                      as weight,
    (raw_json->>'volume')::numeric                                      as volume,
    raw_json->'uom'->>'id'                                              as uom_id,
    jsonb_path_query_first(
        raw_json,
        '$.attributes[*] ? (@.name == "Поклажедатель").value.id'
    ) #>> '{}'                                                          as depositor_id,
    (jsonb_path_query_first(
        raw_json,
        '$.attributes[*] ? (@.name == "Кол-во в ячейке").value'
    ) #>> '{}')::numeric                                                as expected_bin_qty,
    (raw_json->>'updated')::timestamp                                 as updated
from {{ source('moysklad', 'raw') }}
where entity = 'product'
  and raw_json->>'id' is not null
-- если выполняется
{% if is_incremental() %}
-- то приклеить к основному запросу это
    and (raw_json->>'updated')::timestamp > COALESCE((select max(updated) from {{ this }}), '1970-01-01'::timestamp)
{% endif %}
