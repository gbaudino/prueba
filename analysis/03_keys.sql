-- propongo las keys de cada tabla y veo que sea unica


-- tabla customers
SELECT
  COUNT(*) AS filas,
  COUNT(DISTINCT customer_id) AS clientes
FROM raw.customers;


-- tabla products
SELECT
  COUNT(*) AS filas,
  COUNT(DISTINCT product_id) AS productos
FROM raw.products;


-- tabla orders
SELECT
  COUNT(*) AS filas,
  COUNT(DISTINCT order_id) AS ordenes
FROM raw.orders;
-- 15608 filas / 3998 ordenes (distintos id) no es unica pero puede ser por el status

SELECT
  eventos,
  COUNT(*) AS ordenes
FROM (
  SELECT
    order_id,
    COUNT(*) AS eventos
  FROM raw.orders
  GROUP BY order_id
)
GROUP BY eventos
ORDER BY eventos;
-- la mayoria de ordenes tiene 4 eventos (happy path), otras 5 (supongamos que son las que se devuelven), pero algunas tienen hasta 6
-- es raro 6 porque se daria que la orden paso por todos los estados, o sea que en particular, delivered, returned y cancelled a la vez, lo cual no me hace sentido

-- existen filas de una misma orden con el mismo status?
SELECT
  eventos,
  estados_distintos,
  eventos - estados_distintos AS repetidos,
  COUNT(*) AS ordenes
FROM (
  SELECT
    order_id,
    COUNT(*) AS eventos,
    COUNT(DISTINCT status) AS estados_distintos
  FROM raw.orders
  GROUP BY order_id
)
WHERE eventos > estados_distintos
GROUP BY ALL
ORDER BY eventos, estados_distintos;
-- 426 ordenes tienen filas con un mismo status

-- cuantos duplicados hay en total?
SELECT
  COUNT(*) AS duplicados
FROM (
  SELECT
    order_id,
    status
  FROM raw.orders
  GROUP BY ALL
  HAVING COUNT(*) > 1
);
-- 443 duplicados

-- los duplicados son el mismo evento reingestado o son eventos distintos?
SELECT
  COUNT(*) AS ordenes_con_duplicados,
  SUM(CASE WHEN eventos_distintos > 1 THEN 1 ELSE 0 END) distinto_evento,
  SUM(CASE WHEN ingestas_distintas > 1 THEN 1 ELSE 0 END) distinta_ingesta
FROM (
  SELECT
    order_id,
    status,
    COUNT(DISTINCT event_at) AS eventos_distintos,
    COUNT(DISTINCT _ingested_at) AS ingestas_distintas
  FROM raw.orders
  GROUP BY ALL
  HAVING COUNT(*) > 1
);
-- como las 443 son reingestas de un mismo evento debemos deduplicar


-- tabla order_items
SELECT
  COUNT(*) AS filas,
  COUNT(DISTINCT order_id) AS ordenes
FROM raw.order_items;
-- mismo que con orders, 7820 filas / 3998 ordenes, no es unica pero es esperado ya que una orden puede tener n items

-- entonces la key que deberia ser unica es compuesta y contiene tambien el line number
SELECT
  COUNT(*) AS filas,
  COUNT(DISTINCT (order_id, line_number)) AS items_unicos
FROM raw.order_items;
-- tenemos 7820 filas / 7615 items unicos, es decir 205 duplicados

SELECT
  COUNT(*) AS ordenes_con_duplicados,
  SUM(CASE WHEN productos_distintos > 1 THEN 1 ELSE 0 END) AS distinto_producto,
  SUM(CASE WHEN cantidades_distintas > 1 THEN 1 ELSE 0 END) AS distinta_cantidad,
  SUM(CASE WHEN ingestas_distintas > 1 THEN 1 ELSE 0 END) AS distinta_ingesta
FROM (
  SELECT order_id, line_number,
         COUNT(DISTINCT product_id)   AS productos_distintos,
         COUNT(DISTINCT quantity)     AS cantidades_distintas,
         COUNT(DISTINCT _ingested_at) AS ingestas_distintas
  FROM raw.order_items
  GROUP BY order_id, line_number
  HAVING COUNT(*) > 1
)
-- todos los duplicados son reingestas de un mismo item, hay que deduplicar tambien