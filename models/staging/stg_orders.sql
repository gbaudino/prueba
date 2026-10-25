-- 1 fila por evento unico (order_id, status, event_at)
-- con el incremental lee de raw solo lo ingestado desde la ultima carga y descarta los eventos que ya estan
-- porque un duplicado puede llegar en otra ingesta
{{ config(materialized='incremental', incremental_strategy='append') }}

WITH new_events AS (
    SELECT
        trim(order_id)      AS order_id,
        trim(customer_id)   AS customer_id,
        lower(trim(status)) AS status,
        event_at,
        _ingested_at
    FROM {{ source('raw', 'orders') }}
    {% if is_incremental() %}
    WHERE _ingested_at >= {{ since_last_load('_ingested_at') }}
    {% endif %}
    QUALIFY row_number() OVER (
        PARTITION BY trim(order_id), lower(trim(status)), event_at
        ORDER BY _ingested_at
    ) = 1
)

SELECT *
FROM new_events AS n
{% if is_incremental() %}
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ this }} AS t
    WHERE t.order_id = n.order_id
      AND t.status = n.status
      AND t.event_at = n.event_at
)
{% endif %}
