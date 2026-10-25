-- consolido los eventos de cada orden en una sola fila con sus hitos, estado final y validez del lifecycle.
WITH
    events AS (
        SELECT
            order_id,
            customer_id,
            status,
            event_at,
            -- posicion en el camino logico (cancelled puede ocurrir en cualquier punto)
            CASE status
                WHEN 'created' THEN 1
                WHEN 'paid' THEN 2
                WHEN 'shipped' THEN 3
                WHEN 'delivered' THEN 4
                WHEN 'returned' THEN 5
            END AS status_rank,
            -- estado del evento anterior de la misma ord
            lag (status) over (
                PARTITION BY
                    order_id
                ORDER BY
                    event_at
            ) AS previous_status
        FROM
            {{ref ('stg_orders')}}
    )
SELECT
    order_id,
    any_value(customer_id) AS customer_id,
    min(event_at) filter(
        WHERE
            status = 'created'
    ) AS created_at,
    min(event_at) filter(
        WHERE
            status = 'paid'
    ) AS paid_at,
    min(event_at) filter(
        WHERE
            status = 'shipped'
    ) AS shipped_at,
    min(event_at) filter(
        WHERE
            status = 'delivered'
    ) AS delivered_at,
    min(event_at) filter(
        WHERE
            status = 'cancelled'
    ) AS cancelled_at,
    min(event_at) filter(
        WHERE
            status = 'returned'
    ) AS returned_at,
    arg_max(status, event_at) AS final_status,
    -- lifecycle valido si cada evento sigue a su estado anterior segun las transiciones permitidas
    bool_and(
        (
            previous_status IS NULL
            AND status = 'created'
        )
        OR (previous_status, status) IN (
            ('created', 'paid'),
            ('created', 'cancelled'),
            ('paid', 'shipped'),
            ('paid', 'cancelled'),
            ('shipped', 'delivered'),
            ('shipped', 'cancelled'),
            ('delivered', 'returned')
        )
    ) AS is_valid_lifecycle
FROM
    events
GROUP BY
    order_id
HAVING
    bool_or(status = 'created')
    AND count(DISTINCT status_rank) = max(status_rank)
    AND order_id IN (
        SELECT
            order_id
        FROM
            {{ref ('stg_order_items')}}
    )
