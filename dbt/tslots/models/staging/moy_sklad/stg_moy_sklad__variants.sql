{{ config(materialized='incremental', unique_key='variant_id', incremental_strategy='merge') }}

select
    raw_json->>'id'                                                     as variant_id,
    raw_json->'product'->>'id'                                          as product_id,
    jsonb_path_query_first(
        raw_json,
        '$.characteristics[*] ? (@.name == "партия").value'
    ) #>> '{}'                                                          as lot,
    jsonb_path_query_first(
        raw_json,
        '$.characteristics[*] ? (@.name == "дата выработки").value'
    ) #>> '{}'                                                          as mfg_date,
    (raw_json->>'updated')::timestamp                                 as updated
from {{ source('moysklad', 'raw') }}
where entity = 'variant'
  and raw_json->>'id' is not null
  and raw_json->'product'->>'id' is not null
-- если выполняется
{% if is_incremental() %}
-- то приклеить к основному запросу это
    and (raw_json->>'updated')::timestamp > (select max(updated) from {{ this }})
{% endif %}
