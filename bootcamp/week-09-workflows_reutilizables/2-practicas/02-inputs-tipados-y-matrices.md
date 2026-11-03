# Práctica 02 — Inputs tipados y matrices

> El frontend pide algo que `workflow_call` no tiene: una lista, la de versiones de Node. La
> pasas como JSON, la conviertes en matriz con `fromJSON` y devuelves el artefacto como output.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `_node.yml`, con los jobs `lint`, `test` en matriz y `build` del frontend
- El input `node-versions` como lista JSON y matriz con `fromJSON`; el output `artifact-name`
- `ci-web.yml` con `web`, que llama, y `dist-report`, que descarga lo devuelto; y `"[26]"` en un PR

## 📋 Antes de empezar

Terminaste la [práctica 01](01-primer-reutilizable.md): `_python.yml` está en `main`.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git switch -c ci/reusable-node
git branch --show-current
# ci/reusable-node
```

---

## Paso 1: La cabecera de `_node.yml`

**Por qué**: un input de `workflow_call` es `string`, `number` o `boolean`; no hay tipo lista
([teoría 03](../1-teoria/03-inputs-y-outputs.md#no-hay-tipo-lista)). Una lista viaja como cadena
JSON, `"[24, 26]"`. `artifact-name` es obligatorio: el nombre del build lo decide quien llama.

**Comando**: crea `.github/workflows/_node.yml`.

```yaml
# Reutilizable: lint, tests en matriz de versiones de Node, build y artefacto de un frontend
# gestionado con pnpm. Solo se ejecuta cuando otro workflow lo llama.
name: _node

on:
  workflow_call:
    inputs:
      working-directory:
        description: Carpeta del proyecto, la que contiene package.json y pnpm-lock.yaml
        type: string
        required: true
      node-versions:
        description: Versiones de Node de la matriz de tests, como lista JSON
        type: string
        default: "[24, 26]"
      artifact-name:
        description: Nombre del artefacto con el build
        type: string
        required: true

# Techo de permisos del reutilizable: el llamador puede dar menos, nunca más.
permissions:
  contents: read
```

**Verifica**: tres inputs, los tres `string`, y el default de la lista entre comillas.

```bash
yq '.on.workflow_call.inputs | to_entries | map(.key + ":" + .value.type + "=" + (.value.default // "-")) | join(",")' .github/workflows/_node.yml
# working-directory:string=-,node-versions:string=[24, 26],artifact-name:string=-
```

---

## Paso 2: `lint` y la matriz que sale del input

**Por qué**: `fromJSON` convierte la cadena en un array y `strategy.matrix.node` lo recorre como
la lista literal de la Semana 04. La expresión ocupa **todo** el valor de `node:`, sin corchetes.
Los jobs son los de `ci-web.yml`, con la carpeta del input y `defaults` en cada job.

**Comando**: añade el bloque `jobs:` al final de `_node.yml`, con `lint` y `test`.

```yaml
jobs:
  lint:
    name: Lint (eslint)
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
      - uses: pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413 # v6.1.0
        with:
          package_json_file: ${{ inputs.working-directory }}/package.json
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version: "26"
          cache: pnpm
          cache-dependency-path: ${{ inputs.working-directory }}/pnpm-lock.yaml
      - name: Dependencias exactas del lockfile
        run: pnpm install --frozen-lockfile
      - name: eslint
        run: pnpm lint

  test:
    name: Tests (Node ${{ matrix.node }})
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    defaults:
      run:
        shell: bash
        working-directory: ${{ inputs.working-directory }}
    strategy:
      fail-fast: false
      matrix:
        node: ${{ fromJSON(inputs.node-versions) }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413 # v6.1.0
        with:
          package_json_file: ${{ inputs.working-directory }}/package.json
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version: ${{ matrix.node }}
          cache: pnpm
          cache-dependency-path: ${{ inputs.working-directory }}/pnpm-lock.yaml
      - name: Dependencias exactas del lockfile
        run: pnpm install --frozen-lockfile
      - name: vitest
        run: pnpm test
```

**Verifica**: la orden de `node-matrix-from-input` y actionlint, ahora que hay jobs.

```bash
yq '.jobs.test.strategy.matrix.node' .github/workflows/_node.yml
# ${{ fromJSON(inputs.node-versions) }}
actionlint .github/workflows/_node.yml && echo "actionlint ok"
# actionlint ok
```

---

## Paso 3: `build` y el output `artifact-name`

**Por qué**: el output sale en dos saltos: el job `build` lo declara en sus `outputs:` y
`on.workflow_call.outputs` lo publica con `jobs.build.outputs.<nombre>`; el llamador lo lee como
`needs.<job que llama>.outputs.<nombre>` ([teoría 03](../1-teoria/03-inputs-y-outputs.md#devolver-outputs)).
Aunque sea el propio input, devolverlo evita que `dist-report` repita `web-dist` a mano. Sale de
`build`, el job que sube el artefacto.

**Comando**: primero, en `on.workflow_call`, debajo de los `inputs:` y a su misma altura:

```yaml
    outputs:
      artifact-name:
        description: Artefacto que deja el build, para que el llamador lo descargue
        value: ${{ jobs.build.outputs.artifact-name }}
```

Después, el job `build` al final de `jobs:`.

```yaml
  build:
    name: Build
    needs: [lint, test]
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    defaults:
      run:
        shell: bash
        working-directory: ${{ inputs.working-directory }}
    outputs:
      artifact-name: ${{ inputs.artifact-name }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413 # v6.1.0
        with:
          package_json_file: ${{ inputs.working-directory }}/package.json
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version: "26"
          cache: pnpm
          cache-dependency-path: ${{ inputs.working-directory }}/pnpm-lock.yaml
      - name: Dependencias exactas del lockfile
        run: pnpm install --frozen-lockfile
      - name: tsc y vite build
        run: pnpm build
      - uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: ${{ inputs.artifact-name }}
          path: ${{ inputs.working-directory }}/dist
          if-no-files-found: error
          retention-days: 7
```

**Verifica**: la orden de `node-artifact-output` y actionlint.

```bash
yq '.on.workflow_call.outputs.["artifact-name"].value' .github/workflows/_node.yml
# ${{ jobs.build.outputs.artifact-name }}
actionlint .github/workflows/_node.yml && echo "actionlint ok"
# actionlint ok
```

---

## Paso 4: `ci-web.yml`, una llamada y un informe

**Por qué**: `dist-report` es un resumen propio de `tablero`, así que se queda en el llamador
como job normal. Su `needs: web` espera a **todo** el reutilizable y le da sus outputs. La lista
va entre comillas: sin ellas YAML lee una secuencia, no una cadena.

**Comando**: en `ci-web.yml` deja `name`, `on`, `concurrency` y `permissions`, borra el
`defaults:` de la raíz y sustituye todo `jobs:` por esto:

```yaml
jobs:
  web:
    name: Web
    uses: ./.github/workflows/_node.yml # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
    with:
      working-directory: web
      node-versions: "[24, 26]"
      artifact-name: web-dist

  dist-report:
    name: Informe de dist
    needs: web
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - uses: actions/download-artifact@9000827ccba6bdab643e8b6fd33ac0654aef8333 # v8.0.2
        with:
          name: ${{ needs.web.outputs.artifact-name }}
          path: dist
      - name: Tamaño de cada archivo
        run: |
          {
            echo "## web/dist"
            echo
            echo '```'
            du -ah dist | sort -h
            echo '```'
          } >> "$GITHUB_STEP_SUMMARY"
```

**Verifica**: `ci-web-calls-node`, actionlint y dos roturas que caza porque conoce el contrato.

```bash
yq '.jobs.web.uses + " " + (.jobs["dist-report"].steps[] | select(.uses // "" | test("download-artifact")) | .with.name)' .github/workflows/ci-web.yml
# ./.github/workflows/_node.yml ${{ needs.web.outputs.artifact-name }}
actionlint && echo "actionlint ok"
# actionlint ok
cp .github/workflows/ci-web.yml /tmp/ci-web.yml
sed -i 's/needs\.web\.outputs\.artifact-name/needs.web.outputs.artifact/' .github/workflows/ci-web.yml
actionlint 2>&1 | head -1
# .github/workflows/ci-web.yml:42:21: property "artifact" is not defined in object type {artifact-name: string} [expression]
cp /tmp/ci-web.yml .github/workflows/ci-web.yml
sed -i 's/node-versions: "\[24, 26\]"/node-versions: [24, 26]/' .github/workflows/ci-web.yml
actionlint 2>&1 | head -1
# .github/workflows/ci-web.yml:31:22: expected scalar node for string value but found sequence node with "!!seq" tag [syntax-check]
mv /tmp/ci-web.yml .github/workflows/ci-web.yml && actionlint && echo "actionlint ok"
# actionlint ok
```

---

## Paso 5: Por qué este no lo pruebas con act

**Por qué**: `./scripts/ci-local.sh ci-web web` ejecuta los jobs, pero falla en el **post** de
`setup-node`, al guardar la caché de pnpm:

```text
::error::Path Validation Error: Path(s) specified in the action for caching do(es) not exist, hence no cache is being saved.
```

Es la limitación de act con la caché de pnpm que ya tenía `ci-web` en la Semana 08
([teoría 06](../1-teoria/06-limites-y-depuracion.md#3-act-en-tu-docker)). Quitar `cache: pnpm`
empeoraría el CI real por una herramienta local: la ejecución la valida el PR.

**Comando**:

```bash
git add .github/workflows/_node.yml .github/workflows/ci-web.yml
git commit -m "ci(web): extract node jobs into reusable workflow"
git push -u origin ci/reusable-node
gh pr create --fill
sleep 10
id=$(gh run list --workflow ci-web.yml --branch ci/reusable-node --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
```

**Verifica**: un job de test por versión, con el prefijo `Web /`; `dist-report`, del llamador, sin él.

```bash
gh run view "$id" --json jobs --jq '.jobs[].name' | sort
# Informe de dist
# Web / Build
# Web / Lint (eslint)
# Web / Tests (Node 24)
# Web / Tests (Node 26)
```

---

## Paso 6: Otra lista, el mismo reutilizable

**Por qué**: la matriz la decide quien llama: cambias una cadena del `with:` y el reutilizable no
se entera. `git revert` lo deshace con un commit nuevo, sin reescribir la rama.

**Comando**:

```bash
sed -i 's/node-versions: "\[24, 26\]"/node-versions: "[26]"/' .github/workflows/ci-web.yml
git commit -am "ci(web): test only node 26"
git push
sleep 10
id=$(gh run list --workflow ci-web.yml --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
gh run view "$id" --json jobs --jq '[.jobs[].name | select(startswith("Web / Tests"))] | join(",")'
# Web / Tests (Node 26)
```

**Verifica**: devuelve la lista a `[24, 26]`, lleva el PR en verde a `main` y espera a `ci-web`.

```bash
git revert --no-edit HEAD && git push
gh pr merge --squash --delete-branch
git switch main && git pull --ff-only
yq '.jobs.web.with["node-versions"]' .github/workflows/ci-web.yml
# [24, 26]
sleep 10
id=$(gh run list --workflow ci-web.yml --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
```

---

## ✅ Resultado

- [ ] `_node.yml` solo se dispara con `workflow_call` y declara tres inputs `string`
- [ ] La matriz de `test` sale de `fromJSON(inputs.node-versions)`
- [ ] `artifact-name` sale del job `build` y se publica en `on.workflow_call.outputs`
- [ ] `ci-web.yml` tiene `web`, que llama, y `dist-report`, que descarga el artefacto devuelto
- [ ] Un PR con `"[26]"` lanzó un único job de tests
- [ ] `ci-web` está en verde sobre el último commit de `main`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 09
# ✅ La matriz de tests de _node.yml sale del input node-versions con fromJSON
# ✅ _node.yml devuelve el nombre del artefacto como output artifact-name, sacado del job build
# ✅ El job web de ci-web.yml llama a _node.yml y dist-report descarga el artefacto que este devuelve
# ...
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `expected scalar node for string value but found sequence node` | `node-versions: [24, 26]` sin comillas | `node-versions: "[24, 26]"` |
| El run falla sin crear los jobs de tests | La cadena no es JSON válido, por ejemplo `"[24, 26"`; actionlint no lo ve porque es un valor | Corrige la cadena; pruébala con `echo '[24, 26]' \| jq .` |
| `property "artifact" is not defined in object type {artifact-name: string}` | El output tiene otro nombre en `needs.web.outputs` | Usa el nombre exacto de `on.workflow_call.outputs` |
| `dist-report` falla al descargar | `artifact-name` del job `build` no coincide con el `name:` de `upload-artifact` | Los dos salen de `inputs.artifact-name` |
| `ci-local.sh ci-web web` falla en el post de `setup-node` | Limitación de act con la caché de pnpm | Paso 5: valida `ci-web` en el PR |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Primer reutilizable](01-primer-reutilizable.md) | [Secretos y outputs](03-secretos-y-outputs.md) |
