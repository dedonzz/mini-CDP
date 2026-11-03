-- 粒度：一列一個售出品項。營收口徑集中定義在這裡（is_revenue），下游不重算。
{{ config(
    partition_by={'field': 'order_date', 'data_type': 'date'},
    cluster_by=['user_id', 'product_id']
) }}

select
    i.order_item_id,
    i.order_id,
    i.user_id,
    i.product_id,
    i.item_status,
    i.ordered_at,
    date(i.ordered_at) as order_date,
    i.shipped_at,
    i.delivered_at,
    i.returned_at,
    i.sale_price,
    p.cost,
    i.sale_price - p.cost as gross_margin,
    i.item_status not in ('cancelled', 'returned') as is_revenue
from {{ ref('stg_order_items') }} i
left join {{ ref('stg_products') }} p using (product_id)
