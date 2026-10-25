{{config (severity = 'warn')}}
-- las ordenes incompletas (sin items o con estados faltantes) quedan en int_order_lifecycle
-- con is_complete = false y no entran a los marts
SELECT
    order_id
FROM
    {{ref ('int_order_lifecycle')}}
WHERE
    NOT is_complete
