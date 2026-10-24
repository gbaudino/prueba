{% test not_before(model, column_name, other_column) %}
SELECT *
FROM {{ model }}
WHERE
  {{ column_name }} IS NOT NULL
  AND {{ other_column }} IS NOT NULL
  AND {{ column_name }} < {{ other_column }}
{% endtest %}
