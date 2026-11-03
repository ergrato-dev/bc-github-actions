# Rúbrica de evaluación — Semana 04

> CI de frontend con pnpm, matrices y artefactos. Se aprueba con un **mínimo del 70 % en cada
> evidencia**, no en el promedio. Al final está el minisimulacro de cierre de la Fase 1.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de `ci-web.yml` |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** Después de `pnpm install`, `node_modules/react` es un enlace simbólico y los archivos de
`node_modules/.pnpm` tienen un contador de enlaces mayor que 1. ¿Qué te dicen esas dos cosas sobre
cómo instala pnpm?

<details>
<summary>Respuesta</summary>

pnpm guarda cada archivo de cada paquete **una sola vez** en un store global direccionado por
contenido (`~/.local/share/pnpm/store/v11`). En el proyecto, los archivos de `node_modules/.pnpm`
son **enlaces duros** a ese store: el contador mayor que 1 significa que el mismo dato en disco
tiene varios nombres, así que diez proyectos con React no ocupan diez veces. Encima, la raíz de
`node_modules` solo tiene **enlaces simbólicos** a las dependencias que declara `package.json`. Por
eso tu código no puede importar un paquete transitivo que no declaraste: no está en la raíz. El
resultado es una instalación rápida, que ocupa poco y que no esconde dependencias fantasma.

</details>

**2.** En tu máquina, `pnpm install` "arregla" un `pnpm-lock.yaml` desfasado y sigue. En CI usas
`pnpm install --frozen-lockfile`. ¿Qué gana el CI fallando, y por qué escribes el flag si pnpm ya
lo activa con `CI=true`?

<details>
<summary>Respuesta</summary>

Si `package.json` cambió y nadie regeneró el lockfile, `--frozen-lockfile` falla con
`ERR_PNPM_OUTDATED_LOCKFILE` sin instalar nada. Sin el flag, pnpm reescribiría el lockfile **en la
copia del runner**, que se destruye al terminar: el job saldría verde probando dependencias que no
están en el `pnpm-lock.yaml` del repo, y la siguiente persona instalaría otra cosa. El fallo
convierte "se me olvidó comitear el lock" en un rojo visible en el pull request. El flag se
escribe porque el comportamiento por defecto depende de una variable de entorno que no se ve en el
YAML: con el flag, el workflow dice lo que hace y se comporta igual en `act` o en un runner propio.

</details>

**3.** Un workflow pone `actions/setup-node` con `cache: pnpm` antes que `pnpm/action-setup` y el
step falla con `Unable to locate executable file: pnpm`. ¿Por qué el orden importa?

<details>
<summary>Respuesta</summary>

Con `cache: pnpm`, setup-node no adivina dónde está la caché: **le pregunta a pnpm** dónde tiene su
store para saber qué directorio restaurar y guardar. Si pnpm todavía no está instalado en el
runner, no hay a quién preguntar y el step falla. `pnpm/action-setup` primero deja pnpm en el
`PATH`; después setup-node instala Node, calcula la clave con el hash de `pnpm-lock.yaml` y
restaura el store. Dicho de otro modo: la caché de setup-node depende de pnpm, así que pnpm va
antes.

</details>

**4.** `web/package.json` declara `"packageManager": "pnpm@12.16.1"`. ¿Qué problema resuelve ese
campo, y por qué no le pasas además `version:` a `pnpm/action-setup`?

<details>
<summary>Respuesta</summary>

Fija la versión **exacta** de pnpm del proyecto, igual que el lockfile fija las dependencias: pnpm
12 lo respeta y, si ejecutas otra versión dentro del proyecto, cambia a la declarada. Así tu
máquina, la de un compañero y el runner instalan con el mismo pnpm, y subir de versión es un
commit revisable. `pnpm/action-setup` lee ese campo con `package_json_file` cuando no le das
`version`. Si das los dos y difieren, falla con `Multiple versions of pnpm specified`; aunque
coincidan, son dos sitios que actualizar y acabarán divergiendo. Una sola fuente: `packageManager`.

</details>

**5.** Una matriz tiene `node: [24, 26]` y `reporter: [default, dot, verbose]`, con
`exclude: [{node: 24, reporter: dot}, {node: 24, reporter: verbose}]` e
`include: [{node: 26, coverage: true}]`. ¿Cuántos jobs salen y cuáles llevan `coverage`?

<details>
<summary>Respuesta</summary>

El producto cartesiano da 2 × 3 = 6 combinaciones. `exclude` se aplica primero y quita dos: quedan
Node 24 con `default` y Node 26 con las tres. Después `include`: `{node: 26, coverage: true}` no
pisa ningún valor original de las combinaciones con Node 26, así que **añade** `coverage: true` a
las tres. Resultado: **4 jobs**, y los tres de Node 26 llevan `coverage`. Si la entrada de `include`
pisara un valor original (por ejemplo `{node: 22}`), no se fusionaría con ninguna y crearía una
combinación nueva. El orden (primero `exclude`, luego `include`) permite excluir en general y
volver a añadir un caso concreto.

</details>

**6.** El job `test` de `ci-web.yml` corre en Node 24 y 26 con `fail-fast: false`. ¿Qué perderías
con el valor por defecto?

<details>
<summary>Respuesta</summary>

`fail-fast` vale `true` por defecto: en cuanto un job de la matriz falla, GitHub **cancela** los
que están en curso o en cola. Si Node 24 falla, Node 26 aparece como `cancelled` y no sabes si el
código funciona con 26. La pregunta de esta matriz es precisamente **qué** versiones fallan: "falla
con 24 y pasa con 26" dice que usaste algo que solo existe en la versión nueva, y eso lo ves solo si
las dos terminan. `fail-fast: true` es razonable cuando el fallo de uno condena a todos y quieres
ahorrar minutos; aquí cada combinación aporta información distinta.

</details>

**7.** Un compañero pone `max-parallel: 1` en una matriz de cuatro jobs "para gastar menos
minutos". ¿Lo consigue? ¿Para qué sirve de verdad?

<details>
<summary>Respuesta</summary>

No. Los cuatro jobs corren igual y consumen los mismos minutos; solo tardan más en total porque
van de uno en uno. `max-parallel` limita **cuántos jobs de la matriz corren a la vez**, aunque haya
runners para todos. Sirve cuando los jobs compiten por algo externo: un servicio con límite de
peticiones o un entorno compartido que no aguanta dos ejecuciones simultáneas. Para gastar menos,
lo que funciona es quitar combinaciones con `exclude` o probar solo las versiones que promete
`engines`.

</details>

**8.** En la práctica 03, un job `discover` publica `files=["build","lint","test"]` y otro job usa
`matrix: { file: ${{ fromJSON(needs.discover.outputs.files) }} }`. ¿Por qué hace falta `fromJSON`
y qué protege el `if: needs.discover.outputs.files != '[]'`?

<details>
<summary>Respuesta</summary>

Un output de job **siempre es una cadena**. La matriz necesita un array; `fromJSON` convierte el
texto `["build","lint","test"]` en un array de verdad y GitHub expande un job por elemento. Sin
`fromJSON`, la matriz recibiría una cadena y no un conjunto de valores. El `if` cubre el caso de la
lista vacía: si un día `discover` no encuentra nada, no hay nada que expandir y el run no diría con
claridad que no se probó nada. Con la condición, el job aparece como saltado y la causa queda a la
vista. Es el patrón para "un job por paquete" o "un job por archivo que cambió".

</details>

**9.** Desde la v4 de las actions de artefactos, un artefacto es inmutable. ¿Qué pasa si los dos
jobs de la matriz suben `coverage` con el mismo `name`, y qué decide `retention-days`?

<details>
<summary>Respuesta</summary>

Inmutable significa que, una vez subido, no se le añade nada: el segundo `upload-artifact` con el
mismo nombre en el mismo run **falla** con `(409) Conflict`. Antes se permitía y producía artefactos
corruptos cuando dos jobs escribían a la vez. En una matriz, el nombre tiene que llevar la
combinación: `coverage-node-${{ matrix.node }}`. `retention-days` fija **al subirlo** cuántos días
existe: sin él toma el valor del repo, 90 días por defecto en uno público, y ocupa almacenamiento
todo ese tiempo. Para algo que consume el job siguiente, unos pocos días bastan; en `tablero`, 30
como máximo.

</details>

**10.** `ci-web.yml` cachea el store de pnpm y sube `web/dist` como artefacto. ¿Por qué no al revés:
`dist` en la caché y el store como artefacto?

<details>
<summary>Respuesta</summary>

La pregunta que decide es **qué pasa si no está**. Si falta el store, `pnpm install
--frozen-lockfile` descarga del registro e instala exactamente lo mismo, porque lo decide el
lockfile: solo tarda más. Es un atajo, y eso es una caché, que puede expulsarse a los 7 días sin uso
o al pasar de 10 GB sin cambiar el resultado. Si falta `web/dist`, `dist-report` no tiene nada que
medir, y si lo reconstruye mide otra compilación. Es un resultado, y eso es un artefacto: devuelve
exactamente lo que se subió, comprobado por digest, y si no está el job falla. Una caché no
garantiza que exista; un artefacto no se comparte entre runs sin pedirlo. No son intercambiables.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — pnpm en local | `web/package.json` fija pnpm en `packageManager` (check `web-package-manager`) | 5 |
| 01 — pnpm en local | Provoca `ERR_PNPM_OUTDATED_LOCKFILE`, lo arregla y señala en `node_modules` un enlace duro y uno simbólico | 5 |
| 02 — pnpm en un workflow | `web-lab.yml` lanzado a mano y en verde (check `web-lab-dispatched`) | 5 |
| 02 — pnpm en un workflow | Enseña dos runs seguidos con `cache-hit` en `false` y en `true`, y explica por qué pnpm va antes que setup-node | 5 |
| 03 — Matrices | `matrix-lab.yml` lanzado a mano y en verde (check `matrix-lab-dispatched`) | 5 |
| 03 — Matrices | Compara el run con `fail-fast: true` (jobs `cancelled`) y con `false` (jobs `success`), y explica la expansión de `include` y `exclude` | 5 |
| 04 — Artefactos entre jobs | Descarga el artefacto con `gh run download` y demuestra que es idéntico a su build local | 5 |
| 04 — Artefactos entre jobs | Reproduce el `409 Conflict` de dos subidas con el mismo nombre y borra un artefacto con la API comprobando el 404 | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 04` con 18/18. Cada comprobación en rojo
resta la parte proporcional (12/18 de punto).

**Calidad manual de `.github/workflows/ci-web.yml` (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| El `name:` del job `test` lleva la versión de Node (`Tests (Node ${{ matrix.node }})`): la UI y los checks dicen qué falló | 3 |
| Un comentario explica por qué la matriz es 24 y 26 y no "todas las versiones": lo que promete `engines` | 3 |
| `upload-artifact` con `if-no-files-found: error`: un build vacío falla en `build`, no tres jobs después | 3 |
| `dist-report` no tiene checkout ni instala dependencias: solo usa el artefacto | 3 |
| Ningún `TODO` en `.github/workflows/` | 3 |
| Commits en inglés con Conventional Commits (`ci(web): add frontend pipeline`) | 3 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log | Grave: Producto a 0 hasta rotarlo y retirarlo |
| `uses:` remota sin SHA | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}` interpolado dentro de `run:` | Grave: −10 |
| Imagen sin tag o con `latest` | Grave: −10 |
| `npm` o `npx` en un workflow, un script o la documentación de tu repo <!-- antipatron --> | −3 |
| Un `package-lock.json` comiteado junto a `pnpm-lock.yaml` <!-- antipatron --> | −3 |
| `pip` en un script o en la documentación de tu repo | −3 |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

## 🏁 Minisimulacro de cierre de la Fase 1

Cierra las semanas 01-04 en las condiciones del examen GH-200: **60 minutos cronometrados**, sin
abrir la teoría ni buscar en la web. Pon el reloj antes de leer la primera pregunta.

| Parte | Qué es | Tiempo | Puntos |
|---|---|:--:|:--:|
| A | 12 preguntas tipo test, una sola respuesta correcta | 35 min | 12 |
| B | Una tarea práctica sobre tu `tablero` | 25 min | 8 |
| **Total** | | **60 min** | **20** |

**Aprobado: 14 puntos (70 %).** No suma a los pesos de la semana: es tu termómetro de la fase. Si
no llegas, la explicación de cada fallo te dice qué semana repasar antes de la Fase 2.

### Parte A — Preguntas tipo test (35 minutos)

Marca una opción por pregunta y apunta tus respuestas; abre las soluciones solo al final.

**A1.** Creas `deploy-lab.yml` con `on: workflow_dispatch` en la rama `feature/lab` y lo subes.
`gh workflow run deploy-lab.yml --ref feature/lab` falla. ¿Por qué?

- A) `workflow_dispatch` necesita `inputs:` para lanzarse desde `gh`
- B) El archivo del workflow tiene que estar en la rama por defecto
- C) `--ref` solo acepta tags
- D) Falta `permissions: actions: write` en el workflow

<details>
<summary>Solución</summary>

**B.** El evento solo existe si el archivo está en la rama por defecto. Una vez en `main`, puedes
lanzarlo contra cualquier rama con `--ref`. Semana 01, teoría 05.

</details>

**A2.** Un job tiene `if: env.DEPLOY == 'true'` y `DEPLOY` está definido en el `env:` del workflow.
¿Qué ocurre?

- A) Funciona: `env` del workflow se hereda en todo el archivo
- B) Funciona solo si `DEPLOY` se escribe en mayúsculas
- C) No funciona: el contexto `env` no está disponible en el `if` de un job; usa `vars` o `github`
- D) No funciona: los `if` de job solo aceptan funciones de estado

<details>
<summary>Solución</summary>

**C.** Cuando GitHub evalúa `jobs.<id>.if` solo dispone de `github`, `needs`, `vars` e `inputs`.
actionlint lo avisa antes del push. Semana 02, teoría 01.

</details>

**A3.** Con `env: { DEPLOY: 'false' }`, un step tiene `if: ${{ env.DEPLOY }}`. ¿Se ejecuta?

- A) No: `'false'` se convierte en el booleano `false`
- B) Sí: es una cadena no vacía, y una cadena no vacía es verdadera
- C) No: la expresión da error de tipos y el step se salta
- D) Depende del shell por defecto

<details>
<summary>Solución</summary>

**B.** Los valores falsos son `false`, `0`, `-0`, `''` y `null`. La cadena `'false'` es
verdadera. Para el booleano, `fromJSON(env.DEPLOY)`. Semana 02, teoría 02.

</details>

**A4.** El job `summary` tiene que correr aunque falle alguno de los jobs que espera, pero no si
cancelas el run. ¿Qué condición le pones?

- A) `if: always()`
- B) `if: failure()`
- C) `if: success()`
- D) `if: ${{ !cancelled() }}`

<details>
<summary>Solución</summary>

**D.** `always()` corre incluso tras cancelar el run; `!cancelled()` corre con éxito o con fallo,
pero respeta la cancelación. `failure()` solo corre si algo falló y `success()` solo si todo fue
bien. Semana 02, teoría 03.

</details>

**A5.** El job `version` publica un output `version` y el job `summary` tiene `needs: [version]`.
¿Cómo lee `summary` ese valor en un step?

- A) `${{ jobs.version.outputs.version }}`
- B) `${{ needs.version.outputs.version }}`, siempre que `version` mapee el output en
  `jobs.version.outputs` desde `steps.<id>.outputs.version`
- C) `${{ steps.version.outputs.version }}`
- D) Con `$VERSION`: los outputs de job se exportan como variables de entorno

<details>
<summary>Solución</summary>

**B.** Un output de step no sale del job por sí solo: hay que declararlo en `jobs.<id>.outputs`, y
el dependiente lo lee con el contexto `needs`. Semana 02, teoría 06.

</details>

**A6.** Un step ejecuta `echo "API_URL=http://127.0.0.1:8000" >> "$GITHUB_ENV"`. ¿Dónde está
disponible `API_URL`?

- A) En ese mismo step y en los siguientes del job
- B) En los steps siguientes del mismo job, no en el actual ni en otros jobs
- C) En todos los jobs del workflow
- D) Solo en los jobs que tengan `needs` sobre este

<details>
<summary>Solución</summary>

**B.** Los archivos de entorno se leen al terminar el step: el valor existe a partir del siguiente
y solo dentro del job. Para pasar algo a otro job, `$GITHUB_OUTPUT` y outputs de job. Semana 02,
teoría 05.

</details>

**A7.** `ci-web.yml` tiene `defaults.run.working-directory: web`. ¿A qué afecta?

- A) A todos los steps, incluidos los `uses:`
- B) Solo a los steps `run:` del workflow; un `working-directory:` en el step lo tapa
- C) Solo al primer job
- D) Al directorio donde `actions/checkout` descarga el repo

<details>
<summary>Solución</summary>

**B.** `defaults.run` fija `shell` y `working-directory` para los `run`. Las actions de `uses:` no
lo usan: por eso `upload-artifact` lleva `path: web/dist` y no `dist`. Semana 02, teoría 04.

</details>

**A8.** Abres un pull request desde `feature/b` hacia `main`. ¿Qué caché **no** puede restaurar el
run del PR?

- A) Una guardada por un run anterior de ese mismo PR
- B) Una guardada en `main`
- C) Una guardada en `feature/a`, otra rama de trabajo
- D) Ninguna: las cachés son de todo el repo sin restricción

<details>
<summary>Solución</summary>

**C.** El run de un PR lee su propio ámbito (`refs/pull/N/merge`) y el de la rama base, que aquí
es la rama por defecto. Una rama hermana no le es visible. Semana 03, teoría 05.

</details>

**A9.** Una matriz tiene `node: [24, 26]` y `os: [ubuntu-24.04, windows-2025]`, con
`exclude: [{node: 24, os: windows-2025}]` e `include: [{node: 26, coverage: true}]`. ¿Cuántos jobs
se crean?

- A) 3, y los dos de Node 26 llevan `coverage`
- B) 4, porque `include` añade una combinación nueva
- C) 3, y solo uno lleva `coverage`
- D) 5

<details>
<summary>Solución</summary>

**A.** 2 × 2 = 4, menos la excluida = 3. `{node: 26, coverage: true}` no pisa ningún valor original
de las dos combinaciones con Node 26, así que se fusiona con ambas. Semana 04, teoría 04.

</details>

**A10.** Los dos jobs de una matriz ejecutan `actions/upload-artifact` con `name: coverage`. ¿Qué
pasa?

- A) El segundo sobrescribe al primero
- B) Los archivos de los dos se juntan en un artefacto
- C) El segundo upload falla: un artefacto es inmutable y el nombre es único en el run
- D) GitHub renombra el segundo a `coverage-1`

<details>
<summary>Solución</summary>

**C.** Desde la v4, un segundo upload con el mismo nombre falla con `409 Conflict`. El nombre debe
llevar la combinación, por ejemplo `coverage-node-${{ matrix.node }}`. Semana 04, teoría 05.

</details>

**A11.** En la Semana 01 activaste un ajuste de Actions en tu repo. ¿Qué pasa desde entonces con
un job que use `actions/checkout@v7`?

- A) Corre igual, pero actionlint lo marca como aviso
- B) Falla: con `sha_pinning_required` GitHub exige que toda action vaya fijada por SHA completo
- C) Corre con la última versión de la rama `main` de la action
- D) Queda en espera hasta que un administrador lo apruebe

<details>
<summary>Solución</summary>

**B.** `sha_pinning_required` convierte la regla de fijar por SHA en una regla de la plataforma: un
job que use una action por tag o rama no llega a ejecutarse. Un tag es un puntero que su dueño
puede mover; solo el SHA completo identifica un commit. La espera de aprobación (D) es otro ajuste,
el de PRs de contribuidores externos. Semana 01, práctica 04, paso 4, y práctica 01.

</details>

**A12.** Un workflow no declara `permissions:`. ¿Qué permisos tiene su `GITHUB_TOKEN`?

- A) Ninguno: sin la clave el token no se crea
- B) Solo `contents: read`
- C) Los permisos por defecto del repo o de la organización, que alguien puede cambiar
- D) `write-all`, siempre

<details>
<summary>Solución</summary>

**C.** Sin la clave, el token hereda el ajuste del repo o de la organización. Declarar
`permissions: contents: read` en la raíz hace que el workflow diga lo que necesita sin depender de
ese ajuste. Lo verás a fondo en la Semana 12. Semana 01, teoría 03.

</details>

### Parte B — Tarea práctica (25 minutos)

En una rama `sim/phase-1` de tu `tablero`, añade a `.github/workflows/ci.yml` (el de la Semana 02)
un job `announce` que:

1. Espere al job `version` con `needs: [version]`.
2. Corra aunque `version` falle, pero no si cancelas el run.
3. Reciba la versión y el resultado de `version` por `env:`, nunca con `${{ }}` dentro de `run:`.
4. Falle con un mensaje claro si `version` no terminó en `success` o la versión llega vacía.
5. Escriba `Versión <versión>` en `$GITHUB_STEP_SUMMARY`.

No toques el job `summary`: su `needs` lo comprueba `check-week.sh 02`. Abre un pull request hacia
`main`, espera a que el run termine y corrige con estas ocho comprobaciones, 1 punto cada una:

```bash
# 1. El workflow sigue siendo válido
actionlint .github/workflows/ci.yml; echo "exit $?"
# exit 0
# 2. Espera a version
yq '.jobs.announce.needs | join(",")' .github/workflows/ci.yml
# version
# 3. Corre con fallo, no con cancelación
yq '.jobs.announce.if' .github/workflows/ci.yml
# ${{ !cancelled() }}
# 4. Versión y resultado llegan por env
yq '.jobs.announce.steps[].env | to_entries[].value' .github/workflows/ci.yml | grep -c 'needs\.version\.'
# 2
# 5. Ninguna expresión dentro de run
yq '.jobs.announce.steps[].run' .github/workflows/ci.yml | grep -c '\${{' || true
# 0
# 6. Etiqueta de runner fija
yq '.jobs.announce.runs-on' .github/workflows/ci.yml
# ubuntu-24.04
# 7. El run del pull request terminó en verde
gh run list --workflow ci.yml --branch sim/phase-1 --limit 1 --json conclusion --jq '.[0].conclusion'
# success
```

El punto 8 es visual: en el resumen del run (`gh run view <id> --web` o la UI) aparece
`Versión <versión>+<sha corto>`.

Para comprobar el punto 4 del enunciado, cambia un momento el step de `version` por `exit 1`: el
run debe terminar con `announce` en rojo y su mensaje en el log, no saltado. Deshaz el cambio antes
de corregir.

<details>
<summary>Una solución de referencia</summary>

```yaml
  announce:
    name: Anuncio de la versión
    needs: [version]
    # Corre aunque version falle, para decir por qué no hay versión; no si se cancela el run.
    if: ${{ !cancelled() }}
    runs-on: ubuntu-24.04
    steps:
      - name: Versión en el resumen
        env:
          VERSION: ${{ needs.version.outputs.version }}
          VERSION_RESULT: ${{ needs.version.result }}
        run: |
          if [ "$VERSION_RESULT" != "success" ] || [ -z "$VERSION" ]; then
            echo "El job version terminó en '$VERSION_RESULT' y no publicó versión" >&2
            exit 1
          fi
          echo "### Versión $VERSION" >> "$GITHUB_STEP_SUMMARY"
```

Sin `if:`, el `success()` implícito haría que `announce` se saltara al fallar `version` y nunca
verías el mensaje. Con `always()`, correría también tras cancelar el run. Cuando termines, cierra
el pull request sin fusionarlo y borra la rama.

</details>

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 04 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
