-- models/staging/stg_agents.sql
{{ config(materialized='view') }}

select
    ms_id                               as agent_id,
    raw_json->>'name'                   as name,
    raw_json->>'inn'                    as inn,
    (raw_json->>'updated')::timestamptz as updated
from {{ source('moysklad', 'agents') }}
