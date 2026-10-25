-- precio de lista actual, sin historial
select
    product_id,
    product_name,
    category,
    unit_price,
    currency,
    created_at
from {{ ref('stg_products') }}
