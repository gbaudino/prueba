-- todos los eventos de una orden deben pertenecer al mismo cliente
select order_id
from {{ ref('stg_orders') }}
group by order_id
having count(distinct customer_id) > 1
