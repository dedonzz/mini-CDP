-- 對帳：orders.item_count 應等於 order_items 實際筆數。回傳不一致的訂單。
{{ config(severity='warn') }}

select
    o.order_id,
    o.item_count,
    count(i.order_item_id) as actual_items
from {{ ref('stg_orders') }} as o
left join {{ ref('stg_order_items') }} as i using (order_id)
group by 1, 2
having o.item_count != count(i.order_item_id)
