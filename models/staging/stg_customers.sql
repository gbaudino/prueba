-- 1 fila por cliente, deduplicamos quedandonos con el ultimo update
SELECT
    segment,
    created_at,
    updated_at,
    trim(customer_id) AS customer_id,
    trim(first_name) AS first_name,
    trim(last_name) AS last_name,
    lower(trim(email)) AS email,
    upper(trim(country_code)) AS country_code
FROM {{ source('raw', 'customers') }}
QUALIFY row_number() OVER (
    PARTITION BY trim(customer_id)
    ORDER BY updated_at DESC, _extracted_at DESC
) = 1
