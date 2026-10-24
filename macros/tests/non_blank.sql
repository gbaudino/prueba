{% test non_blank (model, column_name) %}
SELECT *
FROM {{model}}
WHERE
    {{column_name}} IS NULL
    OR trim({{column_name}}) = ''
{% endtest %}
