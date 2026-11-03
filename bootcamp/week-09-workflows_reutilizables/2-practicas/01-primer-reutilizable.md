# Práctica 01 — Primer reutilizable

> Los jobs de `ci-api.yml` solo valen para `api/`. En esta práctica los mueves a `_python.yml`,
> que solo corre cuando otro workflow lo llama, y dejas `ci-api.yml` en una llamada.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `_python.yml`, disparado solo por `workflow_call`, con cuatro inputs tipados
- `ci-api.yml` reducido a un job `api` que llama a `_python.yml` con `with:`
- La llamada ejecutada en tu Docker con `ci-local.sh` antes del push
- Los errores de contrato que actionlint para, y el run del PR leído con `gh run view`

## 📋 Antes de empezar

Terminaste la Semana 08: `lint-workflows.yml` corre en cada PR y tienes `scripts/ci-local.sh`.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git switch -c ci/reusable-python
wc -l .github/workflows/ci-api.yml
# 113 .github/workflows/ci-api.yml
```

---

## Paso 1: Un workflow que solo se llama

**Por qué**: con `on: workflow_call` y ningún otro evento, el workflow solo corre cuando un job
de otro lo nombra en `uses:`: quien llama decide cuándo; el reutilizable, cómo
([teoría 02](../1-teoria/02-llamar-a-un-reutilizable.md#el-lado-del-llamado-on-workflow_call)).
Lo que cambia entre proyectos entra por inputs **con tipo**: `integration` es `boolean`, así que
el `if:` recibe un booleano y no la cadena `"false"`, que es verdadera
([teoría 03](../1-teoria/03-inputs-y-outputs.md#declarar-inputs)). El `_` del nombre es
convención de `tablero`: los reutilizables salen primero en `ls`.

**Comando**: crea `.github/workflows/_python.yml` con la cabecera.

```yaml
# Reutilizable: lint, tests unitarios y, si se pide, integración contra PostgreSQL de un
# proyecto Python gestionado con uv. Solo se ejecuta cuando otro workflow lo llama.
name: _python

on:
  workflow_call:
    inputs:
      working-directory:
        description: Carpeta del proyecto, la que contiene pyproject.toml y uv.lock
        type: string
        required: true
      package:
        description: Paquete Python que se mide con la cobertura y que trae el módulo migrate
        type: string
        required: true
      coverage-min:
        description: Cobertura mínima de los tests unitarios, en porcentaje
        type: number
        default: 60
      integration:
        description: Ejecutar tests/integration contra un PostgreSQL 17 de servicio
        type: boolean
        default: true

# Techo de permisos del reutilizable: el llamador puede dar menos, nunca más.
permissions:
  contents: read
```

**Verifica**: las órdenes de `reusables-only-call` y `python-inputs`.

```bash
yq '.on | keys | join(",")' .github/workflows/_python.yml
# workflow_call
yq '.on.workflow_call.inputs | to_entries | map(.key + ":" + .value.type) | sort | join(",")' .github/workflows/_python.yml
# coverage-min:number,integration:boolean,package:string,working-directory:string
```

---

## Paso 2: Los jobs, con inputs en lugar de `api`

**Por qué**: son los jobs de `ci-api.yml` con tres cambios. `api` y `tablero` salen de
`inputs`. El `defaults` pasa de la raíz a cada job: en la raíz no hay contexto y `inputs` no se
puede leer. Y en `run:` los inputs llegan por `env:`, nunca interpolados (regla 4;
[teoría 03](../1-teoria/03-inputs-y-outputs.md#inputs-dentro-de-run-siempre-por-env)).

**Comando**: añade al final de `_python.yml` el bloque `jobs:`.

```yaml
jobs:
  lint:
    name: Lint y formato (ruff)
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    defaults:
      run:
        shell: bash
        working-directory: ${{ inputs.working-directory }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
        with:
          version: "0.13.6"
          enable-cache: true
          cache-dependency-glob: ${{ inputs.working-directory }}/uv.lock
      - name: Dependencias exactas del lockfile
        run: uv sync --locked
      - name: ruff check
        run: uv run --no-sync ruff check --output-format=github .
      - name: ruff format
        run: uv run --no-sync ruff format --check .

  test:
    name: Tests unitarios
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    defaults:
      run:
        shell: bash
        working-directory: ${{ inputs.working-directory }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
        with:
          version: "0.13.6"
          enable-cache: true
          cache-dependency-glob: ${{ inputs.working-directory }}/uv.lock
      - name: Dependencias exactas del lockfile
        run: uv sync --locked
      - name: pytest con cobertura
        env:
          PACKAGE: ${{ inputs.package }}
          COVERAGE_MIN: ${{ inputs.coverage-min }}
        run: uv run --no-sync pytest tests/unit --cov="$PACKAGE" --cov-report=term-missing --cov-fail-under="$COVERAGE_MIN"

  integration:
    name: Tests de integración (PostgreSQL 17)
    needs: test
    if: ${{ inputs.integration }}
    runs-on: ubuntu-24.04
    timeout-minutes: 15
    defaults:
      run:
        shell: bash
        working-directory: ${{ inputs.working-directory }}
    services:
      postgres:
        image: postgres:17.11-alpine
        env:
          POSTGRES_USER: tablero
          # Credencial desechable de CI: la base nace y muere con el job.
          POSTGRES_PASSWORD: cambiame
          POSTGRES_DB: tablero_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U tablero -d tablero_test"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10
    env:
      DATABASE_URL: postgresql://tablero:cambiame@localhost:5432/tablero_test
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
        with:
          version: "0.13.6"
          enable-cache: true
          cache-dependency-glob: ${{ inputs.working-directory }}/uv.lock
      - name: Dependencias exactas del lockfile
        run: uv sync --locked
      - name: Migraciones
        env:
          PACKAGE: ${{ inputs.package }}
        run: uv run --no-sync python -m "$PACKAGE.migrate"
      - name: pytest contra PostgreSQL
        run: uv run --no-sync pytest tests/integration -rs
      - name: Logs de PostgreSQL
        if: ${{ failure() }}
        env:
          POSTGRES_CONTAINER: ${{ job.services.postgres.id }}
        run: docker logs "$POSTGRES_CONTAINER"
```

**Verifica**: actionlint, el `if` de `python-integration-optional` y ningún input en un `run:`.

```bash
actionlint .github/workflows/_python.yml && echo "actionlint ok"
# actionlint ok
yq '.jobs.integration.if' .github/workflows/_python.yml
# ${{ inputs.integration }}
yq '.jobs[].steps[].run // ""' .github/workflows/_python.yml | grep -c 'inputs\.'
# 0
```

---

## Paso 3: `ci-api.yml`, una llamada

**Por qué**: el llamador se queda con lo que es de `tablero`: eventos, `paths`, `concurrency` y
permisos. Con `./`, el reutilizable sale del mismo commit que el llamador, así que un PR prueba
los dos cambios a la vez ([teoría 02](../1-teoria/02-llamar-a-un-reutilizable.md#por-qué-tablero-usa-)).
El `# zizmor: ignore[...]` lo explica la práctica 04, paso 5; sin él, `lint-workflows` se pone
en rojo en tu PR.

**Comando**: en `ci-api.yml` deja `name`, `on`, `concurrency` y `permissions` como están, borra
el bloque `defaults:` de la raíz (sus jobs ya no viven aquí) y sustituye todo `jobs:` por esto:

```yaml
jobs:
  api:
    name: API
    uses: ./.github/workflows/_python.yml # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
    with:
      working-directory: api
      package: tablero
      coverage-min: 60
```

`integration` no aparece: su `default` es `true`, que es lo que `api` necesita.

**Verifica**: la orden de `ci-api-calls-python` y actionlint sobre los dos archivos juntos, que
es como comprueba el contrato entre ellos.

```bash
yq '[.jobs[] | .uses // "sin uses"] | join(",")' .github/workflows/ci-api.yml
# ./.github/workflows/_python.yml
actionlint && echo "actionlint ok"
# actionlint ok
```

---

## Paso 4: La llamada, en tu Docker

**Por qué**: act 0.2.94 resuelve `uses: ./...` y ejecuta el reutilizable con los inputs del
`with:`, sin commit ni push ([teoría 06](../1-teoria/06-limites-y-depuracion.md#3-act-en-tu-docker)).
Se apunta al job que **llama**, `api`: `lint` y `test` ya no existen en `ci-api.yml`.

**Comando**: el log a un archivo, para leerlo después sin repetir la ejecución.

```bash
./scripts/ci-local.sh ci-api api > /tmp/act-api.log 2>&1; echo "exit $?"
# exit 0
```

**Verifica**: los tres jobs del reutilizable y el input que llegó a `pytest`.

```bash
grep -E 'coverage of|🏁' /tmp/act-api.log
# [API/_python/Lint y formato (ruff)] 🏁  Job succeeded
# [API/_python/Tests unitarios      ]   | Required test coverage of 60% reached. Total coverage: 62.03%
# [API/_python/Tests unitarios      ] 🏁  Job succeeded
# [API/_python/Tests de integración (PostgreSQL 17) ] 🏁  Job succeeded
```

Prefijo `<job que llama>/<name del reutilizable>/<job>`; el 60% es el `coverage-min` del `with:`.

---

## Paso 5: El contrato, roto a propósito

**Por qué**: actionlint lee llamador y llamado a la vez, así que un input que el reutilizable no
declara y uno obligatorio que falta son errores **antes** del push
([teoría 03](../1-teoria/03-inputs-y-outputs.md#actionlint-comprueba-el-contrato)). Lo que no ve
es el valor: una cobertura imposible es un contrato válido que falla al ejecutarse.

**Comando**: tres roturas, una cada vez; el archivo no está comiteado y vuelves con una copia.

```bash
cp .github/workflows/ci-api.yml /tmp/ci-api.yml
sed -i 's/^      coverage-min: 60$/&\n      bogus: x/' .github/workflows/ci-api.yml
actionlint 2>&1 | head -1
# .github/workflows/ci-api.yml:33:7: input "bogus" is not defined in "./.github/workflows/_python.yml" reusable workflow. defined inputs are "coverage-min", "integration", "package", "working-directory" [workflow-call]
cp /tmp/ci-api.yml .github/workflows/ci-api.yml
sed -i '/^      package: tablero$/d' .github/workflows/ci-api.yml
actionlint 2>&1 | head -1
# .github/workflows/ci-api.yml:28:11: input "package" is required by "./.github/workflows/_python.yml" reusable workflow [workflow-call]
cp /tmp/ci-api.yml .github/workflows/ci-api.yml
sed -i 's/^      coverage-min: 60$/      coverage-min: 99/' .github/workflows/ci-api.yml
actionlint && ./scripts/ci-local.sh ci-api api 2>&1 | grep -E 'FAIL Required|unitarios.*🏁'
# [API/_python/Tests unitarios      ]   | FAIL Required test coverage of 99% not reached. Total coverage: 62.03%
# [API/_python/Tests unitarios      ] 🏁  Job failed
mv /tmp/ci-api.yml .github/workflows/ci-api.yml
```

(En macOS, `sed -i ''`.) El input que sobra se señala en el `with:`; el que falta, en el `uses:`.

**Verifica**: todo vuelve a pasar.

```bash
actionlint && echo "actionlint ok"
# actionlint ok
```

---

## Paso 6: El PR, los nombres del run y `main`

**Por qué**: act no comprueba permisos, `concurrency`, `timeout-minutes` ni la UI; el PR sí. En
el run, cada job sale como `<job que llama> / <job del reutilizable>`
([teoría 02](../1-teoria/02-llamar-a-un-reutilizable.md#el-nombre-que-ves-en-la-ui)).

**Comando**:

```bash
git add .github/workflows/_python.yml .github/workflows/ci-api.yml
git commit -m "ci(api): extract python jobs into reusable workflow"
git push -u origin ci/reusable-python
gh pr create --fill
sleep 10
id=$(gh run list --workflow ci-api.yml --branch ci/reusable-python --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
```

**Verifica**: los tres jobs del reutilizable, con el prefijo del llamador. El job `api` no
aparece por separado: no tiene runner ni steps, solo da nombre a los demás.

```bash
gh run view "$id" --json jobs --jq '.jobs[].name'
# API / Lint y formato (ruff)
# API / Tests unitarios
# API / Tests de integración (PostgreSQL 17)
```

Con el PR en verde, llévalo a `main`: `callers-green-on-main` mira `main`, no el PR.

```bash
gh pr merge --squash --delete-branch
git switch main && git pull --ff-only
sleep 10
id=$(gh run list --workflow ci-api.yml --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
```

---

## ✅ Resultado

- [ ] `_python.yml` solo se dispara con `workflow_call` y declara cuatro inputs con tipo
- [ ] `ci-api.yml` tiene un único job, `api`, que llama a `_python.yml`
- [ ] La llamada corrió en tu Docker y viste los dos errores de contrato de actionlint
- [ ] El run del PR enseña `API / Lint y formato (ruff)` y los otros dos jobs
- [ ] `ci-api` está en verde sobre el último commit de `main`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 09
# ✅ _python.yml declara los inputs working-directory y package (string), coverage-min (number) e integration (boolean)
# ✅ El job integration de _python.yml solo corre si el input integration es true
# ✅ ci-api.yml tiene un único job y ese job llama a _python.yml
# ...
```

Lo de `_node.yml`, `_image.yml`, `images` y los `paths` sigue en rojo: prácticas 02 a 04.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `context "inputs" is not allowed here` en `working-directory` | Dejaste `defaults:` en la raíz de `_python.yml` con un input | Paso 2: `defaults` dentro de cada job |
| `input "package" is required by "./.github/workflows/_python.yml" reusable workflow` | El `with:` de `ci-api.yml` no pasa `package` | Paso 3: `package: tablero` |
| `ci-local.sh ci-api lint`: `Could not find any stages to run` | `lint` ya no está en `ci-api.yml`, está en el reutilizable | Apunta al job que llama: `ci-local.sh ci-api api` |
| `lint-workflows` en rojo con `self-repository` | Falta el comentario `# zizmor: ignore[self-repository]` en el `uses:` | Paso 3; el porqué, en la práctica 04, paso 5 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Límites y depuración](../1-teoria/06-limites-y-depuracion.md) | [Inputs tipados y matrices](02-inputs-tipados-y-matrices.md) |
