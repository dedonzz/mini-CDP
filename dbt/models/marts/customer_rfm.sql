-- RFM：以快照日（as_of_date）為基準，每位客戶一列；沒有有效購買的客戶標為 non_purchaser（未購買）。
-- R、M 用 NTILE(5) 分五等分（加 user_id 打破同分，結果可重現）；
-- F 大多數人只買 1 次，NTILE 會把同樣次數的人硬切到不同分數，所以改用固定門檻。

with as_of as (
    select {{ snapshot_dt('orders') }} as as_of_date
),

purchases as (
    select
        user_id,
        max(order_date) as last_purchase_date,
        count(*) as frequency,
        sum(net_revenue) as monetary
    from {{ ref('fct_orders') }}
    where net_revenue > 0
    group by user_id
),

scored as (
    select
        p.*,
        date_diff(a.as_of_date, p.last_purchase_date, day) as recency_days,
        ntile(5) over (order by p.last_purchase_date, p.user_id) as r_score,
        least(p.frequency, 5) as f_score,
        ntile(5) over (order by p.monetary, p.user_id) as m_score
    from purchases p
    cross join as_of a
)

select
    c.user_id,
    (select as_of_date from as_of) as as_of_date,
    s.last_purchase_date,
    s.recency_days,
    coalesce(s.frequency, 0) as frequency,
    coalesce(s.monetary, 0) as monetary,
    s.r_score,
    s.f_score,
    s.m_score,
    case
        when s.user_id is null then 'non_purchaser'
        when s.r_score >= 4 and s.f_score >= 2 and s.m_score >= 4 then 'champions'
        when s.r_score >= 3 and (s.f_score >= 2 or s.m_score >= 4) then 'loyal'
        when s.r_score >= 4 then 'new_customers'
        when s.r_score = 3 then 'need_attention'
        when s.f_score >= 2 or s.m_score >= 4 then 'at_risk'
        else 'hibernating'
    end as rfm_segment
from {{ ref('dim_customers') }} c
left join scored s using (user_id)
