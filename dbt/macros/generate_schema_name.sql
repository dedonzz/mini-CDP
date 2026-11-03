{# 直接使用 +schema 指定的 dataset 名稱，不加 target dataset 前綴 #}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {{ custom_schema_name | trim if custom_schema_name else target.dataset }}
{%- endmacro %}
