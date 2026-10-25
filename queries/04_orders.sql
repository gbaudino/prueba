-- proporcion de ordenes por estado final (entregadas vs canceladas)
select
    final_status,
    count(*)                                         as ordenes,
    round(100.0 * count(*) / sum(count(*)) over (), 2) as pct
from marts.fct_orders
group by final_status
order by ordenes desc;
