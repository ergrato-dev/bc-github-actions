# Rúbrica de evaluación — Semana 09

> Workflows reutilizables. Se aprueba con un **mínimo del 70 % en cada evidencia**, no en el
> promedio.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de la capa 09 |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** Tras la capa 09, `ci-api.yml` tiene un solo job y `_python.yml` tiene tres. ¿Qué decide
cada archivo? Un PR que toca `api/`, ¿cuántos runs crea y qué nombres ves en la UI?

<details>
<summary>Respuesta</summary>

El **llamador** (`ci-api.yml`) decide *cuándo* y *con qué*: eventos, `paths`, `concurrency`,
permisos y los valores de los inputs. El **llamado** (`_python.yml`) decide *cómo*: runners,
steps, servicios, `timeout-minutes`. La llamada no crea un run aparte: los jobs del reutilizable
se incrustan en el run del llamador, que sigue siendo **uno**, el de `ci-api`. En la UI aparecen
con el `name:` del job que llama como prefijo: `API / Lint y formato (ruff)`,
`API / Tests unitarios`, `API / Tests de integración (PostgreSQL 17)`. Por eso un reutilizable
empaqueta jobs completos, con su runner y su PostgreSQL de servicio, cosa que una action (unos
steps dentro de un job ajeno) no puede hacer.

</details>

**2.** Añades `timeout-minutes: 15` al job `api` de `ci-api.yml` y actionlint lo rechaza. ¿Por qué?
¿Qué claves admite un job que llama y dónde va el timeout?

<details>
<summary>Respuesta</summary>

Un job con `uses:` no corre en ningún runner: es una llamada. Solo admite lo que decide *si*
corre (`if`, `needs`), *cuántas veces* (`strategy`), *con qué* (`with`, `secrets`), *con qué
techo* (`permissions`), además de `name`, `uses`, `concurrency` y `cache-mode`. Todo lo que
describe *cómo* corre un job (`runs-on`, `steps`, `env`, `defaults`, `services`, `container`,
`timeout-minutes`) pertenece a los jobs del reutilizable. El `timeout-minutes` va en cada job de
`_python.yml`; por eso `jobs-timeout` solo mira los jobs con `runs-on`.

</details>

**3.** `_node.yml` necesita la lista de versiones de Node de la matriz. ¿Qué tipo de input
declaras, cómo la pasa el llamador y por qué `node-versions: [24, 26]` falla?

<details>
<summary>Respuesta</summary>

`workflow_call` solo tiene tres tipos: `string`, `number` y `boolean`. No hay lista. La lista viaja
como un `string` con JSON dentro, `node-versions: "[24, 26]"`, y el reutilizable la convierte con
`${{ fromJSON(inputs.node-versions) }}` en la matriz. Sin comillas, `[24, 26]` es una secuencia
YAML, no un string, y actionlint la rechaza (`expected scalar node for string value but found
sequence node`). Los tipos sí se respetan dentro: `inputs.integration` es un booleano y
`if: ${{ inputs.integration }}` funciona sin compararlo con `'true'`, y `inputs.coverage-min` es
un número.

</details>

**4.** Para publicar las dos imágenes podrías llamar a `_image.yml` una vez con
`strategy.matrix.component: [api, web]`. ¿Qué digest verías en `needs.<job>.outputs.digest`? ¿Por
qué `images.yml` usa dos jobs?

<details>
<summary>Respuesta</summary>

Un job que llama con matriz tiene **un solo** output por nombre: el del último reutilizable que
terminó bien (si ese lo dejó vacío, el del anterior que tenga valor). Verías uno de los dos
digests, el que acabara último, sin saber cuál, y el otro se pierde. No hay forma de pedir "el
digest de la combinación `web`". Con dos jobs, `api` y `web`, cada uno tiene su
`needs.api.outputs.digest` y `needs.web.outputs.digest`, y `summary` los recibe con nombre. El
valor recorre cuatro saltos declarados: `$GITHUB_OUTPUT` del step, `jobs.build.outputs`,
`on.workflow_call.outputs.digest.value` y `needs.<job>.outputs` en el llamador.

</details>

**5.** `secrets: inherit` evitaría declarar `registry-password`. ¿Qué hace exactamente, qué dos
límites tiene y por qué en `tablero` está prohibido?

<details>
<summary>Respuesta</summary>

Pasa **todos** los secretos del llamador al reutilizable. Solo funciona dentro de la misma
organización o enterprise, y solo llega al llamado directo: si ese llama a otro reutilizable, el
segundo no los recibe salvo que el primero se los pase. Está prohibido porque entrega a código
que no ves secretos que no necesita, y la firma del reutilizable deja de decirte qué credencial
usa: ya no puedes revisarlo desde el llamador. Declarado, `registry-password` documenta el
contrato y deja que el llamador elija la credencial (hoy `secrets.GITHUB_TOKEN`, mañana otra
registry sin tocar `_image.yml`). zizmor lo marca con `secrets-inherit`, sin red, y la puerta de
`lint-workflows` lo bloquea.

</details>

**6.** Dentro de `_python.yml`, llamado desde `ci-api` en un PR, ¿cuánto valen
`github.workflow` y `github.event_name`? Y una variable del `env:` de raíz de `ci-api.yml`, ¿llega?

<details>
<summary>Respuesta</summary>

`github.workflow` vale `ci-api` y `github.event_name` vale `pull_request`: el reutilizable hereda
el contexto `github` completo del llamador (ref, sha, payload, token). No existe un evento
`workflow_call` visible desde dentro. El `env:` no cruza en ningún sentido: cada archivo tiene el
suyo. Lo que decide el llamador viaja por un input; lo que devuelve el reutilizable, por un
output; una configuración común no secreta, por `vars.*`. Por eso `_image.yml` recibe el input
`push` en lugar de mirar `github.event_name`: así no se ata a un evento concreto.

</details>

**7.** `_image.yml` declara en su raíz `packages: write`. Quitas ese permiso del job `api` de
`images.yml`. actionlint y zizmor pasan. ¿Qué ocurre al hacer push y por qué?

<details>
<summary>Respuesta</summary>

El run falla **sin crear ningún job**: la página del run explica que un job pide un permiso que no
se le concede. Hay un único `GITHUB_TOKEN` por run y sus permisos solo bajan: la raíz del llamador
fija el techo, el job que llama lo ajusta para esa llamada y el reutilizable solo puede mantener
o bajar lo que recibe. Si pide más, la llamada no valida. Ningún linter lo ve porque el cálculo
lo hace GitHub al crear el run (práctica 04, paso 3). Por eso la raíz de `images.yml` se queda en
`contents: read` y solo `api` y `web` conceden `packages: write`.

</details>

**8.** Copias en `_python.yml` la `concurrency` de `ci-api.yml`
(`${{ github.workflow }}-${{ github.ref }}` con `cancel-in-progress: true`). El run de `ci-api` se
cancela solo al empezar. ¿Por qué?

<details>
<summary>Respuesta</summary>

Las dos `concurrency` se evalúan con el mismo contexto `github`, el del llamador:
`github.workflow` vale `ci-api` en los dos archivos y el grupo resulta idéntico
(`ci-api-refs/pull/7/merge`). El llamador ya ocupa ese grupo; el reutilizable entra en él con
`cancel-in-progress: true` y cancela lo que hay en curso, que es su propio llamador. Es un
interbloqueo sin ningún push nuevo. La regla general: con `cancel-in-progress: true`, nunca el
mismo `group` en llamador y llamado. La de `tablero`, más simple: `concurrency` solo en los
llamadores, porque el reutilizable no sabe cuándo corre.

</details>

**9.** Un repo central quiere encadenar reutilizables y guardarlos en
`.github/workflows/python/`. ¿Qué límites de la plataforma choca? Y si cambias solo `_python.yml`
en un PR, ¿por qué `ci-api` puede no correr?

<details>
<summary>Respuesta</summary>

Los reutilizables tienen que estar **directamente** en `.github/workflows/`: las subcarpetas no
están soportadas. El anidamiento llega a 10 niveles (el llamador de nivel superior más nueve
reutilizables) y un archivo de nivel superior puede usar como mucho 50 reutilizables **únicos**,
anidados incluidos (llamar dos veces a `_image.yml` cuenta uno). Pasarse invalida la llamada. Lo
de `paths` es otra cosa: GitHub evalúa el filtro sobre los archivos que cambian y no sabe que
`ci-api.yml` usa `_python.yml`. Si el llamador no lista el reutilizable en `push` y en
`pull_request`, el cambio entra sin que ningún run lo pruebe, y el fallo aparece en el siguiente
PR que toque `api/`. Es lo que comprueba `paths-include-reusable`.

</details>

**10.** Compara `./.github/workflows/_python.yml`, `$/.github/workflows/_python.yml` y
`<tu-org>/actions-tablero/.github/workflows/_python.yml@<sha>`. ¿Por qué `tablero` usa `./` con
un `# zizmor: ignore[self-repository]`?

<details>
<summary>Respuesta</summary>

`./` resuelve el archivo en el **mismo commit** que el llamador: en un PR que cambia
`_python.yml` se prueba el cambio antes de fusionarlo. `$/` (julio de 2026, solo github.com)
apunta al mismo repo y commit sin depender del sistema de archivos del runner, y las políticas
que exigen referencias fijadas lo cuentan como fijado. `owner/repo/...@sha` apunta a otro repo y
el `@` es obligatorio: un SHA de 40 caracteres con el tag en comentario, porque una rama o un tag
se mueven (Semana 11). zizmor 1.31.1 pide `$/` con la auditoría `self-repository`, pero
actionlint 1.7.12 aún lo rechaza (issue rhysd/actionlint#711) y la puerta exige los dos. Por eso
se queda `./` y el hallazgo se ignora con el motivo escrito. Además, con `./` actionlint lee el
reutilizable y valida la llamada contra su contrato; con una referencia remota no puede.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Primer reutilizable | `_python.yml` solo con `workflow_call`, sus cuatro inputs tipados e `integration` opcional, y `ci-api.yml` reducido a una llamada (checks `reusables-only-call`, `python-inputs`, `python-integration-optional`, `ci-api-calls-python`) | 5 |
| 01 — Primer reutilizable | Enseña la llamada en act con los jobs `API/_python/...`, los dos errores de actionlint del contrato roto (input `bogus` y `package` olvidado) y los nombres `API / ...` del run en GitHub | 5 |
| 02 — Inputs tipados y matrices | Matriz de `_node.yml` desde `fromJSON(inputs.node-versions)`, output `artifact-name` y `dist-report` descargando lo que devuelve (checks `node-matrix-from-input`, `node-artifact-output`, `ci-web-calls-node`) | 5 |
| 02 — Inputs tipados y matrices | Explica el error de la lista sin comillas y enseña un run con otra lista de versiones sin tocar el reutilizable | 5 |
| 03 — Secretos y outputs | `_image.yml` con `registry-password` obligatorio y output `digest`; `images.yml` con dos llamadas, el secreto explícito, `packages: write` solo en `api` y `web` y el resumen con los dos digests (checks `image-secret`, `image-digest-output`, `images-calls-image`, `images-permissions`, `images-digests-summary`) | 5 |
| 03 — Secretos y outputs | Enseña el `secrets-inherit` de zizmor sobre el cambio de prueba, el PR que construye sin publicar y el run de `main` con los dos digests | 5 |
| 04 — Límites y depuración | `paths` con el reutilizable en los tres llamadores y la puerta de linters en verde (checks `paths-include-reusable`, `workflows-lint`, `callers-green-on-main`) | 5 |
| 04 — Límites y depuración | Enseña el PR que solo toca `_python.yml` despertando a `ci-api`, el run fallido por el permiso que no alcanza, el `cancelled` del interbloqueo y el `self-repository` de zizmor | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 09` con 18/18. Cada comprobación en rojo
resta la parte proporcional (12/18 de punto).

**Calidad manual de la capa 09 (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| Cada input y cada output tiene `description`: el reutilizable se entiende sin abrir sus jobs | 3 |
| Ningún reutilizable escribe a mano `api`, `web` ni el paquete `tablero` en sus jobs; las dos excepciones (prefijo `tablero-` y base desechable de PostgreSQL) llevan comentario | 3 |
| Ningún `${{ inputs.* }}` dentro de un `run:`: los inputs llegan al shell por `env:` | 2 |
| `concurrency` solo en los llamadores; ningún reutilizable declara la suya | 2 |
| Cada reutilizable declara en su raíz el techo de `permissions` que necesita, con un comentario | 2 |
| Los `# zizmor: ignore[self-repository]` dicen por qué y no hay ningún otro hallazgo silenciado | 2 |
| El job que llama tiene `name:` y los runs se ven con nombres legibles | 2 |
| Sin `TODO` en `.github/workflows/` y commits en Conventional Commits | 2 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log | Grave: Producto a 0 hasta rotarlo y retirarlo |
| `uses:` remota sin SHA | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}` o `${{ inputs.* }}` interpolado dentro de `run:` | Grave: −10 |
| Imagen sin tag o con `latest` | Grave: −10 |
| `secrets: inherit` en cualquier llamada | −5 |
| Hallazgo de zizmor silenciado sin motivo, o cualquier ignore distinto de `self-repository` | −3 por cada uno |
| `concurrency` declarada en un reutilizable | −3 |
| `packages: write` en la raíz de `images.yml` | −3 |
| Job con `runs-on` sin `timeout-minutes` | −3 por cada uno |
| `pip`, `npm` o Compose v1 en un workflow o en la documentación de tu repo | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 09 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
