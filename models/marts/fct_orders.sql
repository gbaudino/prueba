with items as (
    select
        order_id,
        count(*)         as lines_count,
        sum(quantity)    as units,
        sum(line_amount) as order_amount
    from {{ ref('fct_order_items') }}
    group by order_id
)

select
    o.order_id,
    o.customer_id,
    o.created_at,
    o.created_at::date                          as order_date,
    date_trunc('week', o.created_at)::date      as order_week,
    o.paid_at, o.shipped_at, o.delivered_at, o.cancelled_at, o.returned_at,
    o.final_status,
    o.final_status in ('paid', 'shipped', 'delivered') as is_revenue,
    o.is_valid_lifecycle,
    coalesce(i.lines_count, 0)  as lines_count,
    coalesce(i.units, 0)        as units,
    coalesce(i.order_amount, 0) as order_amount
from {{ ref('int_order_lifecycle') }} o
left join items i using (order_id)
