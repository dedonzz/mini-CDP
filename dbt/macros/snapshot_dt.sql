{#
  快照表要讀哪一天的分區：
  - 有傳 --vars '{ds: YYYY-MM-DD}'（Airflow 排程 / 重跑）→ 用 ds
  - 沒傳（本機開發）→ 查 INFORMATION_SCHEMA.PARTITIONS 取最新分區（metadata，不掃資料）
  回傳 DATE 常數，讓 BigQuery 在編譯時就能做分區剪枝。
#}
{% macro snapshot_dt(table_name) -%}
    {%- if var('ds', none) -%}
        {%- set dt = var('ds') -%}
    {%- elif execute -%}
        {%- set q -%}
            select cast(max(parse_date('%Y%m%d', partition_id)) as string)
            from `{{ target.project }}.cdp_raw.INFORMATION_SCHEMA.PARTITIONS`
            where table_name = '{{ table_name }}' and regexp_contains(partition_id, r'^\d{8}$')
        {%- endset -%}
        {%- set dt = run_query(q).columns[0].values()[0] -%}
    {%- else -%}
        {%- set dt = '1900-01-01' -%}
    {%- endif -%}
    date '{{ dt }}'
{%- endmacro %}
