-- el pre_hook borra las que dejaron de ser completas
{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='order_id',
        pre_hook="{% if is_incremental() %}
            delete from {{ this }}
            where order_id in (select order_id from {{ ref('int_order_lifecycle') }} where not is_complete)
        {% endif %}"
    )
}}
with orders as (
    select *
    from {{ ref('int_order_lifecycle') }}
    where is_complete
    {% if is_incremental() %}
      and last_ingested_at >= {{ since_last_load('last_ingested_at') }}
    {% endif %}
),

items as (
    select
        order_id,
        count(*)         as lines_count,
        sum(quantity)    as units,
        sum(line_amount) as order_amount
    from {{ ref('fct_order_items') }}
    where order_id in (select order_id from orders)
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
    coalesce(i.order_amount, 0) as order_amount,
    o.last_ingested_at
from orders o
left join items i using (order_id)
