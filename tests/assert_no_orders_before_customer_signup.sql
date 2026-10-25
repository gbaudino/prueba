select
    o.order_id,
    o.created_at,
    c.created_at as customer_created_at
from {{ ref('fct_orders') }} as o
inner join {{ ref('dim_customers') }} as c on o.customer_id = c.customer_id
where o.created_at < c.created_at
