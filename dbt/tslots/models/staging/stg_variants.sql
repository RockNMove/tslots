{{ config(materialized='view') }}

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
    raw_json->'barcodes'                                                as barcodes,
    (raw_json->>'updated')::timestamptz                                 as updated
from {{ source('moysklad', 'raw') }}
where entity = 'variant'
