-- ventas, ordenes que terminan como ingreso, por fecha de creacion
-- por dia
select
    order_date,
    count(*) as ventas
from marts.fct_orders
where is_revenue
group by order_date
order by order_date;

-- por semana
select
    order_week,
    count(*) as ventas
from marts.fct_orders
where is_revenue
group by order_week
order by order_week;
