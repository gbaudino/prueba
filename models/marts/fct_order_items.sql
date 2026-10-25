-- line_amount usa el precio de lista actual
-- is_revenue nos dice si la linea cuenta como ingreso, solo verdadero si la
-- orden termino pagada, enviada o entregada
-- ahora en incremental se recalculan las lineas de las ordenes nuevas
-- pre_hook borra las ordenes que dejaron de ser completas
{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['order_id', 'line_number'],
        pre_hook="{% if is_incremental() %}
            delete from {{ this }}
            where order_id in (select order_id from {{ ref('int_order_lifecycle') }} where not is_complete)
        {% endif %}"
    )
}}
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
    o.final_status in ('paid', 'shipped', 'delivered') as is_revenue,
    o.last_ingested_at
from {{ ref('stg_order_items') }} i
join {{ ref('int_order_lifecycle') }} o using (order_id)
join {{ ref('stg_products') }} p using (product_id)
where o.is_complete
{% if is_incremental() %}
  and o.last_ingested_at >= {{ since_last_load('last_ingested_at') }}
{% endif %}
