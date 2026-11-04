# Rúbrica de evaluación — Semana 12

> Modelo de amenazas y endurecimiento. Se aprueba con un **mínimo del 70 % en cada evidencia**,
> no en el promedio.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de la capa 12 |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** En marzo de 2025 alguien movió los tags de `tj-actions/changed-files` a un commit que
volcaba los secretos en el log (CVE-2025-30066). Sitúa el incidente en el modelo de amenazas:
actor, frontera, activo y control. ¿Por qué no se vio afectado quien la tenía fijada por SHA, y
por qué el modelo trata igual a una herramienta de seguridad como Trivy?

<details>
<summary>Respuesta</summary>

**Actor**: el mantenedor de la action, o mejor dicho su cuenta; no hace falta que sea malicioso,
basta con que se la roben. **Frontera**: las referencias externas, la cuarta del modelo.
**Activo**: los secretos del runner, que en un repo público acababan en un log que lee
cualquiera. **Control**: el SHA, la regla 1 del bootcamp.

Con `@v45` el commit que ejecutas lo decide quien controla los tags. Con un SHA de 40
caracteres la referencia identifica el contenido: mover el tag no cambia qué corre en tu job, y
el siguiente run siguió ejecutando el commit de siempre.

Trivy 0.69.4 (2026-03-19) fue una release comprometida de una herramienta de seguridad. Una
herramienta que descargas corre dentro de tu job con tu token igual que cualquier dependencia:
por eso la regla 9 exige versión fijada con checksum, prohíbe esa versión y prohíbe
`trivy-action` por tag. Popularidad o propósito no son integridad. Teoría 01.

</details>

**2.** Rellena la tabla para un PR que abre un desconocido desde un fork: qué workflow corre,
de qué código hace checkout `actions/checkout` sin `ref:`, qué token recibe y si hay secretos,
con `pull_request` y con `pull_request_target`. ¿Qué defensa más actúa antes de que corra nada?

<details>
<summary>Respuesta</summary>

| Evento | Workflow | Checkout por defecto | Token | Secretos |
|---|---|---|---|---|
| `pull_request` desde fork | El del PR | El merge del PR | Solo lectura | No |
| `pull_request_target` | El de la rama por defecto | La rama por defecto | Lo que declares, con escritura | Sí |

Con `pull_request` el código del desconocido corre, pero sin escritura y sin secretos: es la
defensa que GitHub da gratis. `pull_request_target` existe justo para cuando hace falta escritura
en un PR de fork, y por eso es delicado: el PR no puede cambiar los steps, pero si un step trae
su código, ese código corre con escritura.

Antes de todo eso está la **aprobación de workflows de forks**. Por defecto solo se pide en la
primera contribución de alguien; tras un PR aceptado, los siguientes corren sin preguntar. En la
práctica 01 la subes a `all_external_contributors`. Teoría 01.

</details>

**3.** Un workflow tiene `permissions: contents: read` en la raíz. Su job `label` declara
`permissions: pull-requests: write`, hace checkout y corre con `pull_request`. Calcula los
permisos efectivos del job en un PR de tu propia rama y en uno de un fork. ¿Por qué `tablero`
pone `{}` en la raíz en lugar de `contents: read`, y dónde ves lo que el job recibió de verdad?

<details>
<summary>Respuesta</summary>

El bloque del job **sustituye** al de la raíz entero, no se suma. Y en cuanto declaras un scope,
los que no declaras pasan a `none`. En tu rama: `pull-requests: write`, `contents: none` y el
checkout falla. Hace falta `contents: read` en el job. En un fork, además, el recorte del paso 5
convierte todo `write` en `read` (salvo que alguien active "Send write tokens to workflows from
pull requests", que no se activa): `pull-requests: read`, y el etiquetado falla.

Con `contents: read` en la raíz, un job nuevo que olvida su bloque hereda lectura y funciona: el
olvido no se nota. Con `{}`, ese job no recibe nada y falla en el primer checkout. **El fallo te
obliga a pensar qué necesita.**

El YAML dice lo que el job pidió. Lo que recibió, después del default de la org, la raíz, el job,
el techo del reutilizable y el recorte de forks, está en **Set up job → GITHUB_TOKEN
Permissions** del log: `gh run view <run-id> --log | grep -A6 "GITHUB_TOKEN Permissions"`.
Teoría 02.

</details>

**4.** El job `web` de `ci-web` llama a `_node.yml` del repo central con
`permissions: contents: read`. En una versión nueva del central, un job de `_node.yml` pide
`packages: write`. ¿Qué pasa al subir `tablero` a esa versión, y por qué es lo que quieres?

<details>
<summary>Respuesta</summary>

Los permisos del job llamador son el **techo** de todo lo que corre dentro del reutilizable:
puede pedir menos, nunca más. El run falla en la validación, antes de ejecutar nada, con un
mensaje del tipo `is requesting 'packages: write', but is only allowed 'packages: none'`.

Es lo que quieres porque así el central no puede dar más poder a `tablero` sin que tú lo
decidas. Si de verdad hace falta, lo concedes en el job llamador, en un commit de `tablero` que
se revisa; si no, el central tiene un cambio incompatible que no debía haber salido como menor.
Teoría 02.

</details>

**5.** El workflow de laboratorio tiene `run: echo "Gracias por el PR ${{ github.event.pull_request.title }}"`.
Con el título `x"; echo "PWNED-$((6*7))` el log enseña `PWNED-42`. ¿Por qué ocurre, por qué
el `42` es la prueba, por qué cambiar a comillas simples no lo arregla y qué dos condiciones
tiene la versión segura? ¿Por qué el daño fue nulo aun así?

<details>
<summary>Respuesta</summary>

El runner sustituye cada `${{ }}` por su valor y escribe el resultado en un archivo temporal
**antes** de arrancar el shell. El shell recibe `echo "Gracias por el PR x"; echo "PWNED-$((6*7))"`:
dos comandos. La aritmética `$((6*7))` solo la evalúa un shell, así que ver `42` demuestra que el
título se ejecutó. Las comillas las pone tu YAML y el atacante las cierra: con simples, solo
cambia el carácter que escribe.

Versión segura: el valor entra por `env:` (`PR_TITLE: ${{ github.event.pull_request.title }}`)
y el `run:` es `echo "Gracias por el PR $PR_TITLE"`, **el mismo script para todos los PR**. La
variable va **entre comillas dobles**: sin ellas no ejecuta comandos, pero parte el valor en
palabras y expande comodines.

El daño fue nulo porque el laboratorio corre con `pull_request` y `permissions: {}`: el token no
tiene ningún scope ni hay secretos. La inyección se previene con `env:`; el daño se limita con
los permisos. Con `pull_request_target` o `issue_comment`, el mismo step corre con escritura y
secretos. Teoría 03.

</details>

**6.** Un compañero dice: "Ya no tengo `${{ }}` en ningún `run:`, así que no hay inyección".
Dale tres sitios donde la inyección sigue siendo posible y cómo se cierra cada uno. ¿Es de
confianza un input de `workflow_dispatch`?

<details>
<summary>Respuesta</summary>

- **`script:` de `actions/github-script`**: es JavaScript que se monta igual. Con `${{ }}`
  dentro, el título se vuelve código JavaScript. Se pasa por `env:` y se lee con
  `process.env.PR_TITLE`.
- **`GITHUB_ENV`**: escribir texto del atacante ahí define variables para todos los steps
  siguientes. Con un salto de línea puede añadir `BASH_ENV` o `LD_PRELOAD` y tomar procesos que
  no tocaste. Con `GITHUB_PATH` elige qué binario corre al llamar a `git`. No se escriben datos
  del evento en esos archivos.
- **`GITHUB_OUTPUT`**: un output con texto del atacante sigue siendo no confiable; si otro step
  lo usa como `${{ steps.x.outputs.y }}` en un `run:`, la inyección reaparece un step más abajo.
  El dato se vuelve a pasar por `env:` desde su origen.

Un input de `workflow_dispatch` lo lanza alguien con escritura, pero es texto libre: ese
colaborador, o quien robe su sesión, decide qué llega al shell. Se trata como cualquier dato del
evento. Por eso `tablero` no admite **ninguna** expresión en un `run:`: una regla que se
comprueba con `grep` es más fiable que una lista blanca. Teoría 03.

</details>

**7.** Este job tiene permisos acotados y `persist-credentials: false`, y aun así es una «pwn
request». ¿Qué línea lo rompe, qué hace el atacante y qué otras cosas cuentan como "ejecutar
código del PR"?

```yaml
on:
  pull_request_target:
permissions: {}
jobs:
  build:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          persist-credentials: false
      - run: make preview
```

<details>
<summary>Respuesta</summary>

El `ref: ${{ github.event.pull_request.head.sha }}`. `pull_request_target` corre el workflow de
la rama por defecto con escritura y secretos aunque el PR venga de un fork; ese checkout trae el
código del PR a ese job. El atacante abre un PR que cambia el objetivo `preview` del `Makefile`,
y `make preview` ejecuta lo que él escribió con `pull-requests: write` y los secretos del repo.
No necesita inyección ni action comprometida. La regla 6 lo prohíbe.

También ejecutan código del PR: `uv sync`, un `pnpm install` con scripts de instalación, un
`docker build` con su `Dockerfile` y una action local `uses: ./` del PR. La solución no es un
parche: separar lo que construye (`pull_request`, sin escritura) de lo que comenta
(`workflow_run`, sin checkout). Teoría 04.

</details>

**8.** Explica qué puerta cierra cada pieza de `pr-report`: el `if:`, `actions: read`, el
`path` en `runner.temp`, la validación con `^[0-9]+$` y `--body-file`. ¿Por qué el número del PR
viaja en el artefacto en lugar de leerse de `github.event.workflow_run.pull_requests`?

<details>
<summary>Respuesta</summary>

- **`if:`** sobre `workflow_run.event == 'pull_request'` y `conclusion == 'success'`: un `push`
  a `main` o un run fallido no comentan nada.
- **`actions: read`**: lo exige descargar un artefacto de **otro** run con `run-id` y
  `github-token`. No hay `contents`: no hay checkout.
- **`runner.temp`**: saca el artefacto del workspace. Sin `path:`, un `scripts/post-report.sh`
  dentro del artefacto podría pisar un archivo que un step posterior ejecuta con escritura.
- **`^[0-9]+$`** (tras `head -c 10`): el artefacto lo escribió código del PR. Sin validar, el
  atacante elige a qué PR o issue comenta el bot, o mete `1; rm -rf ~`.
- **`--body-file`**: el informe no entra en la línea de comandos ni en una expresión. Como
  comentario es inofensivo: GitHub lo renderiza como Markdown.

`workflow_run.pull_requests` llega **vacío en los PR de forks**, que son justo el caso para el
que existe este patrón. Por eso `ci-web` escribe el número en `pr-number`, y por eso se valida.
Teorías 04 y 05.

</details>

**9.** ¿Por qué un `pull_request_target` no puede guardar entradas en la caché de `main`? Describe
el ataque que eso cierra, qué valor tiene `cache-mode` por defecto y por qué `tablero` no
escribe la clave aunque exista.

<details>
<summary>Respuesta</summary>

Un run restaura cachés de su rama, de la rama por defecto y, si es un PR, de la base. La de
`main` la restaura todo el mundo, así que es la más valiosa. Solo los triggers de confianza
(`push`, `workflow_dispatch`, `schedule`…) pueden escribirla; `pull_request_target`,
`issue_comment` y `workflow_run` solo leen, aunque corran en el contexto de `main`.

El ataque: un PR de fork consigue ejecutar algo dentro de un `pull_request_target` (por
inyección o por un checkout indebido) y deja un `.venv` o un almacén de `pnpm` modificado en la
caché de `main`. El siguiente `push` lo restaura y construye la imagen de GHCR con él: el
atacante pasa de un job sin valor a la imagen que publicas sin tocar un token con escritura.

Sin `cache-mode`, vale `write` en los triggers de confianza y `read` en los de baja confianza:
el default ya es el seguro, y lo ves en la línea `Cache mode:` del log. Escribir
`cache-mode: write` en un trigger de baja confianza reabriría el ataque. `tablero` no la usa
porque no cambia nada y porque actionlint 1.7.12 todavía la rechaza (issue #762): rompería
`lint-workflows` sin ganar nada. Teoría 05.

</details>

**10.** Un PR "actualiza" el SHA de `actions/checkout` y el comentario dice `# v7.0.1`. ¿Qué es
un commit impostor, qué dos defensas tiene `tablero` y qué hace el cooldown de 7 días de
Dependabot? Después, explica por qué la inyección del laboratorio la marca zizmor y CodeQL con su
configuración por defecto no.

<details>
<summary>Respuesta</summary>

GitHub guarda los objetos de un repo y de todos sus forks en la misma red: un commit que solo
existe en un fork se resuelve también como `actions/checkout@<sha>`. El prefijo parece de fiar;
el código es del atacante. Defensas: **nunca copiar un SHA** (se resuelve con
`scripts/resolve-sha.sh` contra el repo oficial) y la auditoría **`impostor-commit`** de zizmor,
que comprueba que el SHA está en una rama o tag del repo nombrado. Es online: necesita
`GH_TOKEN`, y por eso `lint-workflows` pierde el `--offline`. `ref-version-mismatch` comprueba
además que el comentario `# v7.0.1` corresponde a ese SHA, porque el comentario es solo texto.

`cooldown.default-days: 7` hace que Dependabot no proponga una versión hasta que lleva 7 días
publicada: una release comprometida suele detectarse y retirarse en ese plazo. Sin cooldown
aplica 3 días, y zizmor (`dependabot-cooldown`) avisa. Solo afecta a las version updates.

La suite por defecto de CodeQL solo carga consultas de precisión `high` y `very-high`. La
inyección de un `pull_request` sin permisos es `actions/code-injection/medium`, de precisión
`medium`, que solo entra con `queries: security-extended`. zizmor (`template-injection`) la
marca siempre. Por eso se usan los dos: zizmor es la barrera rápida en cada PR; CodeQL sigue el
dato entre steps y guarda historia en Security. Teorías 06 y 07.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Permisos mínimos por job | `permissions: {}` en la raíz de los 7 workflows, un bloque en cada uno de los 16 jobs (también los que llaman a un reutilizable) y aprobación para todos los colaboradores externos (checks `root-permissions-empty`, `jobs-declare-permissions`, `fork-pr-approval`) | 5 |
| 01 — Permisos mínimos por job | Enseña el grupo `GITHUB_TOKEN Permissions` de un job antes y después del cambio, explica por qué solo escriben `images` (`packages`) y `nightly` (`actions`), y los 7 checkouts siguen con `persist-credentials: false` | 5 |
| 02 — Inyección de scripts | Ningún `run:` ni `script:` con `${{ }}`; `codeql.yml` con `languages: actions` y `security-events: write` solo en su job; code scanning con análisis y sin alertas abiertas (checks `no-expressions-in-run`, `codeql-workflow`, `code-scanning-clean`) | 5 |
| 02 — Inyección de scripts | Enseña `PWNED-42` en el log y explica el 42; zizmor (`template-injection`) y actionlint señalan la misma línea; explica por qué CodeQL por defecto no lo marcaba; PR de laboratorio cerrado sin fusionar y `lab/injection` borrada | 5 |
| 03 — pull_request_target y workflow_run | `labeler` sin checkout y fijado por SHA, un PR etiquetado; `pr-report` con guardia, sin checkout y con `run-id`; el bot comentó el informe (checks `labeler-safe`, `labeler-labeled`, `pr-report-safe`, `pr-report-commented`) | 5 |
| 03 — pull_request_target y workflow_run | Cada `dangerous-triggers` ignorado con un motivo cierto; artefacto en `runner.temp` y número validado; explica por qué el PR que añade `labeler.yml` no se etiqueta; PR de prueba cerrado sin fusionar | 5 |
| 04 — Dependabot y zizmor online | `github-actions`, `uv` y `npm` (pnpm) en sus directorios con 7 días de cooldown; zizmor online con el `GITHUB_TOKEN`; linters, pinning y los cinco workflows en verde (checks `dependabot-ecosystems`, `dependabot-cooldown`, `zizmor-online`, `workflows-lint`, `actions-pinned`, `green-on-main`, `writes-only-where-needed`) | 5 |
| 04 — Dependabot y zizmor online | Alertas y security updates activas; comprueba con `matching-refs` que el SHA de un PR de Dependabot es el del tag que anuncia; `actionlint` y zizmor online limpios en local | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 12` con 17/17. Cada comprobación en rojo
resta la parte proporcional (12/17 de punto).

**Calidad manual de la capa 12 (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| Cada `# zizmor: ignore[dangerous-triggers]` lleva un motivo que se sostiene leyendo el workflow: sin checkout, sin ejecutar nada del PR, el artefacto se valida | 3 |
| `pr-report` valida el número del PR con `^[0-9]+$` y descarga el artefacto en `runner.temp`, nunca encima del código | 3 |
| Cada permiso de escritura tiene un comentario o un motivo evidente en el nombre del job; ningún permiso «por si acaso» | 3 |
| El PR de la práctica 02 está cerrado sin fusionar y su rama borrada | 2 |
| Los PRs de Dependabot fusionados dejan constancia de lo revisado: release de la action y SHA del repo oficial | 2 |
| Commits en Conventional Commits, uno por mecanismo (`ci: drop default token permissions`, `ci: add codeql for workflows`…) | 3 |
| Sin `TODO` en el repo | 2 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log | Grave: Producto a 0 hasta rotarlo y retirarlo |
| `pull_request_target` con checkout del head del PR (`head.sha`, `head.ref` o similar) | Grave: −10 |
| Runner propio al alcance de PRs de forks | Grave: −10 |
| `uses:` remota sin SHA, o con un SHA copiado que no pertenece al repo oficial | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}`, `github.head_ref` o `inputs.*` interpolado dentro de `run:` o de `script:` | Grave: −10 |
| Imagen sin tag o con `latest` | Grave: −10 |
| El workflow vulnerable de laboratorio fusionado en `main` | Grave: −10 |
| "Send write tokens to workflows from pull requests" activado | −5 |
| Escritura en un job fuera de la lista de `writes-only-where-needed`, o `read-all` | −5 |
| `download-artifact` sin `path` fuera del workspace, o `pr-number` usado sin validar, en un job con escritura | −5 |
| `cache-mode: write` en un trigger de baja confianza | −5 |
| Alerta de code scanning cerrada a mano sin corregir el workflow | −5 |
| `# zizmor: ignore[...]` sin motivo, genérico o con un motivo falso | −3 |
| `--offline` o `--min-severity` en el job `zizmor` para que pase | −3 |
| Job con `runs-on` sin `timeout-minutes` | −3 por cada uno |
| `pip`, `npm` o Compose v1 en un workflow o en la documentación de tu repo | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 12 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
