-- consolido los eventos de cada orden en una sola fila con sus hitos, estado final y validez del lifecycle
-- is_complete: tiene items y todos los estados del flujo hasta el ultimo alcanzado
-- las incompletas se guardan con is_complete = false y los marts las excluyen
-- en el incremental se recalculan solo las ordenes con eventos o lineas nuevos usando todos sus eventos
-- ya que hay eventos que llegan fuera de orden, entonces el estado no se puede calcular solo con las filas nuevas
{{ config(materialized='incremental', incremental_strategy='delete+insert', unique_key='order_id') }}

WITH
    {% if is_incremental() %}
    changed_orders AS (
        SELECT order_id FROM {{ ref('stg_orders') }}
        WHERE _ingested_at >= {{ since_last_load('last_ingested_at') }}
        UNION
        SELECT order_id FROM {{ ref('stg_order_items') }}
        WHERE _ingested_at >= {{ since_last_load('last_ingested_at') }}
    ),
    {% endif %}
    events AS (
        SELECT
            order_id,
            customer_id,
            status,
            event_at,
            _ingested_at,
            -- posicion en el camino logico (cancelled puede ocurrir en cualquier punto)
            CASE status
                WHEN 'created' THEN 1
                WHEN 'paid' THEN 2
                WHEN 'shipped' THEN 3
                WHEN 'delivered' THEN 4
                WHEN 'returned' THEN 5
            END AS status_rank,
            -- estado del evento anterior de la misma ord
            lag(status) OVER (PARTITION BY order_id ORDER BY event_at) AS previous_status
        FROM {{ ref('stg_orders') }}
        {% if is_incremental() %}
        WHERE order_id IN (SELECT order_id FROM changed_orders)
        {% endif %}
    ),
    items AS (
        SELECT
            order_id,
            max(_ingested_at) AS last_item_ingested_at
        FROM {{ ref('stg_order_items') }}
        {% if is_incremental() %}
        WHERE order_id IN (SELECT order_id FROM changed_orders)
        {% endif %}
        GROUP BY order_id
    )

SELECT
    order_id,
    any_value(customer_id) AS customer_id,
    min(event_at) FILTER (WHERE status = 'created')   AS created_at,
    min(event_at) FILTER (WHERE status = 'paid')      AS paid_at,
    min(event_at) FILTER (WHERE status = 'shipped')   AS shipped_at,
    min(event_at) FILTER (WHERE status = 'delivered') AS delivered_at,
    min(event_at) FILTER (WHERE status = 'cancelled') AS cancelled_at,
    min(event_at) FILTER (WHERE status = 'returned')  AS returned_at,
    -- estado final = el del ultimo evento ocurrido
    arg_max(status, event_at) AS final_status,
    -- lifecycle valido si cada evento sigue a su estado anterior segun las transiciones permitidas
    bool_and(
        (previous_status IS NULL AND status = 'created')
        OR (previous_status, status) IN (
            ('created', 'paid'),
            ('created', 'cancelled'),
            ('paid', 'shipped'),
            ('paid', 'cancelled'),
            ('shipped', 'delivered'),
            ('shipped', 'cancelled'),
            ('delivered', 'returned')
        )
    ) AS is_valid_lifecycle,
    (
        bool_or(status = 'created')
        AND count(DISTINCT status_rank) = max(status_rank)
        AND any_value(last_item_ingested_at) IS NOT NULL
    ) AS is_complete,
    -- cuando llego el ultimo dato (evento o linea) de la orden: es el punto de corte del incremental
    greatest(max(_ingested_at), any_value(last_item_ingested_at)) AS last_ingested_at
FROM events
LEFT JOIN items USING (order_id)
GROUP BY order_id
