-- la idea es revisar como son las tablas, los tipos de datos y los valores categoricos de interes

-- tamanos
SELECT
    table_name AS tabla,
    estimated_size AS filas
FROM duckdb_tables()
WHERE schema_name = 'raw';

-- estructura de cada tabla
DESCRIBE raw.customers;
DESCRIBE raw.products;
DESCRIBE raw.orders;
DESCRIBE raw.order_items;

-- algunas filas
SELECT *
FROM raw.customers
ORDER BY customer_id
LIMIT 10;

SELECT *
FROM raw.products
ORDER BY product_id
LIMIT 10;

SELECT *
FROM raw.orders
ORDER BY order_id, event_at
LIMIT 10;

SELECT *
FROM raw.order_items
ORDER BY order_id, line_number
LIMIT 10;

-- resumen para cada col
SUMMARIZE raw.customers;
SUMMARIZE raw.products;
SUMMARIZE raw.orders;
SUMMARIZE raw.order_items;

-- valores categoricos
SELECT DISTINCT status
FROM raw.orders
ORDER BY status;

SELECT DISTINCT country_code
FROM raw.customers
ORDER BY country_code;

SELECT DISTINCT category
FROM raw.products
ORDER BY category;

SELECT DISTINCT currency
FROM raw.products
ORDER BY currency;
