-- line_amount usa el precio de lista actual
-- is_revenue nos dice si la linea cuenta como ingreso, solo verdadero si la
-- orden termino pagada, enviada o entregada
select
    i.order_id,
    i.line_number,
    i.product_id,
    p.category,
    o.customer_id,
    o.created_at::date                            as order_date,
    o.final_status,
    i.quantity,
    p.unit_price,
    i.quantity * p.unit_price                     as line_amount,
    o.final_status in ('paid', 'shipped', 'delivered') as is_revenue
from {{ ref('stg_order_items') }} i
join {{ ref('int_order_lifecycle') }} o using (order_id)
join {{ ref('stg_products') }} p using (product_id)
