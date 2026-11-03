-- 粒度：一列一個事件。events 量最大，用 incremental + insert_overwrite 只重算需要的日分區：
--   有傳 ds（排程 / 重跑）→ 只覆寫 ds 那一個分區（static partitions，冪等且最便宜）
--   沒傳 ds（本機開發）  → 覆寫最近 3 天（容忍遲到資料）
--   --full-refresh       → 全部重建
{% set ds = var('ds', none) %}
{{ config(
    materialized='incremental',
    incremental_strategy='insert_overwrite',
    partition_by={'field': 'event_date', 'data_type': 'date'},
    partitions=(["date '" ~ ds ~ "'"] if ds else none),
    cluster_by=['user_id', 'event_type']
) }}

select
    event_id,
    user_id,
    session_id,
    sequence_number,
    event_type,
    traffic_source,
    browser,
    uri,
    event_at,
    event_date
from {{ ref('stg_events') }}
{% if is_incremental() %}
    {% if ds %}
        where event_date = date '{{ ds }}'
    {% else %}
        where event_date >= date_sub(current_date(), interval 3 day)
    {% endif %}
{% endif %}
