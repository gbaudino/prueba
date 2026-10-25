-- total ingresos
select sum(line_amount) as ingresos_totales_usd
from marts.fct_order_items
where is_revenue;

-- discrimino por categoria
select
    category,
    sum(line_amount) as ingresos_usd,
    round(100 * sum(line_amount) / sum(sum(line_amount)) over (), 2) as pct
from marts.fct_order_items
where is_revenue
group by category
order by ingresos_usd desc;
