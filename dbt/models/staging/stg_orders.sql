select
    order_id,
    user_id,
    lower(status) as order_status,
    num_of_item as item_count,
    created_at as ordered_at,
    shipped_at,
    delivered_at,
    returned_at,
    dt as snapshot_date
from {{ source('raw', 'orders') }}
where dt = {{ snapshot_dt('orders') }}
