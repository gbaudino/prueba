-- 1 fila por linea (order_id, line_number), dedup dejando el primero ingestado
SELECT
    trim(order_id)   AS order_id,
    line_number,
    trim(product_id) AS product_id,
    quantity,
    _ingested_at
FROM {{ source('raw', 'order_items') }}
qualify row_number() OVER (
    PARTITION BY trim(order_id), line_number
    ORDER BY _ingested_at
) = 1
