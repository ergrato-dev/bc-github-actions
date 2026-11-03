# Práctica 03 — gh CLI para Actions

> La pestaña Actions sirve para mirar un run. Para trabajar con muchos (lanzarlos,
> esperarlos, sacar el log del step que falló, compararlos), `gh` es más rápido y deja
> rastro en tu terminal. Esta práctica hace con `gh` todo lo que hiciste en la UI.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Consultar runs con `gh run list` y filtrarlos con `--json` y `--jq`
- Lanzar `hello.yml` a mano con `gh workflow run` y esperar el resultado con `gh run watch`
- Leer un run por partes: jobs y steps, log completo, solo lo que falló, un job concreto
- Volver a ejecutar un run, solo lo fallido o con logs de depuración
- Medir cuánto tarda un run y resumir los runs de un día

## 📋 Antes de empezar

Terminaste la [práctica 02](02-primer-workflow.md): `hello.yml` está en `main` y tiene al menos un
run en `failure` (el del paso 4) y otro en `success`. Todos los comandos se ejecutan dentro de tu
clon: ahí `gh` sabe que hablas de `<tu-org>/tablero` sin escribirlo.

```bash
cd ~/code/tablero
gh repo view --json nameWithOwner --jq .nameWithOwner
# <tu-org>/tablero
```

---

## Paso 1: gh run list con --json y --jq

**Por qué**: la tabla de `gh run list` es para leer; para filtrar y encadenar, usa `--json`.
Las columnas de la tabla pueden cambiar entre versiones de `gh`; los campos JSON son estables.
`--jq` aplica una expresión de jq sobre ese JSON sin necesitar `jq` instalado aparte.

**Comando**:

```bash
gh run list --workflow hello.yml --limit 5
gh run list --json
# Specify one or more comma-separated fields for `--json`:
#   attempt
#   conclusion
#   createdAt
#   databaseId
#   displayTitle
#   event
#   headBranch
#   headSha
#   ...
```

`--json` sin campos te dice cuáles hay. Pide solo los que necesitas:

```bash
gh run list --workflow hello.yml --limit 5 --json databaseId,event,conclusion,displayTitle \
  --jq '.[] | "\(.databaseId)  \(.event)  \(.conclusion)  \(.displayTitle)"'
# <run-id>  push  success  ci(hello): remove failing step
# <run-id>  push  failure  ci(hello): add failing step
# ...
```

Los filtros más útiles de `gh run list`: `-w` (workflow), `-b` (rama), `-e` (evento), `-s`
(estado o conclusión), `-c` (SHA del commit) y `-L` (cuántos traer; por defecto 20).

**Verifica**:

```bash
gh run list --workflow hello.yml --status failure --json databaseId --jq length
# 1
```

Debe salir al menos `1`: el run que rompiste a propósito en la práctica 02.

---

## Paso 2: Lanzar hello.yml a mano y esperarlo

**Por qué**: `workflow_dispatch` permite lanzar un workflow sin hacer commit, ideal para probar o
para tareas manuales. `gh workflow run` crea ese evento. Para que funcione, el workflow tiene que
declarar `workflow_dispatch` **en la rama por defecto**: GitHub busca ahí qué workflows se pueden
lanzar a mano. `gh workflow run` no devuelve el ID del run: lo obtienes después con `gh run list`.
`gh run watch` sigue el run en vivo y, con `--exit-status`, sale con código distinto de 0 si el
run falla, así puedes encadenarlo con `&&` en scripts.

**Comando**:

```bash
gh workflow run hello.yml
# ✓ Created workflow_dispatch event for hello.yml at main
sleep 5
RUN_ID=$(gh run list --workflow hello.yml --event workflow_dispatch --limit 1 \
  --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
# ✓ main hello · <run-id>
# Triggered via workflow_dispatch less than a minute ago
#
# JOBS
# ✓ Saludo desde el runner in 5s (ID <job-id>)
#   ✓ Set up job
#   ✓ Quién y qué
#   ...
echo "exit $?"
# exit 0
```

El `sleep 5` da tiempo a GitHub para registrar el run: sin él, `gh run list` puede devolver el
run anterior. `-r <rama>` lanza el workflow de otra rama; `-f clave=valor` pasa inputs (los verás
en la Semana 02).

**Verifica**:

```bash
gh run list --workflow hello.yml --event workflow_dispatch --status success \
  --json databaseId --jq length
# 1
gh run view "$RUN_ID" --log | grep 'Quién y qué' | grep -c workflow_dispatch
# 1
```

El step *Quién y qué* imprime ahora `workflow_dispatch` como evento: es el mismo YAML, lanzado por
otro motivo.

---

## Paso 3: Leer un run por partes

**Por qué**: el log completo de un run largo tiene miles de líneas. Casi siempre quieres solo el
step que falló, o solo un job. `gh run view` tiene una opción para cada caso:

| Opción | Qué enseña |
|---|---|
| (sin opciones) | Resumen: estado y jobs |
| `-v` | Además, cada step con su resultado |
| `--log` | El log completo de todos los jobs |
| `--log-failed` | Solo el log de los steps que fallaron |
| `-j <job-id>` | Limita la vista a un job |
| `--exit-status` | Sale con código distinto de 0 si el run falló |

**Comando**: usa el run en rojo de la práctica 02.

```bash
FAILED_ID=$(gh run list --workflow hello.yml --status failure --limit 1 \
  --json databaseId --jq '.[0].databaseId')
gh run view "$FAILED_ID" -v
# X main hello · <run-id>
# Triggered via push about 1 hour ago
#
# JOBS
# X Saludo desde el runner in 4s (ID <job-id>)
#   ✓ Set up job
#   ✓ Quién y qué
#   ✓ Qué máquina
#   ✓ Qué hay en el workspace
#   X Un step que falla
#   - Esto ya no corre
#   ✓ Complete job
gh run view "$FAILED_ID" --log-failed
# Saludo desde el runner  Un step que falla  <fecha>  Voy a salir con código 3
# Saludo desde el runner  Un step que falla  <fecha>  ##[error]Process completed with exit code 3.
```

Cada línea del log lleva delante el job y el step, separados por tabuladores: por eso se filtra
tan bien con `grep` y `cut`. Para limitar a un job, saca su ID del JSON:

```bash
JOB_ID=$(gh run view "$FAILED_ID" --json jobs --jq '.jobs[0].databaseId')
gh run view "$FAILED_ID" -j "$JOB_ID" --log | cut -f2 | sort -u
# (los nombres de los steps de ese job, algo así:)
# Complete job
# Qué hay en el workspace
# Qué máquina
# Quién y qué
# Set up job
# Un step que falla
```

**Verifica**:

```bash
gh run view "$FAILED_ID" --exit-status > /dev/null; echo "exit $?"
# exit 1
gh run view "$RUN_ID" --exit-status > /dev/null; echo "exit $?"
# exit 0
```

---

## Paso 4: Volver a ejecutar: --failed y --debug

**Por qué**: un re-run crea un **intento** nuevo (`attempt`) del mismo run, con el mismo commit y
el mismo YAML. Sirve para fallos que no dependen de tu código (una descarga que falló, una caída
de un servicio externo), no para fallos de tu código. `--failed` repite solo los jobs que fallaron
y los que dependen de ellos. `--debug` activa los logs de depuración del runner: líneas
`##[debug]` con lo que hace por dentro (variables que prepara, archivos que escribe, cómo lanza
cada step).

**Comando**: primero, el re-run del run en rojo, para comprobar lo que dijo la práctica 02:

```bash
gh run rerun "$FAILED_ID" --failed
# ✓ Requested rerun (failed jobs) of run <run-id>
sleep 5
gh run watch "$FAILED_ID" --exit-status --compact; echo "exit $?"
# ...
# X Un step que falla
# exit 1
```

Vuelve a fallar: mismo commit, mismo `exit 3`. Ahora, un re-run en modo depuración del run en
verde del paso 2:

```bash
gh run rerun "$RUN_ID" --debug
# ✓ Requested rerun of run <run-id>
sleep 5
gh run watch "$RUN_ID" --exit-status --compact
```

**Verifica**:

```bash
gh run view "$FAILED_ID" --json attempt --jq .attempt
# 2
gh run view "$RUN_ID" --json attempt --jq .attempt
# 2
gh run view "$RUN_ID" --log | grep -c '##\[debug\]'
# un número mayor que 0
gh run view "$RUN_ID" --attempt 1 --log | grep -c '##\[debug\]'
# 0
```

El intento 1 no tenía depuración; el 2, sí. Con `--attempt N` (`-a N`) eliges qué intento ver.

---

## Paso 5: Medir duración y resumir el día

**Por qué**: la UI te enseña un run cada vez. Con `--json` puedes calcular lo que ella no
resume: cuánto tarda cada run y cuántos fallaron hoy. Lo usarás a fondo en la Semana 19 para medir
coste; aquí basta con saber que los datos están ahí. `fromdateiso8601` es una función de jq que
convierte una fecha `2026-11-02T10:00:00Z` en segundos, y la resta da la duración.

**Comando**:

```bash
gh run list --workflow hello.yml --limit 5 \
  --json databaseId,conclusion,startedAt,updatedAt \
  --jq '.[] | "\(.databaseId)  \(.conclusion)  \((.updatedAt | fromdateiso8601) - (.startedAt | fromdateiso8601))s"'
# <run-id>  success  14s
# <run-id>  failure  11s
# ...
gh run list --created "$(date -u +%F)" --json conclusion \
  --jq 'group_by(.conclusion) | map("\(.[0].conclusion): \(length)") | .[]'
# failure: 1
# success: 5
```

`--created` acepta una fecha (`2026-11-02`) o un rango (`>=2026-11-01`). `date -u +%F` da la fecha
de hoy en UTC, la zona de las fechas de GitHub. La duración incluye la cola y la preparación del
runner, no solo tus steps: un run que tarda 15 s puede tener 3 s de trabajo real.

**Verifica**:

```bash
gh run list --created "$(date -u +%F)" --json conclusion --jq 'map(select(.conclusion == "success")) | length'
# un número mayor que 0
```

---

## ✅ Resultado

- [ ] Filtras runs con `gh run list` y `--json` + `--jq`
- [ ] Has lanzado `hello.yml` con `gh workflow run` y terminó en `success`
- [ ] Lees un run con `-v`, `--log`, `--log-failed` y `-j`
- [ ] Sabes por qué un re-run no arregla un fallo de tu código
- [ ] Has visto los logs `##[debug]` de un re-run con `--debug`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 01
#   ...
#   ✅ hello.yml terminó en success al menos una vez lanzado a mano (workflow_dispatch)
#   ...
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `gh workflow run` responde `HTTP 422: Workflow does not have 'workflow_dispatch' trigger` | `hello.yml` en `main` no declara `workflow_dispatch` | Añádelo en `on:` (práctica 02, paso 1), haz push y repite |
| `gh workflow run` responde `could not find any workflows named hello.yml` | El archivo no está en la rama por defecto, o el nombre no coincide | `gh workflow list` y usa el nombre exacto del archivo |
| `RUN_ID` vacío o con el run anterior | GitHub tardó en registrar el run | Aumenta el `sleep` y repite el `gh run list` |
| `gh run rerun --failed` no repite nada útil | El run falló por un YAML inválido y no llegó a tener jobs | No hay jobs que repetir: corrige el YAML con un commit |
| `gh run rerun` responde `cannot be rerun` en un run viejo | Los re-runs solo se permiten durante 30 días tras el run | Lanza uno nuevo con `gh workflow run` |
| `grep -c '##\[debug\]'` da `0` en el intento 2 | Miraste el intento 1, o el re-run aún no ha terminado | Espera con `gh run watch` y mira sin `--attempt` |
| La duración de un run sale absurda o la expresión `--jq` falla | El run aún no ha terminado y sus fechas no son las finales | Añade `--status completed` al `gh run list` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Tu primer workflow](02-primer-workflow.md) | [actionlint y pinning por SHA](04-actionlint-y-sha.md) |
