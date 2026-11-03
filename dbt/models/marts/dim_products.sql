select
    product_id,
    product_name,
    brand,
    category,
    department,
    sku,
    cost,
    retail_price,
    safe_divide(retail_price - cost, retail_price) as list_margin_rate,
    distribution_center_id
from {{ ref('stg_products') }}
