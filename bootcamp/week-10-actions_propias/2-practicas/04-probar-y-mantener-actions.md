# Práctica 04 — Probar y mantener actions

> `coverage-report` y `sql-lint` existen, pero ningún workflow las llama y nada impide que
> `dist/` se quede atrás del código. En esta práctica las pones a trabajar en `ci-web` y `ci`,
> añades `test-actions.yml` para vigilarlas y cierras la semana con linters, act y el run remoto.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Un job `coverage` en `ci-web.yml` con `coverage-report`, y un job `sql` en `ci.yml` con `sql-lint`
- `test-actions.yml`, que prueba la lógica y falla si `dist/` no coincide con `src/`
- `actionlint && zizmor --offline` en verde sobre workflows y actions
- Los tres jobs nuevos en tu Docker con act, y `test-actions`, `ci-web` y `ci` en verde en `main`

## 📋 Antes de empezar

Terminaste la [práctica 03](03-action-docker.md): la rama `ci/own-actions` lleva un commit con
`coverage-report` y otro con `sql-lint`.

```bash
cd ~/code/tablero
git branch --show-current
# ci/own-actions
git rev-list --count main..
# 2
```

---

## Paso 1: Las actions, en sus workflows

**Por qué**: una action local se llama como un step más, después del checkout. En `ci-web`,
`coverage` es un job propio y no un step de `_node.yml`: el reutilizable sirve a cualquier
frontend y la cobertura con mínimo es una decisión de `tablero`. En `ci`, `sql` entra en el
`needs` de `summary`, que así enseña su resultado. Y los `paths` de `ci-web` suman la action
nueva: un cambio solo en `coverage-report` también tiene que probarse en el workflow que la usa.

**Comando**: en `ci-web.yml`, añade a las dos listas de `paths` la línea
`- ".github/actions/coverage-report/**"` y al final de `jobs:` este job:

```yaml
  coverage:
    name: Cobertura
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: ./.github/actions/setup-tablero # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
        with:
          stack: node
          working-directory: web
      - name: Vitest con cobertura
        working-directory: web
        run: pnpm test:coverage --coverage.reporter=json-summary
      - uses: ./.github/actions/coverage-report # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
        with:
          summary-file: web/coverage/coverage-summary.json
          minimum: "60"
```

`summary-file` va relativo al workspace: los steps `uses:` no heredan el `working-directory`.
En `ci.yml`, antes de `summary`:

```yaml
  sql:
    name: SQL de las migraciones
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: ./.github/actions/sql-lint # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
        with:
          path: api/migrations
          # La migración alinea las columnas con espacios y LT01 las marcaría todas.
          exclude-rules: LT01
```

Y en `summary`, `needs: [runner-info, structure, version, sql]`.

**Verifica**: la orden de `workflows-use-actions`, el `needs` y actionlint.

```bash
{ yq '[.jobs.coverage.steps[].uses // ""] | map(select(test("coverage-report"))) | length' .github/workflows/ci-web.yml; yq '[.jobs.sql.steps[].uses // ""] | map(select(test("sql-lint"))) | length' .github/workflows/ci.yml; } | paste -sd' '
# 1 1
yq '.jobs.summary.needs | join(",")' .github/workflows/ci.yml
# runner-info,structure,version,sql
actionlint && echo "actionlint ok"
# actionlint ok
```

---

## Paso 2: `test-actions.yml` y la frescura de `dist/`

**Por qué**: `dist/` es código generado que se comitea, así que puede mentir: alguien cambia
`src/`, olvida `pnpm build`, y el runner sigue ejecutando el bundle viejo sin que ningún test se
entere, porque los tests prueban `src/`. La única defensa es reconstruir en CI y comparar con lo
comiteado: si `git diff --exit-code` encuentra diferencias, el `dist/` del commit no sale de su
`src/` ([teoría 07](../1-teoria/07-probar-actions.md)). El workflow solo se dispara cuando
cambia algo en `.github/actions/`.

**Comando**: crea `.github/workflows/test-actions.yml`.

```yaml
name: test-actions

on:
  push:
    branches: [main]
    paths:
      - ".github/actions/**"
      - ".github/workflows/test-actions.yml"
  pull_request:
    paths:
      - ".github/actions/**"
      - ".github/workflows/test-actions.yml"
  workflow_dispatch:

# Un run por workflow y ref: en un PR, el push nuevo cancela el run anterior;
# en main cada commit termina su run.
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  coverage-report:
    name: coverage-report (tests y dist)
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    defaults:
      run:
        shell: bash
        working-directory: .github/actions/coverage-report
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: ./.github/actions/setup-tablero # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
        with:
          stack: node
          working-directory: .github/actions/coverage-report
      - name: Tests de la lógica
        run: pnpm test
      - name: Reconstruir dist y comprobar que está al día
        run: |
          pnpm build
          git diff --exit-code -- dist || { echo "::error::dist/ no coincide con src/: ejecuta pnpm build y súbelo"; exit 1; }
```

`setup-tablero` vale también aquí: la action JavaScript es un componente pnpm más.

**Verifica**: la orden de `dist-freshness` y la comprobación en local, con un `src/` cambiado
sin reconstruir.

```bash
yq '.jobs[].steps[].run // ""' .github/workflows/test-actions.yml | grep -cE 'git diff --exit-code'
# 1
cd .github/actions/coverage-report
sed -i 's/Cobertura de la web/Cobertura de web/' src/index.js
pnpm build > /dev/null 2>&1
git diff --exit-code --stat -- dist; echo "exit $?"
#  .github/actions/coverage-report/dist/index.cjs | 2 +-
#  1 file changed, 1 insertion(+), 1 deletion(-)
# exit 1
git restore src dist
cd ~/code/tablero
```

Ese `exit 1` es el que pone `test-actions` en rojo en un PR con `dist/` atrasado.

---

## Paso 3: La puerta de linters, sobre todo `.github/`

**Por qué**: los dos linters ven cosas distintas. actionlint revisa los workflows y, a través de
cada `uses: ./...`, el contrato con el `action.yml`; no audita el `action.yml` en sí. zizmor sí:
recorre `.github/` entero, actions incluidas
([teoría 07](../1-teoria/07-probar-actions.md)). Cada `uses: ./` nuevo necesita su
`# zizmor: ignore[self-repository]`; quítalo de uno para ver qué pasa.

**Comando**:

```bash
cp .github/workflows/ci.yml /tmp/ci.yml
sed -i 's|uses: ./.github/actions/sql-lint # zizmor.*|uses: ./.github/actions/sql-lint|' .github/workflows/ci.yml
zizmor --offline -q .github/ 2>&1 | head -4
# help[self-repository]: use GitHub's dedicated self-repository syntax
#   --> .github/workflows/ci.yml:72:15
#    |
# 72 |         - uses: ./.github/actions/sql-lint
mv /tmp/ci.yml .github/workflows/ci.yml
```

La copia en `/tmp` y no `git restore`: `ci.yml` todavía no está comiteado, y `restore` lo
devolvería a `main`, sin el job `sql`. (En macOS, `sed -i ''`.)

**Verifica**: la orden de `workflows-lint`.

```bash
actionlint && zizmor --offline -q .github/; echo "exit $?"
# No findings to report. Good job! (14 ignored, 6 suppressed)
# exit 0
```

---

## Paso 4: Los tres jobs, en tu Docker

**Por qué**: act ejecuta las tres actions locales: lee la composite, lanza `node` para la
JavaScript y **construye** la imagen de la Docker, igual que el runner
([teoría 07](../1-teoria/07-probar-actions.md)). Hay una diferencia que conviene conocer antes
de asustarse: en act, el post de `actions/setup-node` falla con `Path Validation Error` porque
el directorio de la caché de pnpm no existe en el contenedor de act. Es un límite de act, no de
tu capa: en GitHub ese post guarda la caché y termina en verde.

**Comando**:

```bash
./scripts/ci-local.sh ci sql > /tmp/act-sql.log 2>&1; echo "exit $?"
# exit 0
./scripts/ci-local.sh ci-web coverage > /tmp/act-coverage.log 2>&1; echo "exit $?"
# exit 1
./scripts/ci-local.sh test-actions > /tmp/act-test-actions.log 2>&1; echo "exit $?"
# exit 1
```

**Verifica**: en cada log, lo que importa de la capa, y que el único fallo es el post de
`setup-node`.

```bash
grep -E 'docker build|files=|🏁' /tmp/act-sql.log | cut -c1-90
# [ci/SQL de las migraciones]   🐳  docker build -t act-github-actions-sql-lint-dockeracti
# [ci/SQL de las migraciones]   ⚙  ::set-output:: files=1
# [ci/SQL de las migraciones] 🏁  Job succeeded
grep -E 'percent=|coverage-report:|Failure' /tmp/act-coverage.log | cut -c1-90
# [ci-web/Cobertura]   ⚙  ::set-output:: percent=68.96
# [ci-web/Cobertura]   | coverage-report: 129 ms entre el inicio de main y este post
# [ci-web/Cobertura]   ❌  Failure - Post actions/setup-node@949feb2413d6458794dcd2491c4bab
grep -E 'Success - Main (Tests|Reconstruir)|Failure' /tmp/act-test-actions.log | cut -c1-110
# [test-actions/coverage-report (tests y dist)]   ✅  Success - Main Tests de la lógica [170.378523ms]
# [test-actions/coverage-report (tests y dist)]   ✅  Success - Main Reconstruir dist y comprobar que está al
# [test-actions/coverage-report (tests y dist)]   ❌  Failure - Post actions/setup-node@949feb2413d6458794dcd24
```

Fíjate en el orden de los post en `act-coverage.log`: primero el de `coverage-report`, luego
los de `setup-tablero`. Los post corren en orden inverso al de los main.

---

## Paso 5: El PR y el run sobre `main`

**Por qué**: act no comprueba permisos, `paths`, `concurrency` ni las anotaciones del diff; el PR
sí. Y un verde en el PR no es un verde en `main`: el check `test-actions-green-on-main` filtra
los runs por el SHA de `origin/main`, así que un run antiguo o de otra rama no cuenta.

**Comando**:

```bash
git add .github/workflows/ci-web.yml .github/workflows/ci.yml .github/workflows/test-actions.yml
git commit -m "ci: use own actions in ci-web and ci, add test-actions"
git push -u origin ci/own-actions
gh pr create --fill
sleep 15
gh pr checks --watch > /dev/null; echo "exit $?"
# exit 0
gh pr merge --squash --delete-branch
git switch main && git pull --ff-only
sleep 15
```

En la pestaña **Summary** del run de `ci-web`, el job `Cobertura` enseña la tabla de
`coverage-report`.

**Verifica**: la orden de `test-actions-green-on-main`, esperando antes a que terminen.

```bash
git fetch -q origin main && sha=$(git rev-parse origin/main)
for w in test-actions ci-web ci; do gh run watch "$(gh run list --workflow $w.yml --commit "$sha" --json databaseId --jq '.[0].databaseId')" --exit-status > /dev/null; done
for w in test-actions ci-web ci; do printf '%s=%s ' "$w" "$(gh run list --workflow $w.yml --commit "$sha" --json conclusion --jq '.[0].conclusion')"; done; echo
# test-actions=success ci-web=success ci=success
```

---

## ✅ Resultado

- [ ] `ci-web.yml` tiene el job `coverage` con `coverage-report` y `ci.yml`, el job `sql` con `sql-lint`
- [ ] `test-actions.yml` prueba la lógica y comprueba la frescura de `dist/`
- [ ] Viste fallar la comprobación de `dist/` en local con un `src/` sin reconstruir
- [ ] `actionlint && zizmor --offline -q .github/` termina sin hallazgos
- [ ] act ejecutó las tres actions y sabes por qué falla el post de `setup-node`
- [ ] `test-actions`, `ci-web` y `ci` en verde sobre el último commit de `main`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 10
# ✅ ci-web.yml usa coverage-report en el job coverage y ci.yml usa sql-lint en el job sql
# ✅ test-actions.yml reconstruye dist y falla si no coincide con lo comiteado
# ✅ Los workflows y las actions pasan actionlint y zizmor sin hallazgos
# ✅ Toda uses remota de workflows y actions está fijada por SHA de 40 caracteres con el tag en comentario
# ✅ test-actions, ci-web y ci terminan en success sobre el último commit de main
#
# 17/17 comprobaciones superadas.
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `test-actions` en rojo con `dist/ no coincide con src/` | Cambiaste `src/` y no comiteaste el `dist/` reconstruido | `pnpm build` en la action, `git add dist` y push |
| `ENOENT` con `coverage-summary.json` en `Cobertura` | `summary-file` relativo a `web/`: los steps `uses:` no heredan `working-directory` | Paso 1: `web/coverage/coverage-summary.json` |
| El job `sql` falla con cinco avisos LT01 | Falta `exclude-rules: LT01` en el `with:` | Paso 1 |
| `summary` no enseña el resultado de `sql` | `sql` no está en su `needs` | Paso 1 |
| zizmor: `help[self-repository]` | Un `uses: ./...` sin su comentario `ignore` | Paso 3 |
| act: `Failure - Post actions/setup-node` con `Path Validation Error` | Límite de act con la caché de pnpm | Ninguna: en GitHub termina en verde (paso 4) |
| `test-actions=` vacío en la verificación | El squash no tocó `.github/actions/` y el workflow no se disparó | Lanza `gh workflow run test-actions.yml --ref main` y repite la verificación |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Una action Docker](03-action-docker.md) | [Proyecto: capa 10 de tablero](../3-proyecto/README.md) |
