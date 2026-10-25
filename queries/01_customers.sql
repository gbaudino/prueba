-- clientes totale y los activos
select
    count(*) as clientes_totales,
    count(*) filter (where is_active) as clientes_activos
from marts.dim_customers;

-- crecimiento mensual
select
    signup_month,
    count(*) as clientes_nuevos,
    sum(count(*)) over (order by signup_month) as clientes_acumulados
from marts.dim_customers
group by signup_month
order by signup_month;
