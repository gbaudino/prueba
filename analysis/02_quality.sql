-- quiero encontrar valores faltantes o imposibles

-- tabla customers
-- chequeo que todos tengan id, email y pais
SELECT
    customer_id,
    email,
    country_code,
    created_at,
    updated_at
FROM raw.customers
WHERE customer_id IS NULL
    OR TRIM(customer_id) = ''
    OR email IS NULL
    OR TRIM(email) = ''
    OR country_code IS NULL
    OR TRIM(country_code) = ''
    OR created_at IS NULL
    OR updated_at IS NULL
    OR updated_at < created_at;


-- tabla products
-- chequeo que todos tengan id, nombre, categoria, precio (valido) y moneda
-- no considero 0 como precio invalido
SELECT
    product_id,
    product_name,
    category,
    unit_price,
    currency,
    created_at,
    updated_at
FROM raw.products
WHERE product_id IS NULL
    OR TRIM(product_id) = ''
    OR product_name IS NULL
    OR TRIM(product_name) = ''
    OR category IS NULL
    OR TRIM(category) = ''
    OR unit_price IS NULL
    OR unit_price < 0
    OR currency IS NULL
    OR TRIM(currency) = ''
    OR created_at IS NULL
    OR updated_at IS NULL
    OR updated_at < created_at;

-- tabla orders
-- chequeo eventos de ordenes sin id de orden, id de cliente, estado o fecha
-- considero invalido que la fecha de ingesta sea anterior a la fecha del evento
SELECT
    order_id,
    customer_id,
    status,
    event_at,
    _ingested_at
FROM raw.orders
WHERE order_id IS NULL
    OR TRIM(order_id) = ''
    OR customer_id IS NULL
    OR TRIM(customer_id) = ''
    OR status IS NULL
    OR TRIM(status) = ''
    OR event_at IS NULL
    OR _ingested_at IS NULL
    OR _ingested_at < event_at;

-- tabla order_items
-- chequeo si hay filas sin id de orden, sin num linea/num linea invalido, sin id de producto o sin cantidad/cantidad invalida
SELECT
    order_id,
    line_number,
    product_id,
    quantity,
    _ingested_at
FROM raw.order_items
WHERE order_id IS NULL
    OR TRIM(order_id) = ''
    OR line_number IS NULL
    OR line_number < 1
    OR product_id IS NULL
    OR TRIM(product_id) = ''
    OR quantity IS NULL
    OR quantity <= 0
    OR _ingested_at IS NULL;
