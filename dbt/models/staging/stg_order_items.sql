select
    id as order_item_id,
    order_id,
    user_id,
    product_id,
    inventory_item_id,
    lower(status) as item_status,
    cast(sale_price as numeric) as sale_price,
    created_at as ordered_at,
    shipped_at,
    delivered_at,
    returned_at,
    dt as snapshot_date
from {{ source('raw', 'order_items') }}
where dt = {{ snapshot_dt('order_items') }}
