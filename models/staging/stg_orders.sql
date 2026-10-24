-- 1 fila por evento unico (order_id, status, event_at)
-- corrijo reingestas, dejo la primera ingesta de cada evento
SELECT
    trim(order_id)      AS order_id,
    trim(customer_id)   AS customer_id,
    lower(trim(status)) AS status,
    event_at,
    _ingested_at
FROM {{ source('raw', 'orders') }}
qualify row_number() OVER (
    PARTITION BY trim(order_id), lower(trim(status)), event_at
    ORDER BY _ingested_at
) = 1
