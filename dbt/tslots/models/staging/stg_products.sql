-- models/staging/stg_products.sql
{{ config(materialized='view') }}

select
    ms_id                                                       as product_id,
    raw_json->>'name'                                           as name,
    raw_json->>'article'                                        as article,
    (raw_json->>'weight')::numeric                              as weight,
    (raw_json->>'volume')::numeric                              as volume,
    raw_json->'uom'->>'id'                                      as uom_id,
    -- jsonb_path_query_first ищет атрибут "Поклажедатель" в массиве attributes.
    -- Вернёт NULL если атрибута нет — не падает, в отличие от pandas .str.get()
    jsonb_path_query_first(
        raw_json,
        '$.attributes[*] ? (@.name == "Поклажедатель").value.id'
    ) #>> '{}'                                                  as depositor_id,
    (raw_json->>'updated')::timestamptz                         as updated
from {{ source('moysklad', 'products') }}
