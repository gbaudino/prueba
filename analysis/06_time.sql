-- voy a tratar de entender como llegan los datos en el tiempo para ver como armar el incremental

-- customers y products, son una foto completa o hay varias versiones?
SELECT
    'customers' AS tabla,
    COUNT(DISTINCT _extracted_at) AS extracciones
FROM
    raw.customers
UNION ALL
SELECT
    'products' AS tabla,
    COUNT(DISTINCT _extracted_at) AS extracciones
FROM
    raw.products;
-- una sola extraccion en ambas
-- que pasaria si tuvieramos otra extraccion? se agregarian filas a la tabla o updatearia el extracted_at?
-- por las dudas, defensivamente haria un dedup sobre los clientes y customers dejando el ultimo updateado

-- cuanto tarda un evento en llegar al data lake?
SELECT
    MAX(_ingested_at - event_at) AS demora_maxima,
    AVG(_ingested_at - event_at) AS demora_promedio
FROM raw.orders;
-- demora maxima de casi 2 dias y promedio de casi 5hs
-- la ventana de reproceso tiene que cubrir al menos esos 2 dias

-- hay eventos que llegan despues de otro evento posterior de la misma orden?
WITH
    eventos AS (
        SELECT
            order_id,
            status,
            event_at,
            MIN(_ingested_at) AS ingested_at
        FROM
            raw.orders
        GROUP BY
            order_id,
            status,
            event_at
    )
SELECT
    COUNT(*) AS eventos_fuera_de_orden,
    COUNT(DISTINCT a.order_id) AS ordenes_afectadas
FROM
    eventos AS a
WHERE
    EXISTS (
        SELECT
            1
        FROM
            eventos AS b
        WHERE
            b.order_id = a.order_id
            AND b.event_at > a.event_at
            AND b.ingested_at < a.ingested_at
    );
-- 668 eventos en 656 ordenes llegan despues de uno posterior (por ej llega desp el created que el paid)
-- el estado de una orden no se puede calcular solo con las filas nuevas, hay que recalcularlo con todos sus eventos

-- los duplicados llegan en la misma carga o en otra posterior?
WITH
    duplicados AS (
        SELECT
            'orders' AS tabla,
            MAX(_ingested_at) - MIN(_ingested_at) AS gap
        FROM
            raw.orders
        GROUP BY
            order_id,
            status,
            event_at
        HAVING
            COUNT(*) > 1
        UNION ALL
        SELECT
            'order_items' AS tabla,
            MAX(_ingested_at) - MIN(_ingested_at) AS gap
        FROM
            raw.order_items
        GROUP BY
            order_id,
            line_number
        HAVING
            COUNT(*) > 1
    )
SELECT
    tabla,
    COUNT(*) AS grupos_duplicados,
    MAX(gap) AS gap_max,
    COUNT(*) FILTER(
        WHERE
            gap > INTERVAL 1 DAY
    ) AS gap_mayor_1_dia
FROM
    duplicados
GROUP BY
    tabla
ORDER BY
    tabla;
-- las reingestas llegan hasta casi 2 dias despues del original
-- puede llegar en otra carga, hay que deduplicar contra todo lo ya cargado y no solo dentro de lo nuevo
