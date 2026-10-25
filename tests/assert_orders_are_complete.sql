{{config (severity = 'warn')}}
-- las ordenes incompletas (sin items o con estados faltantes) no entran a int_order_lifecycle
-- vemos que este test da 6, esas 6 son excluidas en int y obvio desp en marts
SELECT DISTINCT
    order_id
FROM
    {{ref ('stg_orders')}}
WHERE
    order_id NOT IN (
        SELECT
            order_id
        FROM
            {{ref ('int_order_lifecycle')}}
    )
