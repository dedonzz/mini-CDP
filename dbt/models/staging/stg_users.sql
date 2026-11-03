select
    id as user_id,
    first_name,
    last_name,
    lower(trim(email)) as email,
    age,
    gender,
    country,
    state,
    city,
    postal_code,
    latitude,
    longitude,
    lower(traffic_source) as signup_traffic_source,
    created_at as signed_up_at,
    dt as snapshot_date
from {{ source('raw', 'users') }}
where dt = {{ snapshot_dt('users') }}
