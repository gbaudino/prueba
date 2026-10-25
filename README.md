# Prueba tecnica Craftech – Data Engineering

Esta es mi solucion a la prueba. Es un modelo de datos y un proceso batch diario que parten del esquema `raw` de un ecommerce (DuckDB) y responden las cuatro preguntas del negocio propuestas.

Segui el stack propuesto usando Python, SQL, DuckDB y dbt para los modelos y los tests.

Lo que mas tiempo me llevo fue entender los datos y armar la capa intermedia. Los problemas que encontre (duplicados, eventos que llegan tarde y fuera de orden, ordenes incompletas) definen casi todas las decisiones de diseño, así que los deje documentados abajo

## Como correrlo desde cero

Lo unico que se necesita es tener instalado [uv](https://docs.astral.sh/uv/). Luego uv instala python y las dependencias.

```bash
git clone https://github.com/gbaudino/prueba
cd prueba
uv sync
uv run python run.py
```

`run.py` corre `dbt build`, que construye todos los modelos y ejecuta todos los tests. El resultado queda en `data/warehouse.duckdb`.

Para ademas ver las respuestas a las preguntas del negocio hay que usar:
```bash
uv run python run.py --queries
```

Y para reconstruir todo desde `raw` en lugar de procesar solo lo nuevo (incremental):

```bash
uv run python run.py --full-refresh
```

Para mirar el resultado a mano instale un cliente cli de DuckDB, podemos hacer:

```bash
uv run duckdb -readonly data/warehouse.duckdb -f queries/02_sales.sql
```

## Respuestas al negocio

Las consultas estan en `queries/`, una por pregunta, y salen de las tablas finales (`marts`). Con los datos entregados:

**Clientes.** Hay 600 clientes registrados, que se fueron dando de alta entre julio de 2025 y junio de 2026. De los 600, 398 estan activos, tomando como activo al que hizo al menos una compra no cancelada en los ultimos 90 dias (esa ventana es una variable). Con 30 dias serian 370 los activos.

**Ventas.** Hay 3.409 ventas, entre el 1 de enero y el 30 de junio de 2026. La consulta `queries/02_sales.sql` las da por dia y por semana. La primera semana aparece con fecha 29 de diciembre de 2025 porque las semanas empiezan en lunes (duckdb) y el 1 de enero cayo jueves.

**Ingresos.** Los ingresos totales son 3.667.812,14 USD. Por categoria:

| Categoria | Ingresos (USD) | % |
|---|---|---|
| electronics | 2.033.343,60 | 55,44 |
| home | 659.723,27 | 17,99 |
| sports | 608.188,94 | 16,58 |
| beauty | 214.243,81 | 5,84 |
| books | 152.312,52 | 4,15 |

Se consideran para los ingresos las no devueltas o canceladas y que estan al menos pagadas.

**Ordenes.** De las 3.992 ordenes completas, el 81,46 % termino entregada y el 10,87 % cancelada. El resto: 3,58 % devuelta, 2,91 % enviada, 1,03 % pagada y 0,15 % recien creada. Si se mira solo lo que ya tiene un final (entregadas mas canceladas), la proporcion es 88,2 % entregadas y 11,8 % canceladas.

## Como esta armado

```
raw (solo lectura)  →  staging  →  intermediate  →  marts
```

- **`staging`** (`stg_*`): una tabla por cada tabla de `raw`, limpia espacios, formatea y deduplica.
- **`intermediate`** (`int_order_lifecycle`): la tabla de ordenes en `raw` es un log de eventos, con una fila por cada cambio de estado. Aca lo colapso a una fila por orden, con la fecha de cada paso (`paid_at`, `shipped_at`, etc.), el estado final, si el ciclo de vida es valido y si la orden esta completa.
- **`marts`**: lo que se consulta. `dim_customers`, `dim_products`, `fct_orders` (una fila por orden) y `fct_order_items` (una fila por linea).

El resto del repo:

| carpeta o archivo | que hay |
|---|---|
| `analysis/` | exploracion inicial hecha sobre los datos raw |
| `queries/` | las respuestas a las preguntas del negocio |
| `tests/` y `macros/` | tests propios y el macro que arma el corte incremental |
| `run.py` | entrypoint |
| `profiles.yml`, `dbt_project.yml` | configuracion de dbt |

## Que encontre en los datos

Antes de modelar explore `raw` con consultas SQL, que están en `analysis/`. Acá va todo lo que encontré.

### Lo mas basico (`01_overview`)

`raw` tiene cuatro tablas: 600 clientes, 80 productos, 15.608 filas de eventos de órdenes y 7.820 filas de items.

- Los estados posibles son seis: `created`, `paid`, `shipped`, `delivered`, `cancelled` y `returned`.
- Hay siete paises (AR, CL, CO, ES, MX, PE, UY), cinco categorias de producto (beauty, books, electronics, home, sports) y dos segmentos de cliente (retail y wholesale).
- Todos los precios estan en USD, asi que no hace falta convertir moneda.
- Las ordenes tienen entre 1 y 4 lineas, con cantidades de 1 a 20 unidades.
- Los eventos van del 1 de enero al 1 de julio de 2026.

### Calidad (`02_quality`)

Busque nulos, textos vacios, fechas imposibles (actualizacion anterior a creacion, ingesta anterior al evento), precios negativos y cantidades menores o iguales a cero. No encontre ninguno en ninguna de las cuatro tablas. Tampoco hay productos con precio cero. Los datos vienen limpios en ese sentido, asi que los problemas estan en otro lado.

### Claves y duplicados (`03_keys`)

- `customers` y `products` tienen exactamente una fila por `customer_id` y por `product_id`. No hay historial de clientes ni de precios.
- `orders` no es una tabla de ordenes: es un log de eventos. Hay 3.998 órdenes distintas repartidas en 15.608 filas, y el grano real es `(order_id, status, event_at)`.
- Hay 443 eventos duplicados en `orders` (afectan a 426 ordenes) y 205 lineas duplicadas en `order_items`. Verifique que ninguno es un evento distinto: todos son el mismo evento o la misma linea ingestados dos veces, con el mismo producto, la misma cantidad y la misma fecha de evento, y solo cambia `_ingested_at`. Por eso se deduplican sin perder nada.
- Los conteos de eventos por orden (la mayoria tiene 4, otras 5, algunas 6) parecen raros porque deberia haber pasado por todos los eventos (imagina pasar por entregado y cancelado), pero eso es por los duplicados. Una orden con 6 filas no paso por los seis estados distintos, tiene eventos repetidos.
- No hay forma de saber el precio al que se vendio cada producto, porque `raw.products` solo guarda el precio de lista actual (y 26 productos tienen una fecha de actualización posterior a la de creacion, o sea que su precio pudo cambiar). Es una limitacion de la fuente y lo deje como supuesto.

### Relaciones (`04_relations`)

Revise todas las referencias entre tablas y esta todo bien, no hay ordenes de clientes inexistentes, ni items de ordenes inexistentes, ni items de productos inexistentes, ni ordenes anteriores al alta del cliente, ni ventas anteriores a la creacion del producto. Pero si encontre esto:

- 5 ordenes no tienen ningun item. Son las mismas 5 que no tienen evento `created`.
- 198 clientes (un tercio) nunca compraron. No es un error, pero hay que tenerlo en cuenta.

### Lifecycle (`05_lifecycle`)

Defini cual es el flujo valido: `created → paid → shipped → delivered → returned`, con `cancelled` posible desde `created`, `paid` o `shipped`, pero no despues de `delivered` (ahi solo se puede devolver). Compare cada evento con el anterior de su orden, ya deduplicado.

- 6 ordenes tienen una transicion invalida: 5 no tienen evento `created`, y 1 pasa de `created` a `shipped` sin haber pasado por `paid`.
- Ninguna orden tiene eventos de clientes distintos.
- Ninguna orden se cancela despues de entregada.

### Tiempo (`06_time`)

Esto es lo que mas peso en el diseño del incremental:

- `customers` y `products` tienen una sola extraccion, asi que no hay versiones que resolver. Igual deduplique porque no se si hay proximos eventos si se updatea la misma fila o se actualiza esa.
- Un evento tarda en llegar, en promedio, casi 5 horas, y como maximo casi 2 dias.
- Hay 668 eventos, de 656 ordenes, que llegan despues de otro evento posterior de la misma orden (por ejemplo, llega el `paid` despues del `shipped`). Eso significa que el estado de una orden no se puede calcular mirando solo las filas nuevas: hay que recalcularlo con todos sus eventos. En 65 ordenes, el ultimo evento ingestado no es el ultimo que ocurrio, asi que calcular el estado por orden de llegada daria un resultado incorrecto.
- La copia de un duplicado puede llegar en otra carga, hasta casi 2 dias despues del original. No alcanza con deduplicar dentro del lote nuevo: hay que deduplicar contra lo ya cargado.

## Decisiones y supuestos

- **Deduplicacion**
  Se hace en staging, por clave natural: `order_id, status, event_at` para los eventos y `order_id, line_number` para los items. Me quedo con la primera ingesta. Los duplicados son copias exactas, asi que no se pierde informacion.
- **Estado de una orden**
  Es el del ultimo evento que ocurrio (`event_at`), no el ultimo que llego porque hay eventos que llegan fuera de orden.
- **Ordenes completas**
  Una orden entra a los marts solo si tiene items y todos los estados del flujo hasta el ultimo que alcanzo.
  6 de 3.998 no cumplen estar completas, quedan marcadas en el intermedio con `is_complete = false` y avisadas por un test.
- **Que es una venta**
  Una orden con estado final `paid`, `shipped` o `delivered`. Una orden `created` todavia no se pago, en una `cancelled` y en una `returned` se devuelve el dinero, asi que ninguna cuenta como ingreso. La fecha de la venta es la fecha de creacion de la orden.
- **Ingresos**
  Se calculan como `cantidad × precio de lista actual`, sumado por linea ya que no hay historial de precios.
- **Cliente activo**
  Es el que compro algo no cancelado en los ultimos `active_window_days` dias (variable, yo elegi 90). La consigna no define "activo". La ventana se puede cambiar en `dbt_project.yml`.
- **"Hoy"**
  Es el ultimo evento cargado, no la fecha del sistema. Asi el resultado se puede reproducir en cualquier fecha.
- **Semanas**
  Empiezan en lunes (`date_trunc('week')`). Es el comportamiento estandar de DuckDB.
- **Moneda**
  Todo esta en USD. Un test avisa, rompiendose, si aparece otra.
- **Materializacion**
  `stg_orders`, `stg_order_items`, `int_order_lifecycle` y los facts son incrementales. Los demas modelos son tablas.

## Tests

`dbt build` corre los tests junto con los modelos. Los problemas que ya conozco de la fuente (duplicados, eventos fuera de orden, ordenes incompletas) estan como advertencia (`severity: warn`). Las reglas del modelo, en cambio, hacen fallar el build si se rompen.

El build termina con 0 errores y 4 advertencias, y las 4 son esperadas:

1. `source_unique_combination_raw_orders...`: los 443 eventos duplicados.
2. `source_unique_combination_raw_order_items`: las 205 lineas duplicadas.
3. `assert_events_arrive_in_order`: las 65 ordenes con ultimo evento ingestado que no es el ultimo ocurrido.
4. `assert_orders_are_complete`: las 6 ordenes incompletas que no llegan a los marts.

En general arme tests asi

- **Sobre `raw`:** claves unicas, nulos, textos vacios, cantidades y precios validos, referencias entre tablas, eventos "del futuro" (ingested_at < event_at) y estados permitidos.
- **Sobre staging:** que ya no queden los problemas de `raw` (aca los tests fallan).
- **Sobre los marts:** lo anterior y que no se pierdan ni se dupliquen filas al unir, por ej que el total de ingresos de `fct_orders` coincida con el de `fct_order_items`.
- **De negocio:** que el lifecycle de las ordenes completas sea valido, que cada orden tenga un solo cliente y que ninguna orden sea anterior al alta de su cliente.

Los tests genericos estan en `macros/tests/` y los demas en `tests/`.

## Como arme el incremental

El proceso corre una vez por dia, asi que no tiene sentido reconstruir todo el historial en cada corrida. Se que con este volumen tardaria lo mismo sin incremental, pero lo arme como lo haria con mas datos en un pipe de prod.

La idea es procesar solo las ordenes que tuvieron algo nuevo, pero recalcularlas con todos los eventos.

1. **Staging** (`stg_orders` y `stg_order_items`) lee de `raw` solo lo ingestado desde la ultima carga, y descarta lo que ya esta cargado.
2. **La capa intermedia** detecta que ordenes tuvieron eventos o lineas nuevos, relee todos los eventos, recalcula la fila de cada una y la reemplaza.
3. **Los facts** (`fct_orders` y `fct_order_items`) hacen lo mismo a partir del intermedio.
4. **Las dims** se reconstruyen enteras porque son tablas chicas.

Cada decision sale de algo que encontre al principio:

- El corte es por `_ingested_at`, no por `event_at` porque los eventos llegan tarde (hasta casi 2 dias). Si cortara por fecha del evento, perderia los que llegan despues. De paso, esto hace que el retraso entre evento e ingesta no afecte la correctitud.
- Se recalcula la orden con todos sus eventos, porque hay eventos que llegan fuera de orden y el estado no se puede calcular solo con lo nuevo.
- Se deduplica contra lo ya cargado, porque la copia de un duplicado puede llegar en otra carga.
- El corte retrocede `lookback_days` desde lo ultimo cargado en cada tabla. Es un margen de seguridad para cargas que lleguen con una fecha de ingesta anterior al maximo ya cargado. No genera duplicados porque cada paso es idempotente: reprocesar lo mismo da lo mismo.

El corte es relativo a lo ultimo que tiene cada tabla, no a la fecha del momento.

**Limitaciones:**

- `line_amount` usa el precio de lista vigente en el momento en que se recalcula la orden. En incremental, una orden queda con el precio de la ultima vez que se toco, y un `--full-refresh` lo actualiza para todas.
- Si se cambia la estructura de un modelo incremental o una definicion, requiere correr `--full-refresh`

## Como lo orquestaria en prod

No lo implemente, pero lo haria con Airflow, con un DAG diario, algo asi:

1. Esperar la carga. Se espera a que el data lake termine de cargar `raw` del dia, con un timeout para no quedar colgado.
2. Chequeamos freshness. Antes de transformar, nos aseguramos que `raw` tiene datos nuevos.
3. dbt build. Una sola tarea que construye los modelos y corre los tests. Si hay un test con error, el DAG falla y los marts no se publican.
4. Una tarea final que mande una alerta si por ejemplo fallaron los tests o bien si todo termino correctamente.

Algunos detalles que se me ocurren:

- Es idempotente por lo que correr el DAG dos veces seguidas da el mismo resultado, asi que reintentar es seguro.
- Para los backfills y cambios de logica deberiamos correr manualmente con `--full-refresh`.
- Si esto creciera los modelos podrian correr con particionado por fecha de ingesta.

## Algunas cosas que haria si tuviera mas tiempo

- Guardar el historial de precios de los productos (por ej con snapshots de dbt) para calcular los ingresos con el precio real de cada venta.
- Armar el DAG de Airflow.
- Añadir sqlfluff o algun formateador de SQL para las consultas por prolijidad.

## Uso de IA

Utilice IA, particularmente Claude y Codex, en varias partes del trabajo.

- En la exploracion (`analysis/`) escribi las consultas y me ayude con IA en consultas complicadas como las de keys o las temporales.
- En los modelos, tests y configuracion de dbt, me ayude con IA principalmente a la hora de implementar el incremental, pero tambien cuando arme la parte mas complicada del modelo a mi parecer que fue el de la capa intermedia donde se aplica la mayor parte de la logica de negocio basada en decisiones y supuestos mios.
- En este informe final, me ayude chequeando varias veces de no olvidarme nada de lo encontrado en la parte inicial.
