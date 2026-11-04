# Rúbrica de evaluación — Semana 10

> Actions propias: composite, JavaScript y Docker. Se aprueba con un **mínimo del 70 % en cada
> evidencia**, no en el promedio.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de la capa 10 |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** `tablero` tiene tres actions y cada una usa un `runs.using` distinto: `composite`,
`node24` y `docker`. ¿Qué ejecuta el runner en cada caso y por qué no valdría un solo tipo para
las tres?

<details>
<summary>Respuesta</summary>

Una **composite** es una lista de steps que el runner despliega dentro del job que la llama:
mismos steps de siempre (`run:` y `uses:`), sin proceso propio. Sirve para `setup-tablero`, que
solo encadena `setup-uv` o `action-setup` + `setup-node` y un `uv sync`/`pnpm install`. Una
**JavaScript** es un archivo que el runner ejecuta con su propio Node (`main`, y opcionalmente
`pre` y `post`): arranca en milisegundos, corre en Linux, Windows y macOS y tiene lógica de
verdad con `@actions/core`. Por eso `coverage-report` lee un JSON, calcula y publica el resumen.
Una **Docker** construye (o descarga) una imagen y ejecuta su `ENTRYPOINT` con el workspace
montado: trae su propio sistema y sus herramientas a versión fijada, a cambio de correr solo en
runners Linux y de pagar la construcción en cada job. `sql-lint` necesita sqlfluff 4.5.0 con su
Python, que no hay que instalar en el runner. Composite no tiene lógica propia, JavaScript no
trae herramientas ajenas a Node y Docker es la más cara: cada tipo cubre un hueco distinto.

</details>

**2.** `setup-tablero` (una action) y `_python.yml` (un workflow reutilizable de la Semana 09)
eliminan repetición. ¿Qué empaqueta cada uno? ¿Por qué `setup-tablero` no puede declarar
`runs-on` ni `services`, y qué exige antes de `uses: ./.github/actions/setup-tablero`?

<details>
<summary>Respuesta</summary>

Un reutilizable empaqueta **jobs completos**: cada uno con su runner, sus servicios, su matriz y
su `timeout-minutes`. Una action empaqueta **steps dentro de un job ajeno**: corre en el runner,
el workspace y el `env` del job que la llama, así que no tiene dónde poner `runs-on`, `services`
ni `strategy`. Por eso se combinan: los tres jobs de `_python.yml` siguen en el reutilizable y
cada uno llama a `setup-tablero` para preparar su entorno. Una action local se lee del disco del
workspace, no de la API: sin un `actions/checkout` antes, `./.github/actions/setup-tablero` no
existe y el step falla con `Can't find 'action.yml'`.

</details>

**3.** En un workflow, un step `run:` sin `shell:` usa bash. En `setup-tablero`, actionlint no
dice nada, pero el check `setup-shell` exige `shell: bash` en cada step `run:`. ¿Por qué la
composite no hereda el shell?

<details>
<summary>Respuesta</summary>

En una composite, `shell` es **obligatorio** en todo step con `run:`: la sintaxis de metadatos
lo marca como requerido, y el runner rechaza la action al cargarla si falta. La razón es que una
action no puede depender del contexto del llamador: los `defaults.run.shell` del workflow no
cruzan la frontera, y la misma action puede llamarse desde un job de Windows donde el shell por
defecto es `pwsh`. Declararlo hace que el step se comporte igual en cualquier job. actionlint
1.7.12 no valida `action.yml`, así que el error solo aparece al ejecutar la action, en act o en
GitHub: lo detecta antes el check.

</details>

**4.** Un step de `setup-tablero` hace `run: cd ${{ inputs.working-directory }} && uv sync
--locked`. Funciona. ¿Qué riesgo tiene y cómo lo escribe `tablero`?

<details>
<summary>Respuesta</summary>

`${{ }}` se sustituye como **texto** en el script antes de que bash lo vea. El valor del input
lo decide el llamador, y un llamador puede pasarle algo que venga de un evento (un nombre de
rama, un título de PR). Con `api; curl ... | sh` como valor, bash ejecuta el segundo comando con
el token del job. La action no sabe de dónde vienen sus inputs, así que trata todos como no
confiables: el valor llega por `env:` (`WORKING_DIRECTORY: ${{ inputs.working-directory }}`) y
el script lee `"$WORKING_DIRECTORY"`, que bash trata como dato. En `setup-tablero` ni siquiera
hace falta: el step usa `working-directory: ${{ inputs.working-directory }}`, que es una clave
del step, no texto de shell. zizmor marca el patrón con `template-injection` también dentro de
`action.yml`.

</details>

**5.** `coverage-report` tiene su código en `src/` y su `.gitignore` excluye `node_modules/`.
¿Por qué `dist/index.cjs` y `dist/post.cjs` **sí** se comitean, y qué protege
`test-actions.yml`?

<details>
<summary>Respuesta</summary>

El runner no instala dependencias de una action: ejecuta con Node el archivo de `main` tal cual
está en el repo. Si `src/index.js` hace `import ... from "@actions/core"` y no hay
`node_modules/`, el step muere con `Cannot find package`. esbuild resuelve ese problema
metiendo `src/` y `@actions/core` en un único archivo por punto de entrada (unos 800 kB), y ese
archivo es lo que se comitea. Comitear `node_modules/` también funcionaría, pero son miles de
archivos y cualquier revisión se ahoga en ellos. El precio de `dist/` es que puede quedarse
**desfasado**: cambias `src/` y olvidas `pnpm build`, y el CI ejecuta el código viejo sin que
nadie lo vea. `test-actions.yml` reconstruye y hace `git diff --exit-code -- dist`: si el bundle
no coincide con `src/`, falla con un `::error::` que dice qué hacer. El formato es CommonJS con
extensión `.cjs` porque un bundle ESM rompe con `Dynamic require of "net" is not supported`
(dependencias CommonJS dentro de `@actions/core`).

</details>

**6.** El `main` de `coverage-report` llama a `setFailed` porque la cobertura baja del mínimo.
¿Corre el `post`? ¿Qué cambia si añades `post-if: success()`?

<details>
<summary>Respuesta</summary>

Sí corre. `post-if` vale por defecto `always()`: el `post` de una action se ejecuta al final del
job, en orden inverso al de los steps, aunque el `main` o cualquier step posterior haya fallado.
Es lo que necesita un `post` de limpieza (cerrar una sesión, borrar credenciales temporales,
subir un log): justo cuando algo falla es cuando más falta hace. Con `post-if: success()`, el
`post` se salta en cuanto el job va en rojo. El de `coverage-report` solo informa de cuánto
tardó, así que el valor por defecto le basta. En una action Docker, los equivalentes son
`pre-entrypoint` y `post-entrypoint`, y `pre-if` existe con la misma idea para `pre`.

</details>

**7.** El `post` de `coverage-report` necesita la hora a la que empezó el `main`. ¿Por qué no
sirven `$GITHUB_OUTPUT` ni `$GITHUB_ENV`, y cómo viaja el valor con `saveState`?

<details>
<summary>Respuesta</summary>

`$GITHUB_OUTPUT` crea outputs del **step** para los steps siguientes del workflow, y
`$GITHUB_ENV` crea variables para **todos** los steps siguientes del job: los dos sacan el dato
de la action y lo dejan a la vista de código ajeno. `$GITHUB_STATE` es privado de la action:
`core.saveState("started", ...)` escribe en ese archivo con un delimitador
(`started<<ghadelimiter_...`), y el runner se lo entrega solo a las fases `pre`/`main`/`post` de
la **misma** action, como la variable de entorno `STATE_started`, que `core.getState("started")`
lee. Ningún otro step ve ese estado. Es el sustituto vigente de `::save-state`, deshabilitado por
inyección: cualquier texto impreso en el log podía escribir estado.

</details>

**8.** En el `entrypoint.sh` de `sql-lint`, `echo "$INPUT_PATH"` funciona pero
`echo "$INPUT_EXCLUDE-RULES"` imprime `-RULES`. ¿Qué pasa y cómo se lee ese input?

<details>
<summary>Respuesta</summary>

El runner entrega cada input como la variable `INPUT_<NOMBRE EN MAYÚSCULAS>` y **no** cambia el
guion por guion bajo: `exclude-rules` llega como `INPUT_EXCLUDE-RULES`. Ese nombre no es un
identificador válido de bash, así que `$INPUT_EXCLUDE` se expande (vacío) y `-RULES` queda como
texto literal. La variable existe en el entorno del proceso; solo hay que leerla sin la
sintaxis `$`: `printenv 'INPUT_EXCLUDE-RULES'`. `core.getInput("exclude-rules")` hace
exactamente eso por dentro en una action JavaScript. La alternativa de declarar `args:` en
`runs` pasa el valor como argumento, pero ata el orden y lo expone en la línea de comandos.

</details>

**9.** Una plantilla antigua declara `using: node20` y funciona. ¿Por qué `tablero` exige
`node24`? Y en `coverage-report`, ¿qué Node ejecuta `dist/index.cjs`: el de `setup-node`?

<details>
<summary>Respuesta</summary>

`using` elige uno de los Node que trae el **propio runner** en sus `externals`, no el que
instala `setup-node`, que solo existe para los steps `run:`. `node16` ya está retirado y
`node20` está deprecado: el runner v2.338.2 aún lo trae, pero no es vigente y una action con
`node20` deja de arrancar el día que lo quiten, sin que cambie ni una línea de tu repo. Las
plantillas oficiales `actions/javascript-action` y `actions/typescript-action` ya usan `node24`.
Por eso el `--target=node24` de esbuild y el `using: node24` van juntos: el bundle se genera
para el mismo Node que lo ejecuta, independiente del Node 26 que `setup-tablero` instala para
la web.

</details>

**10.** `sql-lint` tarda unos segundos en construir su imagen cada vez que corre el job `sql`.
¿Por qué no se reutiliza la imagen del run anterior? ¿Qué alternativa hay y qué cuesta?

<details>
<summary>Respuesta</summary>

Con `image: Dockerfile`, el runner hace `docker build` al empezar el job, en una máquina recién
creada que no guarda nada del run anterior: no hay caché de capas entre runs. Se paga la
descarga de `python:3.15.2-slim-trixie` y el `uv tool install sqlfluff==4.5.0` en **cada** job
que usa la action. La alternativa es publicar la imagen una vez (por ejemplo en GHCR, como en la
Semana 06) y declarar `image: docker://ghcr.io/<tu-org>/sql-lint@sha256:...`: el runner solo la
descarga. El coste es mantener esa imagen: construirla en otro workflow, versionarla y fijarla
por digest cada vez que cambia el Dockerfile. Para una action pequeña dentro de su propio repo,
construir en cada job es más simple y siempre coincide con el commit. En cualquier caso, una
action Docker solo corre en runners Linux.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Primera action composite | `setup-tablero` composite con `stack` y `working-directory` obligatorios, `node-version` por defecto, `shell` en cada `run:` y el output `tool-version` (checks `action-types`, `setup-inputs`, `setup-shell`, `setup-output`) | 5 |
| 01 — Primera action composite | Los seis jobs de `_python.yml` y `_node.yml` usan `setup-tablero` (check `reusables-use-setup`) y enseña los dos avisos de actionlint del contrato roto (`missing input "stack"` e `input "stak" is not defined`) | 5 |
| 02 — Una action JavaScript | `coverage-report` con `node24`, `dist/index.cjs` y `dist/post.cjs`, `@actions/core` y pnpm fijados, estado entre `main` y `post`, tests en verde y `dist/` comiteado sin `node_modules` (checks `coverage-main-post`, `coverage-pnpm`, `coverage-state`, `coverage-dist-committed`, `coverage-tests`) | 5 |
| 02 — Una action JavaScript | Enseña el resumen con la tabla de cobertura, el `::error::` con el mínimo subido a 80 y el log del `post` con los milisegundos | 5 |
| 03 — Una action Docker | `sql-lint` desde su Dockerfile con base de tag completo y sqlfluff fijado, `exclude-rules` leído con `printenv` y output `files` (checks `sql-lint-docker`, `sql-lint-inputs`) | 5 |
| 03 — Una action Docker | Enseña las anotaciones `LT01` sobre `001_tasks.sql` sin `exclude-rules`, el verde con `exclude-rules: LT01` y explica por qué `$INPUT_EXCLUDE-RULES` no se lee | 5 |
| 04 — Probar y mantener actions | Las actions usadas en `ci-web.yml` y `ci.yml`, `test-actions.yml` con la comprobación de `dist/`, linters y SHA en verde y los tres workflows en `success` sobre `main` (checks `workflows-use-actions`, `dist-freshness`, `workflows-lint`, `actions-pinned`, `test-actions-green-on-main`) | 5 |
| 04 — Probar y mantener actions | Enseña el rojo de `test-actions` con un `dist/` desfasado y su arreglo, y las tres actions ejecutadas en act | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 10` con 17/17. Cada comprobación en rojo
resta la parte proporcional (12/17 de punto).

**Calidad manual de la capa 10 (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| Cada `action.yml` tiene `name`, `description` y `description` en cada input y output: se entiende sin abrir el código | 3 |
| Ningún `${{ inputs.* }}` dentro de un `run:` de `setup-tablero`: los inputs llegan por `env:` o por claves del step | 3 |
| `setup-tablero` rechaza un `stack` desconocido con un `::error::` claro antes de instalar nada | 2 |
| La lógica de `coverage-report` vive en `src/evaluate.js`, pura y probada con `node:test`; `index.js` y `post.js` solo hablan con `@actions/core` | 3 |
| El Dockerfile de `sql-lint` fija base, uv y sqlfluff, y `entrypoint.sh` lleva `set -euo pipefail` y bit de ejecución | 2 |
| `exclude-rules: LT01` lleva un comentario que dice por qué se excluye esa regla | 1 |
| `paths` de `ci-api`, `ci-web` y `test-actions` incluyen las actions de las que dependen | 2 |
| Sin `TODO` en `.github/` y commits en Conventional Commits, con `src/` y `dist/` en el mismo commit | 2 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log | Grave: Producto a 0 hasta rotarlo y retirarlo |
| `uses:` remota sin SHA, en un workflow o en un `action.yml` | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}` o `${{ inputs.* }}` interpolado dentro de `run:`, en un workflow o en una composite | Grave: −10 |
| Imagen sin tag o con `latest`, incluida la base del Dockerfile | Grave: −10 |
| `node_modules/` comiteado | −5 |
| `dist/` desfasado respecto a `src/` en `main` | −5 |
| Runtime `node20` o anterior en una action JavaScript | −5 |
| `::set-output` o `::save-state` en lugar de `$GITHUB_OUTPUT` / `$GITHUB_STATE` | −5 |
| Step `run:` sin `shell:` en una composite | −3 por cada uno |
| sqlfluff o cualquier herramienta del Dockerfile sin versión fijada | −3 |
| Hallazgo de zizmor silenciado sin motivo, o cualquier ignore distinto de `self-repository` | −3 por cada uno |
| Job con `runs-on` sin `timeout-minutes` | −3 por cada uno |
| `pip`, `npm` o Compose v1 en un workflow, una action o la documentación de tu repo | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 10 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
