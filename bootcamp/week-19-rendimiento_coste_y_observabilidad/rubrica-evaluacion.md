# Rúbrica de evaluación — Semana 19

> Rendimiento, coste y observabilidad. Se aprueba con un **mínimo del 70 % en cada evidencia**, no
> en el promedio. Esta semana no cierra fase: no lleva minisimulacro.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de la capa 19 |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** Un run de un repo **privado** tiene cuatro jobs en Linux estándar que duran 4 s, 9 s, 48 s y
61 s; otro job se salta por su `if:` y otro solo llama a un reutilizable. ¿Cuántos minutos
facturables suma el run? ¿Por qué `GET .../runs/{id}/timing` devuelve `total_ms: 0` en `tablero`, y
por qué aun así quitas `runner-info`?

<details>
<summary>Respuesta</summary>

**5 minutos**: 1 + 1 + 1 + 2. GitHub redondea por arriba al minuto **cada job por separado**: un
job de 4 s paga un minuto entero y uno de 61 s paga dos. El job saltado no factura porque no llega
a pedir runner. El job que solo llama a un reutilizable tampoco: facturan los jobs de dentro, cada
uno con su propio redondeo. Por eso partir el trabajo en muchos jobs cortos es lo más caro por
segundo útil: seis jobs de 15 s terminan antes que uno de 110 s y facturan el triple.

`tablero` es público y los runners estándar alojados no consumen cupo en repos públicos (tampoco
los runners propios). El endpoint `timing` lo refleja con `total_ms: 0`, aunque `run_duration_ms`
siga diciendo cuánto tardó.

Quitas `runner-info` porque el coste no es solo dinero: era un job más que esperar en cola, pedir
máquina y aparecer en cada run sin que ningún job lo necesitara salvo `summary`. Y el hábito de
medir minutos facturables es el que te ahorra dinero el día que el repo sea privado o use runners
grandes, que facturan también en públicos. Teoría 01, práctica 01 paso 4.

</details>

**2.** `job-timings.sh` enseña para un run: `changes` 3 s de cola y 9 s de duración, `api` 40 s de
cola y 90 s de duración, `web` 4 s de cola y 48 s. `api` y `web` dependen de `changes`. ¿Qué es la
cola y qué la duración? ¿Qué job marca el reloj del run? Si acortas `web` 20 s, ¿qué baja: el reloj,
la factura o las dos?

<details>
<summary>Respuesta</summary>

**Cola** es el tiempo entre que el job se crea (`created_at`) y que un runner lo coge
(`started_at`): no lo controla tu YAML, depende de cuántos runners hay libres. **Duración** es de
`started_at` a `completed_at`: lo que tarda tu trabajo, incluido preparar el job y cada step. El
reloj del run va del primer `created_at` al último `completed_at`.

El reloj lo marca el **camino crítico**: la cadena de `needs` que más tarda de punta a punta,
contando cola y duración. Aquí es `changes` → `api` (≈ 12 s + 130 s), no `web`.

Acortar `web` 20 s **no baja el reloj**, porque `web` no está en el camino crítico: el run sigue
esperando a `api`. La factura podría bajar o no: `web` pasa de 48 s a 28 s y los dos redondean a
un minuto. Lo que de verdad acorta el reloj es atacar `api`, y su cola de 40 s dice que antes de
optimizar tests conviene mirar si faltan runners. Por eso se mide antes de tocar nada. Teoría 02,
práctica 01 pasos 1 a 3.

</details>

**3.** Abres el PR #31 desde `feat/a` y su CI guarda una caché de pnpm. Luego abres el PR #32 desde
`feat/b`, una rama sacada de `feat/a`. ¿Restaura el #32 la caché del #31? ¿Y el push a `main` tras
fusionar el #31? ¿Quién puede leer esa entrada y qué pasa con ella al cerrar el PR?

<details>
<summary>Respuesta</summary>

**No en los dos casos.** Un `pull_request` corre sobre `refs/pull/31/merge` y guarda ahí. Un run
solo restaura de su propia ref, de la rama por defecto y, en un PR, de la rama base. `refs/pull/31/merge`
no es ninguna de esas para el #32 (y las ramas hijas o hermanas no comparten caché), ni tampoco para
el push a `main`: `main` no lee hacia abajo, son las ramas las que leen de `main`.

**Solo los re-runs del propio #31** pueden leer esa entrada. Al cerrarse o fusionarse el PR se
queda huérfana: ocupa sitio hasta que la expulsen 7 días sin acceso o la presión de tamaño, y por
el camino puede empujar fuera la caché de `main`, la única que comparten todos. Por eso existe
`cleanup.yml`.

La otra cara del alcance: cualquiera que abra un PR contra `main`, también desde un fork, puede
**leer** la caché de `main`. Nunca se guarda en caché nada que no publicarías. Teoría 03, práctica 02
paso 3.

</details>

**4.** Un step `actions/cache` tiene `key: pnpm-${{ hashFiles('web/pnpm-lock.yaml') }}` y
`restore-keys: pnpm-`. Cambias una dependencia, el log dice "Cache restored from key: pnpm-ab12…" y
el step siguiente lleva `if: steps.cache.outputs.cache-hit != 'true'`. ¿Corre ese step? ¿Qué se
guarda al final del job? ¿Qué cambia si la clave lleva `github.sha`?

<details>
<summary>Respuesta</summary>

**Sí corre.** `cache-hit` vale `true` solo con coincidencia **exacta** de `key`. Restaurar por un
prefijo de `restore-keys` trae una caché vieja ("stale"), y la documentación del input dice que
`cache-hit` es `false` en ese caso. Es lo que quieres: la caché parcial te ahorra descargar casi
todo, pero falta lo nuevo y la instalación tiene que correr. Saltarse la instalación con un acierto
parcial dejaría el job sin las dependencias recién añadidas.

Al final del job se guarda una **entrada nueva** con la clave del lockfile nuevo, porque esa clave
no existía. Las entradas son inmutables: si la clave ya existe, el guardado se omite.

Con `github.sha` la clave cambia en cada commit: cada run es un fallo de la clave exacta, restaura
por prefijo y guarda una entrada nueva. El repo se llena de entradas casi iguales, sube la presión
sobre los 10 GB y la expulsión acaba sacando lo que sí se reutilizaba. La clave debe cambiar cuando
cambia lo que guarda, y solo entonces. Teoría 03, práctica 02 paso 2.

</details>

**5.** En `exp/shard-web` partes los tests de `web` en dos shards con
`pnpm test --shard=${{ matrix.shard }}/2`. `job-timings.sh` da 41 s para el job entero y 38 s y
37 s para los shards. ¿Por qué el reloj apenas baja y la factura se duplica? ¿Cuándo sí compensaría
partir, y qué se rompe al hacerlo?

<details>
<summary>Respuesta</summary>

Cada shard paga el **arranque completo** del job (A: preparar el runner, checkout, instalar
dependencias) y solo reparte el **trabajo de la suite** (W). El reloj del shard más lento es
≈ A + W/N y la factura ≈ N × ⌈(A + W/N)/60⌉. En `web` hay dos archivos de test: W es pequeño frente
a A, así que repartirlo gana 3 o 4 segundos de reloj y paga dos minutos en vez de uno. El sharding
pierde desde el primer shard.

Compensa cuando **W domina sobre A** (una suite de minutos, con muchos archivos) y está equilibrada:
vitest reparte por archivos, y si uno tarda mucho más que el resto, el shard que lo recibe marca el
reloj de todos. Cada shard extra gana menos reloj y paga lo mismo de arranque.

Al partir se rompen los informes (cada shard tiene el suyo: reporter `blob` y `--merge-reports` en
un job final) y la cobertura: un umbral comprobado por shard falla aunque la suite completa lo
cumpla. La decisión se apunta con sus números aunque sea "no": una medida que dice que no es
también un resultado. Teoría 04, práctica 02 pasos 4 y 5.

</details>

**6.** El job `changes` clona con `fetch-depth: 0` y `filter: blob:none`. ¿Qué trae ese clon y qué
no? ¿Por qué `changed-areas.sh` funciona igual? ¿Por qué no pones `filter: blob:none` en los jobs
de tests, y qué fallaría si `tablero` fuera privado?

<details>
<summary>Respuesta</summary>

Trae **todos los commits y todos los árboles** de la historia, y de los blobs (el contenido de cada
versión de cada archivo) solo los que hacen falta para dejar en disco el commit comprobado. Los
demás se piden al servidor bajo demanda si algún comando los necesita.

`git diff --name-only BASE HEAD` **compara árboles**: si el hash de un archivo cambió, el archivo
cambió, sin abrir su contenido. Necesita la historia completa para encontrar la base (por eso
`fetch-depth: 0`) y no necesita blobs antiguos, que son lo que más pesa.

Los jobs de tests ya usan el clon por defecto de un commit, que es lo mínimo: un clon parcial ahí no
ahorra nada. Y el clon parcial tiene trampas: `git log -p`, `git blame` o un `git diff` con
contenido piden cada blob que falta, uno tras otro, y pueden tardar más que un clon completo. La
descarga bajo demanda es un `fetch` contra `origin`: con `persist-credentials: false` funciona en un
repo público, pero en uno privado fallaría por falta de credenciales. Teoría 05, práctica 01
paso 5.

</details>

**7.** `ci-metrics.yml` se dispara con `workflow_run` tras `ci`. ¿Por qué no corre mientras el
archivo solo está en tu rama? ¿Por qué un workflow `workflow_run` puede leer la caché de `main`
pero no escribir en ella? ¿Qué hace seguro a `ci-metrics` aunque zizmor marque el disparador?

<details>
<summary>Respuesta</summary>

`workflow_run` **solo dispara si el workflow que escucha está en la rama por defecto**. Corre en el
contexto de `main`, con su token y sus secretos: GitHub no deja que una rama cualquiera se enganche
a los runs de otros. Por eso el check `ci-metrics-ran-after-ci` solo se puede poner en verde
después de fusionar.

Como corre con el contexto de `main` aunque lo dispare un run de un PR, `workflow_run` es un
disparador de **baja confianza**: junto con `pull_request_target` e `issue_comment`, solo **lee** la
caché de la rama por defecto. Escribir en ella queda para `push`, `schedule`, `workflow_dispatch` y
otros eventos de confianza. Si un run así pudiera escribir, un PR malicioso podría envenenar la
caché que restaura el siguiente build de `main` (Semana 12).

`ci-metrics` sigue el patrón seguro: **no ejecuta nada del run medido**. Hace checkout de `main`
(sus propios scripts), lee la API con `actions: read` y `contents: read` sobre `permissions: {}` en
la raíz, recibe el id del run por `env:` (`RUN_ID`) y escribe en el resumen. `branches: [main]` deja
fuera los runs de PR y de la cola. El comentario `# zizmor: ignore[dangerous-triggers]` lleva el
porqué en la misma línea. Teorías 03 y 06, práctica 03 pasos 2 y 3.

</details>

**8.** Tienes 20 runs de `ci` en `main`: diecinueve tardan entre 280 y 320 s y uno se quedó colgado
3600 s. ¿Qué dan la media, el p50 y el p95 por rango más cercano? ¿Por qué el presupuesto se pone
sobre el p95 y no sobre la media? ¿Por qué la duración sale de `run_started_at` y el aviso va a
stderr?

<details>
<summary>Respuesta</summary>

La **media** sube a unos 465 s: un solo run raro la arrastra y ya no describe ningún run real. Por
rango más cercano se ordenan las 20 duraciones y se toma la posición ⌈p·n⌉: el **p50** es el 10.º
(unos 300 s, el run típico) y el **p95** es el 19.º, el más lento de los normales (unos 320 s). El
colgado es el 20.º: con 20 muestras no entra en el p95, pero con menos runs el p95 coincide con el
máximo. Por eso la tendencia usa hasta 100 runs.

El p95 es lo que tarda un run malo, pero no el peor: lo que marca la paciencia del equipo. Un
presupuesto sobre la media se dispara o se calla según caigan los atípicos.

`created_at` lo conserva un re-run del primer intento: un re-run tres horas después daría una
duración de tres horas. `run_started_at` es el inicio del intento actual. El aviso va a **stderr**
porque stdout se vuelca en `$GITHUB_STEP_SUMMARY` y el `::warning` acabaría como texto en la tabla;
el runner procesa comandos de workflow en las dos salidas, así que la anotación aparece igual.
Teoría 06, práctica 03 pasos 1 y 4.

</details>

**9.** Bajas la retención del repo a 14 días. Un workflow sube un artefacto con
`retention-days: 30`. ¿Cuánto vive? ¿Afecta ese ajuste a la caché? ¿Dónde guardas lo que sí tiene
que durar, como el SBOM de una release?

<details>
<summary>Respuesta</summary>

**14 días**: `retention-days` en `actions/upload-artifact` no puede superar la retención del repo,
solo acortarla. Por defecto un repo público guarda artefactos y logs 90 días, que también es el
máximo; el `PUT` a `actions/permissions/artifact-and-log-retention` con `-F days=14` lo baja (`-F`
envía un número, no una cadena).

**No afecta a la caché**: son dos bolsas distintas. La caché tiene su propio límite de retención
(7 días sin acceso por defecto, endpoint `actions/cache/retention-limit`) y de tamaño (10 GB,
`actions/cache/storage-limit`), y un repo nunca supera el límite de su org. También se facturan
aparte: los artefactos comparten cupo con Packages; la caché tiene 10 GB incluidos por repo.

Catorce días cubren una iteración: el artefacto con el que depuras el fallo de esta semana sigue
ahí. Lo que debe durar no es un artefacto de CI: va a la release de GitHub o a GHCR, con su
attestation, como en la Semana 14. Teoría 07, práctica 04 paso 1.

</details>

**10.** `prune-caches.sh` borra por `id` las cachés de `refs/pull/N/merge` de PR que ya no están
abiertos y las de `refs/heads/X` de ramas que no existen. ¿Por qué no borra por clave? ¿Por qué
`cleanup.yml` lanzado a mano no borra nada por defecto pero el cron sí? ¿Por qué el workflow fija
`shell: bash` si el script ya lleva `set -euo pipefail`?

<details>
<summary>Respuesta</summary>

`gh cache delete <clave>` borra **todas** las entradas con esa clave en cualquier ref, `main`
incluida, salvo que filtres con `--ref`. Una caché de PR y la de `main` suelen tener la misma clave
(el mismo lockfile). Por `id` se borra exactamente la entrada huérfana. Y las listas de ramas y de
PR abiertos se piden **una vez**, no una llamada por caché. `main` y los tags nunca se tocan.

En `workflow_dispatch` el input `dry-run` vale `true` por defecto: quien lo lanza a mano ve primero
qué se borraría y tiene que pedir `-f dry-run=false` de forma explícita. En `schedule` no existen
inputs: `inputs.dry-run` llega vacío, `DRY_RUN` no vale `true` y el script borra, que es para lo que
existe el cron. Lo seguro depende de quién lo lance.

El `set -euo pipefail` del script protege **dentro** del script. El step hace
`scripts/prune-caches.sh | tee -a "$GITHUB_STEP_SUMMARY"`, y sin shell explícito el runner usa
`bash -e {0}`, sin `pipefail`: si el script falla, `tee` sale con 0 y el step queda en verde. Con
`shell: bash` el runner usa `bash --noprofile --norc -eo pipefail {0}` y el fallo se ve. Teoría 07,
práctica 04 pasos 2 a 4.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Medir la línea base | `job-timings.sh` con cola, duración, redondeo por job, reloj y fila Total; `ci.yml` sin `runner-info` y con `summary` dependiendo solo de lo que usa; `changes` con historial completo sin blobs (checks `job-timings-script`, `no-runner-info`, `changes-blobless`) | 5 |
| 01 — Medir la línea base | Enseña la medida a mano de un run (`gh run view --json jobs` y el endpoint `timing`) y la tabla de tres runs antes y tres después en la descripción del PR, con la diferencia explicada | 5 |
| 02 — Caché y paralelismo medidos | Enseña el inventario de caché (uso, retención y tamaño por API), un acierto exacto y uno por `restore-keys` en los logs, y las entradas de `refs/pull/N/merge` que crea un PR | 5 |
| 02 — Caché y paralelismo medidos | Enseña el experimento de sharding con `job-timings.sh` del job entero y de los dos shards, la decisión escrita con sus números y el PR cerrado sin fusionar | 5 |
| 03 — Métricas del CI | `ci-trend.sh` con p50, p95 y aviso por stderr; `ci-metrics.yml` con sus tres disparadores, solo lectura y los dos jobs al resumen; la variable de presupuesto; actionlint y zizmor limpios; los dos runs en verde sobre `main` (checks `ci-trend-script`, `ci-metrics-triggers`, `ci-metrics-read-only`, `ci-metrics-summary`, `workflows-lint`, `budget-variable`, `ci-metrics-ran-after-ci`, `ci-metrics-trend-ran`) | 5 |
| 03 — Métricas del CI | Enseña la anotación `CI lento` provocada con un presupuesto bajo, el presupuesto definitivo justificado con el p95 medido y la comparación con Actions Performance Metrics de la org | 5 |
| 04 — Retención y limpieza | Retención a 14 días; `prune-caches.sh` con dry-run; `cleanup.yml` diario y a mano con `dry-run` por defecto y solo `actions: write`; la limpieza en verde sobre `main` (checks `artifact-retention`, `prune-caches-script`, `cleanup-workflow`, `cleanup-ran`) | 5 |
| 04 — Retención y limpieza | Enseña la prueba local con el `gh` de mentira, el primer `cleanup` en dry-run antes del real, el recuento de cachés antes y después, y el respaldo antes de borrar los artefactos y logs de un run | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 19` con 15/15. Cada comprobación en rojo
resta la parte proporcional (12/15 de punto).

**Calidad manual de la capa 19 (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| La línea base está escrita: tabla de tres runs antes y tres después en el PR de la práctica 01, con una frase que dice qué cambió y cuánto | 3 |
| Cada optimización tiene su medida delante y detrás, también la que no mejoró (el sharding de la práctica 02) | 3 |
| `CI_P95_BUDGET_SECONDS` sale del p95 medido más un margen justificado por escrito, no de un número redondo | 3 |
| La limpieza es segura: `prune-caches.sh` nunca toca `main` ni tags, borra por `id`, y el primer `cleanup` fue un `dry-run` | 3 |
| Permisos justos: `ci-metrics` solo lee; `cleanup` escribe en Actions y nada más | 2 |
| `job-timings.sh` y `ci-trend.sh` se prueban sin GitHub, con un JSON guardado por stdin | 2 |
| Sin `TODO` en el repo | 2 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log | Grave: Producto a 0 hasta rotarlo y retirar el commit o el log |
| `cleanup` o `prune-caches.sh` que borra cachés de `main`, de tags o de PR abiertos, o que borra por clave sin `--ref` | Grave: −10 |
| `ci-metrics` con algún permiso de escritura, o que hace checkout o ejecuta código del run medido | Grave: −10 |
| `pull_request_target` con checkout del head del PR | Grave: −10 |
| Runner propio al alcance de PRs de forks: un workflow con `pull_request*` o `merge_group` que pide `tablero-runners` | Grave: −10 |
| `uses:` remota sin SHA, o con un SHA copiado que no pertenece al repo oficial | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}`, `github.head_ref`, `inputs.*`, `secrets.*` o `vars.*` interpolado dentro de `run:` | Grave: −10 |
| Imagen sin tag o con `latest` | Grave: −10 |
| `cleanup.yml` sin `concurrency` o con `cancel-in-progress: true` | −3 |
| Un step con tubería a `tee` sin `shell: bash` (sin `pipefail`) | −3 |
| Job con `runs-on` sin `timeout-minutes` | −3 por cada uno |
| `pip`, `npm` o Compose v1 en un workflow o en la documentación de tu repo | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 19 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
