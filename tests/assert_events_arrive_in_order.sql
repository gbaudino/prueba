{{ config (severity = 'warn') }}
-- problema: eventos que llegan fuera de orden
-- ordenes que el ultimo evento ingestado no es el ultimo evento ocurrido
-- calcular el estado con  el orden de llegada daria un resultado incorrecto
WITH
eventos AS (
    SELECT
        order_id,
        status,
        event_at,
        min(_ingested_at) AS ingested_at
    FROM
        {{ source ('raw', 'orders') }}
    GROUP BY
        order_id,
        status,
        event_at
)

SELECT order_id
FROM
    eventos
GROUP BY
    order_id
HAVING
    arg_max(status, ingested_at) <> arg_max(status, event_at)
