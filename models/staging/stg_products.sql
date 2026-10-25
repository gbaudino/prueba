-- 1 fila por producto, deduplicamos quedandonos con el ultimo update
-- no tengo historial de precios, unit_price es el precio de lista actual
SELECT
    unit_price,
    created_at,
    updated_at,
    trim(product_id) AS product_id,
    trim(product_name) AS product_name,
    lower(trim(category)) AS category,
    upper(currency) AS currency
FROM {{ source('raw', 'products') }}
QUALIFY row_number() OVER (
    PARTITION BY trim(product_id)
    ORDER BY updated_at DESC, _extracted_at DESC
) = 1
