# Práctica 01 — Un solo check para un monorepo

> Hoy `tablero` tiene un workflow por área, cada uno con su filtro `paths`. Ninguno de ellos puede
> ser un check obligatorio: si no corre, se queda pendiente para siempre. En esta práctica `ci.yml`
> pasa a ser la única puerta: decide qué áreas cambian, llama solo a sus workflows y lo resume
> todo en un job, `ci-gate`.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `scripts/changed-areas.sh`, que dice qué áreas toca un cambio y corre todo si no hay base
- Un job `changes` en `ci.yml` que calcula las áreas contra la base de cada evento
- `ci-api`, `ci-web`, `ci-tools`, `smoke` y `lint-workflows` convertidos en reutilizables que
  `ci.yml` llama solo cuando su área cambia
- `ci-gate`, que pasa si todo terminó en `success` o `skipped` y falla en cualquier otro caso
- `pr-report.yml` escuchando a `ci`, y un PR de prueba que solo toca `web/` con `ci-gate` en verde

## 📋 Antes de empezar

`check-week.sh 17` está en verde y leíste la teoría, sobre todo la
[03](../1-teoria/03-checks-obligatorios-y-el-job-puerta.md) y la
[04](../1-teoria/04-ci-de-solo-lo-que-cambia.md). En esta práctica `main` todavía no tiene ruleset:
el PR se fusiona como hasta ahora. A partir de la práctica 02, ya no.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
S=~/code/bc-github-actions/bootcamp/week-18-merge_queue_rulesets_y_monorepos/3-proyecto/starter
git switch -c ci/single-gate
```

---

## Paso 1: Qué áreas toca un cambio

**Por qué**: el filtro `paths` decide antes de que exista el run y deja el check pendiente; un
script decide **dentro** del run, que así siempre informa. Sin base con la que comparar (dispatch,
rama nueva, `before` de ceros) no adivina: marca todo. Y si cambia `.github/`, también todo
([teoría 04](../1-teoria/04-ci-de-solo-lo-que-cambia.md#sin-base-todo)).

**Comando**: copia el script del starter y rellena sus **TODO 1, 2 y 3**:

```bash
mkdir -p scripts
cp "$S/scripts/changed-areas.sh" scripts/
```

El TODO 1 sustituye la línea de `changed=`; el TODO 2 rellena `all`; el TODO 3 amplía la
expresión de `smoke`:

```bash
if [[ -n "$base" ]] && git cat-file -e "$base^{commit}" 2>/dev/null; then
  changed=$(git diff --name-only "$base" HEAD)
else
  changed=".github/"
fi
# Un cambio en .github/ puede alterar cualquier workflow o action: se prueba todo.
all=false
if grep -q '^\.github/' <<<"$changed"; then all=true; fi
# ...
echo "smoke=$(area '^(api/|web/|compose\.yaml$|scripts/smoke-test\.sh$)')"
```

`git cat-file -e "$base^{commit}"` cubre la cadena vacía, los ceros y un SHA que el clon no
tiene. Sin base, el script finge que cambió `.github/` y el TODO 2 hace el resto.

**Verifica**: tres casos que no dependen del contenido de tu repo:

```bash
ls -l scripts/changed-areas.sh | cut -c1-10
# -rwxr-xr-x
scripts/changed-areas.sh HEAD | tr '\n' ' '; echo
# api=false web=false tools=false smoke=false workflows=false
scripts/changed-areas.sh "" | tr '\n' ' '; echo
# api=true web=true tools=true smoke=true workflows=true
scripts/changed-areas.sh 0000000000000000000000000000000000000000 | tr '\n' ' '; echo
# api=true web=true tools=true smoke=true workflows=true
```

Contra `HEAD` no hay diff y nada corre; sin base, todo. `changed-areas-script` prueba además, en
un repo temporal, un cambio solo en `web/` y otro en `.github/`.

```bash
git add scripts/changed-areas.sh
git commit -m "ci: add changed-areas script"
```

---

## Paso 2: El job `changes`

**Por qué**: la base del diff cambia con el evento: en un PR, la punta de la rama destino; en la
cola, el commit de `main` bajo el grupo (`merge_group.base_sha`, que usarás desde la práctica 03);
en un push, el commit anterior. `||` toma la primera que exista. `fetch-depth: 0` trae el
historial: con el clon superficial la base no está y el script correría todo siempre
([teoría 04](../1-teoria/04-ci-de-solo-lo-que-cambia.md#el-historial-completo)).

**Comando**: el `ci.yml` del starter sustituye al tuyo. El starter trae el `uses:` del job `sql`
con otra org: recupera tu línea, la que apunta a `<tu-org>/actions-tablero`.

```bash
cp "$S/.github/workflows/ci.yml" .github/workflows/ci.yml
mine=$(git show HEAD:.github/workflows/ci.yml | grep -m1 'actions-tablero/sql-lint@')
awk -v mine="$mine" '/actions-tablero\/sql-lint@/ { print mine; next } { print }' \
  .github/workflows/ci.yml > ci.tmp && mv ci.tmp .github/workflows/ci.yml
git diff HEAD -- .github/workflows/ci.yml | grep -c 'sql-lint@'
# 0
```

Rellena los **TODO 5 y 6**. Los dos steps del job `changes` quedan así:

```yaml
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          # La base del diff puede estar muchos commits atrás.
          fetch-depth: 0
          persist-credentials: false
      - name: Diff contra la base del evento
        id: diff
        env:
          # PR: la rama destino; cola: lo que hay delante en main; push: el commit anterior.
          BASE: ${{ github.event.pull_request.base.sha || github.event.merge_group.base_sha || github.event.before }}
        run: scripts/changed-areas.sh "$BASE" | tee -a "$GITHUB_OUTPUT"
```

**Verifica**:

```bash
yq '.jobs.changes.steps[0].with."fetch-depth", .jobs.changes.steps[1].env.BASE' .github/workflows/ci.yml
# 0
# ${{ github.event.pull_request.base.sha || github.event.merge_group.base_sha || github.event.before }}
```

`actionlint` aún se queja de los jobs de área: lo arregla el paso siguiente.

---

## Paso 3: Las áreas, como reutilizables

**Por qué**: cada área conserva su workflow, pero deja de dispararse sola: `workflow_call` para
que la llame `ci.yml` y `workflow_dispatch` para `nightly.yml`. Fuera los filtros `paths` y el
bloque `concurrency`: en un reutilizable `github.workflow` es el del llamante, su grupo chocaría
con el del run de `ci` y GitHub cancelaría uno
([teoría 04](../1-teoria/04-ci-de-solo-lo-que-cambia.md#los-reutilizables-y-la-concurrencia)).

**Comando**: edita a mano la cabecera de los cinco archivos. `ci-api.yml` queda así hasta `jobs:`:

```yaml
name: ci-api
on:
  # Lo llama ci.yml cuando su área cambia; nightly.yml lo relanza sobre main.
  workflow_call:
  workflow_dispatch:
# Raíz vacía: cada job declara solo los permisos que usa.
permissions: {}
jobs:
```

Lo mismo en `ci-web.yml` y `smoke.yml`; en `ci-tools.yml` y `lint-workflows.yml`, que `nightly.yml`
no lanza, el comentario se queda en `# Lo llama ci.yml cuando su área cambia.` Los jobs no se tocan: sus `timeout-minutes` siguen donde estaban. Un job que **llama** a un
reutilizable no admite `timeout-minutes`; el límite vive en los jobs del reutilizable.

Después rellena el **TODO 7** de `ci.yml`: cada job de área con su `if:`.

```yaml
  # Un reutilizable llamado con ./ corre en el mismo commit que ci.yml: ya está fijado.
  api:
    needs: changes
    if: needs.changes.outputs.api == 'true'
    uses: ./.github/workflows/ci-api.yml # zizmor: ignore[self-repository]
    permissions:
      contents: read
```

`web`, `tools`, `smoke` y `workflows` siguen el mismo molde, cada uno con su salida en el `if:`
y su archivo en `uses:`. Las salidas son cadenas: se comparan con `'true'` entre comillas.

**Verifica**: cada workflow de área, con sus disparadores y si conserva `concurrency`; y cada job
de área de `ci.yml`, con su `if:`:

```bash
for f in ci-api ci-web ci-tools smoke lint-workflows; do
  printf '%s=%s ' $f "$(yq '(.on | keys | join(",")) + "," + (has("concurrency") | tostring)' .github/workflows/$f.yml)"
done; echo
# ci-api=workflow_call,workflow_dispatch,false ci-web=workflow_call,workflow_dispatch,false ci-tools=workflow_call,workflow_dispatch,false smoke=workflow_call,workflow_dispatch,false lint-workflows=workflow_call,workflow_dispatch,false
yq '[.jobs | to_entries | .[] | select(.value.uses) | .key + ":" + (.value.if | sub(".*outputs\\."; "") | sub(" .*"; ""))] | join(" ")' .github/workflows/ci.yml
# api:api web:web tools:tools smoke:smoke workflows:workflows
```

```bash
git add .github/workflows
git commit -m "ci: call area workflows from ci only when their area changes"
```

---

## Paso 4: `ci-gate`, la única puerta

**Por qué**: un job saltado cuenta como éxito en un check obligatorio, y un job cuyo `needs` falló
se salta. Sin `if: always()`, un fallo en `api` saltaría `ci-gate` y el ruleset lo vería verde.
Con él, `ci-gate` corre siempre y solo acepta `success` y `skipped`. `runner-info` y `summary`
no entran en `needs`: son informativos
([teoría 03](../1-teoria/03-checks-obligatorios-y-el-job-puerta.md#la-puerta-que-no-se-deja-engañar)).

**Comando**: rellena los **TODO 8 y 9**:

```yaml
  ci-gate:
    name: ci-gate
    needs: [structure, version, sql, changes, api, web, tools, smoke, workflows]
    # Sin always() un fallo en needs salta este job, y un check saltado cuenta como éxito.
    if: always()
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    permissions: {}
    steps:
      - name: Ningún job necesario falló ni se canceló
        env:
          RESULTS: ${{ toJSON(needs.*.result) }}
        run: |
          echo "$RESULTS"
          jq -e 'all(.[]; . == "success" or . == "skipped")' <<<"$RESULTS" > /dev/null
```

`name: ci-gate` fijo es lo que exigirá el ruleset; si lo cambias, el check obligatorio deja de
aparecer.

**Verifica**: el último step decide bien con tres listas de resultados, sin hacer push:

```bash
r=$(yq '.jobs."ci-gate".steps[-1].run' .github/workflows/ci.yml)
for res in '["success","skipped"]' '["success","failure"]' '["cancelled","success"]'; do
  RESULTS="$res" bash -c "$r" > /dev/null 2>&1 && echo "$res pasa" || echo "$res bloquea"
done
# ["success","skipped"] pasa
# ["success","failure"] bloquea
# ["cancelled","success"] bloquea
```

```bash
git commit -am "ci: add ci-gate job"
```

---

## Paso 5: `pr-report` escucha a `ci`

**Por qué**: `ci-web` ya no corre por su cuenta, sino dentro de un run de `ci`: es a `ci` a quien
tiene que escuchar `workflow_run`. Y si el PR no toca `web/`, no hay artefacto `dist-report`: el
job pregunta antes de descargar. Un `workflow_run` usa la versión de `main`: el cambio se nota
tras fusionar.

**Comando**: en `.github/workflows/pr-report.yml`, cambia `workflows: [ci-web]` por
`workflows: [ci]` (y el comentario de encima). Después añade un step **antes** de la descarga
y pon el mismo `if:` en la descarga y en el comentario. Fragmento de los steps:

```yaml
    steps:
      # Si el PR no toca web/, ci no llama a ci-web y no hay informe que comentar.
      - name: Buscar el informe de dist
        id: report
        env:
          GH_TOKEN: ${{ github.token }}
          RUN_ID: ${{ github.event.workflow_run.id }}
        run: echo "count=$(gh api "repos/$GITHUB_REPOSITORY/actions/runs/$RUN_ID/artifacts?name=dist-report" --jq .total_count)" >> "$GITHUB_OUTPUT"
      - if: steps.report.outputs.count != '0'
        uses: actions/download-artifact@9000827ccba6bdab643e8b6fd33ac0654aef8333 # v8.0.2
        # ... with: como estaba
      - name: Comentar en el PR
        if: steps.report.outputs.count != '0'
        # ... env: y run: como estaban
```

**Verifica**:

```bash
yq '.on.workflow_run.workflows[0], ([.jobs.comment.steps[] | .if // "-"] | join(" | "))' .github/workflows/pr-report.yml
# ci
# - | steps.report.outputs.count != '0' | steps.report.outputs.count != '0'
```

```bash
git commit -am "ci(pr-report): follow ci and skip when there is no dist report"
```

---

## Paso 6: Lint, fusionar y un PR que solo toca `web/`

**Por qué**: el primer PR toca `.github/`, así que su `ci` corre todas las áreas: es la prueba
completa. La prueba de verdad del diff es un segundo PR que solo toca `web/`: `api`, `tools` y
`workflows` tienen que salir saltados y `ci-gate` en verde igualmente.

**Comando**:

```bash
actionlint && GH_TOKEN=$(gh auth token) zizmor -q .github/ && echo limpio
# limpio
git push -u origin ci/single-gate
gh pr create --title "ci: run only changed areas behind a single ci-gate" --body "Capa 18, práctica 01."
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch > /dev/null; gh pr checks "$pr" --json name,bucket --jq '.[] | select(.name == "ci-gate") | .bucket'
# pass
gh pr merge "$pr" --squash --delete-branch
git switch main && git pull --ff-only
```

Ahora el PR de prueba, que no se fusiona:

```bash
git switch -c test/web-only
echo '<!-- prueba de ci-gate -->' >> web/index.html
git commit -am "chore(web): ci-gate smoke test"
git push -u origin test/web-only
gh pr create --title "chore(web): ci-gate smoke test" --body "Solo toca web/. No se fusiona."
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch > /dev/null
```

**Verifica**: `ci-gate` pasa con las áreas sin cambios saltadas, y `pr-report` comentó:

```bash
gh pr checks "$pr" --json name,bucket --jq '.[] | select(.name == "ci-gate") | .bucket'
# pass
gh pr checks "$pr" --json name,bucket --jq '[.[] | select(.bucket == "skipping") | .name] | sort | join(",")'
# api,tools,workflows
sleep 60; gh pr view "$pr" --json comments --jq '.comments | length'
# 1
```

Los nombres de los checks saltados pueden variar; lo que importa es que esas tres áreas no
corrieron. Cierra el PR de prueba sin fusionarlo:

```bash
gh pr close "$pr" --delete-branch
git switch main && git branch -D test/web-only
```

---

## ✅ Resultado

- [ ] `scripts/changed-areas.sh` marca solo las áreas que cambian, y todas sin base o con `.github/`
- [ ] `ci.yml` tiene `changes`, cinco jobs de área con `if:` y `ci-gate` con `if: always()`
- [ ] Los cinco workflows de área solo admiten `workflow_call` y `workflow_dispatch`, sin `concurrency`
- [ ] `pr-report.yml` escucha a `ci` y no falla cuando no hay `dist-report`
- [ ] Un PR que solo tocaba `web/` dejó `ci-gate` en verde con `api`, `tools` y `workflows` saltados

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 18
# ...
#   ✅ scripts/changed-areas.sh marca solo las áreas que tocan los archivos cambiados, y todas si cambia .github/ o no hay base
#   ❌ ci.yml corre en pull_request, en merge_group y en push a main
# ...
```

En verde, las ocho de esta práctica: de `changed-areas-script` a `workflows-lint`; `ci-triggers`
espera a la práctica 03. Las de semanas anteriores que pasan a rojo (los `paths` de la 07, por
ejemplo) están en [comprobaciones superadas por capas posteriores](../../../docs/autograding.md#comprobaciones-superadas-por-capas-posteriores).

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `changes` marca todo `true` en un PR que solo toca `web/` | El checkout es superficial y la base no está en el clon | `fetch-depth: 0` en el checkout de `changes` (paso 2) |
| `actionlint` dice que el workflow llamado no tiene `workflow_call` | El reutilizable aún tiene `push`/`pull_request` en `on:` | Paso 3: `workflow_call` y `workflow_dispatch` |
| Un run de `ci` aparece cancelado sin que hicieras push | Un reutilizable conserva su `concurrency` con `github.workflow` | Quita el bloque `concurrency` del reutilizable |
| `ci-gate` sale `skipped` cuando falla un área | Falta `if: always()` | Paso 4 |
| `ci-gate` en verde con `api` en rojo | El `jq` no tiene `-e` o falta un job en `needs` | `jq -e` y los nueve jobs en `needs` |
| `pr-report` falla al descargar en un PR que no toca `web/` | Falta el step `report` o los `if:` que lo usan | Paso 5 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Bots que abren PR y el token de una App](../1-teoria/07-bots-que-abren-pr-y-el-token-de-una-app.md) | [Ruleset y CODEOWNERS en main](02-ruleset-y-codeowners-en-main.md) |
