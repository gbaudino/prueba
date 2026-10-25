-- la suma en fct_orders debe ser igual a la suma en fct_order_items, si no perdi/duplique filas
select o.total_orders, i.total_items
from (select sum(order_amount) as total_orders from {{ ref('fct_orders') }}) o,
     (select sum(line_amount)  as total_items  from {{ ref('fct_order_items') }}) i
where abs(o.total_orders - i.total_items) > 0.005
-- el margen es porque sumamos decimales y puede haber una dif minima
