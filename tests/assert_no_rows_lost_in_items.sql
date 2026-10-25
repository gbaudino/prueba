-- no deberian perderse lineas de ordenes al pasar a fct_order_items (en el join)
SELECT
    s.n_stg,
    f.n_fct
FROM
    (
        SELECT
            count(*) AS n_stg
        FROM
            {{ref ('stg_order_items')}}
        WHERE
            order_id IN (
                SELECT
                    order_id
                FROM
                    {{ref ('int_order_lifecycle')}}
            )
    ) s,
    (
        SELECT
            count(*) AS n_fct
        FROM
            {{ref ('fct_order_items')}}
    ) f
WHERE
    s.n_stg <> f.n_fct
