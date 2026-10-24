-- 1 fila por producto, deduplicamos quedandonos con el ultimo update
-- no tengo historial de precios, unit_price es el precio de lista actual
SELECT
    trim(product_id)      AS product_id,
    trim(product_name)    AS product_name,
    lower(trim(category)) AS category,
    unit_price,
    upper(currency)       AS currency,
    created_at,
    updated_at
FROM {{ source('raw', 'products') }}
qualify row_number() OVER (
    PARTITION BY trim(product_id)
    ORDER BY updated_at DESC, _extracted_at DESC
) = 1
