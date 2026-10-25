{{ config(severity='warn') }}
-- ordenes completas cuyos eventos no siguen las transiciones permitidas por ej cancelled desp de delivered
select
    order_id,
    final_status
from {{ ref('fct_orders') }}
where not is_valid_lifecycle
