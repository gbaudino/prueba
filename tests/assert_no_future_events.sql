-- ningun evento puede ocurrir despues de haber sido ingestado
select
    order_id,
    status,
    event_at,
    _ingested_at
from {{ source('raw', 'orders') }}
where _ingested_at < event_at
