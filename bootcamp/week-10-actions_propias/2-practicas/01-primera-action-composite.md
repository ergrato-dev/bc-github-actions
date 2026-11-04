# Práctica 01 — Primera action composite

> Los seis jobs de `_python.yml` y `_node.yml` repiten los mismos tres o cuatro steps para
> preparar uv o pnpm. En esta práctica los metes en `setup-tablero`, una action composite, y
> cada job pasa a prepararse con una sola línea.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `.github/actions/setup-tablero/action.yml`, composite, con tres inputs y un output
- Los tres jobs de `_python.yml` y los tres de `_node.yml` preparados con ella
- Los errores que actionlint ya ve en la llamada y el que solo aparece al ejecutarla
- `ci-api` corriendo en tu Docker con la action y en verde en `main`

## 📋 Antes de empezar

Terminaste la Semana 09: `_python.yml` y `_node.yml` están en `main` y sus llamadores, en verde.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git switch -c ci/setup-tablero
grep -cE 'setup-uv@|action-setup@|setup-node@' .github/workflows/_python.yml .github/workflows/_node.yml
# .github/workflows/_python.yml:3
# .github/workflows/_node.yml:6
```

---

## Paso 1: El contrato de la action

**Por qué**: una action se define en un `action.yml` dentro de su carpeta, y la carpeta es su
nombre. Arriba va el contrato (`inputs` y `outputs`), abajo `runs`, que con `using: composite`
dice que la action es una lista de steps que corren **dentro del job que la llama**, en su mismo
runner y su mismo workspace ([teoría 01](../1-teoria/01-anatomia-de-una-action.md)). A
diferencia de un reutilizable, los inputs de una action no tienen `type`: todo llega como
cadena, así que `stack` se valida a mano en el primer step
([teoría 02](../1-teoria/02-actions-composite.md)). El valor entra al shell por `env:`, nunca
interpolado en `run:` (regla 4).

**Comando**: crea `.github/actions/setup-tablero/action.yml`.

```yaml
name: setup-tablero
description: Instala uv o pnpm con Node y las dependencias exactas del lockfile de un componente de tablero
inputs:
  stack:
    description: Pila del componente, python o node
    required: true
  working-directory:
    description: Carpeta del componente, la que contiene uv.lock o pnpm-lock.yaml
    required: true
  node-version:
    description: Versión de Node, solo se usa con stack node
    default: "26"
outputs:
  tool-version:
    description: Versión de uv o de pnpm que ha quedado instalada
    value: ${{ steps.tool.outputs.version }}
runs:
  using: composite
  steps:
    - name: Comprobar el input stack
      if: ${{ inputs.stack != 'python' && inputs.stack != 'node' }}
      shell: bash
      env:
        STACK: ${{ inputs.stack }}
      run: |
        echo "::error title=setup-tablero::stack debe ser python o node y es '$STACK'"
        exit 1
```

El output `tool-version` apunta al step `tool`, que añades en el paso 2.

**Verifica**: el tipo de la action y qué inputs son obligatorios.

```bash
yq '.runs.using' .github/actions/setup-tablero/action.yml
# composite
yq '.inputs | to_entries | map(.key + ":" + ((.value.required // false) | tostring)) | join(",")' .github/actions/setup-tablero/action.yml
# stack:true,working-directory:true,node-version:false
```

---

## Paso 2: Los steps, cada uno con su `shell`

**Por qué**: en un workflow, un `run:` sin `shell:` hereda `defaults.run.shell` o el de la
plataforma. En una composite no hay `defaults`: cada step `run` **tiene que** declarar su
`shell`, o GitHub rechaza la action al cargarla
([teoría 02](../1-teoria/02-actions-composite.md)). Los steps con `uses:` sí valen tal cual, con
su SHA, y el `if:` de cada uno decide la pila. El último escribe `version=` en
`$GITHUB_OUTPUT` con `id: tool`, que es de donde sale el output del paso 1.

**Comando**: añade al final de `runs.steps`, con la misma sangría que el primer step:

```yaml
    - uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
      if: ${{ inputs.stack == 'python' }}
      with:
        version: "0.13.6"
        enable-cache: true
        cache-dependency-glob: ${{ inputs.working-directory }}/uv.lock

    - uses: pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413 # v6.1.0
      if: ${{ inputs.stack == 'node' }}
      with:
        package_json_file: ${{ inputs.working-directory }}/package.json

    - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
      if: ${{ inputs.stack == 'node' }}
      with:
        node-version: ${{ inputs.node-version }}
        cache: pnpm
        cache-dependency-path: ${{ inputs.working-directory }}/pnpm-lock.yaml

    - name: Dependencias exactas del lockfile
      shell: bash
      working-directory: ${{ inputs.working-directory }}
      env:
        STACK: ${{ inputs.stack }}
      run: |
        if [ "$STACK" = python ]; then uv sync --locked; else pnpm install --frozen-lockfile; fi

    - name: Versión de la herramienta
      id: tool
      shell: bash
      env:
        STACK: ${{ inputs.stack }}
      run: |
        if [ "$STACK" = python ]; then tool=uv; else tool=pnpm; fi
        echo "version=$("$tool" --version)" >> "$GITHUB_OUTPUT"
```

`package_json_file` (input de `pnpm/action-setup` en ese SHA) lee el `packageManager` del
componente, que no está en la raíz.

**Verifica**: la orden de `setup-shell` y zizmor, que sí audita un `action.yml` (actionlint no).

```bash
yq '[.runs.steps[] | select(has("run")) | .shell // "falta"] | unique | join(",")' .github/actions/setup-tablero/action.yml
# bash
zizmor --offline -q .github/actions/ && echo "zizmor ok"
# No findings to report. Good job!
# zizmor ok
```

---

## Paso 3: `_python.yml` se prepara con la action

**Por qué**: una action local se lee del disco del workspace, así que `actions/checkout` va
**antes** de `uses: ./.github/actions/setup-tablero`: sin checkout no hay `action.yml` que leer.
La ruta empieza en la raíz del repo, no en la carpeta del workflow. El `# zizmor: ignore[...]`
es el mismo de la Semana 09: zizmor 1.31.1 pide la sintaxis `$/`, que actionlint 1.7.12 aún
rechaza ([teoría 07](../1-teoria/07-probar-actions.md)).

**Comando**: en los tres jobs de `_python.yml` (`lint`, `test` e `integration`) sustituye el
step de `setup-uv` y el de `uv sync --locked` por uno solo. En `lint` queda así:

```yaml
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: ./.github/actions/setup-tablero # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
        with:
          stack: python
          working-directory: ${{ inputs.working-directory }}
      - name: ruff check
        run: uv run --no-sync ruff check --output-format=github .
      - name: ruff format
        run: uv run --no-sync ruff format --check .
```

En `test` e `integration`, igual: checkout, `setup-tablero` y los steps propios del job, que no
cambian.

**Verifica**: un `setup-tablero` por job, ningún `setup-uv` y actionlint, que ya lee el
`action.yml` de la action local para comprobar la llamada.

```bash
yq '[.jobs[] | ([.steps[].uses // "" | select(test("setup-tablero"))] | length)] | join(",")' .github/workflows/_python.yml
# 1,1,1
grep -c 'setup-uv@' .github/workflows/_python.yml
# 0
actionlint && echo "actionlint ok"
# actionlint ok
```

---

## Paso 4: `_node.yml`, con la versión de Node como input

**Por qué**: en `_node.yml` la action ahorra más: `action-setup`, `setup-node` y
`pnpm install` en cada job. El job `test` corre en matriz, así que pasa `matrix.node` como
`node-version`; `lint` y `build` fijan `"26"`, que es también el `default` del input. Escribirlo
igual en los dos deja claro qué versión construye el artefacto.

**Comando**: en los tres jobs de `_node.yml`, sustituye los tres steps de preparación por
`setup-tablero`. En `test`:

```yaml
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: ./.github/actions/setup-tablero # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
        with:
          stack: node
          node-version: ${{ matrix.node }}
          working-directory: ${{ inputs.working-directory }}
      - name: vitest
        run: pnpm test
```

En `lint` y `build`, `node-version: "26"`. `build` conserva su `upload-artifact` tras el build.

**Verifica**: la orden de `reusables-use-setup`, que mira los dos reutilizables a la vez.

```bash
for f in _python _node; do printf '%s=%s ' "$f" "$(yq '[.jobs[] | ([.steps[].uses // "" | select(test("setup-tablero"))] | length) ] | join(",")' .github/workflows/$f.yml)"; done; echo
# _python=1,1,1 _node=1,1,1
grep -lE 'setup-uv@|action-setup@|setup-node@' .github/workflows/_python.yml .github/workflows/_node.yml
# (sin salida)
actionlint && echo "actionlint ok"
# actionlint ok
```

---

## Paso 5: Romper la llamada, en local

**Por qué**: actionlint conoce los inputs de la action porque lee su `action.yml`, así que un
input mal escrito y uno obligatorio que falta son errores antes del push. Lo que no puede ver es
el **valor**: `stack: ruby` es un contrato válido, y solo el step de comprobación del paso 1 lo
para al ejecutarse.

**Comando**: dos roturas en `_python.yml`, deshechas con `git restore`, y un workflow de usar y
tirar que no se comitea.

```bash
sed -i '0,/^          stack: python$/{s//          stak: python/}' .github/workflows/_python.yml
actionlint 2>&1 | grep '^\.github'
# .github/workflows/_python.yml:44:11: input "stak" is not defined in action "setup-tablero" defined at "./.github/actions/setup-tablero". available inputs are "node-version", "stack", "working-directory" [action]
# .github/workflows/_python.yml:42:15: missing input "stack" which is required by action "setup-tablero" defined at "./.github/actions/setup-tablero". all required inputs are "stack", "working-directory" [action]
git restore .github/workflows/_python.yml
```

(En macOS, `sed -i ''`.) Ahora el valor. Crea `.github/workflows/try-setup.yml`:

```yaml
# Prueba de un solo uso: no se comitea.
name: try-setup

on: workflow_dispatch

permissions:
  contents: read

jobs:
  try:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: ./.github/actions/setup-tablero # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
        with:
          stack: ruby
          working-directory: api
```

```bash
actionlint && echo "actionlint ok"
# actionlint ok
EVENT=workflow_dispatch ./scripts/ci-local.sh try-setup 2>&1 | grep -E '::error|🏁'
# [try-setup/try]   ❗  ::error title=setup-tablero::stack debe ser python o node y es 'ruby'
# [try-setup/try] 🏁  Job failed
rm .github/workflows/try-setup.yml
```

**Verifica**: solo quedan tus cambios de los pasos 1 a 4.

```bash
git status --short
#  M .github/workflows/_node.yml
#  M .github/workflows/_python.yml
# ?? .github/actions/
```

---

## Paso 6: `paths`, act y el PR

**Por qué**: `ci-api` y `ci-web` se disparan por `paths`, y GitHub no sabe que sus
reutilizables usan `setup-tablero`: un cambio solo en la action no lanzaría ningún run. Es la
lección de la Semana 09 un nivel más abajo. Antes del push, act ejecuta la action local en tu
Docker; en su log, los outputs salen como `::set-output::`, que es solo cómo act los muestra,
no el comando retirado.

**Comando**: en `ci-api.yml` y en `ci-web.yml`, añade a las dos listas de `paths` (`push` y
`pull_request`) la línea:

```yaml
      - ".github/actions/setup-tablero/**"
```

```bash
for f in ci-api ci-web; do printf '%s=%s ' "$f" "$(grep -c 'setup-tablero/\*\*' .github/workflows/$f.yml)"; done; echo
# ci-api=2 ci-web=2
./scripts/ci-local.sh ci-api api > /tmp/act-api.log 2>&1; echo "exit $?"
# exit 0
grep -m1 'tool-version' /tmp/act-api.log
# [API/_python/Tests unitarios      ]   ⚙  ::set-output:: tool-version=uv 0.13.6 (x86_64-unknown-linux-gnu)
grep -c '🏁  Job succeeded' /tmp/act-api.log
# 3
```

El orden cambia entre ejecuciones (jobs en paralelo). Con `ci-web`, act falla en el post de
`setup-node`; lo ves en la práctica 04, paso 4.

```bash
git add .github/actions/setup-tablero .github/workflows/_python.yml .github/workflows/_node.yml .github/workflows/ci-api.yml .github/workflows/ci-web.yml
git commit -m "ci: add setup-tablero composite action"
git push -u origin ci/setup-tablero
gh pr create --fill
sleep 15
gh pr checks --watch > /dev/null; echo "exit $?"
# exit 0
```

**Verifica**: en `main`, `ci-api` y `ci-web` en verde sobre el commit fusionado.

```bash
gh pr merge --squash --delete-branch
git switch main && git pull --ff-only
sleep 15
for w in ci-api ci-web; do id=$(gh run list --workflow $w.yml --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId'); gh run watch "$id" --exit-status > /dev/null; echo "$w exit $?"; done
# ci-api exit 0
# ci-web exit 0
```

---

## ✅ Resultado

- [ ] `setup-tablero` es composite, con `shell: bash` en cada `run` y zizmor sin hallazgos
- [ ] Los seis jobs de `_python.yml` y `_node.yml` se preparan con la action
- [ ] Viste los dos errores de actionlint en la llamada y el `::error` de `stack: ruby` en act
- [ ] `ci-api` y `ci-web` están en verde sobre el último commit de `main`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 10
# ✅ setup-tablero declara los inputs stack y working-directory como obligatorios y node-version con valor por defecto
# ✅ Todos los steps run de setup-tablero declaran shell
# ✅ Todos los jobs de _python.yml y _node.yml preparan el entorno con setup-tablero y ninguno llama directamente a setup-uv, action-setup ni setup-node
# ...
```

`action-types` y lo de `coverage-report` y `sql-lint` siguen en rojo: prácticas 02 a 04.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El run falla al cargar la action con `Required property is missing: shell` | Un step `run` de la composite sin `shell:` | Paso 2: `shell: bash` en cada step `run` |
| `Can't find 'action.yml'` en el step de `setup-tablero` | La action se llama antes del checkout, o la ruta no empieza en la raíz | Paso 3: checkout primero y `./.github/actions/setup-tablero` |
| `missing input "stack" which is required by action "setup-tablero"` | El `with:` de algún job no pasa `stack` | Pasos 3 y 4: `stack: python` o `stack: node` |
| `lint-workflows` en rojo con `self-repository` | Falta el `# zizmor: ignore[self-repository]` en un `uses: ./...` | Paso 3 |
| Un PR que solo cambia la action no lanza `ci-api` | Faltan las líneas de `setup-tablero/**` en `paths` | Paso 6 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Probar actions](../1-teoria/07-probar-actions.md) | [Una action JavaScript](02-action-javascript.md) |
