{{ config(materialized='view') }}

select
    raw_json->>'id'                                 as agent_id,
    raw_json->>'name'                               as name,
    raw_json->>'inn'                                as inn,
    (raw_json->>'updated')::timestamptz             as updated
from {{ source('moysklad', 'raw') }}
where entity = 'counterparty'
