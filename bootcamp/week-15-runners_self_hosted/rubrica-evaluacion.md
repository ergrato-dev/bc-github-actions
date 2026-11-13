# Rúbrica de evaluación — Semana 15

> Runners propios. Se aprueba con un **mínimo del 70 % en cada evidencia**, no en el
> promedio.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de la capa 15 |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** Tienes un único runner propio, con las etiquetas `self-hosted`, `Linux`, `X64` y
`tablero-lab`, online y libre. ¿Cuáles de estos jobs recoge y por qué?
(a) `runs-on: self-hosted`; (b) `runs-on: [self-hosted, linux]`;
(c) `runs-on: [self-hosted, tablero-lab, gpu]`; (d) `runs-on: ubuntu-24.04`. ¿Qué le pasa al
que no recoge nadie?

<details>
<summary>Respuesta</summary>

Una lista en `runs-on` exige **todas** sus etiquetas; un runner con más etiquetas de las pedidas
también vale. Recoge (a) y (b): las dos son un subconjunto de las suyas. No recoge (c), porque le
falta `gpu`, ni (d): `ubuntu-24.04` es una etiqueta de los runners alojados por GitHub, y ese job
va a uno de ellos.

El job (c) se queda en cola esperando un runner online y libre con las tres etiquetas. Si ninguno
aparece en 24 horas, falla. Por eso `tablero` usa una etiqueta propia y única, `tablero-lab`, y
no se fía de `self-hosted` sola: (a) lo recogería cualquier runner propio que tuvieras.
Teoría 03.

</details>

**2.** Registras un runner con `config.sh --labels tablero-lab` y otro con `generate-jitconfig`
pasando solo `labels[]=tablero-lab`. Un job pide `runs-on: [self-hosted, tablero-lab]`. ¿Lo
pueden recoger los dos? ¿Qué etiquetas tiene cada uno, de qué tipo son en la API y qué hace
`--no-default-labels`?

<details>
<summary>Respuesta</summary>

Solo el primero. `config.sh` añade tres etiquetas automáticas, `self-hosted`, el sistema
operativo (`Linux`) y la arquitectura (`X64` o `ARM64`), que la API devuelve con
`type: read-only`, más las de `--labels`, con `type: custom`. Con `--no-default-labels` no pone
ninguna de las tres automáticas.

Un runner JIT no pasa por `config.sh`: sus etiquetas son **exactamente** las que envías a
`generate-jitconfig`, sin ninguna por defecto. Con solo `tablero-lab` le falta `self-hosted` y el
job no casa. Por eso `jit-runner.sh` pasa las dos, y el check `jit-runner-labels` lo comprueba.
Teoría 03.

</details>

**3.** Compara un runner persistente, uno registrado con `config.sh --ephemeral` y uno JIT en
tres cosas: cuántos jobs acepta, qué credencial llega a la máquina y qué encuentra el siguiente
job en `_work`. ¿Por qué el JIT de `tablero` corre además dentro de un contenedor con `--rm`?

<details>
<summary>Respuesta</summary>

| | Persistente | `--ephemeral` | JIT |
|---|---|---|---|
| Jobs | Muchos, uno tras otro | Uno | Uno como mucho |
| Credencial | Token de registro y luego `.credentials` mientras exista | Token de registro y luego `.credentials` | Solo la config JIT, de un solo uso |
| `_work` del job anterior | Lo hereda el siguiente job | Queda en la máquina | Queda en la máquina |

El JIT además lo registra la API desde fuera, así que la máquina nunca ve un token de registro.
Pero "efímero" describe al **runner**, no a la máquina: al darlo de baja, `_work`, `_tool` y
los archivos del usuario siguen en el disco, y un runner nuevo en esa máquina los encuentra. Lo
viste en la práctica 01, con `state=inherited`. Lo que garantiza que nada pasa al siguiente job
es destruir la máquina: el contenedor con `--rm` desaparece al salir `run.sh`, con todo lo que el
job escribió. Teoría 04.

</details>

**4.** Un compañero propone crear un runner group "solo para `tablero`" en tu organización del
bootcamp y registrar ahí un runner de organización. ¿Qué problema tiene en una org Free? ¿Cómo
consigue `tablero` el mismo efecto, y qué hueco cierra la política de runners de repositorio?

<details>
<summary>Respuesta</summary>

Toda organización tiene un grupo por defecto, pero la documentación solo garantiza crear grupos
adicionales en el plan Team. En Free no puedes crear un grupo que solo vea `tablero`: un runner
de organización quedaría al alcance de lo que permita el grupo por defecto, no de un único repo.

`tablero` usa un runner **de repositorio**, registrado en `<tu-org>/tablero`: ningún otro repo
puede pedirle nada, sin depender del plan. El hueco que queda es que el admin de **cualquier**
repo de la org puede registrar runners de repositorio en el suyo. La política
*Repository-level self-hosted runners* en *Selected repositories* con solo `tablero`
(`enabled_repositories: selected`) lo cierra; es el check `org-self-hosted-selected`.

En Team, el grupo sí sería la herramienta: `visibility: selected`, `allows_public_repositories`
(por defecto `false`, solo repos privados) y `selected_workflows` para limitarlo a
`lab.yml@refs/heads/main`. Teoría 06.

</details>

**5.** `tablero` es público. Describe cómo alguien sin permisos en tu org conseguiría ejecutar
código en tu máquina a través del runner, aunque `lab.yml` solo escuche `workflow_dispatch`.
¿Qué capa lo frena de verdad, y por qué `first_time_contributors` no basta?

<details>
<summary>Respuesta</summary>

Hace un fork, **añade** en él un workflow con `on: pull_request` y
`runs-on: [self-hosted, tablero-lab]` y abre un PR. Para `pull_request`, GitHub usa los workflows
del commit del PR: su archivo cuenta como si estuviera en tu repo. Que `lab.yml` sea
`workflow_dispatch` solo protege `main`; el atacante trae su propio workflow. Lo que busca no es
el `GITHUB_TOKEN` (de solo lectura y sin secretos en un PR de fork), sino la máquina: tu red,
persistencia, tu CPU.

Lo frena la aprobación para **todos** los contribuidores externos
(`all_external_contributors`): ningún workflow de un PR de fork corre hasta que un mantenedor lo
aprueba. Con `first_time_contributors` un atacante paciente manda primero un PR inocente y,
cuando ya no es nuevo, el malo. Aprobar es aceptar ejecutar ese código: un PR de fork que toca
`.github/` y menciona `self-hosted` o `tablero-lab` no se aprueba. Por eso GitHub recomienda
runners propios solo en repos privados. Teoría 07.

</details>

**6.** Para que los jobs puedan hacer `docker build`, alguien añade al `docker run` del runner
`-v /var/run/docker.sock:/var/run/docker.sock` y dice: "el contenedor sigue con
`--cap-drop ALL` y `no-new-privileges`, no pasa nada". ¿Por qué se equivoca?

<details>
<summary>Respuesta</summary>

Quien habla con el socket habla con el demonio de Docker, y el demonio es root en tu máquina. El
job no necesita salir de su contenedor: le pide al demonio **otro**, por ejemplo con `/` del host
montado, y ese segundo contenedor se crea con las opciones del demonio, no con las tuyas. Tu
`--cap-drop ALL` y tu `no-new-privileges` no le afectan, y el job lee y escribe tu disco como
root. Además puede inspeccionar los demás contenedores y ejecutar comandos dentro de ellos.

El precio de no montarlo es que ese runner no sirve para `services:`, `container:` ni
`docker build`; el job de `tablero-lab` solo corre tests unitarios. Si hiciera falta Docker, la
respuesta es una máquina dedicada, no el socket del host. Es el TODO 6 del starter y el check
`runner-container-isolated`. Teoría 05, práctica 03 paso 4.

</details>

**7.** El `FROM` de `ops/runner/Dockerfile` fija `actions-runner:2.338.2` por digest, y el
contenedor se borra después de cada job. ¿Qué pasa con la auto-actualización del runner en ese
montaje? ¿Qué ocurre si dejas la imagen tal cual mucho tiempo después de que salga una versión
nueva, y qué pieza de `tablero` lo evita?

<details>
<summary>Respuesta</summary>

El runner se actualiza solo por defecto, pero en un contenedor desechable la actualización se
perdería con el contenedor: la siguiente vuelta del bucle arranca otra vez la versión del `FROM`.
La versión es la que fija la imagen, y actualizarla es cosa tuya.

GitHub da **63 días** desde que hay una versión nueva del runner; pasado ese plazo, el runner deja
de recibir jobs y `lab.yml` se queda en cola. Lo evita Dependabot: el ecosistema `docker` vigila
también `/ops/runner` (check `dependabot-runner-image`) y propone un PR con el tag y el digest
nuevos. Fijar por digest no es quedarse congelado: es cambiar de versión con un PR revisable.
Teoría 02 y 05, práctica 03 paso 2.

</details>

**8.** Lanzas `lab.yml` con `gh workflow run` un viernes, pero `jit-runner.sh` no está corriendo
y no hay ningún runner `tablero-lab` registrado. ¿En qué estado queda el run y cuánto tiempo?
¿Y si arrancas el bucle el lunes? ¿Qué hace GitHub con un runner JIT que quedó offline al parar el
bucle con Ctrl-C?

<details>
<summary>Respuesta</summary>

El job queda en cola esperando un runner online y libre con `self-hosted` y `tablero-lab`. Un job
de runner propio puede esperar **como mucho 24 horas**; si ninguno lo recoge, falla. El lunes ya
habrá fallado: el bucle no lo rescata y tienes que relanzarlo con el runner ya escuchando, como
en la práctica 04 paso 4.

Si paras el bucle con un runner JIT registrado y sin job, queda offline. GitHub borra un runner
efímero que no se conecta en un día (uno persistente, a los 14), pero no esperes: lo borras con
`DELETE repos/{owner}/{repo}/actions/runners/{id}`, como en la práctica 02 paso 5. El check
`runners-ephemeral` exige que no quede ninguno persistente y que el del último `lab.yml` ya no
exista. Teorías 02, 03 y 04.

</details>

**9.** `jit-runner.sh` pasa la configuración con `-e ACTIONS_RUNNER_INPUT_JITCONFIG` y
`./run.sh`, no con `./run.sh --jitconfig "$cfg"`. ¿Qué gana con eso? ¿Queda la config
completamente oculta en tu máquina? ¿Qué valor tiene esa config si se filtra antes del job y
después?

<details>
<summary>Respuesta</summary>

Un argumento se ve en `ps` y en la línea de comandos del contenedor. El runner lee cualquier
argumento de una variable `ACTIONS_RUNNER_INPUT_<ARG>`, la **quita de su entorno** antes de lanzar
nada y enmascara `jitconfig` como secreto en los logs: los procesos del job no la heredan y no
pueden leerla de `env`.

No queda oculta del todo: `docker inspect` sí enseña las variables con las que arrancó el
contenedor, así que quien pueda hablar con tu Docker puede verla. Por eso la config nunca se
escribe en un archivo, ni se hace `echo`, ni se usa `set -x`.

Es una credencial de un solo uso. Antes del job, quien la tenga puede conectarse como ese runner
y recibir el job que le toque; después ya no vale para nada: un runner con una config usada
termina con `Runner listener exit with terminated error`. Teoría 04, práctica 02 paso 3.

</details>

**10.** Enumera quién puede hacer que un job corra en tu runner `tablero-lab`: (a) otro repo de
tu org; (b) un desconocido con un PR desde un fork; (c) un colaborador con permiso de escritura en
`tablero`; (d) una action de terceros que usa `lab.yml`. Para cada uno, di qué capa lo frena o
por qué no lo frena ninguna.

<details>
<summary>Respuesta</summary>

(a) Nadie fuera de `tablero`: el runner es de repositorio, y la política de la org solo permite
runners de repositorio en `tablero`, así que otro repo no puede registrar uno propio.

(b) Su workflow no corre sin tu aprobación (`all_external_contributors`); el riesgo que queda eres
tú aprobando sin leer `.github/`.

(c) Ninguna capa técnica de esta semana: puede lanzar `lab.yml` o cambiarlo en `main`. Lo
reducen los rulesets y la revisión obligatoria de la Semana 18.

(d) Corre dentro del job, en tu runner y con todo su alcance. La frenan las actions por SHA y
`uv sync --locked` de semanas anteriores, y el contenedor endurecido y desechable acota el daño a
ese job, aunque no lo que alcance por la red mientras dura.

Además, el runner solo existe mientras tú arrancas el bucle: fuera de ese rato, nadie recoge
nada. Teoría 07.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Primer runner propio | Política de la org en *Selected* con solo `tablero`, aprobación para todos los contribuidores externos y `tablero-lab` en `.github/actionlint.yaml` (checks `org-self-hosted-selected`, `fork-pr-approval`) | 5 |
| 01 — Primer runner propio | Enseña con `runner-probe.yml` que el segundo job en el runner persistente hereda lo del primero (`state=inherited`) y borra después el runner persistente | 5 |
| 02 — Runner JIT efímero en Docker | `jit-runner.sh` pide la config a `generate-jitconfig` en el grupo por defecto con `self-hosted` y `tablero-lab`, y la entrega por `ACTIONS_RUNNER_INPUT_JITCONFIG` (checks `jit-not-registration-token`, `jit-runner-labels`, `jitconfig-by-env`) | 5 |
| 02 — Runner JIT efímero en Docker | Con el bucle en marcha, dos jobs seguidos dan `state=clean` en runners distintos; al parar, borra el runner JIT que quedó offline | 5 |
| 03 — Contenedor endurecido e imagen al día | Imagen oficial fijada por tag y digest, Dependabot sobre `/ops/runner` y contenedor con `--rm`, sin capacidades, sin escalada, con límites y sin socket ni volúmenes (checks `runner-image-pinned`, `dependabot-runner-image`, `runner-container-locked`, `runner-container-isolated`) | 5 |
| 03 — Contenedor endurecido e imagen al día | Enseña `sudo` bloqueado por `no-new-privileges` y la demostración del socket de Docker, y explica por qué el segundo contenedor ignora tus opciones; borra los contenedores de la demostración | 5 |
| 04 — El workflow del runner propio | `lab.yml` solo con `workflow_dispatch`, único job `self-hosted`, `runs-on: [self-hosted, tablero-lab]`, `contents: read`, timeout de 30 o menos, sin secretos y linters limpios (checks `lab-dispatch-only`, `self-hosted-only-in-lab`, `lab-runs-on`, `lab-job-limits`, `workflows-lint`) | 5 |
| 04 — El workflow del runner propio | `lab.yml` en verde en el último commit de `main` en un runner `tablero-lab`, `runner-probe.yml` borrado y ningún runner registrado al acabar (checks `lab-green-on-own-runner`, `runners-ephemeral`) | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 15` con 16/16. Cada comprobación en rojo
resta la parte proporcional (0,75 puntos).

**Calidad manual de la capa 15 (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| El digest del `Dockerfile` se sacó con `docker buildx imagetools inspect` y es el del índice del tag que dice la línea | 3 |
| La config JIT nunca toca el disco ni el historial: no hay `echo` de ella, ni archivo temporal, ni `set -x` en el script | 3 |
| Los límites de memoria y CPU tienen sentido para tu máquina, y un comentario dice por qué | 2 |
| El runner persistente de la práctica 01 está borrado, y también los JIT que quedaron offline al parar el bucle | 2 |
| El workflow de prueba de las prácticas (`runner-probe.yml`) está borrado de `main` | 2 |
| `lab.yml` no usa secretos ni sube permisos: lo que corre en tu máquina no recibe más de lo que necesita | 2 |
| Commits en Conventional Commits, uno por mecanismo (`ci: add jit runner in docker`, `ci: run unit tests on self-hosted runner`…) | 2 |
| Sin `TODO` en el repo | 2 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log | Grave: Producto a 0 hasta rotar el secreto y retirar el log |
| Config JIT o token de registro comiteado, guardado en un archivo del repo o impreso en un log | Grave: Producto a 0 hasta borrar el runner con la API, retirar el commit o el log y registrar uno nuevo |
| `pull_request_target` con checkout del head del PR | Grave: −10 |
| Runner propio al alcance de PRs de forks: un workflow con `pull_request*` que pide `self-hosted`, o una política de aprobación distinta de `all_external_contributors` | Grave: −10 |
| `uses:` remota sin SHA, o con un SHA copiado que no pertenece al repo oficial | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}`, `github.head_ref`, `inputs.*`, `secrets.*` o `vars.*` interpolado dentro de `run:` | Grave: −10 |
| Imagen sin tag o con `latest`, incluido el `FROM` del runner | Grave: −10 |
| Contenedor del runner con `--privileged`, el socket de Docker montado o `--network host` | −5 |
| Runner persistente registrado en `tablero` al entregar | −5 |
| Runners de repositorio permitidos en toda la org (*All repositories*) | −5 |
| `self-hosted` sola en `runs-on`, sin la etiqueta propia | −3 |
| Job con `runs-on` sin `timeout-minutes` | −3 por cada uno |
| `pip`, `npm` o Compose v1 en un workflow o en la documentación de tu repo | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 15 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
