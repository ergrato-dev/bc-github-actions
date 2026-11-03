# Rúbrica de evaluación — Semana 07

> Disparadores, filtros y concurrencia. Se aprueba con un **mínimo del 70 % en cada evidencia**, no
> en el promedio.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de la capa 07 y de `nightly.yml` |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** Abres un PR cuyo primer commit toca `api/` y el segundo solo `web/`. En el segundo push,
¿corre `ci-api`? ¿Y si esos dos commits llegaran a `main` en dos pushes directos?

<details>
<summary>Respuesta</summary>

En el PR, sí. Para `pull_request` GitHub calcula un diff de **tres puntos** `base...head`: compara
la base de fusión con la punta del PR, así que ve **todo** lo que el PR cambia respecto a `main`,
`api/` incluido. El check del PR refleja el PR entero, no el último commit. En `push` el diff es de
**dos puntos** `before..after`: solo cuenta lo que trae ese push. El segundo push a `main`, que
solo toca `web/`, no despierta a `ci-api`. Por eso los `paths` de `push` y de `pull_request` se
escriben iguales, pero no "ven" lo mismo. Y hay dos límites: un push de más de 1.000 commits corre
siempre, y un diff de más de 3.000 archivos puede no correr aunque algún archivo case.

</details>

**2.** Marcas `ci-api / Tests (pytest)` como check obligatorio en `main`. Un PR que solo toca
`web/` se queda con `Expected — Waiting for status to be reported` y no se puede fusionar. ¿Por
qué, y por qué quitar los `paths` no es la solución?

<details>
<summary>Respuesta</summary>

Cuando un filtro de rutas salta un workflow, **no se crea ningún run**: no hay check verde ni
gris, no hay check. La protección espera un estado que nunca va a llegar, y el botón de fusionar no
se habilita. Quitar los `paths` lo desbloquea, pero devuelve el problema que resolvías: todo el CI
corriendo en cada cambio de cualquier carpeta. La solución es un **job puerta** que corre siempre,
decide qué partes eran necesarias y es el único check obligatorio (Semana 18). Mientras `tablero`
no tenga checks obligatorios, el filtro no bloquea nada.

</details>

**3.** Añades `schedule` con `17 3 * * *` en tu rama `ci/nightly` y esperas a la mañana
siguiente. No hay ningún run. ¿Qué pasó? ¿Y por qué `17` y no `0`?

<details>
<summary>Respuesta</summary>

GitHub lee el `schedule` **tal como está en la rama por defecto** y corre sobre su último commit:
un cron en una rama de trabajo no hace nada hasta que se fusiona, y entonces su run tiene
`github.ref == 'refs/heads/main'`. La hora es UTC salvo que declares `timezone` con un nombre IANA.
El minuto 0 es el de más carga, porque casi todo el mundo pone ahí su cron; los runs programados se
retrasan con carga alta y alguno se puede descartar. Un minuto cualquiera como el 17 esquiva el
pico. Dos reglas más: el intervalo mínimo es de 5 minutos, y en un repo público el cron se
desactiva tras 60 días sin actividad.

</details>

**4.** `dry_run` es un input `boolean`. Lo desmarcas al lanzar el workflow y aun así corre el job
con `if: ${{ github.event.inputs.dry_run }}`. ¿Por qué? ¿Qué escribes en su lugar?

<details>
<summary>Respuesta</summary>

`github.event.inputs.dry_run` llega como la **cadena** `'false'`, y una cadena no vacía es
verdadera en una expresión: el `if:` es siempre verdadero. `inputs.dry_run` respeta el tipo
declarado y vale el booleano `false`, así que el job se salta cuando debe. Usa siempre `inputs`:
además existe en todos los eventos del workflow, vacío en `push` o `schedule`, y
`inputs.target || 'all'` da el valor por defecto. Los tipos son `string`, `boolean`, `choice`,
`number` y `environment`, con 25 inputs como máximo; un `choice` rechaza en origen un valor fuera
de `options` (el HTTP 422 de la práctica 03).

</details>

**5.** Para relanzar el CI cada noche, `nightly.yml` podría hacer un commit vacío y un `git push`
con el `GITHUB_TOKEN`. ¿Por qué no despertaría a nadie? ¿Qué dos eventos sí lo hacen?

<details>
<summary>Respuesta</summary>

Los eventos que provoca el `GITHUB_TOKEN` **no crean runs nuevos**. GitHub lo impide a propósito:
si un push hecho con ese token disparara workflows, uno que hace push sobre su propia rama se
despertaría a sí mismo sin fin. El push existe en el repo, pero ningún workflow se entera. Las dos
excepciones son `workflow_dispatch` (lanzar un workflow concreto por su archivo y una `ref`, con
`actions: write`) y `repository_dispatch` (un evento con nombre propio en la rama por defecto, con
`contents: write`). `workflow_run` también encadena, pero no lo crea ningún token: lo emite GitHub
cuando otro workflow cambia de estado.

</details>

**6.** Un workflow escucha `workflow_run` sobre `ci-api` con `types: [completed]` y despliega.
Un día despliega tras un `ci-api` en rojo. ¿Qué faltaba? ¿Qué otro riesgo tiene este evento?

<details>
<summary>Respuesta</summary>

`completed` no significa `success`: también es `completed` un run fallido o cancelado. Hay que
comprobar `github.event.workflow_run.conclusion == 'success'` en un `if:`, como en el paso 5 de la
práctica 04 (`skipped,success`). Además, `workflows` lista los workflows por su `name:`, no por el
archivo, y el workflow que declara `workflow_run` solo funciona desde la rama por defecto. El
riesgo: corre con los permisos y secretos del repo aunque el run vigilado viniera de un PR de un
fork. Descargar sus artefactos o hacer checkout de su código es ejecutar código ajeno con
privilegios. Esta semana se usa solo para leer metadatos; el patrón seguro llega en la Semana 12.

</details>

**7.** Con `group: ${{ github.workflow }}-${{ github.ref }}` y `cancel-in-progress: false`, haces
tres pushes seguidos a `main`: A, B y C. ¿Qué runs llegan a correr? ¿Por qué el grupo lleva las dos
partes?

<details>
<summary>Respuesta</summary>

Corren A y C. En un grupo hay como mucho **un run en curso y uno pendiente**: A corre, B queda
pendiente, y cuando llega C **sustituye a B**, que se cancela sin haber empezado. Pasa sea cual sea
`cancel-in-progress`, que solo decide qué le ocurre a A. El nombre importa porque el grupo es una
cadena compartida entre workflows: solo `ci` hace que el PR de Ana cancele el de Luis; solo
`github.workflow` hace que un PR cancele a `main`; solo `github.ref` hace que `ci-api` cancele a
`ci-web`. Workflow y ref juntos dan un grupo por workflow y rama, o por PR (`refs/pull/<n>/merge`).
Si necesitas que no se pierda ninguno, `queue: max` existe en la documentación, pero actionlint
1.7.12 lo rechaza.

</details>

**8.** ¿Por qué `cancel-in-progress: ${{ github.event_name == 'pull_request' }}` y no
`cancel-in-progress: true`?

<details>
<summary>Respuesta</summary>

En un PR, un push nuevo deja obsoleto el run anterior: nadie va a fusionar con el resultado de un
commit que ya no es la punta, y cancelarlo ahorra minutos y da el verde antes. En `main` cada
commit es una versión que va a existir: su run publica imágenes, y un run cortado a medias deja
un commit de `main` sin verificar o un paquete a medio publicar. La expresión da `true` en los PR y
`false` en todo lo demás. Si ves runs de `main` en `cancelled` lanzados por `push`, tu
`cancel-in-progress` no está distinguiendo eventos.

</details>

**9.** Un job de `smoke` se cuelga esperando a un contenedor que nunca arranca. Sin
`timeout-minutes`, ¿cuánto tarda en morir? Y cuando lo cancelas, ¿por qué el step de limpieza con
`if: always()` sí corre?

<details>
<summary>Respuesta</summary>

El timeout por defecto de un job es de **360 minutos**: seis horas de runner ocupado y de cola para
todo lo demás. Con `timeout-minutes` en unas tres veces la duración normal (medida antes con
`gh run list`), el cuelgue muere en minutos y un día lento no da rojos falsos. Al cancelar, GitHub
reevalúa los `if:`: un job cuyo `if:` sigue siendo verdadero, como `always()`, no se cancela; en
los steps que faltan, corren los que llevan `always()` o `cancelled()` y el resto se salta. Al step
en curso le manda `SIGINT`, a los 7,5 s `SIGTERM` y 2,5 s después mata el árbol de procesos. Por
eso la limpieza con `always()` debe ser corta: si se cuelga, solo la para el timeout, o un
`gh run cancel --force`.

</details>

**10.** En `nightly.yml`, ¿qué tiene de malo `const target = '${{ inputs.target }}';` dentro de
`script:` si `target` es un `choice`? ¿Cómo se escribe bien?

<details>
<summary>Respuesta</summary>

`script:` es código, y GitHub sustituye la expresión **antes** de que Node lo lea, igual que en un
`run:`. Hoy el `choice` limita los valores, pero el patrón se copia: con un `string`, un valor como
`'; await github.rest.repos.delete(context.repo); '` se vuelve código JavaScript que corre con el
token del job, y con `${{ github.event.* }}` el texto lo escribe cualquiera. Lo correcto es pasar
el dato por `env:` (`TARGET: ${{ inputs.target || 'all' }}`) y leer `process.env.TARGET` en el
script: la expresión se sustituye en un valor de YAML, no en código, y el valor por defecto cubre
los runs de `schedule`, donde `inputs` está vacío. Es lo que comprueba `nightly-script-env`.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Filtros de ramas y rutas | `paths` idénticos en `push` y `pull_request` de los cuatro workflows por carpeta, cada uno con su YAML en la lista (checks `ci-api-paths`, `ci-web-paths`, `smoke-paths`, `images-paths`) | 5 |
| 01 — Filtros de ramas y rutas | Enseña el PR que solo toca `README.md` despertando solo a `ci`, y explica qué tags y ramas disparó el laboratorio con la negación `!` | 5 |
| 02 — Concurrencia y timeouts | `concurrency` por workflow y ref, cancelando solo en PR, y `timeout-minutes` en los trece jobs (checks `ci-concurrency-group`, `ci-cancel-only-pr`, `jobs-timeout`) | 5 |
| 02 — Concurrencia y timeouts | Enseña los dos runs `cancelled` de los tres pushes, el job que venció su techo con la limpieza `always()` en `success`, y los cinco workflows en verde sobre `main` | 5 |
| 03 — Cron y dispatch con inputs | `dispatch-lab.yml` lanzado con `-f` y con `--json`; el texto hostil llega al log como texto y el valor fuera de `options` da HTTP 422 | 5 |
| 03 — Cron y dispatch con inputs | Explica el `success`/`skipped` de los dos `if:` con `inputs.flag` y `github.event.inputs.flag`; enseña un run con evento `schedule` y el cron desactivado y retirado del YAML | 5 |
| 04 — Encadenar workflows | `chain-lab.yml` en verde por `repository_dispatch` (check `repository-dispatch-received`), con el payload hostil leído por `env:` como texto | 5 |
| 04 — Encadenar workflows | `workflow_run` sigue solo tras un `dispatch-lab` verde (`skipped,success`) y `github-script` lee el run vigilado con el id por `env:` | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 07` con 16/16. Cada comprobación en rojo
resta la parte proporcional (12/16 de punto).

**Calidad manual de la capa 07 (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| Cada `timeout-minutes` está calibrado: unas tres veces la duración normal del job, no 360 ni 1 | 3 |
| `nightly.yml` tiene `concurrency` con un grupo fijo y `cancel-in-progress: false`: dos nightlies no se pisan, y uno lanzado a mano no mata al del cron | 3 |
| El cron no cae en el minuto 0, y un comentario dice por qué | 2 |
| Los filtros de `push` y `pull_request` son idénticos en cada workflow | 3 |
| Un comentario en cada workflow con `concurrency` explica por qué `main` no cancela | 2 |
| El resumen del run de `nightly.yml` lista los workflows que lanzó | 3 |
| Sin `TODO` en `.github/workflows/` y commits en Conventional Commits | 2 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log, también un PAT para lanzar workflows | Grave: Producto a 0 hasta rotarlo y retirarlo |
| `uses:` remota sin SHA | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}` o `${{ inputs.* }}` interpolado dentro de `run:` | Grave: −10 |
| `${{ inputs.* }}` o `${{ github.event.* }}` interpolado dentro de `script:` de `github-script` | Grave: −10 |
| Imagen sin tag o con `latest` | Grave: −10 |
| `cancel-in-progress: true` a secas en un workflow que corre en `push` a `main` | −5 |
| `actions: write` o `contents: write` en la raíz del workflow | −5 |
| Job sin `timeout-minutes` | −3 por cada uno |
| Commit vacío o push con el `GITHUB_TOKEN` para disparar otro workflow | −3 |
| `pip`, `npm` o Compose v1 en un workflow o en la documentación de tu repo | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 07 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
