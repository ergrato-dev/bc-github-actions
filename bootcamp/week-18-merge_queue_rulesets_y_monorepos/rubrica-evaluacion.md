# Rúbrica de evaluación — Semana 18

> Merge queue, rulesets y monorepos. Se aprueba con un **mínimo del 70 % en cada evidencia**, no
> en el promedio. Esta semana abre la Fase 6: no lleva minisimulacro.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de la capa 18 |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** Antes de esta semana `ci-api.yml` tenía `on: pull_request: paths: ['api/**']`. Si marcas
su job `test` como check obligatorio en el ruleset, ¿qué ve un PR que solo toca `web/`? ¿Y si en
lugar del filtro `paths` el job tuviera `if: false`?

<details>
<summary>Respuesta</summary>

**Con el filtro `paths`, el PR se queda bloqueado**: el workflow ni siquiera arranca, así que el
check no llega nunca y GitHub lo muestra como "Expected" (pendiente). La documentación lo dice
así: si un workflow se salta por filtro de rutas, de ramas o por el mensaje del commit, sus
checks se quedan en "Pending" y un PR que los exige no se puede fusionar.

**Con `if: false`, el PR se puede fusionar**: el workflow arranca, el job se salta y un job
saltado informa de su estado como "Success". Los estados que cuentan como éxito para un check
obligatorio son `success`, `skipped` y `neutral`.

Por eso `tablero` decide qué correr **dentro** de un workflow que siempre arranca (`ci.yml`, sin
`paths`) y salta jobs con `if:`. Pero esa misma regla es peligrosa: un job saltado también pasa,
así que el check obligatorio no puede ser un job de área, sino `ci-gate`. Teoría 03.

</details>

**2.** Un compañero quita `if: always()` de `ci-gate` porque "si todo está en `needs`, ya espera a
todos". Una tarde `api` falla. ¿Qué pasa con el PR? ¿Por qué el paso de `ci-gate` usa `jq -e` y no
basta con mirar si algún resultado es `failure`?

<details>
<summary>Respuesta</summary>

**El PR se fusiona con `api` en rojo.** Sin `if:`, un job tiene implícito `success()`: si algún
job de `needs` falla, `ci-gate` **se salta**, y un job saltado cuenta como éxito para el check
obligatorio. La puerta se abre justo cuando debería cerrarse. Con `if: always()` corre siempre y
decide él.

`jq -e 'all(.[]; . == "success" or . == "skipped")'` sobre `toJSON(needs.*.result)` es una lista
blanca: cualquier cosa que no sea éxito o saltado bloquea, incluido `cancelled`. Buscar solo
`failure` dejaría pasar un `cancelled` (alguien canceló el run o un job) sin que se haya probado
nada. `-e` hace que `jq` salga con error cuando el resultado es `false`; sin él,
imprime `false` y sale con 0. Y `needs` tiene que listar todos los jobs que importan: un job que no
está en `needs` no lo ve la puerta. Teoría 03, práctica 01 paso 4.

</details>

**3.** Dos PR, A y B, están en verde contra el mismo `main`. Fusionas A y, sin que nadie toque B,
fusionas B. `main` se rompe. ¿Cómo es posible y cómo lo evita la merge queue? ¿Qué pasa si el
workflow del check obligatorio no escucha `merge_group`?

<details>
<summary>Respuesta</summary>

Los checks de B se probaron contra el `main` **anterior** a A. Cada PR está bien por separado, pero
B puede usar algo que A cambió o borró (un conflicto semántico, no de texto). Nada volvió a probar
B encima de A.

La merge queue crea una rama temporal `gh-readonly-queue/main/...` con `main` + A, y otra con
`main` + A + B, y pide los checks para cada una con el evento `merge_group` (`checks_requested`).
Solo entra en `main` lo que pasó sobre lo que de verdad va a haber en `main`. Si el grupo de B
falla, la cola saca B y A entra igual.

Si el workflow no escucha `merge_group`, nadie contesta a la cola: el check no se reporta, la
cola espera hasta `check_response_timeout_minutes` (30 en `tablero`), lo da por fallido y saca el
PR. La documentación lo dice con un "must". Teoría 05, práctica 03.

</details>

**4.** El job `changes` usa
`BASE: ${{ github.event.pull_request.base.sha || github.event.merge_group.base_sha || github.event.before }}`.
¿Qué base da cada evento? ¿Por qué el checkout lleva `fetch-depth: 0`, y por qué
`changed-areas.sh` marca todo `true` si la base está vacía o es una cadena de ceros?

<details>
<summary>Respuesta</summary>

En un `pull_request`, `pull_request.base.sha` es el commit de la rama base contra el que se abrió
el PR. En `merge_group`, `merge_group.base_sha` es el commit padre del grupo: lo que habrá en `main`
justo antes de él, sobre lo que la cola prueba. En un `push`, `event.before` es lo que había en la rama
antes del push. `||` devuelve el primer valor no vacío, y en cada evento solo existe uno.

Por defecto `actions/checkout` trae un solo commit; la base no está en el clon y `git diff` no
puede compararla. `fetch-depth: 0` trae el historial completo.

Una base vacía (`workflow_dispatch`) o de ceros (el primer push de una rama nueva) no es un commit:
no hay contra qué comparar. Lo seguro es correr todo. Lo mismo con `.github/`: un cambio en un
workflow o una action puede romper cualquier área. Ante la duda se prueba de más, nunca de menos.
Teoría 04, práctica 01 pasos 1 y 2.

</details>

**5.** Al convertir `ci-api.yml` en reutilizable, alguien deja su bloque
`concurrency: group: ${{ github.workflow }}-${{ github.ref }}` con `cancel-in-progress: true`.
¿Qué pasa al abrir un PR que toca `api/`? ¿Por qué no se arregla cambiando `github.workflow`
por el nombre del archivo?

<details>
<summary>Respuesta</summary>

**El run de `ci` acaba cancelado.** Cuando un workflow se llama con `workflow_call`, el contexto
`github` es siempre el del llamante: `github.workflow` vale `ci`, el mismo valor que usa el
`concurrency` de `ci.yml`. El reutilizable cae en el grupo del run que lo está ejecutando y GitHub
cancela uno de los dos. La documentación lo avisa: no uses el mismo grupo en el llamado y en el
llamante.

Se podría inventar otro grupo, pero no hace falta: la concurrencia ya la controla `ci.yml`, que es
el que arranca por cada evento. Un reutilizable sin `concurrency` propia hereda ese control. Por
eso `areas-callable-only` exige que no la tengan. Teoría 04, práctica 01 paso 3.

</details>

**6.** El check obligatorio del ruleset es `context: ci-gate` con `integration_id: 15368`. ¿Qué es
ese número, cómo lo compruebas y qué ataque evita? ¿Qué ves en el PR si te equivocas de número?

<details>
<summary>Respuesta</summary>

15368 es el id de la app **GitHub Actions** (`gh api apps/github-actions --jq .id`). Con él, el
check solo cuenta si lo emite un job de Actions. Sin él, cualquiera con un token que pueda
escribir estados de commit (una integración, un PAT filtrado, otra App) podría publicar un estado
`ci-gate` en verde sobre su commit y abrir la puerta sin correr el CI.

Si el número es otro, el PR espera un `ci-gate` de esa otra app que nunca llega: el job de
Actions sale verde y el PR sigue bloqueado. Se arregla en el YAML y se aplica con un `PUT`. Por
eso `ruleset-file` y `ruleset-active` comprueban `ci-gate@15368`, no solo el nombre. Teoría 02,
práctica 02.

</details>

**7.** En `tablero` el ruleset tiene `bypass_actors: []`. Un viernes `ci-gate` falla en todos los
PR por una action caída y quieres fusionar un arreglo urgente. ¿Puedes usar `gh pr merge --admin`?
¿Qué harías? Y si la org añadiera un ruleset de organización que también apunta a `main`, ¿cuál
gana?

<details>
<summary>Respuesta</summary>

**No**: `--admin` salta los requisitos solo si tienes permiso de bypass, y nadie lo tiene,
tampoco el admin. Es una decisión: lo que entra en `main` siempre ha pasado por la misma puerta.
El arreglo va por PR: si el problema está en el CI, el PR que lo arregla toca `.github/`, corre
todo y, si pasa, entra por la cola. En un caso extremo, un admin cambia el ruleset (queda en su
historial) y lo devuelve después; no se deja un bypass permanente "por si acaso".

Los rulesets **no tienen prioridad**: todos los que aplican a una rama se suman, y si la misma
regla está definida de formas distintas gana la versión más restrictiva. `rules/branches/main`
devuelve el resultado ya sumado, con el `ruleset_source_type` de cada regla. Los rulesets de
organización exigen GitHub Team o Enterprise; en una org Free solo hay rulesets de repositorio
(en repos públicos). Teoría 01.

</details>

**8.** Tienes `/.github/ @<tu-usuario>` y debajo `* @<tu-org>/web-team` en `.github/CODEOWNERS`.
¿Quién es el dueño de `.github/workflows/ci.yml`? ¿Qué pasa si el usuario de una línea no tiene
escritura en el repo? Y con `required_approving_review_count: 0`, ¿para qué sirve CODEOWNERS en
`tablero`?

<details>
<summary>Respuesta</summary>

**`@<tu-org>/web-team`**: gana el **último** patrón que casa, y `*` casa con todo. Lo general va
arriba y lo concreto abajo; aquí está al revés.

Los dueños necesitan permiso de escritura (un equipo, además, visible). Si no lo tienen, esa línea
no asigna a nadie; una línea con sintaxis inválida se ignora sin avisar en el PR. Por eso conviene
`gh api repos/{owner}/{repo}/codeowners/errors`, que debe devolver `errors: []`
(`codeowners-valid`). El archivo se busca en `.github/`, la raíz y `docs/`, en ese orden, y cuenta
el de la rama base del PR.

Con 0 aprobaciones, GitHub sigue pidiendo revisión al dueño en cada PR que toca su ruta: deja
claro quién responde de `.github/` y `ops/`. En un equipo, el ruleset añadiría
`require_code_owner_review: true` y al menos una aprobación, y entonces el PR no entraría sin su
visto bueno. Trabajando solo no puedes aprobar tu propio PR, así que exigirlo te bloquearía.
Teoría 06.

</details>

**9.** Con `GITHUB_TOKEN`, el PR de release de release-please aparece pero `ci-gate` no corre solo.
¿Por qué? ¿Por qué la solución es el token de una GitHub App y no un PAT? ¿Y por qué, después,
`can_approve_pull_request_reviews` vuelve a `false`?

<details>
<summary>Respuesta</summary>

Los eventos de `GITHUB_TOKEN` no crean runs, para evitar bucles, salvo `workflow_dispatch`,
`repository_dispatch` y un caso nuevo: cuando `GITHUB_TOKEN` abre o actualiza un PR, los runs de
`pull_request` se crean en estado **approval-required** y alguien con escritura tiene que pulsar
"Approve workflows to run". Sin eso, el check obligatorio nunca llega y el PR no entra.

Con el token de la App, el PR lo abre la App: es un actor normal y el CI corre como en cualquier
otro PR. Frente a un PAT, el token de la App caduca en una hora como mucho (y
`create-github-app-token` lo revoca al terminar el job), solo vale donde la App está instalada
(solo `tablero`) y solo con los permisos que pide el step (`permission-contents` y
`permission-pull-requests`). Un PAT es de una persona, dura meses y llega a todo lo que ella llega.

El ajuste "Allow GitHub Actions to create and approve pull requests" se abrió en la Semana 14 solo
para que release-please creara su PR. El mismo ajuste deja que **cualquier** workflow apruebe PR,
y la API lo describe como un riesgo: un workflow comprometido podría aprobar su propio cambio. Ya
nadie lo necesita, así que se cierra en la org y en el repo. Teoría 07, práctica 04.

</details>

**10.** El ruleset de `tablero` tiene `strict_required_status_checks_policy: false` y la regla
`merge_queue` con `grouping_strategy: ALLGREEN`. ¿Por qué no `true`? ¿Qué cambiaría con
`HEADGREEN`? ¿Y por qué `merge_method` va en mayúsculas cuando `allowed_merge_methods` va en
minúsculas?

<details>
<summary>Respuesta</summary>

`strict: true` obliga a que la rama del PR esté al día con `main` antes de fusionar: cada vez que
entra otro PR, todos los demás tienen que actualizarse y volver a pasar el CI. Con la cola no
aporta nada: la cola ya prueba cada PR encima del `main` real (y de los que van delante), que es
justo lo que `strict` intentaba garantizar, sin hacer que cada autor actualice a mano.

Con `ALLGREEN` cada grupo de la cola tiene que pasar sus checks. Con `HEADGREEN` basta con que pase
el commit de cabeza del grupo, que contiene a todos los anteriores: menos runs que esperar, pero un
fallo intermedio que el último commit tapa podría entrar. Para un repo con poco tráfico como
`tablero`, `ALLGREEN` es más claro.

Son dos reglas distintas de la API: `pull_request.allowed_merge_methods` acepta `merge`, `squash`
y `rebase`, y `merge_queue.merge_method` acepta `MERGE`, `SQUASH` y `REBASE`. Un valor en el caso
equivocado da `HTTP 422`. Teorías 02 y 05, práctica 03 paso 2.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Un solo check para un monorepo | `changed-areas.sh` con base inválida y `.github/` → todo; `changes` contra las tres bases con historial completo; áreas como reutilizables sin `concurrency`, llamadas con `if:`; `ci-gate` con `if: always()`, sin permisos y bloqueando `failure` y `cancelled`; `pr-report` escuchando a `ci`; actionlint y zizmor limpios (checks `changed-areas-script`, `ci-changes-job`, `areas-called-by-changes`, `areas-callable-only`, `ci-gate-needs-all`, `ci-gate-blocks`, `pr-report-follows-ci`, `workflows-lint`) | 5 |
| 01 — Un solo check para un monorepo | Enseña el PR que solo toca `web/` con `api`, `tools` y `workflows` en `skipped` y `ci-gate` en verde, y la prueba local de `ci-gate` con un resultado `cancelled` que bloquea | 5 |
| 02 — Ruleset y CODEOWNERS en main | `CODEOWNERS` con `/.github/` y `/ops/` y sin errores en la API; `ruleset-main.yaml` sin bypass, con 0 aprobaciones y `ci-gate@15368`; el ruleset activo en `main` (checks `codeowners`, `codeowners-valid`, `ruleset-file`, `ruleset-active`) | 5 |
| 02 — Ruleset y CODEOWNERS en main | Enseña el push directo y el force push rechazados con `GH013`, `main` intacto, y un PR con `ci-gate` en rojo en estado `BLOCKED` | 5 |
| 03 — Merge queue | `ci.yml` escucha `merge_group`; la regla `merge_queue` en el archivo y activa; el último commit de `main` pasó `ci-gate` en la cola y en el push (checks `ci-triggers`, `ruleset-file`, `ruleset-active`, `merged-through-queue`) | 5 |
| 03 — Merge queue | Enseña el respaldo del ruleset antes del `PUT`, el run `merge_group` en `gh-readonly-queue/main/pr-<n>-…` y dos PR probados a la vez en la cola | 5 |
| 04 — release-please con una GitHub App | `release.yml` con `permissions: {}`, `environment: release` y el token de la App limitado a contents y pull-requests; environment `release` solo para `main` con la clave y el client ID; `can_approve_pull_request_reviews=false` en org y repo; el PR de release de la App con `ci-gate` en verde (checks `release-app-token`, `release-environment`, `actions-cannot-approve`, `release-pr-by-app`) | 5 |
| 04 — release-please con una GitHub App | Enseña la App con `contents=write,metadata=read,pull_requests=write events=0` e instalación `selected`, el respaldo de la política antes del `PUT`, `org-default-token-read` de la Semana 11 de nuevo en verde y la release desplegada por `deploy.yml` | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 18` con 18/18. Cada comprobación en rojo
resta la parte proporcional (12/18 de punto).

**Calidad manual de la capa 18 (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| `ruleset-main.yaml` lleva un comentario por regla con el riesgo que frena, y otro que explica `strict_required_status_checks_policy: false` con la cola | 3 |
| El ruleset activo coincide con el archivo, y lo enseñas sacándolo de la API con `yq -P`, no de memoria | 3 |
| La App `tablero-release` pide solo Contents, Pull requests y Metadata, sin webhook, solo instalable en tu cuenta e instalada solo en `tablero` | 3 |
| La clave `.pem` vive fuera de cualquier repo con permisos `600`, y la App tiene una sola clave activa | 3 |
| `changed-areas.sh` explica en su cabecera por qué `.github/` y una base inválida corren todo | 2 |
| Los PR de prueba de las prácticas están cerrados o fusionados y sus ramas borradas | 2 |
| Sin `TODO` en el repo | 2 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log, o la clave privada de la App en un commit, un log o un archivo dentro de un repo | Grave: Producto a 0 hasta rotar la clave (generar otra, actualizar el secreto y borrar la vieja) y retirar el commit o el log |
| Clave privada o client ID de la App guardados fuera del environment `release` (como secreto del repo o de la org) | Grave: −10 |
| Ruleset con un bypass para el rol admin, para ti o para cualquier otro actor | Grave: −10 |
| Check obligatorio sin `integration_id`, o con uno distinto del de GitHub Actions | Grave: −10 |
| GitHub App con permisos que release-please no usa (de organización, Administration, Workflows, Actions…) o instalada en todos los repos de la org | Grave: −10 |
| `can_approve_pull_request_reviews` en `true` en la org o en el repo | Grave: −10 |
| `pull_request_target` con checkout del head del PR | Grave: −10 |
| Runner propio al alcance de PRs de forks: un workflow con `pull_request*` o `merge_group` que pide `tablero-runners` | Grave: −10 |
| `uses:` remota sin SHA, o con un SHA copiado que no pertenece al repo oficial | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}`, `github.head_ref`, `inputs.*`, `secrets.*` o `vars.*` interpolado dentro de `run:` | Grave: −10 |
| Imagen sin tag o con `latest` | Grave: −10 |
| `ci-gate` sin `if: always()`, o que deja pasar `cancelled` | −5 |
| Un workflow de área con `concurrency` propia o con `paths` | −5 |
| Un PAT en lugar del token de la App | −5 |
| `secrets: inherit` al llamar a un reutilizable | −3 |
| Job con `runs-on` sin `timeout-minutes` | −3 por cada uno |
| `pip`, `npm` o Compose v1 en un workflow o en la documentación de tu repo | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 18 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
