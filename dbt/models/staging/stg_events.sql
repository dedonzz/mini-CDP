-- events 是增量表：每個 dt 分區只有當天新事件，所以讀全部分區即為完整歷史
select
    id as event_id,
    user_id,  -- 未登入訪客為 null
    session_id,
    sequence_number,
    lower(event_type) as event_type,
    lower(traffic_source) as traffic_source,
    browser,
    uri,
    city,
    state,
    postal_code,
    ip_address,
    created_at as event_at,
    dt as event_date
from {{ source('raw', 'events') }}
