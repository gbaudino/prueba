-- is_active si tuvo al menos una compra no cancelada en los ultimos {{ var('active_window_days') }} dias
-- tomo como referencia el ultimo evento cargado, no el dia que corre el test
with orders as (
    select
        customer_id,
        count(*)                                                        as orders_count,
        min(created_at)                                                 as first_order_at,
        max(created_at) filter (where final_status <> 'cancelled')      as last_purchase_at
    from {{ ref('int_order_lifecycle') }}
    where is_complete
    group by customer_id
)

select
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.country_code,
    c.segment,
    c.created_at,
    date_trunc('month', c.created_at)::date as signup_month,
    coalesce(o.orders_count, 0)             as orders_count,
    o.first_order_at,
    o.last_purchase_at,
    coalesce(o.last_purchase_at >= (select max(event_at) from {{ ref('stg_orders') }}) - interval '{{ var("active_window_days") }} days', false) as is_active
from {{ ref('stg_customers') }} c
left join orders o using (customer_id)
