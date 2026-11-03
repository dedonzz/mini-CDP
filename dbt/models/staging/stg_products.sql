select
    id as product_id,
    name as product_name,
    brand,
    category,
    department,
    sku,
    cast(cost as numeric) as cost,
    cast(retail_price as numeric) as retail_price,
    distribution_center_id,
    dt as snapshot_date
from {{ source('raw', 'products') }}
where dt = {{ snapshot_dt('products') }}
