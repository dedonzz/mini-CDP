-- 客戶維度：users 每一位註冊用戶都是 Customer（含未下單者）
select
    user_id,
    first_name,
    last_name,
    email,
    age,
    case
        when age < 25 then '18-24'
        when age < 35 then '25-34'
        when age < 45 then '35-44'
        when age < 55 then '45-54'
        else '55+'
    end as age_band,
    gender,
    country,
    state,
    city,
    signup_traffic_source,
    signed_up_at,
    date(signed_up_at) as signup_date
from {{ ref('stg_users') }}
