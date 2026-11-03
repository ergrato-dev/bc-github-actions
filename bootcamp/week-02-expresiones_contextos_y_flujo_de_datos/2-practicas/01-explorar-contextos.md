# Práctica 01 — Explorar contextos

> Un contexto es lo que GitHub sabe del run en el momento de evaluar una expresión: quién lo lanzó,
> sobre qué commit, en qué máquina. Esta práctica escribe `explore.yml`, un workflow que solo mira
> y no toca nada, para que veas esos datos con tus ojos antes de usarlos en `ci.yml`.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `explore.yml`, un workflow que se lanza solo a mano e imprime los contextos `github`, `runner`,
  `job` y `steps`
- Pasar cualquier valor de un contexto al shell por `env:`, nunca escrito dentro de `run:`
- Crear la variable de configuración `PROJECT_NAME` y leerla con `vars.PROJECT_NAME`
- Probar las funciones `format`, `contains`, `startsWith`, `join`, `fromJSON` y `hashFiles`

## 📋 Antes de empezar

Terminaste la Semana 01: `~/code/tablero` tiene `hello.yml` y `ci.yml` en verde en `main`.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
ls .github/workflows
# ci.yml  hello.yml
```

Todos los workflows de práctica de esta semana usan **solo** `workflow_dispatch`. Tienen que estar
en `main` para que puedas lanzarlos (teoría 05 de la Semana 01), pero así un push no los ejecuta y
el historial de Actions no se llena de runs de prueba. Cada push a `main` sí lanzará `ci.yml`: es
lo esperado.

---

## Paso 1: El contexto github, campo a campo

**Por qué**: `${{ github.sha }}` no lo resuelve el shell: lo sustituye GitHub **antes** de mandar
el step al runner. Si esa sustitución cae dentro de `run:`, el valor pasa a formar parte del
script y un valor con comillas o `$(...)` se ejecutaría como código (teoría 02, sección 4). La
forma segura y la que usarás siempre: la expresión va en `env:` y el script lee una variable de
entorno normal.

**Comando**: crea `.github/workflows/explore.yml`:

```yaml
name: explore

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  contexts:
    name: Contextos
    runs-on: ubuntu-24.04
    steps:
      - name: Contexto github
        id: github-info
        env:
          EVENT_NAME: ${{ github.event_name }}
          REF: ${{ github.ref }}
          SHA: ${{ github.sha }}
          ACTOR: ${{ github.actor }}
          REPOSITORY: ${{ github.repository }}
          RUN_ID: ${{ github.run_id }}
          RUN_ATTEMPT: ${{ github.run_attempt }}
        run: |
          echo "evento:      $EVENT_NAME"
          echo "ref:         $REF"
          echo "sha:         $SHA"
          echo "actor:       $ACTOR"
          echo "repositorio: $REPOSITORY"
          echo "run:         $RUN_ID (intento $RUN_ATTEMPT)"
```

Varios de estos valores existen también como variables de entorno por defecto (`$GITHUB_SHA`,
`$GITHUB_ACTOR`...). El contexto sirve allí donde no hay shell: en un `if:`, en un `with:` o en
los `outputs:` de un job, que verás en la práctica 03.

**Verifica**:

```bash
actionlint .github/workflows/explore.yml
# (sin salida: no hay errores)
yq '.jobs.contexts.steps[0].run' .github/workflows/explore.yml | grep -c '\${{'
# 0
```

El `0` es lo que importa: ninguna expresión dentro del script.

---

## Paso 2: runner, job y steps en JSON

**Por qué**: `toJSON()` convierte un contexto entero en texto JSON. Es la forma más rápida de
descubrir qué campos tiene sin buscarlo en la documentación. Vale para contextos que no llevan
credenciales: `runner`, `job`, `steps`. **Nunca** `toJSON(secrets)`, que es la definición de
imprimir secretos, ni `toJSON(github)` entero, que incluye `github.token`: GitHub lo enmascara en
el log, pero el valor queda igualmente en el entorno del step, al alcance de cualquier
programa que corra en él. Pide los campos que necesitas, uno a uno, como en el paso 1.

**Comando**: añade este step al final de `steps:`:

```yaml
      - name: runner, job y steps
        env:
          RUNNER: ${{ toJSON(runner) }}
          JOB: ${{ toJSON(job) }}
          STEPS: ${{ toJSON(steps) }}
        run: |
          echo "runner: $RUNNER"
          echo "job:    $JOB"
          echo "steps:  $STEPS"
```

`steps` solo contiene los steps **anteriores** del mismo job que tienen `id:`. Por eso el primer
step lleva `id: github-info`: sin él, `steps` sería `{}`.

**Verifica**:

```bash
yq '.jobs.contexts.steps[] | select(.name == "runner, job y steps") | .env | keys | join(",")' \
  .github/workflows/explore.yml
# RUNNER,JOB,STEPS
grep -nE 'toJSON\((secrets|github)\)' .github/workflows/explore.yml || echo "nada peligroso"
# nada peligroso
```

---

## Paso 3: Una variable de configuración

**Por qué**: un valor que no es secreto pero que no quieres escribir en cada workflow (el nombre
del proyecto, una URL pública, una región) va en una **variable de configuración**. Vive en los
settings del repo o de la organización, se lee con el contexto `vars` y la cambias sin tocar el
YAML. Si la variable no existe, `vars.X` vale cadena vacía: el workflow no falla, simplemente
recibe nada.

**Comando**:

```bash
gh variable set PROJECT_NAME --body tablero
# ✓ Created variable PROJECT_NAME for <tu-org>/tablero
```

En la UI es **Settings → Secrets and variables → Actions → Variables**. Añade este step al final
de `explore.yml`:

```yaml
      - name: Variable de configuración
        env:
          PROJECT: ${{ vars.PROJECT_NAME }}
        run: echo "proyecto = ${PROJECT:-<sin definir>}"
```

**Verifica**:

```bash
gh variable get PROJECT_NAME
# tablero
gh variable list --json name,value --jq '.[] | .name + "=" + .value'
# PROJECT_NAME=tablero
```

---

## Paso 4: Funciones de expresión

**Por qué**: las expresiones tienen un puñado de funciones propias (teoría 02). No hay bucles ni
variables: todo se resuelve en una línea, antes de que el step empiece. `hashFiles()` es la única
que mira el disco del runner, así que necesita el código descargado: sin checkout devuelve cadena
vacía.

**Comando**: añade el checkout **como primer step** del job (antes de *Contexto github*) y un step
nuevo al final:

```yaml
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
```

```yaml
      - name: Funciones
        env:
          GREETING: ${{ format('{0} corre en {1}', github.repository, runner.os) }}
          IS_MAIN: ${{ github.ref_name == 'main' }}
          LONG_LIVED: ${{ contains(fromJSON('["main", "develop"]'), github.ref_name) }}
          IS_TAG: ${{ startsWith(github.ref, 'refs/tags/') }}
          PARTS: ${{ join(fromJSON('["api", "web", "db"]'), ', ') }}
          LOCK_HASH: ${{ hashFiles('api/uv.lock') }}
          MISSING_HASH: ${{ hashFiles('no-existe.lock') }}
        run: |
          echo "format:     $GREETING"
          echo "==:         $IS_MAIN"
          echo "contains:   $LONG_LIVED"
          echo "startsWith: $IS_TAG"
          echo "join:       $PARTS"
          echo "hashFiles:  $LOCK_HASH"
          echo "sin archivo: '${MISSING_HASH}'"
```

Dos detalles de sintaxis: dentro de una expresión las cadenas van entre **comillas simples**, y
`fromJSON('[...]')` es la forma de escribir una lista literal, que las expresiones no tienen.

**Verifica**:

```bash
actionlint .github/workflows/explore.yml
# (sin salida: no hay errores)
yq '[.jobs.contexts.steps[].name // "checkout"] | join(" | ")' .github/workflows/explore.yml
# checkout | Contexto github | runner, job y steps | Variable de configuración | Funciones
```

---

## Paso 5: Lanzarlo y leer el log

**Por qué**: `workflow_dispatch` solo funciona si el archivo existe en la rama por defecto. Con el
push a `main` el workflow queda disponible; con `gh workflow run` lo lanzas. El log es donde
compruebas que cada expresión dio lo que esperabas.

**Comando**:

```bash
git add .github/workflows/explore.yml
git commit -m "ci: add explore workflow"
git push
gh workflow run explore.yml
# ✓ Created workflow_dispatch event for explore.yml at main
sleep 5   # el run tarda unos segundos en aparecer
RUN_ID=$(gh run list --workflow explore.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
gh run view "$RUN_ID" --log | grep -E 'evento:|proyecto =|format:|contains:|join:|hashFiles:|sin archivo'
# Contextos  Contexto github  ...  evento:      workflow_dispatch
# Contextos  Variable de configuración  ...  proyecto = tablero
# Contextos  Funciones  ...  format:     <tu-org>/tablero corre en Linux
# Contextos  Funciones  ...  contains:   true
# Contextos  Funciones  ...  join:       api, web, db
# Contextos  Funciones  ...  hashFiles:  <64 caracteres hexadecimales>
# Contextos  Funciones  ...  sin archivo: ''
```

Busca también en el log la línea `steps:` del paso 2: verás `"github-info"` con su `outcome` y su
`conclusion`. Son los dos campos que usarás en la práctica 02.

**Verifica**:

```bash
gh run list --workflow explore.yml --event workflow_dispatch --status success \
  --json databaseId --jq length
# 1
```

---

## ✅ Resultado

- [ ] `explore.yml` está en `main` y solo se lanza a mano
- [ ] Ningún `run:` de `explore.yml` contiene `${{ }}`: todo llega por `env:`
- [ ] La variable `PROJECT_NAME` vale `tablero` y el workflow la lee con `vars.PROJECT_NAME`
- [ ] Has visto en el log el resultado de seis funciones de expresión
- [ ] Al menos un run de `explore.yml` lanzado a mano terminó en `success`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 02
```

Los checks de `conditions.yml`, `data-flow.yml`, `graph.yml` y `ci.yml` siguen en rojo: llegan en
las prácticas siguientes y en el proyecto.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `gh workflow run` responde `could not find any workflows named explore.yml` | El archivo no está en `main` en GitHub | `git push` y comprueba con `gh workflow list` |
| `HTTP 422: Workflow does not have 'workflow_dispatch' trigger` | `on:` no tiene `workflow_dispatch:` | Revisa el paso 1 y vuelve a hacer push |
| `proyecto = <sin definir>` | La variable no existe o tiene otro nombre | `gh variable list`; los nombres distinguen mayúsculas |
| `hashFiles:` sale vacío | El checkout no está antes del step *Funciones* | Muévelo al principio de `steps:` (paso 4) |
| actionlint: `got unexpected character '"'` | Una cadena dentro de `${{ }}` va entre comillas dobles | Las cadenas de una expresión van entre comillas simples |
| actionlint: `could not parse as YAML: mapping values are not allowed in this context` | Un `run:` de una línea contiene `: ` (dos puntos y espacio), que YAML lee como otra clave | Pasa a bloque con `run: |` o quita el espacio tras los dos puntos |
| `steps:  {}` en el log | El primer step no tiene `id:` | Añade `id: github-info` (paso 2) |
| El run no aparece tras `gh workflow run` | Tarda unos segundos en crearse | Repite `gh run list --workflow explore.yml --limit 1` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Datos entre jobs: needs y outputs](../1-teoria/06-datos-entre-jobs.md) | [Condiciones y estado](02-condiciones-y-estado.md) |
