-- Customer 360：每位客戶一列，整合基本資料、交易、行為與 RFM 分群。
{{ config(cluster_by=['rfm_segment', 'country']) }}

with orders as (
    select
        user_id,
        count(*) as orders_count,
        countif(net_revenue > 0) as purchasing_orders,
        sum(net_revenue) as lifetime_revenue,
        sum(net_margin) as lifetime_margin,
        sum(returned_items) as returned_items,
        sum(item_count) as items_ordered,
        min(ordered_at) as first_order_at,
        max(ordered_at) as last_order_at
    from {{ ref('fct_orders') }}
    group by user_id
),

top_category as (
    select user_id, category as favorite_category
    from {{ ref('fct_order_items') }}
    join {{ ref('dim_products') }} using (product_id)
    where is_revenue
    group by user_id, category
    qualify row_number() over (partition by user_id order by sum(sale_price) desc, category) = 1
),

behavior as (
    select
        user_id,
        count(distinct session_id) as sessions_count,
        count(*) as events_count,
        countif(event_type = 'cart') as cart_events,
        countif(event_type = 'purchase') as purchase_events,
        max(event_at) as last_seen_at
    from {{ ref('fct_events') }}
    where user_id is not null
    group by user_id
)

select
    c.user_id,
    c.first_name,
    c.last_name,
    c.email,
    c.age,
    c.age_band,
    c.gender,
    c.country,
    c.state,
    c.city,
    c.signup_traffic_source,
    c.signed_up_at,
    coalesce(o.orders_count, 0) as orders_count,
    coalesce(o.purchasing_orders, 0) as purchasing_orders,
    coalesce(o.lifetime_revenue, 0) as lifetime_revenue,
    coalesce(o.lifetime_margin, 0) as lifetime_margin,
    safe_divide(o.lifetime_revenue, o.purchasing_orders) as avg_order_value,
    safe_divide(o.returned_items, o.items_ordered) as return_rate,
    o.first_order_at,
    o.last_order_at,
    t.favorite_category,
    coalesce(b.sessions_count, 0) as sessions_count,
    coalesce(b.events_count, 0) as events_count,
    coalesce(b.cart_events, 0) as cart_events,
    coalesce(b.purchase_events, 0) as purchase_events,
    b.last_seen_at,
    r.as_of_date,
    r.recency_days,
    r.r_score,
    r.f_score,
    r.m_score,
    r.rfm_segment
from {{ ref('dim_customers') }} c
left join orders o using (user_id)
left join top_category t using (user_id)
left join behavior b using (user_id)
left join {{ ref('customer_rfm') }} r using (user_id)
