# Práctica 01 — Depurar un run que falla

> Un workflow de laboratorio que falla como fallan los de verdad: un script que busca un archivo
> donde no está. Lo lees desde la terminal sin abrir el navegador, lo relanzas con depuración, lo
> arreglas y le enseñas a explicar sus propios fallos con anotaciones, grupos, máscaras y resumen.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `debug-lab.yml` en `main`, con `workflow_dispatch` y un input
- Un run rojo leído con `gh run view`, `--log-failed` y `--log | grep`, sin abrir la UI
- El mismo run relanzado con `gh run rerun --failed --debug` y sus líneas `##[debug]`
- El script arreglado y emitiendo `::group::`, `::notice`, `::warning` con archivo y línea,
  `::debug::`, `::add-mask::` y un resumen en `$GITHUB_STEP_SUMMARY`
- Un `::error` con archivo y línea que sí pone el step en rojo, leído como dato desde la API

## 📋 Antes de empezar

Cerraste la Semana 07: `main` tiene los seis workflows de la capa 07 en verde. actionlint y
zizmor están instalados ([`docs/setup-entorno.md`](../../../docs/setup-entorno.md), apartados 3
y 4).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
actionlint -version | head -1
# 1.7.12
zizmor --version
# zizmor 1.31.1
```

---

## Paso 1: Un workflow que falla

**Por qué**: para aprender a leer un fallo necesitas uno que no esperes ver resuelto en la
primera línea del log. Este script comprueba que la versión de Python fijada en
`api/.python-version` es la que dices en el input, pero la lee desde la raíz del repo: el error
de ruta más común en un `run:`, que en tu máquina no ves porque allí estás dentro de `api/`.
`workflow_dispatch` solo funciona si el workflow está en la rama por defecto
([teoría 07](../1-teoria/07-estrategia-de-pruebas-de-workflows.md#la-rama-de-prueba)): por eso va a
`main`. No corre en ningún `push` ni PR, así que no deja nada en rojo hasta que tú lo lances.

**Comando**: crea `.github/workflows/debug-lab.yml`.

```yaml
name: debug-lab

on:
  workflow_dispatch:
    inputs:
      expected_python:
        description: Versión de Python que esperas en api/.python-version
        type: string
        default: "3.15"

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  versions:
    name: Versiones declaradas
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Comprobar la versión de Python
        # El input lo escribe quien lanza el run: llega al shell por env:, nunca con ${{ }}.
        env:
          EXPECTED_PYTHON: ${{ inputs.expected_python }}
        run: |
          pinned=$(cat .python-version)
          echo "Fijada: $pinned · esperada: $EXPECTED_PYTHON"
          test "$pinned" = "$EXPECTED_PYTHON"
```

```bash
actionlint .github/workflows/debug-lab.yml && zizmor --offline .github/workflows/debug-lab.yml
# No findings to report. Good job! (1 suppressed)
git add .github/workflows/debug-lab.yml
git commit -m "test: add debug lab workflow"
git push
gh workflow run debug-lab.yml
sleep 10
id=$(gh run list --workflow debug-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
echo "$id" > /tmp/debug-lab-run.txt
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 1
```

Los linters no protestan: el YAML está bien escrito y es seguro. El fallo es de lógica, y eso
solo lo ve quien ejecuta ([teoría 07](../1-teoria/07-estrategia-de-pruebas-de-workflows.md#qué-capa-caza-cada-error)).

**Verifica**:

```bash
gh run view "$id" --json conclusion,event --jq '"\(.event) \(.conclusion)"'
# workflow_dispatch failure
```

---

## Paso 2: Leer el fallo desde la terminal

**Por qué**: el orden de lectura es siempre el mismo: anotaciones, primer job en rojo, primer step
en rojo, primer error del log ([teoría 01](../1-teoria/01-leer-un-run-que-falla.md#el-orden-de-lectura)).
`gh` lo recorre igual que la UI y además te deja usar `grep`, que en un run de cinco jobs es la
diferencia entre un minuto y diez.

**Comando**: la vista general, el log solo de lo que falló y una búsqueda en el log completo.

```bash
id=$(cat /tmp/debug-lab-run.txt)
gh run view "$id"
# X main debug-lab · <id>
# ...
# JOBS
# X Versiones declaradas in 6s (ID <job-id>)
#   ✓ Set up job
#   ✓ Run actions/checkout@...
#   X Comprobar la versión de Python
# ...
# ANNOTATIONS
# X Process completed with exit code 1.
# Versiones declaradas: .github#...

gh run view "$id" --log-failed | tail -2
# Versiones declaradas  Comprobar la versión de Python  2026-...Z cat: .python-version: No such file or directory
# Versiones declaradas  Comprobar la versión de Python  2026-...Z ##[error]Process completed with exit code 1.
```

La anotación solo dice el código de salida: es la que pone el runner cuando un step termina con
algo distinto de 0. La causa está **una línea más arriba**, en la salida de `cat`. Y fíjate en que
el `echo` de la segunda línea del script nunca se ejecutó: con `bash -e`, la asignación
`pinned=$(cat ...)` hereda el código de `cat` y el script para ahí.

`--log-failed` lleva el job y el step delante de cada línea, así que una búsqueda en el log
completo sigue diciendo de dónde viene cada coincidencia:

```bash
gh run view "$id" --log | grep -n 'python-version'
# <n>:Versiones declaradas  Comprobar la versión de Python  ...   pinned=$(cat .python-version)
# <n>:Versiones declaradas  Comprobar la versión de Python  ... cat: .python-version: No such file or directory
```

La primera coincidencia es el script tal como lo recibió el runner (lo imprime al empezar cada
`run:`); la segunda, el error.

**Verifica**: el job y el step en rojo, sacados como datos.

```bash
gh run view "$id" --json jobs \
  --jq '.jobs[] | .name as $j | .steps[] | select(.conclusion == "failure") | "\($j) / \(.name)"'
# Versiones declaradas / Comprobar la versión de Python
```

---

## Paso 3: Un reintento con depuración

**Por qué**: aquí el log normal ya bastaba, pero no siempre es así: cuando un `if:` no hace lo que
crees o una action se comporta raro, las líneas `##[debug]` enseñan cómo se evaluó cada expresión
y qué hizo cada action por dentro ([teoría 03](../1-teoria/03-logs-de-depuracion.md)).
`--debug` las activa **solo para ese intento**: no creas ningún secreto ni variable que luego
tengas que acordarte de borrar. Y el reintento corre el mismo YAML del mismo SHA, así que vuelve a
fallar igual: eso confirma que no es intermitente.

**Comando**:

```bash
gh run rerun "$id" --failed --debug
sleep 5
gh run watch "$id" > /dev/null
gh run view "$id" --log-failed | grep -F '##[debug]' | head -5
# Versiones declaradas  Comprobar la versión de Python  ...  ##[debug]Evaluating condition for step: 'Comprobar la versión de Python'
# Versiones declaradas  Comprobar la versión de Python  ...  ##[debug]Evaluating: success()
# ...
```

Busca `inputs.expected_python` en ese log: el runner enseña cómo evaluó la expresión del `env:`
y su resultado, `3.15`, antes de pasarlo al shell. Es la forma de comprobar el valor de una
expresión sin añadir un `echo`.

**Verifica**: el run va por el segundo intento y su log trae líneas de depuración.

```bash
gh run view "$id" --json attempt --jq .attempt
# 2
gh run view "$id" --log-failed | grep -cF '##[debug]'
# un número mayor que 0
gh run view "$id" --attempt 1 --log-failed | grep -cF '##[debug]'
# 0
```

El primer intento sigue ahí, sin depuración: `--attempt` elige cuál lees.

---

## Paso 4: Arreglarlo y que se explique solo

**Por qué**: arreglar la ruta es una línea. Pero el próximo que lea este run no debería necesitar
`grep`: un script bien hecho dice qué comprobó con **anotaciones** (arriba del run, con archivo y
línea), pliega lo largo en **grupos**, deja pistas `::debug::` que solo salen cuando alguien pide
depuración y resume el resultado en `$GITHUB_STEP_SUMMARY`
([teoría 02](../1-teoria/02-comandos-de-workflow.md)). El token de usar y tirar del último step
existe para que veas `::add-mask::` trabajar: se enmascara **antes** de imprimirlo.

`LAB_OWNER` lee una variable del repo que no existe: el `||` le da un valor por defecto. La usarás
con act en la práctica 04.

**Comando**: sustituye los steps del job por estos.

```yaml
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Inventario de versiones
        env:
          LAB_OWNER: ${{ vars.LAB_OWNER || 'sin definir' }}
        run: |
          echo "::debug::Directorio de trabajo: $PWD"
          echo "::group::Archivos de versión"
          grep -Hn '' api/.python-version
          grep -Hn '^requires-python' api/pyproject.toml
          grep -Hn '"packageManager"' web/package.json
          echo "::endgroup::"
          echo "::notice title=Responsable::$LAB_OWNER"
          # Un rango abierto acepta versiones de Python que nadie ha probado todavía.
          line=$(grep -n '^requires-python = ">=' api/pyproject.toml | cut -d: -f1 || true)
          if [[ -n "$line" ]]; then
            echo "::warning file=api/pyproject.toml,line=$line,title=Rango abierto::requires-python no tiene techo"
          fi

      - name: Comprobar la versión de Python
        # El input lo escribe quien lanza el run: llega al shell por env:, nunca con ${{ }}.
        env:
          EXPECTED_PYTHON: ${{ inputs.expected_python }}
        run: |
          pinned=$(cat api/.python-version)
          {
            echo "## Versiones de tablero"
            echo "| Qué | Valor |"
            echo "|---|---|"
            echo "| Python fijado | \`$pinned\` |"
            echo "| Python esperado | \`$EXPECTED_PYTHON\` |"
          } >> "$GITHUB_STEP_SUMMARY"
          if [[ "$pinned" != "$EXPECTED_PYTHON" ]]; then
            echo "::error file=api/.python-version,line=1,title=Versión de Python::fijada $pinned, esperada $EXPECTED_PYTHON"
            exit 1
          fi
          echo "::notice title=Python::$pinned, la esperada"

      - name: Token de sesión de usar y tirar
        run: |
          session_token=$(openssl rand -hex 16)
          # Se enmascara antes de que nada pueda imprimirlo.
          echo "::add-mask::$session_token"
          echo "Token de sesión: $session_token"
```

```bash
actionlint .github/workflows/debug-lab.yml && zizmor --offline .github/workflows/debug-lab.yml
# No findings to report. Good job! (1 suppressed)
git add .github/workflows/debug-lab.yml
git commit -m "test(debug-lab): read python version from api and annotate the result"
git push
gh workflow run debug-lab.yml
sleep 10
id=$(gh run list --workflow debug-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
```

**Verifica**: el run en verde, tres anotaciones leídas desde la API del check run y el token
enmascarado en el log.

```bash
job=$(gh run view "$id" --json jobs --jq '.jobs[0].databaseId')
gh api "repos/{owner}/{repo}/check-runs/$job/annotations" \
  --jq '[.[].annotation_level] | sort | join(",")'
# notice,notice,warning
gh api "repos/{owner}/{repo}/check-runs/$job/annotations" \
  --jq '.[] | select(.annotation_level == "warning") | "\(.path):\(.start_line) \(.message)"'
# api/pyproject.toml:5 requires-python no tiene techo
gh run view "$id" --log | grep -F 'Token de sesión'
# Versiones declaradas  Token de sesión de usar y tirar  ...Z Token de sesión: ***
```

Abre el run con `gh run view "$id" --web`: arriba, las tres anotaciones; en el step de
inventario, el grupo **Archivos de versión** plegado; y en la página del run, la tabla del resumen.
El `::debug::` no aparece: solo sale en un intento con depuración.

---

## Paso 5: Un error con archivo y línea

**Por qué**: `::error` crea la marca roja pero no cambia el código de salida
([teoría 02](../1-teoria/02-comandos-de-workflow.md#una-anotación-de-error-no-falla-el-step)). Por
eso el script emite la anotación **y luego** sale con 1: el step se pone rojo y la anotación dice
exactamente qué archivo y qué línea mirar, en lugar del genérico *Process completed with exit
code 1*.

**Comando**: lánzalo esperando una versión que no es la fijada.

```bash
gh workflow run debug-lab.yml -f expected_python=3.14
sleep 10
id=$(gh run list --workflow debug-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 1
```

**Verifica**: las anotaciones de error, con su ruta y su línea.

```bash
job=$(gh run view "$id" --json jobs --jq '.jobs[0].databaseId')
gh api "repos/{owner}/{repo}/check-runs/$job/annotations" \
  --jq '.[] | select(.annotation_level == "failure") | "\(.path):\(.start_line)\t\(.message)"'
# api/.python-version:1	fijada 3.15, esperada 3.14
# .github:...	Process completed with exit code 1.
```

La primera es la tuya; la segunda, la del runner. El resumen del job sigue escribiéndose aunque el
step falle: el bloque `{ ... } >> "$GITHUB_STEP_SUMMARY"` va antes del `exit 1`. Compara este
run con el del paso 1: allí necesitaste el log para saber qué pasaba; aquí la anotación ya lo dice
todo, y en un PR aparecería sobre la línea del diff.

`debug-lab.yml` se queda en `main`: en la práctica 03 lo pasarás por zizmor y en la 04 lo
ejecutarás con act.

---

## ✅ Resultado

- [ ] `debug-lab.yml` está en `main` y pasa actionlint y zizmor
- [ ] Leíste el primer fallo con `gh run view`, `--log-failed` y `--log | grep`
- [ ] Relanzaste el run con `--failed --debug` y viste líneas `##[debug]` solo en el intento 2
- [ ] El run arreglado termina en verde con dos `notice` y un `warning` con archivo y línea
- [ ] El token de sesión sale como `***` en el log
- [ ] Un run con `expected_python=3.14` termina en rojo con un `::error` en `api/.python-version:1`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 08
# ✅ Todos tus workflows pasan actionlint
# ✅ Toda uses: remota de tus workflows está fijada por SHA de 40 caracteres con el tag en comentario
```

Las comprobaciones de `lint-workflows.yml` y `ci-local.sh` siguen en rojo: llegan en las
prácticas 02 a 04.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `could not find any workflows named debug-lab.yml` | El archivo no está en `main` | Paso 1: `git push` a `main` antes de `gh workflow run` |
| `gh run list` devuelve el run anterior | El run nuevo aún no se había creado | Sube el `sleep` a 15 segundos y repite el `gh run list` |
| `--log-failed` no devuelve nada | El run aún está en curso o terminó en verde | `gh run watch "$id"` y comprueba `conclusion` |
| `gh run rerun` dice `cannot be rerun` | Hay un intento en marcha, o el run es de hace más de 30 días | Espera a que termine o lanza uno nuevo con `gh workflow run` |
| Sin líneas `##[debug]` tras el reintento | Lees el intento 1, o el rerun fue sin `--debug` | `gh run view "$id" --json attempt`; repite con `--debug` |
| La anotación `warning` no tiene archivo | `line` salió vacío porque el `grep` no casó | Mira el `requires-python` de tu `api/pyproject.toml` y ajusta el patrón |
| Las anotaciones salen como texto en el log | Espacios antes de `::` o comando mal escrito | La línea tiene que empezar exactamente por `::warning ` o `::error ` |
| El token sale en claro | `echo` antes de `::add-mask::` | El orden importa: enmascara primero, imprime después |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Estrategia de pruebas de workflows](../1-teoria/07-estrategia-de-pruebas-de-workflows.md) | [actionlint y problem matchers](02-actionlint-y-problem-matchers.md) |
