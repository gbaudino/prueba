-- quiero revisar que los eventos de las ordenes lleguen en un orden determinado y no falten eventos intermedios

-- transiciones invalidas del ciclo de vida (haciendo el dedup de los eventos si no tendriamos falsos positivos)
WITH eventos AS (
    SELECT DISTINCT
        order_id,
        status,
        event_at
    FROM raw.orders
),

transiciones AS (
    SELECT
        order_id,
        status AS estado,
        LAG(status)
            OVER (PARTITION BY order_id ORDER BY event_at)
            AS estado_anterior
    FROM eventos
),

validas (estado_anterior, estado) AS (
    VALUES
    (CAST(NULL AS VARCHAR), 'created'),
    ('created', 'paid'),
    ('created', 'cancelled'),
    ('paid', 'shipped'),
    ('paid', 'cancelled'),
    ('shipped', 'delivered'),
    ('shipped', 'cancelled'),
    ('delivered', 'returned')
)

SELECT
    t.estado_anterior,
    t.estado,
    COUNT(*) AS ordenes
FROM transiciones AS t
WHERE
    NOT EXISTS (
        SELECT 1
        FROM validas AS v
        WHERE
            v.estado_anterior IS NOT DISTINCT FROM t.estado_anterior
            AND v.estado = t.estado
    )
GROUP BY t.estado_anterior, t.estado
ORDER BY ordenes DESC;
-- 6 ordenes con alguna transicion invalida, 5 sin created y 1 con shipped sin paid


-- ordenes con diferentes clientes en los diferentes eventos
SELECT COUNT(*) AS ordenes_con_clientes_distintos
FROM (
    SELECT order_id
    FROM raw.orders
    GROUP BY order_id
    HAVING COUNT(DISTINCT customer_id) > 1
);
