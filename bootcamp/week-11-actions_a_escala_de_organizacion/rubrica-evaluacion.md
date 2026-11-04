# Rúbrica de evaluación — Semana 11

> Actions a escala de organización. Se aprueba con un **mínimo del 70 % en cada evidencia**, no
> en el promedio. Esta semana cierra la Fase 3 e incluye su minisimulacro.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de la capa 11 |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** La organización crea `tablero-admin`, otro servicio Python. Tiene tres caminos para
reutilizar el CI de `tablero`: copiar `.github/actions/` y los reutilizables, llamarlos desde
`<tu-org>/tablero/.github/actions/...@<sha>`, o sacarlos a `<tu-org>/actions-tablero`. ¿Qué
falla en los dos primeros y qué se queda en cada repo de producto con el tercero?

<details>
<summary>Respuesta</summary>

**Copiar** crea un fork silencioso: a la semana hay dos `setup-tablero` y un arreglo llega a uno
y no al otro. **Llamar a `tablero`** funciona, pero cada versión del CI es un commit de la
aplicación: no puedes publicar una corrección del CI sin publicar lo que haya en `main` de la API
y la web, ni etiquetar una cosa sin la otra. El **repo central** tiene su propio ciclo de vida,
sus releases y su CI, y los productos lo consumen por SHA como consumen `actions/checkout`.

En el central va lo que no depende de un producto: las actions, los reutilizables y el CI que
los prueba. En cada repo de producto se queda lo que decide **cuándo** y **con qué**: los
disparadores, los filtros `paths`, la concurrencia y los valores de los inputs. Por eso un
llamador de `tablero` es corto. Teoría 01.

</details>

**2.** Mueves `_python.yml` y `setup-tablero` a `actions-tablero` y dejas
`uses: ./setup-tablero` en el reutilizable. Llamado desde `tablero`, el job no encuentra el
`action.yml`. ¿Por qué? ¿A qué repo y a qué commit apunta `$/setup-tablero`, y qué tres
consecuencias tiene para el repo central?

<details>
<summary>Respuesta</summary>

`./` no nombra un repo: es una ruta dentro del **workspace del job**, y en un reutilizable el
contexto `github` es el del llamador, así que `actions/checkout` sin `repository:` descarga
`tablero`. El runner busca `$GITHUB_WORKSPACE/setup-tablero` dentro de `tablero`, donde no existe.
En la capa 10 los dos repos coincidían y por eso funcionaba.

`$/` apunta al repo del **archivo** que contiene el `uses:` (`actions-tablero`) en el **commit
que está corriendo** (el SHA que fijó `tablero`). Consecuencias: no depende del checkout; la
action va con la versión fijada del reutilizable, sin un segundo commit que actualice
referencias internas; y cuenta como fijada para la política de SHA obligatorio. Si quieres
saber qué versión del reutilizable corre, `job.workflow_sha` te da el commit del central;
`github.workflow_sha` es el de `tablero`. Teoría 02.

</details>

**3.** actionlint 1.7.12 rechaza cada `uses: $/...` con
`specifying action "$/setup-tablero" in invalid format`. Un compañero propone desactivar la
regla `action` en la configuración. ¿Qué propones tú y cómo compruebas que funciona?

<details>
<summary>Respuesta</summary>

Desactivar la regla `action` deja de detectar referencias mal fijadas de verdad, que es lo que
más importa en un repo que publica actions. Se ignora **solo ese mensaje** en
`.github/actionlint.yaml`, bajo `paths: .github/workflows/**/*.yml: ignore:`, con una regex que
casa únicamente con `specifying action "\$/[^"]+" in invalid format`. Un `uses:` sin `@` o con
otro formato sigue siendo error. Lleva un comentario con el issue rhysd/actionlint#711, y cuando
actionlint admita `$/` la excepción se borra y nada más cambia.

Para comprobarlo, `actionlint -verbose` imprime por archivo cuántos errores ha filtrado la
configuración: en `_python.yml`, tres, uno por job. Si `$/` sigue dando error y esa línea no
aparece, actionlint no está leyendo el archivo. Teoría 02.

</details>

**4.** Clasifica estos cambios en `actions-tablero` según SemVer y di la regla que usas para
dudar: (a) `setup-tablero` cachea con la clave correcta; (b) input nuevo `python-version` con
default; (c) el `minimum` por defecto de `coverage-report` pasa de 60 a 80; (d) `_image.yml`
pasa a necesitar un permiso más del llamador.

<details>
<summary>Respuesta</summary>

(a) parche, `v1.0.1`: arreglo sin tocar la interfaz. (b) menor, `v1.1.0`: algo nuevo y
opcional. (c) mayor: el default cambia el resultado, y un consumidor con cobertura del 70 % pasa
a rojo. (d) mayor: el llamador tiene que conceder el permiso o la llamada no valida.

La interfaz pública de una action es su `action.yml` (inputs, outputs, defaults y lo que hace
con ellos); la de un reutilizable, su `on.workflow_call` y los permisos que necesita. La regla:
si un consumidor que **no toca nada** puede pasar de verde a rojo al subir, es mayor. Las notas
de una versión menor o de parche no tienen sección de "qué tienes que cambiar": si la tienen, la
versión está mal elegida. Teoría 03.

</details>

**5.** `tablero` fija `actions-tablero/...@<sha> # v1.0.0`. ¿Qué SHA es ese exactamente si el
tag es anotado? ¿Cómo compruebas que el comentario no miente, y qué dos explicaciones hay si no
coincide?

<details>
<summary>Respuesta</summary>

Un tag anotado apunta a un objeto `tag` (autor, fecha, mensaje), que a su vez apunta al commit.
El runner ejecuta un **commit**, así que se fija el SHA del commit, no el del objeto tag.
`scripts/resolve-sha.sh` y `gh api repos/<tu-org>/actions-tablero/commits/v1.0.0 --jq .sha`
devuelven siempre el commit, sea el tag ligero o anotado; en `git ls-remote --tags` es la línea
`^{}`.

El comentario `# v1.0.0` es texto: nadie impide un SHA y un tag que no se corresponden. Si
`commits/v1.0.0` no devuelve tu SHA, o lo escribiste mal (o fijaste el del objeto tag), o el tag
se movió después de que lo resolvieras. La segunda es la grave, y la cierra la release
inmutable. Teorías 03 y 04.

</details>

**6.** Muchas actions públicas ofrecen un tag `v1` que su autor mueve en cada release. ¿Por qué
`tablero` no lo usa y por qué `actions-tablero` no publica `v1` como release?

<details>
<summary>Respuesta</summary>

Quien escribe `@v1` recibe parches y menores sin tocar nada: lo que ejecuta su CI cambia sin un
commit en su repo y sin revisión, y un tag movido por error o por una cuenta comprometida llega
a todos a la vez. En la organización se quiere lo contrario: subir es un PR que cambia el SHA y
ejecuta el CI con la versión nueva antes de fusionar.

Además, una release inmutable bloquea su tag en un commit: un `v1` que se mueve no puede ser el
tag de una release inmutable. Si algún día se ofrece a terceros, será un tag aparte, sin release
y sin protección. Teorías 03 y 04.

</details>

**7.** Activas la inmutabilidad en `actions-tablero` y publicas `v1.0.0`. ¿Qué queda bloqueado
y qué no? ¿Por qué se publica en dos tiempos? Un atacante con permiso de escritura en el central,
¿qué puede hacer todavía y qué lo frena?

<details>
<summary>Respuesta</summary>

Al **publicar**: el tag queda fijo en su commit (no se mueve ni se borra mientras exista la
release), los assets no se modifican ni se borran, y GitHub firma una attestation con el tag, el
commit y el digest de cada asset, que comprueba `gh release verify`. El título y las notas siguen
editables. Si borras la release, ese nombre de tag no se puede reutilizar. No es retroactiva: lo
publicado antes de activarla sigue siendo mutable.

Dos tiempos (borrador, revisión, publicación) porque las protecciones solo valen para lo
publicado: un borrador se puede cambiar, y una vez publicada ya no admite el asset que olvidaste.

El atacante no puede mover `v1.0.0` ni recrearlo. Puede empujar a `main` (nadie lo ejecuta: los
consumidores fijan el SHA de `v1.0.0`) o publicar `v1.0.1`, que solo llega a quien suba. Eso lo
frena la revisión del PR que cambia el SHA y el `compare/v1.0.0...v1.0.1`, no la inmutabilidad.
Teoría 04.

</details>

**8.** Publicas la plantilla `ci-python` en `<tu-org>/.github`. ¿Dónde va exactamente, qué hace
GitHub con `$default-branch` y por qué la plantilla es solo un llamador del `_python.yml`
central fijado por SHA, sin steps propios?

<details>
<summary>Respuesta</summary>

En `workflow-templates/` en la **raíz** del repo `.github` de la org (no dentro de su
`.github/`), con el par `ci-python.yml` y `ci-python.properties.json`, que lleva `name` y
`description` obligatorias. En el plan Free el repo `.github` tiene que ser público.
`$default-branch` es sustitución de texto al crear el workflow: el repo recibe ya `main` (o su
rama por defecto); por eso no va dentro de `${{ }}`.

Una plantilla se **copia una vez**: si mañana la cambias, los repos que ya la usaron no se
enteran. Si contuviera todos los steps, cada repo se quedaría con una copia que nadie actualiza.
Como llamador fino, lo que cambia con el tiempo vive en `actions-tablero` y los repos creados
desde la plantilla lo reciben subiendo el SHA, como `tablero`. Plantilla para descubrir y
arrancar; reutilizable para ejecutar y mantener. Teoría 05.

</details>

**9.** Para la política de actions de la org dudas entre `local_only` "para ir a lo seguro",
`selected` con `verified_allowed: true` y `selected` con patrones. ¿Qué elige `tablero` y por
qué? ¿Qué cuidado hay que tener al aplicarlo con `gh api -X PUT`?

<details>
<summary>Respuesta</summary>

`local_only` bloquea también las actions de GitHub: `tablero` se queda sin `actions/checkout`.
`verified_allowed: true` abre todo el Marketplace de creadores verificados: "verificado" dice
quién es el creador, no qué hace cada versión de cada action suya. Lo que encaja es `selected`
con `github_owned_allowed: true`, `verified_allowed: false` y una lista de patrones con las seis
actions de terceros que usa `tablero` (`astral-sh/setup-uv@*`, `pnpm/action-setup@*` y las cuatro
de `docker`). Las actions de la propia org, `./` y `$/` se permiten con `selected`. Con
`sha_pinning_required: true` encima, toda action tiene que ir por SHA completo.

Cuidados: el `PUT` de `selected-actions` **sustituye** la lista entera, así que mandas siempre
todos los patrones; `selected` y la lista se activan a la vez, o el siguiente push falla en
`setup-uv`; y antes de exigir SHA compruebas que ningún repo de la org tiene un `uses:` sin
fijar. `-F` para los booleanos, `-f` para los textos. Teoría 06.

</details>

**10.** Las políticas impiden ejecutar lo que no está en la lista. ¿Qué no impiden, y qué añade
la regla "Require workflows to pass before merging"? ¿Qué condiciones pone al workflow exigido y
por qué no la practicas?

<details>
<summary>Respuesta</summary>

Las políticas no obligan a ejecutar nada: un repo puede borrar su CI y fusionar lo que quiera,
porque un repo sin workflows no incumple ninguna. La regla de un ruleset de **organización** (o
empresa) hace que cada PR hacia las ramas elegidas ejecute un workflow que vive en otro repo de
la org, y que no se pueda fusionar si no pasa. El repo protegido no puede quitarlo ni cambiar su
SHA.

Condiciones: `on:` incluye `pull_request`, `pull_request_target` o `merge_group`; sus filtros se
ignoran; no corre en eventos disparados por el `GITHUB_TOKEN`; no puede usar las actions de
CodeQL salvo `upload-sarif`; y bloquea los pushes directos a esas ramas. Los rulesets de
organización exigen el plan Team o Enterprise, y la org del bootcamp es Free. La antigua función
"required workflows" de Actions está retirada: su sustituto es esta regla. Los checks requeridos
de un ruleset de repo sí están en Free y llegan en la Semana 18. Teoría 07.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Repo central y primera release | `actions-tablero` público con las tres actions en la raíz; `_python.yml` y `_node.yml` con `$/setup-tablero` en sus seis jobs; `ci.yml` en verde sobre el commit de la release; `v1.0.0` publicada e inmutable; SHA fijado igual al commit del tag (checks `central-reusables-self-repository`, `central-ci-green-on-release`, `central-release-immutable`, `pinned-sha-matches-tag`) | 5 |
| 01 — Repo central y primera release | Enseña `actionlint -verbose` con los errores filtrados de `$/`, la salida de `gh release verify v1.0.0` con el SHA del commit en verde, y explica por qué `--target` lleva el SHA y no `main` | 5 |
| 02 — Consumir el repo central | Llamadores de los tres reutilizables y actions en `coverage` y `sql` por SHA; sin `.github/actions/`, `_*.yml` ni `test-actions.yml`; una sola pareja SHA + tag (checks `tablero-calls-central-reusables`, `tablero-uses-central-actions`, `no-local-copies`, `single-central-version`) | 5 |
| 02 — Consumir el repo central | Linters y pinning en verde, y `ci`, `ci-api` y `ci-web` en `success` sobre `main` (checks `workflows-lint`, `actions-pinned`, `green-on-main`); cambio de llamadores y borrado de copias en el mismo PR, con los `paths` limpios de rutas que ya no existen | 5 |
| 03 — Políticas de la organización | `selected` con SHA obligatorio, actions de GitHub más patrones sin creadores verificados, y token de solo lectura que no aprueba PR (checks `org-allowed-actions`, `org-selected-actions`, `org-default-token-read`) | 5 |
| 03 — Políticas de la organización | Guardó la foto de las políticas previas en `~/code/org-policy-backup/`, enseña el run de la rama `test/org-policy` cortado por el `@v7` sin SHA y la rama ya borrada | 5 |
| 04 — Workflow templates | `<tu-org>/.github` público, plantilla con `$default-branch` que llama al `_python.yml` central por SHA y `.properties.json` con `name` y `description` propios (checks `dot-github-public`, `template-calls-central`, `template-metadata`) | 5 |
| 04 — Workflow templates | La copia con `$default-branch` sustituido pasa actionlint y zizmor, la plantilla se ve en Actions → New workflow de un repo de la org y `template_lag` dice que está al día | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 11` con 17/17. Cada comprobación en rojo
resta la parte proporcional (12/17 de punto).

**Calidad manual de la capa 11 (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| El `README.md` de `actions-tablero` tiene el catálogo completo (cada action y cada reutilizable con su línea `uses:` lista para copiar) y una política de versiones que dice qué cambio sube el major | 4 |
| Las notas de la release `v1.0.0` dicen qué contiene y de qué semana viene cada pieza | 2 |
| `actionlint.yaml` ignora solo el mensaje de `$/`, con un comentario que enlaza el issue de actionlint; ningún otro error queda silenciado | 3 |
| La lista de patrones de la org es la mínima: las actions de terceros que de verdad se usan, por repo (`astral-sh/setup-uv@*`), no por propietario entero salvo justificación | 3 |
| La plantilla dice al que la adopta qué inputs tiene que cambiar, y su `description` cita la versión del repo central que usa | 2 |
| Commits de los tres repos en Conventional Commits; en `actions-tablero`, uno por pieza movida | 2 |
| Sin `TODO` en ninguno de los tres repos | 2 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log | Grave: Producto a 0 hasta rotarlo y retirarlo |
| `uses:` remota sin SHA, incluido un llamador al repo central por `@v1.0.0`, `@v1` o `@main` | Grave: −10 |
| Workflow sin `permissions:` o con `write-all`, en cualquiera de los tres repos | Grave: −10 |
| `${{ github.event.* }}` o `${{ inputs.* }}` interpolado dentro de `run:` | Grave: −10 |
| Imagen sin tag o con `latest`, incluida la base del Dockerfile de `sql-lint` | Grave: −10 |
| `allowed_actions: all`, `verified_allowed: true` o un patrón `*` / `*/*` en la org | −5 |
| Release del central publicada sin inmutabilidad, o un tag publicado movido "para arreglarlo" | −5 |
| `uses: ./` en un reutilizable del repo central | −5 |
| Regla `action` de actionlint desactivada, o cualquier ignore que no sea el mensaje de `$/` | −3 |
| Dos versiones del central conviviendo en `tablero` | −3 |
| Plantilla con `branches: [main]` en lugar de `$default-branch`, o con los steps del CI copiados | −3 |
| Job con `runs-on` sin `timeout-minutes` | −3 por cada uno |
| `pip`, `npm` o Compose v1 en un workflow, una action o la documentación de tus repos | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

## 🏁 Minisimulacro de cierre de la Fase 3

Cierra las semanas 09-11 en las condiciones del examen GH-200: **60 minutos cronometrados**, sin
abrir la teoría ni buscar en la web. Cubre los dominios D1 (escribir y mantener workflows), D3
(escribir y mantener actions) y D4 (gestionar Actions en la organización). Pon el reloj antes de
leer la primera pregunta.

| Parte | Qué es | Tiempo | Puntos |
|---|---|:--:|:--:|
| A | 12 preguntas tipo test, una sola respuesta correcta | 35 min | 12 |
| B | Una tarea sobre tu repo central y `tablero` | 25 min | 8 |
| **Total** | | **60 min** | **20** |

**Aprobado: 14 puntos (70 %).** No suma a los pesos de la semana: es tu termómetro de la fase. Si
no llegas, la explicación de cada fallo te dice qué semana repasar antes de la Fase 4.

### Parte A — Preguntas tipo test (35 minutos)

Marca una opción por pregunta y apunta tus respuestas; abre las soluciones solo al final.

**A1.** Quieres que `ci-api.yml` use `_python.yml` del repo central. ¿Dónde va el `uses:`?

- A) En un step, después de `actions/checkout`
- B) A nivel de job, y ese job no lleva `runs-on`, `timeout-minutes` ni `steps`
- C) A nivel de job, con `runs-on: ubuntu-24.04` para elegir el runner
- D) En la raíz del workflow, junto a `on:`

<details>
<summary>Solución</summary>

**B.** Un reutilizable se llama desde el `uses:` de un job; un step espera una action y GitHub
no expande un workflow desde ahí. `runs-on`, `timeout-minutes` y `env` no se admiten en el job
que llama: van en los jobs del reutilizable. Semana 09, teoría 02.

</details>

**A2.** `_image.yml` necesita la credencial de GHCR. ¿Cómo la recibe?

- A) `secrets: inherit` en el job que llama
- B) Como input: `with: token: ${{ secrets.GITHUB_TOKEN }}`
- C) Declarada en `on.workflow_call.secrets` y pasada una a una desde el llamador
- D) Por el `env:` del workflow llamador

<details>
<summary>Solución</summary>

**C.** `inherit` pone todos los secretos del llamador al alcance del reutilizable y zizmor lo
marca; un input no se trata como secreto; el `env` del llamador no cruza al reutilizable. Semana
09, teoría 04.

</details>

**A3.** El llamador concede `contents: read` al job que llama, y un job de `_image.yml` declara
`packages: write`. ¿Qué pasa?

- A) El job del reutilizable recibe `packages: write`: manda el reutilizable
- B) La llamada no valida y el run no arranca: el reutilizable no puede subir lo que el llamador no concede
- C) El job corre con `contents: read` y falla al publicar
- D) GitHub concede el permiso y avisa en el resumen

<details>
<summary>Solución</summary>

**B.** Los permisos del reutilizable solo pueden bajar desde los del job que llama. El arreglo es
conceder `packages: write` (y repetir `contents: read`) en el job llamador. Semana 09, teoría 05.

</details>

**A4.** Un step `run:` de una action composite no declara `shell:`. ¿Qué pasa?

- A) Usa bash, como en un workflow
- B) Hereda el `defaults.run.shell` del workflow que la llama
- C) El runner rechaza la action al cargarla: en una composite `shell` es obligatorio en cada `run:`
- D) actionlint lo detecta y el run no empieza

<details>
<summary>Solución</summary>

**C.** La composite no depende del contexto del llamador, que podría ser un job de Windows. Los
`defaults` del workflow no cruzan la frontera. actionlint 1.7.12 no valida `action.yml`, así que
el fallo aparece al ejecutarla. Semana 10, teoría 02.

</details>

**A5.** Una action JavaScript con `runs.using: node24` importa `@actions/core`. ¿Qué se comitea?

- A) `src/` y `package.json`: el runner hace `pnpm install` antes de `main`
- B) `src/` y `node_modules/`
- C) El bundle en `dist/`, que lleva el código y sus dependencias: el runner no instala dependencias de una action
- D) Nada: el runner compila `src/` al cargar la action

<details>
<summary>Solución</summary>

**C.** `main` y `post` apuntan a `dist/`, que se genera con esbuild y se comitea; `node_modules/`
no. Un CI comprueba que `dist/` no está desfasado respecto a `src/`. Semana 10, teorías 03 y 04.

</details>

**A6.** Una action declara `post` sin `post-if`. El step `main` falla. ¿Corre el `post`?

- A) No: `post` solo corre si `main` terminó bien
- B) Sí: el `post-if` por defecto es `always()`
- C) Solo si el job tiene `continue-on-error: true`
- D) Solo en runners Linux

<details>
<summary>Solución</summary>

**B.** Por eso la limpieza va en `post`: corre justo cuando más importa. `post-if: success()`
tiene sentido para guardar resultados, no para limpiar. Semana 10, teoría 05.

</details>

**A7.** `sql-lint` es una action Docker. Un equipo la usa en un job que corre en un runner Windows. ¿Qué
pasa?

- A) Funciona igual: Docker corre en todos los runners alojados
- B) Funciona, pero más lento
- C) El step falla: las actions Docker solo corren en runners Linux
- D) El runner la convierte en composite

<details>
<summary>Solución</summary>

**C.** Si hace falta en Windows o macOS, hay que reescribirla como JavaScript o composite.
Semana 10, teorías 01 y 06.

</details>

**A8.** En `actions-tablero`, `_python.yml` usa `uses: ./setup-tablero`. Lo llama `tablero`. ¿Qué
pasa y cuál es el arreglo?

- A) Funciona: `./` es relativo al archivo del reutilizable
- B) Falla: `./` se resuelve en el workspace del job, que es el checkout de `tablero`; el arreglo es `uses: $/setup-tablero`
- C) Falla; el arreglo es `uses: <tu-org>/actions-tablero/setup-tablero@main`
- D) Falla; el arreglo es añadir `repository: <tu-org>/actions-tablero` al checkout de cada job

<details>
<summary>Solución</summary>

**B.** `$/` resuelve al repo del archivo que corre, en el commit que corre, sin checkout. C
rompe el pinning y D obliga a adivinar qué commit descargar. Semana 11, teoría 02.

</details>

**A9.** Quieres que en la org solo corran las actions de GitHub, las de la propia org y seis de
terceros, todas fijadas por SHA. ¿Qué configuras?

- A) `allowed_actions: local_only` y `sha_pinning_required: true`
- B) `allowed_actions: selected`, `github_owned_allowed: true`, `verified_allowed: true` y los patrones
- C) `allowed_actions: selected`, `github_owned_allowed: true`, `verified_allowed: false`, los seis patrones y `sha_pinning_required: true`
- D) `allowed_actions: all` y una revisión obligatoria de cada PR

<details>
<summary>Solución</summary>

**C.** `local_only` bloquea también `actions/checkout`; `verified_allowed: true` abre todo el
Marketplace verificado; `all` no restringe nada. Semana 11, teoría 06.

</details>

**A10.** Publicaste `v1.0.0` del central y **después** activaste la inmutabilidad. La API dice
`immutable=false`. ¿Qué haces?

- A) Volver a guardar la release para que tome el ajuste
- B) Borrar la release y recrear `v1.0.0`
- C) Publicar una release nueva, `v1.0.1`, y subir el SHA en los consumidores
- D) Mover el tag `v1.0.0` al mismo commit para que se bloquee

<details>
<summary>Solución</summary>

**C.** La inmutabilidad no es retroactiva: solo protege las releases publicadas después de
activarla. Recrear o mover el tag es justo lo que hay que evitar. Semana 11, teoría 04.

</details>

**A11.** Mejoras la plantilla `ci-python` de `<tu-org>/.github`. ¿Qué repos reciben el cambio?

- A) Todos los que la usaron: GitHub sincroniza las plantillas
- B) Solo los repos que creen un workflow desde la plantilla a partir de ahora
- C) Los que tengan `filePatterns` que casen
- D) Ninguno hasta que publiques una release del repo `.github`

<details>
<summary>Solución</summary>

**B.** Una plantilla se copia una vez al crear el workflow. Por eso es un llamador fino al
reutilizable central fijado por SHA: lo que cambia vive en el central y llega subiendo el SHA.
Semana 11, teoría 05.

</details>

**A12.** Un ruleset de organización exige `required-python.yml` antes de fusionar. ¿Qué es cierto?

- A) Puede dispararse con `push` si lleva `branches: [main]`
- B) Sus filtros `paths` deciden en qué PR corre
- C) Necesita en `on:` `pull_request`, `pull_request_target` o `merge_group`, y sus filtros se ignoran
- D) Se configura en Settings → Actions de la org, como "required workflows"

<details>
<summary>Solución</summary>

**C.** Qué ramas y repos cubre lo decide el ruleset, no el workflow. La función "required
workflows" de los ajustes de Actions está retirada. Semana 11, teoría 07.

</details>

### Parte B — Publicar un parche y subir a los consumidores (25 minutos)

Publica `v1.0.1` de `actions-tablero` con un **cambio compatible** y haz que `tablero` y la
plantilla la usen. El cambio es de tu elección, siempre que no toque la interfaz: por ejemplo,
una `description` más clara en un input de `setup-tablero`, o el `name:` de un step. Nada de
inputs, outputs ni defaults nuevos o renombrados: eso ya no es un parche.

> ⚠️ **Una release inmutable no tiene vuelta atrás.** Revisa el borrador con
> `gh release view v1.0.1` antes de publicarlo: si te equivocas, el siguiente intento es `v1.0.2`,
> y el nombre `v1.0.1` no se puede reutilizar aunque borres la release.

Lo que tienes que hacer, sin más guía que lo aprendido en la fase:

1. El cambio en `~/code/actions-tablero`, con su `ci.yml` en verde sobre ese commit.
2. La release `v1.0.1` como borrador sobre el SHA de ese commit, revisada y publicada.
3. En `~/code/tablero`, una rama con las siete referencias al central subidas al SHA de
   `v1.0.1` en un solo commit, su PR con los checks en verde y el merge.
4. La plantilla de `~/code/org-dot-github` y la versión que cita su `.properties.json`,
   subidas a `v1.0.1`.

Corrige con estas ocho comprobaciones, 1 punto cada una:

```bash
ORG=<tu-org>
export GH_REPO="$ORG/tablero"
# 1. La release es la última, publicada e inmutable
gh api "repos/$ORG/actions-tablero/releases/latest" --jq '"\(.tag_name) immutable=\(.immutable) draft=\(.draft)"'
# v1.0.1 immutable=true draft=false
# 2. El CI del central en verde sobre el commit de v1.0.1
sha=$(gh api "repos/$ORG/actions-tablero/commits/v1.0.1" --jq .sha)
gh api "repos/$ORG/actions-tablero/actions/workflows/ci.yml/runs?head_sha=$sha" --jq '[.workflow_runs[].conclusion] | index("success") != null'
# true
# 3. La attestation resuelve el tag a ese mismo commit
gh release verify v1.0.1 -R "$ORG/actions-tablero" 2>&1 | grep -c "$sha"
# 1
# 4. El parche no toca más que lo que dices (README.md aparece si lo cambiaste tras v1.0.0)
gh api "repos/$ORG/actions-tablero/compare/v1.0.0...v1.0.1" --jq '.files[].filename'
# README.md
# setup-tablero/action.yml
# 5. tablero fija una sola versión, la nueva
cd ~/code/tablero && git pull -q --ff-only
grep -rhoE "$ORG/actions-tablero/[^@ ]+@[0-9a-f]{40} # v[0-9.]+" .github/workflows | sed -E 's/.*@//' | sort -u
# <sha-de-v1.0.1> # v1.0.1
# 6. Ese SHA es el del tag
grep -rhoE "$ORG/actions-tablero/[^@ ]+@[0-9a-f]{40}" .github/workflows | sed -E 's/.*@//' | sort -u | grep -cx "$sha"
# 1
# 7. La plantilla está al día (función template_lag de la práctica 04, paso 4)
template_lag
# plantilla al día: v1.0.1
# 8. La capa sigue completa
cd ~/code/bc-github-actions && ./scripts/check-week.sh 11 | tail -1
# 17/17 comprobaciones superadas.
```

<details>
<summary>Solución de referencia y fallos típicos</summary>

```bash
# 1. Cambio compatible en el central
cd ~/code/actions-tablero && git switch main && git pull -q --ff-only
# ... edita la description de un input en setup-tablero/action.yml ...
git commit -am "docs(setup-tablero): clarify working-directory input" && git push
id=$(gh run list --workflow ci.yml --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null && echo "central en verde"

# 2. Borrador sobre el SHA en verde, revisión y publicación
sha=$(git rev-parse HEAD)
gh release create v1.0.1 --draft --target "$sha" --title "v1.0.1" \
  --notes "Parche. setup-tablero: description más clara de working-directory. Nada que cambiar en el llamador."
gh release view v1.0.1 --json tagName,isDraft,targetCommitish
gh release edit v1.0.1 --draft=false

# 3. Subir los consumidores en un solo commit
cd ~/code/tablero && git switch -c ci/actions-tablero-v1.0.1
old=$(gh api "repos/$ORG/actions-tablero/commits/v1.0.0" --jq .sha)
new=$(gh api "repos/$ORG/actions-tablero/commits/v1.0.1" --jq .sha)
grep -rl "$old" .github/workflows | xargs sed -i "s/$old # v1.0.0/$new # v1.0.1/"
git commit -am "ci: bump actions-tablero to v1.0.1" && git push -u origin HEAD
gh pr create --fill && gh pr checks --watch > /dev/null && gh pr merge --squash --delete-branch

# 4. La plantilla
cd ~/code/org-dot-github
sed -i "s/$old # v1.0.0/$new # v1.0.1/" workflow-templates/ci-python.yml
sed -i 's/v1\.0\.0/v1.0.1/' workflow-templates/ci-python.properties.json
git commit -am "feat(workflow-templates): use actions-tablero v1.0.1" && git push
```

Fallos que cuestan puntos:

- **`--target main`** en vez del SHA: si `main` avanza entre el borrador y la publicación, el tag
  acaba en un commit que el CI no probó (comprobación 2). Semana 11, práctica 01, paso 5.
- **Subir solo algunos llamadores**: dos versiones del central conviven y la comprobación 5 da
  dos líneas. Semana 11, teoría 03.
- **Olvidar la plantilla**: `tablero` está en `v1.0.1` y los repos nuevos nacen en `v1.0.0`. Es
  otro repo y nadie la toca si no lo haces tú. Semana 11, teoría 05 y práctica 04.
- **Un cambio de interfaz con número de parche** (renombrar un input "ya que estabas"): el
  consumidor que sube sin tocar nada pasa a rojo. Eso era `v2.0.0`. Semana 11, teoría 03.
- **El PR de `tablero` no ejecuta el CI**: alguien quitó del filtro `paths` el propio archivo del
  llamador. Semana 07 y Semana 11, teoría 01.

Si fallaste la 1 por `immutable=false`, comprueba que la inmutabilidad sigue activada en
`actions-tablero` antes de publicar `v1.0.2`.

</details>

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 11 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
