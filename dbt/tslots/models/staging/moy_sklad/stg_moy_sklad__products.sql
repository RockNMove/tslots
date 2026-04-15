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
    (raw_json->>'updated')::timestamptz                                 as updated
from {{ source('moysklad', 'raw') }}
where entity = 'product'
  and raw_json->>'id' is not null
{% if is_incremental() %}
    and (raw_json->>'updated')::timestamptz > (select max(updated) from {{ this }})
{% endif %}
