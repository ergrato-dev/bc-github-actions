# Práctica 04 — Un pipeline con grafo

> Un pipeline real no es una fila de jobs: es un grafo. Unos jobs corren en paralelo, otros
> esperan, y uno final tiene que contar qué pasó aunque algo haya fallado. Esta práctica monta ese
> grafo en `graph.yml` y lo rompe a propósito antes de llevar la idea a `ci.yml` en el proyecto.

**Tiempo estimado**: 1,5 h

## 🎯 Qué vas a conseguir

- `graph.yml`, un grafo en diamante: `prepare` → `lint` y `test` en paralelo → `report`
- `bash` como shell por defecto con `defaults:`
- Ver cómo un fallo en `test` deja `report` en `skipped`
- Un job final con `!cancelled()` que lee el resultado de todos con `needs`
- Un resumen en Markdown en la página del run con `$GITHUB_STEP_SUMMARY`

## 📋 Antes de empezar

Terminaste la [práctica 03](03-outputs-entre-steps-y-jobs.md).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
```

---

## Paso 1: El diamante y actionlint antes del push

**Por qué**: `needs:` define el grafo. Los jobs sin `needs:` arrancan a la vez; un job con
`needs: [a, b]` espera a los dos. `defaults.run.shell: bash` cambia el shell de todos los `run:`:
GitHub ejecuta entonces `bash --noprofile --norc -eo pipefail {0}`, y `pipefail` hace que un fallo
a mitad de una tubería (`cmd | grep x`) falle el step en lugar de perderse. actionlint comprueba
el grafo antes del push: un `needs:` a un job que no existe o un ciclo saltan en local.

**Comando**: crea `.github/workflows/graph.yml`:

```yaml
name: graph

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

# bash explícito activa pipefail en todos los run de este workflow.
defaults:
  run:
    shell: bash

jobs:
  prepare:
    name: Preparar
    runs-on: ubuntu-24.04
    outputs:
      started-at: ${{ steps.clock.outputs.started-at }}
    steps:
      - name: Hora de inicio
        id: clock
        run: echo "started-at=$(date -u +%H:%M:%S)" >> "$GITHUB_OUTPUT"

  lint:
    name: Lint
    needs: prepare
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: Todos los workflows usan .yml
        run: |
          found=$(find .github/workflows -name '*.yaml')
          test -z "$found" || { echo "renombra a .yml: $found"; exit 1; }

  test:
    name: Test
    needs: prepare
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: El archivo de control existe
        run: test -f .github/graph-ok

  report:
    name: Informe
    needs: [prepare, lint, test]
    runs-on: ubuntu-24.04
    steps:
      - name: Todo terminó
        run: echo "lint y test terminaron bien"
```

`test` comprueba un archivo, `.github/graph-ok`, que todavía no existe: es tu interruptor para
romper y arreglar el grafo sin tocar el YAML.

**Verifica**:

```bash
actionlint
# (sin salida: actionlint sin argumentos revisa todos los .github/workflows/*.yml)
yq '.jobs | to_entries[] | .key + " <- " + ((.value.needs // []) | [.] | flatten | join(","))' \
  .github/workflows/graph.yml
# prepare <-
# lint <- prepare
# test <- prepare
# report <- prepare,lint,test
```

---

## Paso 2: Romper test y ver report en skipped

**Por qué**: un job con el `if:` implícito, `success()`, solo arranca si **todos** los jobs de su
`needs:` terminaron en `success`. Si uno falla, se salta. Un job de informe con esa regla solo
informa cuando no hay nada que contar.

**Comando**:

```bash
git add .github/workflows/graph.yml
git commit -m "ci: add graph workflow"
git push
gh workflow run graph.yml
sleep 5
RUN_ID=$(gh run list --workflow graph.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status; echo "exit $?"
# ...
# exit 1
```

**Verifica**:

```bash
gh run view "$RUN_ID" --json jobs --jq '.jobs[] | .name + ": " + .conclusion'
# Preparar: success
# Lint: success
# Test: failure
# Informe: skipped
```

Abre el run en la UI: el grafo dibuja el diamante, con `Test` en rojo y `Informe` gris.

---

## Paso 3: Un informe que corre aunque algo falle

**Por qué**: `if: ${{ !cancelled() }}` arranca el job tanto si los anteriores fallaron como si no,
y solo se lo salta si cancelas el run (práctica 02, paso 5). Dentro, el contexto `needs` tiene el
`result` de cada job: `success`, `failure`, `cancelled` o `skipped`. `toJSON(needs)` lo pasa
entero al shell por `env:` y `jq`, que viene instalado en el runner, lo recorre. El informe
termina fallando si algo falló: si saliera en verde, un check del PR mentiría.

**Comando**: sustituye el job `report` por este:

```yaml
  report:
    name: Informe
    needs: [prepare, lint, test]
    if: ${{ !cancelled() }}
    runs-on: ubuntu-24.04
    steps:
      - name: Resultado de cada job
        env:
          NEEDS: ${{ toJSON(needs) }}
          STARTED_AT: ${{ needs.prepare.outputs.started-at }}
        run: |
          echo "empezó a las $STARTED_AT"
          jq -r 'to_entries[] | "\(.key): \(.value.result)"' <<<"$NEEDS"
          jq -e 'all(.[]; .result == "success")' <<<"$NEEDS" > /dev/null
```

`jq -e` sale con código 1 si la expresión es `false`: es la línea que hace fallar el job.

```bash
git commit -am "ci(graph): report even on failure"
git push
gh workflow run graph.yml
sleep 5
RUN_ID=$(gh run list --workflow graph.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status; echo "exit $?"
# exit 1
```

**Verifica**:

```bash
gh run view "$RUN_ID" --json jobs --jq '.jobs[] | .name + ": " + .conclusion'
# Preparar: success
# Lint: success
# Test: failure
# Informe: failure
gh run view "$RUN_ID" --log | grep -E 'Informe.*(lint|test): '
# Informe  Resultado de cada job  ...  lint: success
# Informe  Resultado de cada job  ...  test: failure
```

`Informe` ya no se salta: corre, cuenta qué pasó y falla porque `test` falló.

---

## Paso 4: Un resumen en la página del run

**Por qué**: el log se lee buscando; el resumen se ve al abrir el run. Todo lo que escribes en
`$GITHUB_STEP_SUMMARY` aparece en Markdown en la página del run, debajo del grafo. Cada step tiene
un límite de 1 MiB de resumen; si te pasas, el resumen de ese step no se sube y aparece un aviso,
pero el step no falla.

**Comando**: en el step *Resultado de cada job*, sustituye la línea `jq -r ...` por este bloque
(deja la de `jq -e` al final):

```yaml
          {
            echo "## graph"
            echo
            echo "Empezó a las ${STARTED_AT} UTC."
            echo
            echo "| Job | Resultado |"
            echo "|---|---|"
            jq -r 'to_entries[] | "| \(.key) | \(.value.result) |"' <<<"$NEEDS"
          } >> "$GITHUB_STEP_SUMMARY"
```

```bash
git commit -am "ci(graph): write step summary"
git push
gh workflow run graph.yml
sleep 5
RUN_ID=$(gh run list --workflow graph.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID"
gh run view "$RUN_ID" --web
```

**Verifica**: en la página del run, debajo del grafo, aparece *Informe summary* con el título
`graph`, la hora y la tabla: `prepare` y `lint` en `success`, `test` en `failure`.

```bash
yq '.jobs.report.steps[0].run' .github/workflows/graph.yml | grep -c GITHUB_STEP_SUMMARY
# 1
```

---

## Paso 5: Dejarlo en verde

**Por qué**: el grafo está bien; lo que falla es el dato que `test` comprueba. Crear el archivo
cambia el resultado sin tocar el YAML, igual que un commit que arregla un test real.

**Comando**:

```bash
touch .github/graph-ok
git add .github/graph-ok
git commit -m "chore: add graph control file"
git push
gh workflow run graph.yml
sleep 5
RUN_ID=$(gh run list --workflow graph.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status; echo "exit $?"
# exit 0
```

**Verifica**:

```bash
gh run view "$RUN_ID" --json jobs --jq '.jobs[] | .name + ": " + .conclusion'
# Preparar: success
# Lint: success
# Test: success
# Informe: success
gh run list --workflow graph.yml --event workflow_dispatch --status success \
  --json databaseId --jq length
# 1
```

En el proyecto llevas esta misma forma a `ci.yml`: un job que calcula la versión y un `summary`
que espera a todos, con la variable `PROJECT_NAME` de la práctica 01.

---

## ✅ Resultado

- [ ] `graph.yml` dibuja un diamante: `prepare` → `lint` y `test` en paralelo → `report`
- [ ] `defaults.run.shell: bash` está en la raíz del workflow
- [ ] Has visto `report` en `skipped` con el `if:` implícito y corriendo con `!cancelled()`
- [ ] El informe lee `needs` por `env:` y falla si algún job falló
- [ ] El resumen aparece en la página del run
- [ ] El último run de `graph.yml` lanzado a mano está en verde

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 02
```

Los checks de `ci.yml` siguen en rojo hasta que termines el [proyecto](../3-proyecto/README.md).

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| actionlint: `job "report" needs job "tests" which does not exist` | Un nombre de `needs:` no coincide con el id del job | Los ids son las claves bajo `jobs:`, no el `name:` |
| actionlint: `string should not be empty` en `if: !cancelled()` | En YAML `!` abre una etiqueta y el valor queda vacío | `if: ${{ !cancelled() }}` |
| `Informe` sale `success` aunque `test` falló | Falta la línea `jq -e` al final | Sin ella el step termina con el código de la última orden, que fue bien |
| `jq: error ... Cannot iterate over null` | `NEEDS` está vacío: el job no tiene `needs:` | `needs: [prepare, lint, test]` |
| `Test` sigue en rojo tras el paso 5 | `.github/graph-ok` no llegó a `main` | `git ls-files .github/graph-ok` y `git push` |
| No aparece el resumen | Escribiste en `$GITHUB_OUTPUT` en lugar de `$GITHUB_STEP_SUMMARY` | Revisa la redirección del bloque `{ ... }` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Outputs entre steps y jobs](03-outputs-entre-steps-y-jobs.md) | [Proyecto: capa 02 de tablero](../3-proyecto/README.md) |
