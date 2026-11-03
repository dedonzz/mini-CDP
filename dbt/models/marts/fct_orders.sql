-- 粒度：一列一張訂單。金額由品項加總，口徑與 fct_order_items 一致。
{{ config(
    partition_by={'field': 'order_date', 'data_type': 'date'},
    cluster_by=['user_id']
) }}

with items as (
    select
        order_id,
        sum(sale_price) as gross_revenue,
        sum(if(is_revenue, sale_price, 0)) as net_revenue,
        sum(if(is_revenue, gross_margin, 0)) as net_margin,
        countif(item_status = 'returned') as returned_items
    from {{ ref('fct_order_items') }}
    group by order_id
)

select
    o.order_id,
    o.user_id,
    o.order_status,
    o.ordered_at,
    date(o.ordered_at) as order_date,
    o.shipped_at,
    o.delivered_at,
    o.returned_at,
    o.item_count,
    coalesce(i.gross_revenue, 0) as gross_revenue,
    coalesce(i.net_revenue, 0) as net_revenue,
    coalesce(i.net_margin, 0) as net_margin,
    coalesce(i.returned_items, 0) as returned_items,
    date_diff(o.delivered_at, o.ordered_at, day) as days_to_deliver,
    row_number() over (partition by o.user_id order by o.ordered_at, o.order_id) as user_order_seq
from {{ ref('stg_orders') }} o
left join items i using (order_id)
