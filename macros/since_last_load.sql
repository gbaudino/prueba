{#
   punto de corte del incremental: lo ultimo que ya tiene esta tabla menos lookback_days de margen
   reproceso un poco hacia atras por seguridad y no genera duplicados porque cada modelo es idempotente
#}
{% macro since_last_load(column) -%}
    (SELECT max({{ column }}) FROM {{ this }}) - interval '{{ var("lookback_days") }} days'
{%- endmacro %}
