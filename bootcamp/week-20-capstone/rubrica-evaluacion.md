# Rúbrica de evaluación — Semana 20

> Capstone: un pipeline de producción defendido. Se aprueba con un **mínimo del 70 % en cada
> evidencia**, no en el promedio. Es la última semana: cierra la Fase 6 y el bootcamp con la
> defensa del capstone y un simulacro final tipo GH-200.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de la capa 20 + defensa del capstone |

El [simulacro final tipo GH-200](#-simulacro-final-tipo-gh-200) no suma a los pesos: es tu
termómetro antes de reservar el examen.

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** Un equipo te enseña su pipeline: `release.yml` genera SBOM y attestations de procedencia
de cada imagen, y `deploy.yml` despliega `ghcr.io/<tu-org>/app:1.4.0` con `helm upgrade`. ¿Qué
criterio de producción incumple? ¿Por qué firmar no basta, y qué cambiarías en `deploy.yml`?

<details>
<summary>Respuesta</summary>

Incumple el criterio 6, **despliegue verificado y reversible**, y deja sin efecto el 5. Una firma
no protege a nadie si nadie la comprueba: si alguien sube otra imagen con el tag `1.4.0`, o
`deploy.yml` recibe un tag que `release.yml` nunca construyó, el clúster la ejecuta igual. Un tag
se puede mover; la attestation habla de un digest concreto.

El arreglo es el de `tablero` en la Semana 17: el primer job de `deploy.yml` ejecuta
`gh attestation verify` con `--repo` y `--signer-workflow` apuntando a `release.yml`, saca de la
attestation el digest verificado y Helm despliega `imagen@sha256:…`, no el tag. Así lo que llega
al clúster es exactamente lo que firmó tu pipeline. Teoría 01, tabla de los siete criterios.

</details>

**2.** Un compañero quiere integrar un componente Python cuyos tests de integración viven en
`tests/it/` y que no tiene módulo `migrate`. Propone copiar `ci-api.yml` y cambiar las rutas.
¿Qué le respondes? ¿Qué dos caminos tiene, y cuál descartas?

<details>
<summary>Respuesta</summary>

Copiar el job funciona el primer día y diverge al tercer cambio: dos copias con versiones de ruff
o pasos de caché distintos y nadie sabe cuál es la buena. Es lo que el capstone demuestra que no
hace falta.

`_python.yml` tiene un contrato: los inputs (`working-directory`, `package`, `coverage-min`,
`integration`) y lo que asume en sus steps (`uv sync --locked`, `tests/unit`, `tests/integration`
y `python -m <package>.migrate` antes de la integración). Los dos caminos válidos son **adaptar
el componente** (mover los tests a `tests/integration` y añadir un `migrate`) o **ampliar el
reutilizable** con un input nuevo, por PR al central y con una release nueva que después adoptan
los repos. Se descarta la copia. Teoría 02, "El contrato de `_python.yml`".

</details>

**3.** El job `worker` de `ci-worker.yml` no tiene `runs-on` ni `timeout-minutes`. ¿Es un fallo
de la política de la Semana 07 ("timeout en todo job")? ¿Dónde está el timeout de lo que corre, y
cómo trata ese caso `audit-workflows.sh`?

<details>
<summary>Respuesta</summary>

No es un fallo. Un job que **llama a un reutilizable** no corre en un runner: solo delega, así
que no tiene `runs-on` y no admite `timeout-minutes`. Los tres jobs de `_python.yml` (lint, tests
unitarios e integración) traen su propio runner y su propio `timeout-minutes`, y son los que
consumen tiempo.

Por eso la regla `timeout` de la política solo mira jobs con `runs-on`. Si exigiera timeout a
todos los jobs, daría falsos positivos en cada llamada a un reutilizable, y una regla que da
falsos positivos acaba ignorada. Teoría 03, "Dos excepciones que no son concesiones".

</details>

**4.** `scripts/changed-areas.sh` marca `worker=true` si cambia `worker/` **o**
`api/migrations/`. ¿Por qué la segunda ruta? Da un ejemplo concreto de PR que pasaría en verde
sin ella.

<details>
<summary>Respuesta</summary>

El worker no tiene esquema propio: borra filas de la tabla `tasks`, cuyo esquema vive en
`api/migrations/`, y `tablero_worker.migrate` aplica esas mismas migraciones antes de sus tests
de integración. Una migración que renombra `created_at` rompe la consulta del worker sin tocar
un archivo de `worker/`.

Si el área solo mirara su carpeta, ese PR correría `api` (que no usa la columna de la misma
forma) y no correría `worker`: `ci-gate` saldría en verde y el fallo aparecería en producción.
Un área se define por **de qué depende** el componente, no por dónde está su código. Teoría 02,
"El área: qué rutas la disparan".

</details>

**5.** Añades el job `worker` a `ci.yml` con su `needs: changes` y su `if:`, pero olvidas añadir
`worker` a `ci-gate.needs`. Un PR rompe un test del worker. ¿Qué ves en el PR, qué hace la merge
queue y por qué?

<details>
<summary>Respuesta</summary>

En el PR ves el job `worker / Worker / Tests unitarios` en rojo, pero `ci-gate` en verde, porque
no lo espera. La merge queue **fusiona igual**: el ruleset de `main` solo exige `ci-gate`, que es
el único check requerido, y `ci-gate` solo mira los jobs de su `needs`.

Es el fallo más probable de la práctica 01 y la razón del coste que anotas en la decisión de un
único check: `ci-gate.needs` hay que mantenerlo a mano al añadir un área. El check
`ci-calls-worker` lo comprueba en `tablero`; en un repo sin él, solo lo para la revisión. Teoría
02, "`ci.yml`: cuatro cambios", y teoría 04, "Decisiones".

</details>

**6.** Todos los workflows de un repo tienen `permissions:` en la raíz y pasan actionlint, zizmor
y tu política. Aun así, la auditoría marca un riesgo en la capa de **ajustes**. Pon un ejemplo de
lo que se puede escapar ahí, explica por qué ninguna de las tres herramientas lo ve y cómo lo
compruebas.

<details>
<summary>Respuesta</summary>

Un ejemplo: el permiso por defecto del `GITHUB_TOKEN` de la org en `write`, o la aprobación de
PRs de forks relajada a "solo quien contribuye por primera vez", o la retención por encima de lo
decidido. Ninguno está en un archivo del repo: son ajustes de la org y del repo, y actionlint,
zizmor y tu política solo leen archivos.

El permiso por defecto importa aunque hoy todos los workflows tengan `permissions:`: el día que un
workflow nuevo lo olvide, hereda ese valor. Se comprueba leyéndolos por API:
`gh api orgs/<tu-org>/actions/permissions/workflow --jq .default_workflow_permissions` (`read`),
`.../fork-pr-contributor-approval --jq .approval_policy` (`all_external_contributors`) y
`.../artifact-and-log-retention --jq .days` (`14`), con la fecha en la sección de evidencias.
Teoría 03, "Las cuatro capas".

</details>

**7.** Esta expresión de yq tenía que listar los `uses:` de jobs y de steps sin nulos:
`.jobs[] | .uses, (.steps[]? | .uses) | select(. != null)`. ¿Qué imprime en realidad y por qué?
¿Qué consecuencia tendría en `audit-workflows.sh`?

<details>
<summary>Respuesta</summary>

En yq la coma tiene **menos precedencia** que la tubería, así que se lee como
`(.jobs[] | .uses), ((.steps[]? | .uses) | select(. != null))`. La primera mitad imprime el
`uses` de cada job, `null` incluido para los que tienen `runs-on`. La segunda se aplica a la raíz
del documento, que no tiene `steps`, y no imprime nada.

En la política, los `null` se tomarían por `uses:` sin fijar (falsos positivos) y, peor, los
`uses:` de los steps desaparecerían sin error: un `actions/checkout@v7` por tag pasaría la
auditoría. La corrección es agrupar: `.jobs[] | (.uses, (.steps[]? | .uses)) | select(. != null)`.
Por eso el script se prueba contra un repo con un fallo de cada regla (check `audit-script`).
Teoría 03, "La trampa de yq".

</details>

**8.** La auditoría encuentra tres imágenes sin digest en `actions-tablero` v1.0.0. ¿Por qué no
las corriges sobreescribiendo esos archivos en `tablero`? ¿Por qué publicas v1.1.0 como release
nueva y mueves **todas** las referencias de `tablero`, también las que no usan esas imágenes?

<details>
<summary>Respuesta</summary>

Porque el código está en el central: `_python.yml` y `sql-lint/Dockerfile` se ejecutan desde
`actions-tablero`, no desde `tablero`. Copiar el arreglo en `tablero` crea dos fuentes de verdad,
y el siguiente repo que llame al central hereda el fallo. Se corrige con un PR al central.

Release nueva porque v1.0.0 es **inmutable** (Semana 11): su tag no se puede mover, y eso es lo
que garantiza a quien la consume que no cambia bajo sus pies. Y todas las referencias porque
mezclar dos commits del central en un repo es mezclar dos políticas: un `ci-api` en v1.0.0 seguiría
usando `postgres` sin digest. La prueba es una sola línea en
`grep -rhoE 'actions-tablero/[^@]+@[0-9a-f]{40}' .github | sed 's/.*@//' | sort -u`. Teoría 03,
"Corregir el central".

</details>

**9.** En la sección de riesgos de un documento de defensa lees "El pipeline podría ser más
seguro" y, en evidencias, cinco enlaces a runs de hace dos meses. ¿Qué dos problemas tiene y cómo
los reescribes?

<details>
<summary>Respuesta</summary>

El riesgo es **vago**: no dice qué falta, por qué se acepta ni qué lo cerraría, así que nadie lo
puede discutir. Uno concreto: "Dependabot no actualiza el digest de `postgres` en `_python.yml`
del central; lo reviso a mano en cada release del central". O: "El chart no despliega el worker;
lo cerraría un CronJob en `deploy/k8s` con su RBAC".

Las evidencias **han caducado**: con la retención de 14 días de `tablero` (Semana 19), un run de
hace dos meses ya no existe y el enlace da `not found`. Las evidencias se eligen regenerables y se
dice cómo: "se regenera con `gh workflow run ci.yml --ref main`", y se regeneran antes de cada
defensa. Teoría 04, "Riesgos aceptados" y "Mantener el documento vivo".

</details>

**10.** Quieres que `smoke-production` sea igual que `smoke-staging` pero con
`timeout-minutes: 10`, y escribes `smoke-production: { <<: *smoke, timeout-minutes: 10 }`. ¿Qué
pasa? ¿Qué sí puedes hacer con anclas en un workflow y qué usas para lo demás?

<details>
<summary>Respuesta</summary>

No funciona: `<<` es la **clave de fusión** de YAML y GitHub no la admite, aunque la guía del
examen la mencione. actionlint lo rechaza con `GitHub Actions does not support YAML merge key "<<"
[syntax-check]`.

Desde el 18 de septiembre de 2025 sí admite **anclas** (`&nombre`) y **alias** (`*nombre`): un
alias repite un nodo entero tal cual (un `env`, un step, un job), y el ancla tiene que ir antes que
el alias en el mismo archivo. Para variaciones ("igual pero con otro timeout") usas una matriz o un
reutilizable con inputs; para compartir entre archivos o repos, un reutilizable o una action,
porque un ancla no cruza archivos. Y zizmor 1.31.1 avisa con un `WARN` cuando un archivo las usa.
Teoría 05, "Anclas y alias de YAML".

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Integrar el worker | `worker/` completo; `ci-worker.yml` sin steps, por SHA y con integración; área `worker` con `api/migrations/`; `ci.yml` con output, job, `ci-gate.needs` y `structure`; un `ci` completo en verde sobre el último commit de `main` (checks `worker-component`, `ci-worker-reusable-only`, `changed-areas-worker`, `ci-calls-worker`, `ci-full-run-green`) | 5 |
| 01 — Integrar el worker | Enseña el commit de prueba en `api/migrations/` que marca `worker=true`, y los tres jobs `worker / Worker / …` del run completo con su enlace | 5 |
| 02 — Imagen y release del worker | Base y uv por digest; `images.yml` con `worker/**` y el job `worker` en el resumen; la matriz de `release.yml`; Dependabot en `uv` y `docker`; attestations de procedencia y SBOM verificadas (checks `worker-base-by-digest`, `images-worker`, `release-worker`, `dependabot-worker`, `worker-image-attested`) | 5 |
| 02 — Imagen y release del worker | Enseña cómo sacaste cada digest (`docker buildx imagetools inspect`), el PR de release fusionado por la cola y la salida de `gh attestation verify` del worker con `--signer-workflow` | 5 |
| 03 — Auditoría completa | `audit-workflows.sh` con las seis reglas, salida `ruta: regla: detalle` y código 1; `tablero` y el central v1.1.0 con `0 hallazgos`; todas las referencias en v1.1.0; job `policy` en `lint-workflows.yml`; actionlint y zizmor limpios (checks `audit-script`, `audit-clean`, `central-clean`, `central-pinned-v1.1.0`, `audit-in-ci`, `workflows-lint`) | 5 |
| 03 — Auditoría completa | Enseña los tres hallazgos del central v1.0.0, el PR que los corrige, la release v1.1.0 inmutable, zizmor online sobre los dos repos y los ajustes leídos por API con fecha | 5 |
| 04 — Defensa del pipeline | `docs/pipeline.md` con las cinco secciones y al menos tres runs, todos en verde (check `defense-doc`) | 5 |
| 04 — Defensa del pipeline | El ensayo cronometrado hecho, con la lista de preguntas en las que tuviste que buscar la prueba y lo que reforzaste después en el documento | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (10 puntos)**: `./scripts/check-week.sh 20` con 17/17. Cada comprobación en rojo
resta la parte proporcional (10/17 de punto).

**Calidad manual de la capa 20 (10 puntos)**:

| Criterio | Puntos |
|---|:--:|
| El worker no tiene CI propio: `ci-worker.yml` solo llama al central, y si algo faltaba se añadió allí con una release | 2 |
| Cada regla de `audit-workflows.sh` tiene su porqué escrito (comentario o documento) y sale de una regla del bootcamp | 2 |
| El modelo de amenazas tiene al menos cuatro activos, y cada defensa baja a un archivo, un ajuste o una regla de la política | 2 |
| Tres decisiones con su alternativa descartada y su coste; al menos dos riesgos aceptados concretos, con qué los cerraría | 2 |
| Cada evidencia dice qué demuestra y cómo se regenera; el documento se lee en diez minutos sin abrir un YAML | 2 |
| **Total** | **10** |

**Defensa del capstone (10 puntos)**: la puntuación de la
[defensa](#-defensa-del-capstone), sobre 30, dividida entre 3.

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log | Grave: Producto a 0 hasta rotarlo y retirar el commit o el log |
| `pull_request_target` con checkout del head del PR | Grave: −10 |
| Runner propio al alcance de PRs de forks: un workflow con `pull_request*` o `merge_group` que pide `tablero-runners` | Grave: −10 |
| `uses:` remota sin SHA, o con un SHA copiado que no pertenece al repo oficial | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}`, `github.head_ref`, `inputs.*`, `secrets.*` o `vars.*` interpolado dentro de `run:` | Grave: −10 |
| Imagen sin tag o con `latest` | Grave: −10 |
| Una evidencia de `docs/pipeline.md` que enlaza un run en rojo presentado como verde, o una afirmación inventada en la defensa | Grave: −10 |
| `ci-worker.yml` con steps propios o un job copiado de `ci-api.yml` | −5 |
| `worker` fuera de `ci-gate.needs` | −5 |
| Referencias de `tablero` a dos commits distintos del central | −5 |
| `audit-workflows.sh` que imprime hallazgos y sale con 0 | −5 |
| Job con `runs-on` sin `timeout-minutes` | −3 por cada uno |
| `pip`, `npm` o Compose v1 en un workflow o en la documentación de tu repo | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

## 🎤 Defensa del capstone

La defensa es la prueba de que entiendes el pipeline, no solo de que funciona. Hazla con alguien
que no haya visto `tablero` (un compañero, otra persona del bootcamp) o, si estudias solo,
grábate y puntúate después con esta tabla. Antes de empezar, regenera las evidencias (práctica 04,
paso 3) y deja abierta una terminal en `~/code/tablero` con `GH_REPO` exportada.

### Guion cronometrado (25 minutos)

| Minuto | Bloque | Qué cuentas | Apoyo permitido |
|:--:|---|---|---|
| 0-2 | Mapa | El camino de un cambio, de un PR a production; `ci-gate` como único check; cómo entró el worker | Solo el mapa de `docs/pipeline.md` |
| 2-5 | Amenazas | Los cuatro activos (o más), de qué los proteges y dónde está cada defensa | La tabla del documento |
| 5-8 | Decisiones | Tres decisiones con su porqué, lo que descartaste y lo que pagas | El documento |
| 8-10 | Riesgos y evidencias | Lo que no cubre el pipeline y qué lo cerraría; qué demuestra cada run | El documento |
| 10-25 | Preguntas | Las diez de abajo, unos 90 segundos cada una | Terminal para lanzar la prueba |

Reglas: **ningún YAML abierto** en la exposición, **dos frases por respuesta** y la prueba si te
la piden. "No lo sé, lo compruebo así" con el comando correcto es una respuesta válida; inventar no
lo es.

### Las diez preguntas

Las siete primeras son las de la tabla de la
[teoría 04](1-teoria/04-defender-un-pipeline.md), en su orden, y su prueba es la línea
correspondiente del paso 5 de la [práctica 04](2-practicas/04-defensa-del-pipeline.md). Las tres
últimas son propias del capstone.

| # | Pregunta | Respuesta que se espera | Evidencia que se espera |
|:--:|---|---|---|
| 1 | ¿Qué tiene que pasar para que algo entre en `main`? | `ci-gate` en verde en la merge queue, que corre `ci.yml` con `merge_group` sobre lo que quedará en `main` | `gh api 'repos/{owner}/{repo}/rules/branches/main'` con `ci-gate` como único check requerido, y un run de `merge_group` |
| 2 | ¿Qué pasa si un fork abre un PR que cambia `ci.yml`? | Su `ci.yml` corre sin secretos y con token de lectura, y no corre hasta que alguien lo aprueba; nunca llega a `tablero-runners` | `approval_policy` = `all_external_contributors` y ningún workflow de `pull_request*` con `runs-on: tablero-runners` |
| 3 | ¿Cómo sabes que la imagen de production es la que construyó `release.yml`? | `deploy.yml` verifica la attestation con `--signer-workflow` y despliega el digest verificado, no el tag | `gh attestation verify` en directo y el log del job que verifica |
| 4 | ¿Qué pasa si el despliegue a production falla? | Helm revierte a la revisión anterior y el run queda en rojo; no se rehace la release | Historial de `deploy.yml` y el run de rollback de la Semana 17 |
| 5 | ¿Quién puede cambiar los reutilizables? | Solo un PR al central seguido de una release inmutable; `tablero` no cambia hasta que un PR mueve su SHA | Una sola línea en el `grep` de referencias por SHA, y el historial de releases del central |
| 6 | ¿Cómo sabes que el CI no se está haciendo lento? | `ci-metrics.yml` calcula p50 y p95 y avisa si el p95 supera `CI_P95_BUDGET_SECONDS` | El último run de `ci-metrics.yml` en verde y su resumen |
| 7 | ¿Qué no cubre este pipeline? | Lo que está en "Riesgos aceptados", con qué lo cerraría | La propia sección, leída sin dudar |
| 8 | ¿Por qué `ci-worker.yml` no tiene steps? ¿Qué harías si el worker necesitara algo que `_python.yml` no hace? | Porque el CI de Python vive en el central; si falta algo, se añade un input allí por PR y release, y se mueven las referencias | `yq '.jobs[] \| has("steps")' .github/workflows/ci-worker.yml` → `false` |
| 9 | ¿Qué encontró tu auditoría que actionlint y zizmor no vieron? | Imágenes sin digest en el central v1.0.0 (y en el Dockerfile del worker de `app/`): YAML válido y sin vulnerabilidad conocida, pero contra la política | `scripts/audit-workflows.sh` sobre un clon de v1.0.0 (`3 hallazgos`) y de v1.1.0 (`0 hallazgos`) |
| 10 | Si mañana alguien quita `worker` de `ci-gate.needs`, ¿quién lo nota? | Ninguna herramienta automática: el ruleset solo mira `ci-gate` y la política no compara los jobs con `needs`. Lo para la revisión; cerrarlo sería una regla nueva en la política | `yq '.jobs."ci-gate".needs' .github/workflows/ci.yml` y la propuesta de regla, o el riesgo anotado |

La décima no tiene una respuesta "buena" escrita en el material: mide si sabes reconocer un hueco
y proponer su cierre en lugar de negarlo.

### Puntuación (30 puntos)

**Exposición (10 puntos)**:

| Criterio | Puntos |
|---|:--:|
| El mapa se entiende sin abrir un YAML y nombra `ci-gate` como única puerta | 3 |
| El modelo de amenazas baja cada defensa a un archivo, un ajuste o una regla | 3 |
| Decisiones con alternativa y riesgos concretos, dichos sin que los pidan | 2 |
| Termina en diez minutos o menos | 2 |

**Preguntas (20 puntos)**, 2 por pregunta:

| Puntos | Cuándo |
|:--:|---|
| 2 | Respuesta correcta en dos frases y, si se pide, la prueba lanzada y con la salida esperada |
| 1 | Respuesta correcta sin prueba, o "no lo sé, lo compruebo así" con el comando correcto |
| 0 | No responde, responde leyendo el YAML, o inventa |

**Aprobado: 21 puntos (70 %).** Una respuesta inventada que se descubre al lanzar la prueba
activa la penalización grave de Producto.

## 🏁 Simulacro final tipo GH-200

Cierra el bootcamp en las condiciones del examen: **90 minutos cronometrados**, sin abrir la
teoría ni buscar en la web. Las 30 preguntas de la Parte A se reparten por los cinco dominios de
la guía vigente ("Skills measured as of January 2026") según su peso. No reproduce ni la duración
ni el número de preguntas del examen real: esos datos se consultan en la página oficial el día que
reserves ([teoría 06](1-teoria/06-el-examen-gh-200.md)).

| Parte | Qué es | Tiempo | Puntos |
|---|---|:--:|:--:|
| A | 30 preguntas tipo test, una sola respuesta correcta | 60 min | 30 |
| B | Una auditoría semanal en `tablero`, de la rama a "en pausa" | 30 min | 10 |
| **Total** | | **90 min** | **40** |

| Dominio | Peso en la guía | Preguntas | Peso aquí |
|---|:--:|:--:|:--:|
| D1 · Author and manage workflows | 20-25 % | A1-A7 | 23 % |
| D2 · Consume and troubleshoot workflows | 15-20 % | B1-B6 | 20 % |
| D3 · Author and maintain actions | 15-20 % | C1-C6 | 20 % |
| D4 · Manage GitHub Actions for the enterprise | 20-25 % | E1-E7 | 23 % |
| D5 · Secure and optimize automation | 10-15 % | F1-F4 | 13 % |

**Aprobado: 28 puntos (70 %).** Apunta también tu nota por dominio: un dominio por debajo del
70 % es tu lista de repaso, con la semana que indica cada solución.

### Parte A — Preguntas tipo test (60 minutos)

Marca una opción por pregunta y apunta tus respuestas; abre las soluciones solo al final.

#### D1 · Author and manage workflows

**A1.** Un workflow tiene tres jobs. El job `deploy` necesita la versión que calcula el job
`build`. ¿Cómo llega?

- A) `build` escribe `VERSION=1.2.3` en `$GITHUB_ENV` y `deploy` lee `$VERSION`
- B) `build` declara `outputs:` a partir de `steps.<id>.outputs`, y `deploy`, con `build` en su `needs`, lee `needs.build.outputs.<nombre>`
- C) `deploy` lee `steps.<id>.outputs.version` del step de `build`
- D) `deploy` lee `jobs.build.outputs.version` sin `needs`

<details>
<summary>Solución</summary>

**B.** `$GITHUB_ENV` solo afecta a los steps siguientes del mismo job, y el contexto `steps` solo
ve los del job actual. Los datos entre jobs viajan por `outputs` del job y `needs.<job>.outputs`,
y el job que lee tiene que tener al otro en su `needs`. Semana 02.

</details>

**A2.** ¿Cuál de estos fragmentos de un workflow acepta GitHub?

- A) `env: *shared`, con `&shared` definido antes en el mismo archivo
- B) `<<: *base` dentro de un job para heredar sus claves y sobrescribir una
- C) `env: *shared`, con `&shared` definido en otro workflow del repo
- D) Ninguno: GitHub no admite anclas de YAML

<details>
<summary>Solución</summary>

**A.** Desde el 18 de septiembre de 2025, GitHub admite anclas y alias dentro de un archivo, con
el ancla antes del alias. La clave de fusión `<<` no la admite (actionlint la rechaza con
`GitHub Actions does not support YAML merge key "<<"`), y un ancla no cruza archivos. Semana 20,
teoría 05.

</details>

**A3.** Tres workflows del mismo repo repiten el mismo step de checkout con
`persist-credentials: false` y la misma instalación de herramientas. ¿Qué usas para no repetirlo?

- A) Un ancla en el primer workflow y un alias en los otros dos
- B) Una action composite (o un reutilizable si lo que se repite son jobs enteros)
- C) Un `env:` en la raíz de cada workflow
- D) Un archivo YAML aparte incluido con `include:`

<details>
<summary>Solución</summary>

**B.** Para repetir steps entre archivos, una action composite; para jobs enteros, un reutilizable.
Un ancla vive en su archivo y no se comparte. Los workflows no tienen `include:`. Semanas 09 y 10,
y Semana 20, teoría 05.

</details>

**A4.** Una matriz de seis combinaciones no declara `fail-fast`. Una combinación falla a los dos
minutos. ¿Qué pasa con las demás?

- A) Siguen hasta terminar: `fail-fast` vale `false` por defecto
- B) GitHub cancela las que están en curso o en cola
- C) Se reintenta la que falló hasta tres veces
- D) Se ejecutan, pero su resultado se ignora

<details>
<summary>Solución</summary>

**B.** `strategy.fail-fast` vale `true` por defecto: si un job de la matriz falla, GitHub cancela
los que están en curso o en cola. Con `fail-fast: false` siguen todas, y `max-parallel` limita
cuántas corren a la vez. Semana 04.

</details>

**A5.** Un workflow declara `concurrency` con un grupo por rama y `cancel-in-progress: false`.
Mientras corre el run A llegan, en este orden, B y C a la misma rama. ¿Qué pasa?

- A) Los tres corren en paralelo
- B) A sigue; B queda pendiente y, al llegar C, B se cancela y C pasa a ser el pendiente
- C) A se cancela y corre C
- D) A sigue y B y C esperan en cola, por orden

<details>
<summary>Solución</summary>

**B.** En un grupo hay como mucho un run en curso y uno pendiente; un pendiente nuevo sustituye al
anterior. `cancel-in-progress` solo decide qué pasa con el que está en curso: con `true`, A se
cancelaría. Semana 07.

</details>

**A6.** Diseñas una cadena de workflows reutilizables. ¿Qué límite es real?

- A) Un reutilizable puede vivir en una subcarpeta de `.github/workflows/`
- B) Hasta 10 niveles de anidamiento y 50 reutilizables únicos por run
- C) Un reutilizable no puede llamar a otro reutilizable
- D) Un llamador solo puede llamar a un reutilizable por workflow

<details>
<summary>Solución</summary>

**B.** Hasta 10 niveles (el llamador más nueve reutilizables encadenados) y 50 reutilizables
únicos; nada en subcarpetas. Un reutilizable sí puede llamar a otro, y un llamador puede tener
varios jobs que llaman a reutilizables distintos. Semana 09.

</details>

**A7.** Activas la merge queue en `main` con `ci-gate` como check requerido. Los PRs entran en
la cola y salen por timeout sin fusionarse. `ci-gate` está verde en cada PR. ¿Qué falta?

- A) Exigir también cada job del CI en el ruleset
- B) `merge_group` en el `on:` del workflow que publica `ci-gate`
- C) `pull_request_target` en lugar de `pull_request`
- D) Aprobar de nuevo cada PR dentro de la cola

<details>
<summary>Solución</summary>

**B.** La cola espera el check requerido sobre el commit del grupo, y solo lo publica un workflow
que escucha `merge_group`. Por eso `merge_group` va en `ci.yml` primero y la regla de la cola
después. Semana 18.

</details>

#### D2 · Consume and troubleshoot workflows

**B1.** Un check requerido se queda en *Expected — Waiting for status to be reported* en un PR que
solo cambia la documentación. ¿Cuál es la causa más probable?

- A) El runner está caído
- B) El workflow que produce el check no se disparó por un filtro `paths`; un workflow saltado deja el check pendiente
- C) El job tiene `if:` falso; un job saltado deja el check pendiente
- D) Falta `timeout-minutes`

<details>
<summary>Solución</summary>

**B.** Un workflow que no se dispara no informa de nada y el check queda esperando. Un job saltado,
en cambio, cuenta como éxito. Por eso `tablero` tiene un workflow que corre siempre y un job
puerta, `ci-gate`. Semana 18.

</details>

**B2.** Quieres ver la evaluación de las expresiones y los mensajes `::debug::` de cada step en el
log de un run. ¿Qué activas?

- A) `ACTIONS_RUNNER_DEBUG=true`
- B) `ACTIONS_STEP_DEBUG=true`
- C) `set -x` en cada `run:`
- D) `debug: true` en el `on:`

<details>
<summary>Solución</summary>

**B.** `ACTIONS_STEP_DEBUG` añade las líneas `##[debug]` en el log de cada step. `ACTIONS_RUNNER_DEBUG`
añade los logs de diagnóstico del runner, en la carpeta `runner-diagnostic-logs` del archivo de
logs. Para un solo intento, `gh run rerun --debug`. Semana 08.

</details>

**B3.** Una matriz de seis jobs falla solo en una combinación por un fallo intermitente de red.
¿Cómo reejecutas solo esa?

- A) `gh run rerun <id>`
- B) `gh run rerun <id> --job <job-id>`, con el `<job-id>` de `gh run view <id> --json jobs`
- C) Un commit vacío
- D) `gh workflow run` con el nombre de la combinación

<details>
<summary>Solución</summary>

**B.** `--job` reejecuta ese job y los que dependen de él. `gh run rerun <id>` sin más reejecuta
el run entero, y `--failed` todos los fallidos. Semanas 08 y 20, teoría 05.

</details>

**B4.** Quieres parar `nightly.yml` dos semanas sin perder su historial ni la forma de lanzarlo
después. ¿Qué haces?

- A) Borrar el archivo y recuperarlo de git
- B) `gh workflow disable nightly.yml` y, al volver, `gh workflow enable nightly.yml`
- C) Comentar el bloque `on:`
- D) `gh run delete` de todos sus runs

<details>
<summary>Solución</summary>

**B.** Deshabilitar lo para y lo oculta de `gh workflow list` (sale con `--all`), y conserva los
runs. Borrar el archivo también lo para, pero sus runs siguen y cada uno se borra con
`gh run delete <id>`. Semanas 07 y 20, teoría 05.

</details>

**B5.** Un job en `ubuntu-24.04` empieza a fallar un lunes sin que nadie haya cambiado el repo.
El viernes pasaba. ¿Qué miras primero?

- A) El grupo "Runner Image" del paso "Set up job" en los dos runs, para comparar la versión de imagen
- B) Cambiar a `ubuntu-latest`
- C) Borrar la caché
- D) El historial de commits de `main`

<details>
<summary>Solución</summary>

**A.** Las imágenes alojadas se actualizan, también con la etiqueta fijada. Si la versión cambió
entre el run verde y el rojo, las notas de release de `actions/runner-images` dicen qué se movió.
`ubuntu-latest` no lo arregla: añade otro cambio que no controlas. Semana 20, teoría 05.

</details>

**B6.** Un workflow hace `git push` de un commit a una rama con el `GITHUB_TOKEN`. El CI de esa
rama no arranca. ¿Por qué?

- A) Falta `contents: write`
- B) Los eventos que provoca el `GITHUB_TOKEN` no crean runs nuevos
- C) El push necesita `persist-credentials: false`
- D) `push` no dispara workflows en ramas que no son `main`

<details>
<summary>Solución</summary>

**B.** Es una protección contra bucles: un push, un PR o una release hechos con el `GITHUB_TOKEN`
no disparan workflows (salvo `workflow_dispatch` y `repository_dispatch`). La salida es un
dispatch explícito o una GitHub App, nunca un PAT clásico. Semana 07.

</details>

#### D3 · Author and maintain actions

**C1.** Una action composite tiene un step `run: ./scripts/check.sh` sin más claves y falla al
validar. ¿Qué falta?

- A) `runs-on`
- B) `shell:` en el step
- C) `permissions:`
- D) `working-directory:`

<details>
<summary>Solución</summary>

**B.** En una composite, cada step `run:` declara su `shell:`: no hay un `defaults.run.shell` del
workflow que lo herede. `runs-on` y `permissions` son del job que la usa, no de la action.
Semana 10.

</details>

**C2.** Tu action Docker funciona en `ubuntu-24.04`. Un equipo la usa en `windows-2022` y el step
falla. ¿Por qué?

- A) Le falta `branding`
- B) Las actions Docker solo corren en runners Linux
- C) Necesita `using: node24`
- D) Windows exige la imagen por digest

<details>
<summary>Solución</summary>

**B.** Una action Docker solo corre en runners Linux. Si necesitas varios sistemas, una action
JavaScript o una composite. Semana 10.

</details>

**C3.** Una action tiene que borrar un recurso temporal que crea, aunque el job falle después.
¿Cómo lo haces sin que cada workflow que la use añada un step final?

- A) Action JavaScript con `post:` (que por defecto corre siempre), guardando lo necesario en `$GITHUB_STATE` desde el `main`
- B) Un step con `if: always()` en cada workflow
- C) `continue-on-error: true` en la action
- D) Una composite con `post:`

<details>
<summary>Solución</summary>

**A.** `post:` corre al final del job, con `post-if` para condicionarlo, y lee lo que el `main`
guardó en `$GITHUB_STATE` como `STATE_<nombre>`. Así guardan su caché `setup-node` y `setup-uv`.
La opción B obliga a repetir la limpieza en cada workflow. Semana 10.

</details>

**C4.** Publicas una action JavaScript nueva. ¿Qué `runs.using` declaras?

- A) `node16`
- B) `node20`
- C) `node24`
- D) `docker`

<details>
<summary>Solución</summary>

**C.** `node16` está retirado y `node20` deprecado (el runner aún lo trae). El runtime vigente es
el de `docs/stack-versions.md`, `node24`. `docker` es otro tipo de action. Semana 10.

</details>

**C5.** Quieres que quien consume tu action tenga la garantía de que una versión publicada no
cambia nunca. ¿Qué existe hoy para eso?

- A) Las immutable actions publicadas con `actions/publish-immutable-action`, listas para uso general
- B) Releases inmutables en el repo de la action y consumidores que la fijan por SHA
- C) Un tag `v1` que mueves con cada parche
- D) Publicar en el Marketplace

<details>
<summary>Solución</summary>

**B.** Las immutable actions (paquetes OCI en GHCR) existen en la guía, pero
`actions/publish-immutable-action` sigue "not ready for public use" (comprobado el 14 de noviembre
de 2026). Una release inmutable no deja mover ni borrar su tag, y fijar por SHA protege aunque
alguien mueva un tag. Un tag mayor que se mueve es justo lo contrario. Semanas 11 y 20.

</details>

**C6.** Necesitas reutilizar un CI que levanta PostgreSQL como service container y corre en su
propio runner con su timeout. ¿Qué construyes?

- A) Una action composite
- B) Un workflow reutilizable con `on: workflow_call`
- C) Una action JavaScript
- D) Un ancla de YAML

<details>
<summary>Solución</summary>

**B.** Un reutilizable define jobs completos, con `runs-on`, `services` y `timeout-minutes`. Una
composite es una lista de steps que corre dentro del job que la llama y no puede declarar
runner ni services. Es exactamente `_python.yml` con `integration: true`. Semanas 09 y 10.

</details>

#### D4 · Manage GitHub Actions for the enterprise

**E1.** Una org quiere que solo se usen actions de GitHub y propias, y siempre fijadas por SHA.
¿Dónde se configura?

- A) Un workflow en cada repo que revisa los `uses:`
- B) La política de actions de la org: `allowed_actions: selected` con las de GitHub y los patrones propios, más `sha_pinning_required`
- C) `CODEOWNERS` sobre `.github/workflows/`
- D) Un ruleset con check requerido

<details>
<summary>Solución</summary>

**B.** Es una política de la org que aplica GitHub al ejecutar, no algo que dependa de cada repo.
CODEOWNERS y rulesets controlan quién aprueba, no qué actions se pueden ejecutar. Semana 11.

</details>

**E2.** Una empresa en GitHub Enterprise Cloud activa una lista de IP permitidas. Sus workflows en
runners alojados estándar dejan de acceder a sus repos privados. ¿Qué opción documentada lo
resuelve?

- A) Añadir a la lista los rangos de `gh api /meta --jq .actions`
- B) Runners propios (o runners grandes con IP estática) y sus IP en la lista
- C) Cambiar a `ubuntu-latest`
- D) Un PAT con más permisos

<details>
<summary>Solución</summary>

**B.** Las IP de los runners alojados estándar son miles de rangos y cambian
(`gh api /meta --jq '.actions | length'` devolvió 8350 el 14 de noviembre de 2026). Las salidas
documentadas son runners propios o runners grandes con IP estática. La lista de IP solo existe en
Enterprise Cloud. Semana 20, teoría 05.

</details>

**E3.** Un equipo de una org en plan Team ve que sus jobs con `runs-on: ubuntu-latest` ya no <!-- antipatron -->
encuentran runner, y los de `ubuntu-24.04` sí. ¿Qué explica el síntoma?

- A) `ubuntu-latest` está retirado para todo GitHub
- B) La org deshabilitó las etiquetas estándar como `ubuntu-latest` para todos sus repos
- C) El repo superó su cupo de minutos
- D) Hace falta registrar un runner propio con esa etiqueta

<details>
<summary>Solución</summary>

**B.** Desde el 25 de junio de 2026, en Team y Enterprise una org puede deshabilitar las etiquetas
estándar como `ubuntu-latest`. Si fuera el cupo, fallarían también los de `ubuntu-24.04`. Por eso
el bootcamp fija la versión desde la Semana 01. Semana 20, teoría 05.

</details>

**E4.** Una org quiere ofrecer a sus miembros plantillas de workflow sin hacer público ningún
repo. ¿Es posible y dónde van?

- A) No: las plantillas solo funcionan desde un repo `.github` público
- B) Sí: en `workflow-templates/` de un repo `.github` privado o interno de la org
- C) Sí: en `.github/workflows/` de cualquier repo privado
- D) Solo en GitHub Enterprise Server

<details>
<summary>Solución</summary>

**B.** Las plantillas viven en `workflow-templates/` del repo `.github` de la org (Semana 11).
Desde septiembre de 2025, las de un `.github` privado o interno también se ofrecen a los miembros.
Semana 20, teoría 05.

</details>

**E5.** En una org del plan Free, un runner propio solo debe poder usarlo `tablero`. ¿Qué haces?

- A) Un runner group con solo `tablero`
- B) Un runner de repositorio en `tablero`, con la política de runners de repositorio de la org limitada a `tablero`
- C) Un `if: github.repository == '<tu-org>/tablero'` en cada job
- D) Una etiqueta secreta

<details>
<summary>Solución</summary>

**B.** Un runner de repositorio no lo ve ningún otro repo, y la política impide que otros repos
registren los suyos. Los runner groups adicionales son de Team en adelante; `if:` y etiquetas los
puede escribir cualquiera. Semana 15.

</details>

**E6.** La org tiene la retención de artefactos y logs en 30 días. Un repo de la org intenta
subirla a 90 y no puede. ¿Por qué?

- A) 30 días es el máximo de GitHub para cualquier repo
- B) La retención de la org es el techo de la de sus repos
- C) Los repos públicos no admiten más de 30
- D) Hace falta borrar la caché antes

<details>
<summary>Solución</summary>

**B.** La org fija la retención máxima y cada repo puede bajarla, no subirla por encima. Se lee
y se cambia por la API de permisos de Actions (`artifact-and-log-retention`). Semana 19.

</details>

**E7.** `tablero` es público y tiene un runner propio. ¿Qué ajuste impide que el workflow de un PR
de un fork llegue a ejecutarse sin que nadie lo revise?

- A) Que el PR de un fork no reciba secretos
- B) La aprobación obligatoria para todos los contribuidores externos (`all_external_contributors`)
- C) La aprobación solo para quien contribuye por primera vez
- D) `permissions: {}` en la raíz

<details>
<summary>Solución</summary>

**B.** En un `pull_request` corre el workflow del commit del PR: el atacante trae el suyo.
Quitarle secretos o permisos no protege la máquina, y la aprobación solo para primerizos se
esquiva con un primer PR inocente. Semana 15.

</details>

#### D5 · Secure and optimize automation

**F1.** Un step hace `run: echo "Título: ${{ github.event.pull_request.title }}"`. ¿Cuál es el
riesgo y la corrección?

- A) Ninguno: GitHub escapa los títulos
- B) Inyección de scripts: el título se pega en el script antes de ejecutarlo. Se pasa por `env:` (`TITLE: ${{ github.event.pull_request.title }}`) y se usa `"$TITLE"`
- C) Solo es un riesgo en repos privados
- D) Se corrige con comillas simples dentro del `run:`

<details>
<summary>Solución</summary>

**B.** `${{ }}` se sustituye antes de que el shell lea el script: un título con `"; curl …`
ejecuta código. Por `env:` llega como dato. Las comillas no lo arreglan, porque el atacante las
cierra. Semana 12.

</details>

**F2.** Un workflow con `pull_request_target` hace checkout de `github.event.pull_request.head.sha`
y ejecuta los tests del PR. ¿Qué problema tiene?

- A) Ninguno, si el job tiene `timeout-minutes`
- B) El código del PR corre con escritura y secretos del repo base
- C) `pull_request_target` no admite checkout
- D) Solo falla en forks privados

<details>
<summary>Solución</summary>

**B.** `pull_request_target` da escritura y secretos a un PR de cualquiera. Con el checkout del
head, el código del atacante corre con ellos. El patrón seguro no hace checkout del PR y separa lo
que necesita privilegios con `workflow_run`. Semana 12.

</details>

**F3.** Un job tiene que desplegar en un proveedor cloud sin guardar una clave de larga duración.
¿Qué necesita?

- A) Un secreto de environment con la clave
- B) `permissions: id-token: write` en ese job y una relación de confianza en el proveedor ligada a los claims (`sub`, `repository`, environment)
- C) Un PAT clásico
- D) `secrets: inherit`

<details>
<summary>Solución</summary>

**B.** OIDC: el job pide un token firmado por GitHub y el proveedor lo canjea por una credencial
de corta duración si los claims casan. No queda ningún secreto estático que robar. Semana 13.

</details>

**F4.** El job que firma la attestation de procedencia de una imagen falla por permisos. ¿Qué dos
permisos necesita, además de lo que pida para subir la imagen?

- A) `contents: write` y `packages: read`
- B) `id-token: write` y `attestations: write`
- C) `actions: write` y `checks: write`
- D) Ninguno: la firma es local

<details>
<summary>Solución</summary>

**B.** `id-token: write` para pedir el token OIDC que Fulcio canjea por el certificado de firma, y
`attestations: write` para guardar el bundle en la API de attestations del repo. Semana 14.

</details>

### Parte B — Una auditoría semanal en `tablero` (30 minutos)

Añade a `tablero` un workflow `weekly-audit` que pase tu política cada lunes y deje en el resumen
del run lo que usa la imagen, y después **ponlo en pausa** sin perder su historial. Cubre D1
(anclas, disparadores), D2 (lanzar, leer, deshabilitar) y D5 (permisos y fijado), sin más guía que
lo aprendido:

1. `.github/workflows/weekly-audit.yml` con `schedule` semanal y `workflow_dispatch`,
   `permissions: {}` en la raíz y dos jobs en `ubuntu-24.04` con timeout y solo `contents: read`:
   `policy`, que ejecuta `scripts/audit-workflows.sh`, e `inventory`, que escribe en
   `$GITHUB_STEP_SUMMARY` el valor de `RUNNER_TOOL_CACHE` y la versión de `yq`. Los dos comparten
   el step de checkout **con un ancla `&checkout` y su alias**.
2. Entra en `main` por PR y por la merge queue.
3. Lánzalo a mano sobre `main` y espera a que termine en verde.
4. Deshabilítalo.

Corrige con estas diez comprobaciones, 1 punto cada una:

```bash
cd ~/code/tablero && git switch -q main && git pull -q --ff-only
export GH_REPO=<tu-org>/tablero
f=.github/workflows/weekly-audit.yml
# 1. Los dos disparadores
yq '.on | keys | sort | join(",")' "$f"
# schedule,workflow_dispatch
# 2. permissions: {} en la raíz
yq '[(has("permissions")), (.permissions | length)] | join(" ")' "$f"
# true 0
# 3. El checkout compartido con ancla y alias, sin credenciales en los dos jobs
grep -cE '&checkout|\*checkout' "$f"; yq 'explode(.) | .jobs.inventory.steps[0].with."persist-credentials"' "$f"
# 2
# false
# 4. Timeout en los dos jobs
yq '[.jobs[] | .["timeout-minutes"]] | length' "$f"
# 2
# 5. actionlint limpio
actionlint "$f" && echo ok
# ok
# 6. La política sigue sin hallazgos con el archivo nuevo
scripts/audit-workflows.sh | tail -1
# 0 hallazgos
# 7. Entró por PR
git log -1 --format=%s -- "$f"
# ci: add weekly audit workflow (#<n>)
# 8. Un run a mano sobre main, con sus dos jobs en verde
id=$(gh run list --workflow weekly-audit.yml --event workflow_dispatch --branch main --json databaseId,conclusion --jq '[.[] | select(.conclusion == "success")][0].databaseId')
gh run view "$id" --json jobs --jq '"\(.jobs | length) \([.jobs[].conclusion] | unique | join(","))"'
# 2 success
# 9. Deshabilitado, no borrado
gh workflow list --all --json name,state --jq '.[] | select(.name == "weekly-audit") | .state'
# disabled_manually
# 10. Su historial sigue ahí
gh run list --workflow weekly-audit.yml --json databaseId --jq 'length > 0'
# true
```

<details>
<summary>Solución de referencia y fallos típicos</summary>

```yaml
name: weekly-audit
on:
  schedule:
    - cron: "17 6 * * 1"
  workflow_dispatch:
permissions: {}
jobs:
  policy:
    name: Política semanal
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    permissions:
      contents: read
    steps:
      - &checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - run: scripts/audit-workflows.sh
  inventory:
    name: Imagen y toolcache
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    permissions:
      contents: read
    steps:
      - *checkout
      - run: |
          {
            echo "| Dato | Valor |"
            echo "|---|---|"
            echo "| RUNNER_TOOL_CACHE | $RUNNER_TOOL_CACHE |"
            echo "| yq | $(yq --version) |"
          } >> "$GITHUB_STEP_SUMMARY"
```

```bash
git switch -c ci/weekly-audit
# ... el archivo de arriba en .github/workflows/weekly-audit.yml ...
git add .github/workflows/weekly-audit.yml
git commit -m "ci: add weekly audit workflow" && git push -u origin HEAD
gh pr create --fill
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch --required > /dev/null && gh pr merge "$pr"
until [ "$(gh pr view "$pr" --json state --jq .state)" = MERGED ]; do sleep 15; done
git switch main && git pull -q --ff-only
gh workflow run weekly-audit.yml --ref main && sleep 5
gh run watch "$(gh run list --workflow weekly-audit.yml --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status > /dev/null
gh workflow disable weekly-audit.yml
```

Comprobado con actionlint 1.7.12, zizmor 1.31.1 (sin hallazgos, con el `WARN` de anclas) y tu
`audit-workflows.sh` (`0 hallazgos`), noviembre de 2026.

Fallos que cuestan puntos:

- **`<<: *checkout` para cambiar algo del step**: GitHub no admite la clave de fusión y actionlint
  lo rechaza. Si un job necesita otro `with:`, escribe ese step entero. Semana 20, teoría 05.
- **El alias antes que el ancla** (el job `inventory` escrito primero con `*checkout`): el ancla
  tiene que aparecer antes en el archivo. Semana 20, teoría 05.
- **`gh workflow run` antes de fusionar**: `workflow_dispatch` lanza el workflow que existe en la
  rama que pasas con `--ref`; si aún no está en `main`, no hay nada que lanzar ahí. Semana 07.
- **Borrar el archivo en lugar de deshabilitarlo**: la comprobación 9 no lo encuentra y el
  siguiente que quiera reactivarlo tiene que rehacerlo. Semana 20, teoría 05.
- **`ci-gate` en rojo en el PR por la política**: un job sin `timeout-minutes` o un `uses:` por tag.
  Lo que te exige `policy` en el PR es lo mismo que comprueba aquí. Semana 20, práctica 03.

</details>

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 20 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
