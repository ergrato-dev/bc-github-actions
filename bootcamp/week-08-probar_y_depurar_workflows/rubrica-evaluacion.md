# Rúbrica de evaluación — Semana 08

> Probar y depurar workflows. Se aprueba con un **mínimo del 70 % en cada evidencia**, no en el
> promedio. Esta semana cierra la Fase 2: al final tienes el minisimulacro de la fase.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de la capa 08 (`lint-workflows.yml` y `ci-local.sh`) |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** Un step ejecuta `uv run pytest | tee pytest.txt` sin `shell:`. Dos tests fallan, el log
lo dice con `FAILED` en rojo, y el step queda en verde. ¿Por qué? ¿Y qué decide de verdad el color
de un step?

<details>
<summary>Respuesta</summary>

El color lo decide **solo el código de salida** del proceso: GitHub no lee el texto del log. Un
`ERROR` impreso con código 0 deja el step verde, y un `exit 1` mudo lo deja rojo. Sin `shell:`,
el step corre con `bash -e {0}`: `-e` para en el primer comando que falla, pero sin `pipefail` el
código de una tubería es el del **último** comando, `tee`, que casi siempre termina en 0. Con
`shell: bash` el runner usa `bash --noprofile --norc -eo pipefail {0}` y la tubería falla si falla
cualquier parte. Es un falso verde de los peores: nadie mira el log de un step verde.

</details>

**2.** Un run de `ci-api` está en rojo: `lint` falló, `test` aparece como omitido y la última
línea del log de `lint` es `Process completed with exit code 1.` ¿Por dónde empiezas a leer y
qué dos errores de lectura evitas?

<details>
<summary>Respuesta</summary>

Por las **anotaciones** del run: si una trae archivo y línea, ve ahí. Si no, el **primer** job en
rojo, su **primer** step en rojo y el **primer** error dentro de ese log. Los dos errores: buscar
la causa en `test`, que se omitió porque depende de `lint` (`needs:`), y quedarse con la última
línea, que es el código de salida y no la causa. Desde la terminal, `gh run view <id> --log-failed`
te da solo los steps fallidos con el job y el step delante de cada línea, así que `grep` no pierde
el contexto.

</details>

**3.** Tu script de validación imprime tres
`::error file=api/src/tablero/main.py,line=12::...` y termina con `exit 0`. ¿Qué ves en el run? ¿Y
si `file` apunta a un archivo que no existe en el commit?

<details>
<summary>Respuesta</summary>

Tres anotaciones rojas sobre un step **verde**: `::error::` crea una marca pero no cambia el código
de salida. Es lo más confuso que puedes enseñar; emite y luego sal con 1. Si el archivo no existe
en el commit, la anotación se queda en el resumen del run, sin enlazar a ninguna línea ni aparecer
en **Files changed**. Por debajo son anotaciones del check run del job, y por eso
`gh api repos/{owner}/{repo}/check-runs/<job-id>/annotations` las devuelve en JSON.

</details>

**4.** ¿Por qué GitHub deshabilitó `::set-output`? Y si un step hace `cat` de un archivo que llega
en un PR, ¿por qué lo rodeas con `::stop-commands::` y un token aleatorio, no fijo?

<details>
<summary>Respuesta</summary>

Porque cualquier texto que acabara impreso en el log (el título de un PR, un mensaje de commit)
podía contener `::set-output name=...::` y cambiar el output de un step. Hoy los datos van a
archivos que el runner prepara por step y que nadie más imprime: `$GITHUB_OUTPUT`, `$GITHUB_ENV`,
`$GITHUB_PATH` y `$GITHUB_STEP_SUMMARY`. Con el resto de comandos el riesgo sigue: un archivo de
un PR puede emitir anotaciones falsas o un `::add-mask::` que tape texto. `::stop-commands::<token>`
apaga la interpretación hasta ver `::<token>::`. Si el token fuera fijo, el texto no confiable
podría incluirlo y reactivar los comandos; aleatorio por run, no puede adivinarlo.

</details>

**5.** Generas un token temporal en un step y haces `echo "::add-mask::$token"`. Nombra tres
formas de que el token acabe igualmente en el log.

<details>
<summary>Respuesta</summary>

`add-mask` enmascara **desde ese momento**: si el valor se imprimió antes, ya está en el log para
siempre. Con `set -x` activo antes de enmascarar, bash imprime el comando con el valor dentro. Y
enmascara por línea: un valor de varias líneas hay que enmascararlo línea a línea. Los
`secrets.*` se enmascaran solos; `add-mask` es para lo que generas tú en el job. Las credenciales
desechables del bootcamp valen `cambiame` y no hace falta ocultarlas.

</details>

**6.** Tienes `ACTIONS_STEP_DEBUG` como variable del repo con `false` y como secreto con `true`.
¿Hay logs de depuración? ¿Qué añade cada uno de los dos interruptores, y por qué prefieres
`gh run rerun <id> --failed --debug`?

<details>
<summary>Respuesta</summary>

Sí: con el mismo nombre en variable y secreto, **gana el secreto**. `ACTIONS_STEP_DEBUG` añade
líneas `##[debug]` al log de cada step (evaluación de `if:` y expresiones, detalles internos de
las actions, tus `::debug::`); `ACTIONS_RUNNER_DEBUG` añade los logs de diagnóstico del runner y
del worker, en la carpeta `runner-diagnostic-logs` del archivo de logs. `--debug` activa los dos
**solo para ese intento**, sin crear nada en el repo; una variable o un secreto los dejan
encendidos para todos los runs, y en un repo público como `tablero` cualquiera lee esos logs. En
tus scripts, `RUNNER_DEBUG` (o `runner.debug == '1'`) dice si alguien pidió depuración.

</details>

**7.** Un job falla por una errata en el `run:` de un step del workflow. La corriges con un push
y relanzas el run fallido con `gh run rerun --failed`. Sigue en rojo. ¿Por qué?

<details>
<summary>Respuesta</summary>

Un reintento corre **el mismo YAML del mismo SHA**: no ve el arreglo que hiciste después. Sirve
para dos cosas: confirmar un fallo intermitente (el mismo commit sale verde) y repetir con
`--debug`. El arreglo lo prueba el run nuevo que crea tu push, no un reintento del viejo; y mejor
en una rama con su PR que en `main`.
Antes de reintentar, compara con el último verde del workflow (`gh run list --status success`): si
es del mismo SHA, el fallo no viene de tu código.

</details>

**8.** El job `actionlint` registra el matcher oficial y aun así un error no sale como anotación.
¿Cómo convierte un problem matcher texto en anotaciones, y qué dos causas buscas primero?

<details>
<summary>Respuesta</summary>

`::add-matcher::.github/actionlint-matcher.json` registra un JSON con un `owner`, una `severity` y
una regex cuyos grupos dan `file`, `line`, `column`, `message` y `code`. El runner pasa cada línea
de los steps siguientes del mismo job por la regex y, si casa, crea la anotación. Causas típicas:
el matcher se registró **antes del checkout**, así que la ruta no existía; o el archivo de la
coincidencia no está en el repo con esa ruta, y la anotación se descarta. Una regex propia es la
tercera: el matcher oficial del tag `v1.7.12` tolera los códigos de color de `-color`. Y
`::remove-matcher owner=actionlint::` lo retira si otra herramienta imprime líneas parecidas.

</details>

**9.** En `debug-lab.yml` escribes `run: echo "${{ inputs.note }}"`. actionlint 1.7.12 pasa en
verde y zizmor 1.31.1 termina con código 14. ¿Qué ve cada uno? ¿Y por qué la puerta usa la
persona `regular`, `--offline` y `--format=github`?

<details>
<summary>Respuesta</summary>

actionlint marca las expresiones de datos no confiables conocidas, como `github.event.*`, pero no
`${{ inputs.* }}` en `run:`; zizmor sí, con la auditoría `template-injection`, porque el valor se
sustituye **antes** de que bash lea el script. El código 14 significa que hay al menos un hallazgo
de severidad alta: el step falla sin hacer nada más. El arreglo es la regla 4: el dato por `env:` y
`"$NOTE"` en el script. En la puerta, `regular` da los mínimos falsos positivos (`pedantic` y
`auditor` son para revisar), `--offline` no necesita token ni depende de la red, y
`--format=github` emite comandos de workflow que el runner convierte en anotaciones sin matcher.
Si un hallazgo se acepta, `# zizmor: ignore[template-injection]` con su porqué, como comentario
**de YAML**: dentro de un `run: |` de varias líneas el `#` es parte del script y zizmor no lo ve.

</details>

**10.** `ci-local.sh` ejecuta un job con act 0.2.94 y termina en verde. ¿Qué no has comprobado
todavía? ¿Por qué la imagen es `catthehacker/ubuntu:act-24.04-20260815` y no `act-24.04`?

<details>
<summary>Respuesta</summary>

act ejecuta los steps en un contenedor de tu Docker, pero **ignora** `permissions`,
`concurrency`, `timeout-minutes`, `continue-on-error` y `environment:`; no crea anotaciones ni hay
`GITHUB_TOKEN` automático, y `$GITHUB_STEP_SUMMARY` solo se imprime en el log. Tampoco cuentes con
`services:`. Un permiso que falta, un filtro de rutas que no casa o un timeout corto solo los ve el
runner real, en una rama con su PR. `act-24.04` se mueve con cada publicación: tu prueba cambiaría
sin que cambies nada. El tag con fecha es la misma regla que el SHA de una action. Y en `.secrets`
solo valores de prueba, con el archivo en `.gitignore` antes de crearlo.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Depurar un run que falla | Enseña el primer fallo leído con `gh run view`, `--log-failed` y `--log \| grep`, y las líneas `##[debug]` solo en el intento 2 tras `gh run rerun --failed --debug` | 5 |
| 01 — Depurar un run que falla | `debug-lab.yml` arreglado: dos `notice` y un `warning` con archivo y línea, el token como `***`, y un run con `expected_python=3.14` en rojo con el `::error` en `api/.python-version:1` | 5 |
| 02 — actionlint y problem matchers | `lint-workflows.yml` instala actionlint 1.7.12 con `sha256sum -c` y registra el matcher del tag (checks `actionlint-checksum`, `actionlint-matcher-file`, `actionlint-matcher-registered`, `lint-paths`) | 5 |
| 02 — actionlint y problem matchers | El PR roto quedó en rojo con la anotación en la línea 16, leída desde la API, y se cerró sin fusionar (check `lint-caught-a-pr`) | 5 |
| 03 — zizmor: primer contacto | Explica qué enseña `regular`, qué añade `pedantic` y qué es `suppressed`; provocó un `template-injection` que actionlint no vio y lo corrigió con `env:` | 5 |
| 03 — zizmor: primer contacto | Job `zizmor` con 1.31.1, `--offline` y `--format=github`, y cero hallazgos en todos los workflows (checks `zizmor-pinned`, `zizmor-annotations`, `workflows-zizmor`, `lint-green-on-main`) | 5 |
| 04 — act en local | act 0.2.94 instalado tras `sha256sum -c`; `ci-local.sh` con imagen fechada y `--list` (checks `ci-local-script`, `ci-local-image`, `ci-local-list`) | 5 |
| 04 — act en local | `ci-api lint` y `lint-workflows` en verde en local, el error de ruff cazado antes del push, y `.secrets`/`.vars` con valores de prueba ignorados por git | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 08` con 15/15. Cada comprobación en rojo
resta la parte proporcional (12/15 de punto).

**Calidad manual de la capa 08 (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| El checksum de actionlint sale del campo `digest` de la release (`gh api`) y un comentario dice de dónde viene | 3 |
| `actionlint-matcher.json` es la copia exacta del tag 1.7.12 (`diff` contra el original vacío) | 2 |
| Los dos jobs de `lint-workflows.yml` son independientes: si actionlint falla, zizmor también informa | 3 |
| `ci-local.sh` falla con un mensaje claro si falta act o el workflow no existe, y avisa si la versión de act no es la fijada | 3 |
| El PR roto de la práctica 02 se cerró sin fusionar y su rama se borró | 2 |
| Ningún hallazgo de zizmor se silenció sin un comentario que diga por qué | 3 |
| Sin `TODO` en `.github/workflows/` ni en `scripts/`, y commits en Conventional Commits | 2 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log, también en `.secrets` o en `.vars` | Grave: Producto a 0 hasta rotarlo y retirarlo |
| `uses:` remota sin SHA | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}` o `${{ inputs.* }}` interpolado dentro de `run:` | Grave: −10 |
| Imagen sin tag o con `latest`, también la del runner de act | Grave: −10 |
| actionlint o act instalados sin checksum, o con `curl \| bash` | Grave: −10 |
| Hallazgo de zizmor silenciado sin motivo (`ignore` sin comentario, `\|\| true`, `continue-on-error`) | −5 |
| `ACTIONS_STEP_DEBUG` o `ACTIONS_RUNNER_DEBUG` dejado activo en el repo, como variable o secreto | −5 |
| `actionlint \|\| true` o cualquier forma de que la puerta no falle | −5 |
| zizmor sin versión fijada o sin `--offline` en la puerta | −3 |
| Job sin `timeout-minutes` | −3 por cada uno |
| `pip`, `npm` o Compose v1 en un workflow o en la documentación de tu repo | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

## 🏁 Minisimulacro de cierre de la Fase 2

Cierra las semanas 05-08 en las condiciones del examen GH-200: **60 minutos cronometrados**, sin
abrir la teoría ni buscar en la web. Cubre los dominios D1 (escribir y mantener workflows) y D2
(consumir workflows: leer runs, logs y depurar). Pon el reloj antes de leer la primera pregunta.

| Parte | Qué es | Tiempo | Puntos |
|---|---|:--:|:--:|
| A | 12 preguntas tipo test, una sola respuesta correcta | 35 min | 12 |
| B | Una tarea de depuración sobre tu `tablero` | 25 min | 8 |
| **Total** | | **60 min** | **20** |

**Aprobado: 14 puntos (70 %).** No suma a los pesos de la semana: es tu termómetro de la fase. Si
no llegas, la explicación de cada fallo te dice qué semana repasar antes de la Fase 3.

### Parte A — Preguntas tipo test (35 minutos)

Marca una opción por pregunta y apunta tus respuestas; abre las soluciones solo al final.

**A1.** Un job corre directamente en `ubuntu-24.04` (sin `container:`) con un service `postgres`
sano, sin `ports`. Los tests conectan a `localhost:5432` y fallan con `connection refused`. ¿Qué
falta?

- A) `--health-cmd` en `options`
- B) `ports: [5432:5432]` en el servicio
- C) Cambiar el host a `postgres`
- D) Un `sleep 10` antes de los tests

<details>
<summary>Solución</summary>

**B.** Un job en el runner llega al servicio por el puerto publicado en el host. El nombre
`postgres` solo resuelve desde un job en contenedor, y el servicio ya está sano, así que no es el
healthcheck. `sleep` nunca es la solución. Semana 05, teoría 03.

</details>

**A2.** El mismo servicio, pero ahora el job declara `container: python:3.13-slim`. ¿Qué
`DATABASE_URL` usa?

- A) `postgresql://tablero:cambiame@localhost:5432/tablero_ci`
- B) `postgresql://tablero:cambiame@postgres:5432/tablero_ci`
- C) `postgresql://tablero:cambiame@127.0.0.1:5432/tablero_ci`
- D) La de `job.services.postgres.ports['5432']` con `localhost`

<details>
<summary>Solución</summary>

**B.** El job es otro contenedor de la misma red y resuelve el servicio por su clave bajo
`services:`. `localhost` sería el propio contenedor del job. Semana 05, teoría 03.

</details>

**A3.** ¿Qué hace el runner con un service que declara `--health-cmd "pg_isready -U tablero -d
tablero_ci"`?

- A) Lo ejecuta antes de cada step
- B) Espera en *Initialize containers* a que esté `healthy` antes del primer step, y falla el job
  si no lo consigue
- C) Lo ejecuta solo si el job falla
- D) Nada: `options` se ignora en los runners alojados

<details>
<summary>Solución</summary>

**B.** Sin healthcheck el runner da el servicio por listo en cuanto arranca, y el primer step llega
antes que PostgreSQL. Si no llega a sano, el job falla en *Initialize containers* y tus steps no
corren. Semana 05, teorías 03 y 07.

</details>

**A4.** El workflow tiene `permissions: contents: read` en la raíz y el job `publish` declara
`permissions: packages: write`. El `actions/checkout` del job falla. ¿Por qué?

- A) `packages: write` no existe para el `GITHUB_TOKEN`
- B) Los permisos del job sustituyen a los de la raíz: el job ya no tiene `contents: read`
- C) GHCR exige un PAT
- D) El checkout necesita `contents: write`

<details>
<summary>Solución</summary>

**B.** No se suman: el bloque del job reemplaza al de la raíz. Repite `contents: read` en el job.
Semana 06, teoría 04.

</details>

**A5.** Quieres construir la imagen en cada PR y publicarla solo fuera de los PR, también al
lanzar el workflow a mano. ¿Qué pones en `push:` de `docker/build-push-action`?

- A) `${{ github.event_name == 'push' }}`
- B) `${{ github.event_name != 'pull_request' }}`
- C) `${{ github.ref == 'refs/heads/main' }}`
- D) `true`, y un `if:` en el step del build

<details>
<summary>Solución</summary>

**B.** Con `== 'push'`, `workflow_dispatch` deja de publicar. Un `if:` en el step del build hace
que en el PR no se construya nada. Semana 06, teoría 07.

</details>

**A6.** Una matriz construye `api` y `web` con `cache-from` y `cache-to` `type=gha,mode=max`, sin
`scope`. ¿Qué pasa?

- A) Funciona igual: cada imagen tiene su caché automática
- B) Cada imagen pisa el índice de caché de la otra y casi nunca hay acierto
- C) El build falla por caché duplicada
- D) Solo se cachea la etapa final

<details>
<summary>Solución</summary>

**B.** Hace falta `scope=${{ matrix.image }}`, el mismo en `cache-from` y en `cache-to`. Lo de la
etapa final es `mode=min`. Semana 06, teoría 06.

</details>

**A7.** `ci-api` tiene `paths: ["api/**"]` en `push` y en `pull_request`. Un PR tiene un commit
que toca `api/` y otro, posterior, que solo toca `web/`. Tras el segundo push al PR, ¿corre
`ci-api`?

- A) No: el último push solo trae cambios en `web/`
- B) Sí: en `pull_request` GitHub compara `base...head` y ve todo lo que cambia el PR
- C) Solo si el PR es de un fork
- D) Solo si se añade `paths-ignore`

<details>
<summary>Solución</summary>

**B.** El diff de `pull_request` es de tres puntos, contra la base de fusión; en `push` es de dos
puntos, solo lo que trae ese push. Semana 07, teoría 01.

</details>

**A8.** `concurrency` con `group: ${{ github.workflow }}-${{ github.ref }}` y
`cancel-in-progress: false`. Llegan tres pushes seguidos a `main`: A, B y C. ¿Qué runs llegan a
correr?

- A) A, B y C, en orden
- B) Solo C
- C) A y C: B queda pendiente y C lo sustituye
- D) A y B: C se descarta

<details>
<summary>Solución</summary>

**C.** En un grupo hay como mucho un run en curso y uno pendiente; el pendiente nuevo sustituye al
anterior. `cancel-in-progress` solo decide qué le pasa a A. Semana 07, teoría 06.

</details>

**A9.** Un step de `nightly.yml` hace un commit vacío y `git push` con el `GITHUB_TOKEN` para que
corra `ci`. No corre nada. ¿Qué usas en su lugar?

- A) Un PAT clásico en un secreto
- B) `workflow_dispatch` sobre `ci.yml`, con `actions: write`
- C) `git push --force`
- D) `on: push` con `branches: ['**']`

<details>
<summary>Solución</summary>

**B.** Los eventos del `GITHUB_TOKEN` no crean runs, para evitar bucles; `workflow_dispatch` y
`repository_dispatch` son las excepciones. Un PAT clásico tiene un alcance excesivo y no caduca.
Semana 07, teoría 05.

</details>

**A10.** Un step `run: uv run pytest | tee out.txt` sin `shell:` queda verde aunque fallan tests.
¿Qué lo arregla?

- A) `continue-on-error: false`
- B) `shell: bash`, que añade `-o pipefail`
- C) `if: success()`
- D) `::error::` al final del step

<details>
<summary>Solución</summary>

**B.** Sin `shell:` el step corre con `bash -e {0}` y la tubería devuelve el código de `tee`. Una
anotación de error no cambia el código de salida. Semana 08, teoría 01.

</details>

**A11.** Quieres los logs de depuración de un run fallido sin dejar nada encendido en el repo.
¿Qué haces?

- A) Crear el secreto `ACTIONS_STEP_DEBUG` con `true`
- B) `gh run rerun <id> --failed --debug`
- C) Añadir `set -x` a todos los `run:`
- D) `echo "::debug::on"` en el primer step

<details>
<summary>Solución</summary>

**B.** `--debug` activa los dos niveles solo para ese intento. El secreto o la variable valen para
todos los runs siguientes hasta que alguien los borre. Semana 08, teoría 03.

</details>

**A12.** Te falta `pull-requests: write` en un job que comenta en el PR. ¿Qué capa de pruebas lo
detecta antes?

- A) actionlint
- B) zizmor
- C) act
- D) Solo el runner real, en una rama con su PR

<details>
<summary>Solución</summary>

**D.** actionlint y zizmor leen el YAML pero no ejecutan, y act ignora `permissions`. Lo que
depende de GitHub como plataforma (permisos, filtros, servicios, timeouts) solo lo ve el runner
real. Semana 08, teoría 07.

</details>

### Parte B — Depurar un workflow roto (25 minutos)

En una rama `sim/phase-2` de tu `tablero`, crea `.github/workflows/sim-debug.yml` copiando
**tal cual** este workflow. Tiene cuatro fallos: uno lo ve actionlint, otro zizmor, otro solo el
runner real y el cuarto esconde al tercero.

```yaml
name: sim-debug

on:
  pull_request:
    paths:
      - ".github/workflows/sim-debug.yml"
  workflow_dispatch:
    inputs:
      note:
        description: "Nota para el resumen"
        type: string
        default: "simulacro"

# Mínimo privilegio: lo viste en la Semana 01 y lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  db-check:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    services:
      postgres:
        image: postgres:17.11-alpine
        env:
          POSTGRES_USER: tablero
          # Credencial desechable de CI, no un secreto.
          POSTGRES_PASSWORD: cambiame
          POSTGRES_DB: tablero_ci
        options: >-
          --health-cmd "pg_isready -U tablero -d tablero_ci"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10
    steps:
      - name: Versión del servidor
        env:
          PGPASSWORD: cambiame
        run: psql -h localhost -U tablero -d tablero_ci -tAc 'SHOW server_version;' | tee server-version.txt

  report:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    needs: [db-chek]
    steps:
      - name: Resumen
        run: |
          echo "### Nota del simulacro" >> "$GITHUB_STEP_SUMMARY"
          echo "${{ inputs.note }}" >> "$GITHUB_STEP_SUMMARY"
```

Haz commit, push y abre un PR en borrador hacia `main`. A partir de ahí, depura con lo que
aprendiste en la fase: `actionlint`, `zizmor --offline`, las anotaciones de `lint-workflows`,
`gh run view --log-failed` y `gh run view --log | grep`. No borres el healthcheck ni cambies la
imagen. Cuando creas que está, corrige con estas ocho comprobaciones, 1 punto cada una:

```bash
# 1. actionlint en verde
actionlint .github/workflows/sim-debug.yml; echo "exit $?"
# exit 0
# 2. zizmor sin hallazgos
zizmor --offline .github/workflows/sim-debug.yml; echo "exit $?"
# ... No findings to report. Good job! ...
# exit 0
# 3. report espera al job que existe
yq '.jobs.report.needs | join(",")' .github/workflows/sim-debug.yml
# db-check
# 4. Ninguna expresión dentro del run de report
yq '.jobs.report.steps[].run' .github/workflows/sim-debug.yml | grep -c '\${{' || true
# 0
# 5. La tubería falla si falla psql
yq '.jobs.db-check.steps[0].shell' .github/workflows/sim-debug.yml
# bash
# 6. PostgreSQL publicado en el runner
yq '.jobs.db-check.services.postgres.ports[0]' .github/workflows/sim-debug.yml
# 5432:5432
# 7. sim-debug en verde en la rama
gh run list --workflow sim-debug.yml --branch sim/phase-2 --limit 1 --json conclusion --jq '.[0].conclusion'
# success
# 8. La puerta en verde en la rama
gh run list --workflow lint-workflows.yml --branch sim/phase-2 --limit 1 --json conclusion --jq '.[0].conclusion'
# success
```

<details>
<summary>Los cuatro fallos y una solución de referencia</summary>

1. **`needs: [db-chek]`**. GitHub no llega a crear jobs: el run falla por un archivo de workflow
   inválido, y actionlint lo dice antes del push (`job "report" needs job "db-chek" which does not
   exist`). Semana 02 y Semana 08, teoría 04.
2. **`${{ inputs.note }}` dentro de `run:`**. actionlint 1.7.12 no lo marca; zizmor sí
   (`template-injection`, severidad alta, código 14) y su anotación aparece en el PR gracias a
   `--format=github`. El dato llega por `env:`. Semana 08, teoría 05.
3. **`| tee` sin `shell: bash`**. Arreglados los dos primeros, `sim-debug` sale **verde**, pero
   `gh run view <id> --log | grep -i 'connection refused'` enseña que `psql` nunca conectó: `tee`
   devuelve 0. Es un falso verde. Con `shell: bash` (pipefail) el step pasa a rojo y el fallo de
   verdad aparece. Semana 08, teoría 01.
4. **Falta `ports`**. El servicio está sano, pero el job corre en el runner y `localhost:5432` no
   llega a ningún sitio sin publicar el puerto. Semana 05, teoría 03.

```yaml
    services:
      postgres:
        # ... image, env y options sin cambios ...
        # Sin publicar el puerto, localhost:5432 da connection refused desde el runner.
        ports:
          - 5432:5432
    steps:
      - name: Versión del servidor
        # bash con pipefail: sin él, tee devuelve 0 y el step queda verde aunque psql falle.
        shell: bash
        env:
          PGPASSWORD: cambiame
        run: psql -h localhost -U tablero -d tablero_ci -tAc 'SHOW server_version;' | tee server-version.txt

  report:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    needs: [db-check]
    steps:
      - name: Resumen
        env:
          # En pull_request inputs está vacío: el valor por defecto cubre ese caso.
          NOTE: ${{ inputs.note || 'simulacro' }}
        run: |
          echo "### Nota del simulacro" >> "$GITHUB_STEP_SUMMARY"
          echo "$NOTE" >> "$GITHUB_STEP_SUMMARY"
```

Si viste el verde del punto 3 y lo diste por bueno, repasa la teoría 01 de esta semana: es el
fallo que más cuesta en producción. Cuando termines, cierra el PR sin fusionarlo y borra la rama.

</details>

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 08 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
