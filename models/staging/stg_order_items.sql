-- 1 fila por linea (order_id, line_number), dedup dejando el primero ingestado
-- con el ncremental solo lee lo nuevo y descarta lo que ya esta en la tabla
{{ config(materialized='incremental', incremental_strategy='append') }}

WITH new_lines AS (
    SELECT
        trim(order_id)   AS order_id,
        line_number,
        trim(product_id) AS product_id,
        quantity,
        _ingested_at
    FROM {{ source('raw', 'order_items') }}
    {% if is_incremental() %}
    WHERE _ingested_at >= {{ since_last_load('_ingested_at') }}
    {% endif %}
    QUALIFY row_number() OVER (
        PARTITION BY trim(order_id), line_number
        ORDER BY _ingested_at
    ) = 1
)

SELECT *
FROM new_lines AS n
{% if is_incremental() %}
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ this }} AS t
    WHERE t.order_id = n.order_id
      AND t.line_number = n.line_number
)
{% endif %}
