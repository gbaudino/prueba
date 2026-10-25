-- reviso las relaciones entre las tablas para buscar huerfanos o absudros

-- ordenes que el cliente no existe en customers
SELECT COUNT(DISTINCT o.customer_id) AS clientes_inexistentes
FROM raw.orders AS o
WHERE NOT EXISTS (
    SELECT 1
    FROM raw.customers AS c
    WHERE c.customer_id = o.customer_id
);

-- items que la orden no existe en orders
SELECT COUNT(DISTINCT i.order_id) AS ordenes_inexistentes
FROM raw.order_items AS i
WHERE NOT EXISTS (
    SELECT 1
    FROM raw.orders AS o
    WHERE o.order_id = i.order_id
);

-- items que el producto no existe en products
SELECT COUNT(*) AS items_con_producto_inexistente
FROM raw.order_items AS i
WHERE NOT EXISTS (
    SELECT 1
    FROM raw.products AS p
    WHERE p.product_id = i.product_id
);

-- ordenes que no tienen ningun item
SELECT COUNT(DISTINCT o.order_id) AS ordenes_sin_items
FROM raw.orders AS o
WHERE NOT EXISTS (
    SELECT 1
    FROM raw.order_items AS i
    WHERE i.order_id = o.order_id
);

-- eventos de una orden anteriores a la creacion del cliente
SELECT COUNT(DISTINCT o.order_id) AS ordenes_antes_de_cliente
FROM raw.orders AS o
INNER JOIN raw.customers AS c ON o.customer_id = c.customer_id
WHERE o.event_at < c.created_at;

-- items vendidos antes de que existiera el producto
WITH o AS (
    SELECT
        order_id,
        MIN(event_at) AS primer_evento
    FROM raw.orders
    GROUP BY order_id
)

SELECT COUNT(DISTINCT i.order_id) AS ordenes_antes_de_producto
FROM raw.order_items AS i
INNER JOIN o ON i.order_id = o.order_id
INNER JOIN raw.products AS p ON i.product_id = p.product_id
WHERE o.primer_evento < p.created_at;
