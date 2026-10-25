select o.order_id, o.created_at, c.created_at as customer_created_at
from {{ ref('fct_orders') }} o
join {{ ref('dim_customers') }} c using (customer_id)
where o.created_at < c.created_at
