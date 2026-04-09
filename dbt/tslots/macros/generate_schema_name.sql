-- macros/generate_schema_name.sql
--
-- По умолчанию dbt генерирует имя схемы как:
--   <target_schema>_<custom_schema>
-- например: public_bronze, public_silver, public_gold
--
-- Этот макрос переопределяет поведение:
-- если в dbt_project.yml задана +schema: bronze → создаётся просто bronze
-- если schema не задана → используется schema из profiles.yml (public)

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
