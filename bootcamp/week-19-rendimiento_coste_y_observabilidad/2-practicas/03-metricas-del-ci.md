# Práctica 03 — Métricas del CI

> Medir a mano una vez sirve para decidir; medir solo cada día sirve para darte cuenta de que
> algo empeoró. En esta práctica `ci-metrics.yml` publica los tiempos de cada run de `ci` en
> `main` y, cada lunes, la tendencia de duración y éxito contra un presupuesto que avisa.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `scripts/ci-trend.sh` completo (`TODO 3` y `TODO 4`): runs, tasa de éxito, p50, p95 y aviso
- `ci-metrics.yml` completo (`TODO 5` y `TODO 6`), en `main` por la cola
- Un run de `ci-metrics` disparado por `workflow_run` tras el `ci` de `main`
- La variable `CI_P95_BUDGET_SECONDS` con un presupuesto que sabes justificar
- La tendencia lanzada a mano y comparada con Insights de la organización

## 📋 Antes de empezar

Terminaste las prácticas [01](01-medir-la-linea-base.md) y [02](02-cache-y-paralelismo-medidos.md).
Leíste la [teoría 06](../1-teoria/06-metricas-y-observabilidad.md).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
S=~/code/bc-github-actions/bootcamp/week-19-rendimiento_coste_y_observabilidad/3-proyecto/starter
git switch -c ci/metrics
cp "$S/scripts/ci-trend.sh" scripts/
cp "$S/.github/workflows/ci-metrics.yml" .github/workflows/
grep -nE 'TODO [0-9]+' scripts/ci-trend.sh .github/workflows/ci-metrics.yml | grep -oE '^[^:]+|TODO [0-9]+' | paste - -
# scripts/ci-trend.sh	TODO 3
# scripts/ci-trend.sh	TODO 4
# .github/workflows/ci-metrics.yml	TODO 5
# .github/workflows/ci-metrics.yml	TODO 6
```

---

## Paso 1: `ci-trend.sh`

**Por qué**: la media esconde la cola larga: nueve runs de 4 minutos y uno de 20 dan una media de
5,6 que no describe ninguno. El p50 dice cómo es un run normal y el p95 cómo es uno malo, que es
el que hace esperar a alguien. El script usa el percentil por rango más cercano, el valor en la
posición `ceil(p·n)` de la lista ordenada, y mide cada run desde `run_started_at` y no desde
`created_at`, que un re-run conserva ([teoría 06](../1-teoria/06-metricas-y-observabilidad.md#percentiles-no-medias)).

**Comando**: prueba el starter con veinte runs inventados, de 30 s a 600 s, tres de ellos fallidos:

```bash
fixture=$(jq -nc 'range(20) as $i | {conclusion: (if $i < 17 then "success" else "failure" end), run_started_at: "2026-11-14T10:00:00Z", updated_at: (1794650400 + ($i + 1) * 30 | todate)}')
printf '%s' "$fixture" | BUDGET=500 scripts/ci-trend.sh
# | Runs | Éxito | p50 (s) | p95 (s) |
# |--:|--:|--:|--:|
# | 20 | 85 % | 300 | 600 |
```

El p95 sale 600, el máximo, y no hay aviso aunque 600 pasa de 500. En el **TODO 3**, el cuarto
valor deja de ser el máximo y usa la función `pct` que ya calcula el p50:

```jq
  "\(length) \([.[] | select(.conclusion == "success")] | length) \(pct(0.5)) \(pct(0.95))"
```

En el **TODO 4**, sustituye la línea `: "$budget"` por la comprobación. El aviso va a **stderr**:
en el workflow, stdout acaba en el resumen, y el runner procesa los comandos `::warning` de los
dos flujos, así que el aviso llega a las anotaciones sin ensuciar la tabla:

```bash
if [[ -n "$budget" ]] && (( p95 > budget )); then
  echo "::warning title=CI lento::p95 de ${p95} s, por encima del presupuesto de ${budget} s" >&2
fi
```

Sin `BUDGET` la condición no se evalúa: sin presupuesto, el script solo informa.

**Verifica**: la tabla por stdout y el aviso por stderr, por separado:

```bash
printf '%s' "$fixture" | BUDGET=900 scripts/ci-trend.sh 2>&1 | tail -1
# | 20 | 85 % | 300 | 570 |
printf '%s' "$fixture" | BUDGET=500 scripts/ci-trend.sh 2>&1 >/dev/null
# ::warning title=CI lento::p95 de 570 s, por encima del presupuesto de 500 s
gh api "repos/{owner}/{repo}/actions/workflows/ci.yml/runs?branch=main&status=completed&per_page=100" \
  --jq '.workflow_runs[]' | scripts/ci-trend.sh | tail -1
# | <runs> | <éxito> % | <p50> | <p95> |
```

Con 20 runs, `ceil(0.95 · 20) = 19`: el p95 es el run 19 de 20 (570 s), no el último (600 s).

---

## Paso 2: `ci-metrics.yml`

**Por qué**: `workflow_run` corre **después** de `ci`, en un workflow aparte con su propio token
y su propio código: el de `main`, nunca el del run medido. Por eso puede leer la API sin riesgo,
y por eso zizmor lo marca (`dangerous-triggers`) y el comentario del starter explica por qué se
acepta. Sin filtro de rama correría también tras el `ci` de cada PR y de cada grupo de la cola,
que no son el `main` que quieres vigilar. Los dos jobs solo leen: `actions: read` para la API de
runs y jobs, `contents: read` para el checkout.

**Comando**: en el **TODO 5**, debajo de `types: [completed]`:

```yaml
    branches: [main]
```

En el **TODO 6**, el último step del job `trend` sustituye al `echo` del starter. Mismo esquema
que el job `run`, con el presupuesto por `env:`:

```yaml
      - name: Últimos 100 runs en el resumen
        env:
          GH_TOKEN: ${{ github.token }}
          # Sin la variable no hay aviso: la tabla sale igual.
          BUDGET: ${{ vars.CI_P95_BUDGET_SECONDS }}
        run: |
          {
            echo "## Tendencia de ci en main"
            echo
            gh api "repos/$GITHUB_REPOSITORY/actions/workflows/ci.yml/runs?branch=main&status=completed&per_page=100" --jq '.workflow_runs[]' |
              scripts/ci-trend.sh
          } >> "$GITHUB_STEP_SUMMARY"
```

`defaults.run.shell: bash` activa `pipefail`: si `gh api` falla, el step falla, en lugar de dejar
una tabla de cero runs en el resumen.

**Verifica**: las órdenes de `ci-metrics-triggers`, `ci-metrics-read-only` y `ci-metrics-summary`:

```bash
yq '(.on | keys | sort | join(",")) + " from=" + (.on.workflow_run.workflows | join(",")) + " types=" + (.on.workflow_run.types | join(",")) + " branches=" + (.on.workflow_run.branches | join(","))' .github/workflows/ci-metrics.yml
# schedule,workflow_dispatch,workflow_run from=ci types=completed branches=main
yq '"root=" + (.permissions | length | tostring) + " " + ([.jobs | to_entries[] | .key + ":" + (.value.permissions | to_entries | map(.key + "=" + .value) | sort | join("+")) + ":" + (.value | has("timeout-minutes") | tostring)] | join(" "))' .github/workflows/ci-metrics.yml
# root=0 run:actions=read+contents=read:true trend:actions=read+contents=read:true
yq '.jobs.trend.steps[-1].env.BUDGET' .github/workflows/ci-metrics.yml
# ${{ vars.CI_P95_BUDGET_SECONDS }}
```

---

## Paso 3: PR, cola y el primer run tras `ci`

**Por qué**: `workflow_run` solo se dispara si el workflow que escucha **ya está en la rama por
defecto**. En el PR, `ci-metrics.yml` no hace nada; cuando entra en `main`, el `ci` del push de
ese mismo merge es el primero que mide. Antes del push, el lint en local, el mismo que corre `lint-workflows`
en el PR: zizmor necesita un token para sus auditorías en línea.

**Comando**:

```bash
actionlint && GH_TOKEN=$(gh auth token) zizmor -q .github/ && echo limpio
# limpio
git add scripts/ci-trend.sh .github/workflows/ci-metrics.yml
git commit -m "ci: add ci-metrics with job timings and weekly trend"
git push -u origin ci/metrics
gh pr create --title "ci: add ci-metrics with job timings and weekly trend" --body "Capa 19, práctica 03."
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch --required > /dev/null && gh pr merge "$pr"
until [ "$(gh pr view "$pr" --json state --jq .state)" = MERGED ]; do sleep 15; done
git switch main && git pull --ff-only
sha=$(git rev-parse HEAD); sleep 10
gh run watch "$(gh run list --workflow ci.yml --event push --commit "$sha" --json databaseId --jq '.[0].databaseId')" > /dev/null
sleep 20
m=$(gh run list --workflow ci-metrics.yml --event workflow_run --commit "$sha" --json databaseId --jq '.[0].databaseId')
gh run watch "$m" --exit-status > /dev/null && echo metrics-ok
# metrics-ok
```

Abre el resumen con `gh run view "$m" --web`: verás la tabla de `job-timings.sh` del `ci` que
acaba de terminar, con su reloj y sus minutos.

**Verifica**: la orden de `ci-metrics-ran-after-ci`, qué job corrió, y que ningún `ci` de PR ni
de la cola disparó `ci-metrics`:

```bash
gh run list --workflow ci-metrics.yml --event workflow_run --commit "$sha" --json conclusion --jq '[.[].conclusion] | first'
# success
gh run view "$m" --json jobs --jq '.jobs[] | "\(.name): \(.conclusion)"'
# Tiempos del run: success
# Tendencia de ci en main: skipped
gh run list --workflow ci-metrics.yml --limit 50 --json headBranch --jq 'map(.headBranch) | unique | join(",")'
# main
```

---

## Paso 4: El presupuesto y la tendencia

**Por qué**: sin un umbral escrito, "el CI va lento" no es accionable. El presupuesto sale de tu
p95 real más un margen que sepas justificar: lo bastante alto para no avisar por el ruido de la
cola, lo bastante bajo para avisar si un cambio añade un minuto. Va en una variable de repo y no
en el YAML: ajustarlo no exige un PR, y el historial de la variable no se mezcla con el del CI.

**Comando**:

```bash
gh api "repos/{owner}/{repo}/actions/workflows/ci.yml/runs?branch=main&status=completed&per_page=100" \
  --jq '.workflow_runs[]' | scripts/ci-trend.sh | tail -1
# | 41 | 95 % | 236 | 318 |
```

Con un p95 de 318 s y un margen del 20 % salen 382: redondea a 380. Usa tus números:

```bash
gh variable set CI_P95_BUDGET_SECONDS --body 380
gh workflow run ci-metrics.yml --ref main
sleep 10
t=$(gh run list --workflow ci-metrics.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$t" --exit-status > /dev/null && echo trend-ok
# trend-ok
```

Para ver el aviso sin tocar la variable, pasa un presupuesto imposible al script en local:

```bash
gh api "repos/{owner}/{repo}/actions/workflows/ci.yml/runs?branch=main&status=completed&per_page=100" \
  --jq '.workflow_runs[]' | BUDGET=1 scripts/ci-trend.sh > /dev/null
# ::warning title=CI lento::p95 de 318 s, por encima del presupuesto de 1 s
```

**Verifica**: las órdenes de `budget-variable` y `ci-metrics-trend-ran`:

```bash
gh variable get CI_P95_BUDGET_SECONDS
# 380
git fetch -q origin main
gh run list --workflow ci-metrics.yml --event workflow_dispatch --commit "$(git rev-parse origin/main)" --json conclusion --jq '[.[].conclusion] | first'
# success
```

Apunta en la descripción del PR de esta práctica (`gh pr edit "$pr" --body-file ...`) de dónde
sale el 380: la rúbrica pide que el presupuesto tenga un porqué.

---

## Paso 5: Comparar con Insights

**Por qué**: GitHub ya da métricas de Actions en la organización. Conocerlas evita reinventarlas,
y compararlas con las tuyas te dice qué mide cada una. **Actions Performance Metrics** (tiempos
de run y de cola, tasa de fallo) está en todos los planes de GitHub Cloud; **Actions Usage
Metrics** (minutos) se documenta para Enterprise Cloud: comprueba si tu org la ve. Insights da
medias por workflow y por job de todo el repo; `ci-metrics` da percentiles de un workflow en una
rama, y avisa. Ninguna sustituye a la otra.

**Comando**: en GitHub, **tu org → Insights → Actions Performance Metrics**. Filtra por el repo
`tablero`, el workflow `ci` y los últimos 30 días, y apunta el tiempo medio de run y la tasa de
fallo. Después calcula lo mismo con la API, solo para `main`:

```bash
gh api -X GET "repos/{owner}/{repo}/actions/workflows/ci.yml/runs" \
  -f branch=main -f status=completed -f per_page=100 -f created=">=$(date -d '-30 days' +%F)" \
  --jq '.workflow_runs[]' \
  | jq -rs '"runs=\(length) media=\(map((.updated_at | fromdate) - (.run_started_at | fromdate)) | add / length | floor) s fallos=\(map(select(.conclusion == "failure")) | length)"'
# runs=41 media=241 s fallos=2
```

Con `-X GET`, `gh api` pone los `-f` en la query string, ya codificados.

**Verifica**: escribe la comparación en una línea y guárdala con tus mediciones:

```bash
echo "Insights ci 30 d: media <x> s, fallo <y> %. API main: media <z> s. Diferencia: Insights incluye PR y cola." \
  >> ~/code/perf-19/insights.txt
wc -l < ~/code/perf-19/insights.txt
# 1
```

Si Insights da una media menor, lo normal es que cuente los runs de PR y de la cola, que se
saltan áreas; si da una tasa de fallo mayor, que cuente runs cancelados por `concurrency`.

---

## ✅ Resultado

- [ ] `scripts/ci-trend.sh` con p95 por `pct` y aviso por stderr con presupuesto
- [ ] `ci-metrics.yml` en `main`, con `branches: [main]` y la tendencia con `BUDGET`
- [ ] Un run de `ci-metrics` por `workflow_run` en verde tras el `ci` de `main`
- [ ] `CI_P95_BUDGET_SECONDS` creada con un número que sale de tus datos
- [ ] La tendencia lanzada a mano en verde y comparada con Insights

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 19
# ...
#   ✅ ci-metrics terminó en success tras el ci del último commit de main
#   ✅ La tendencia de ci-metrics corrió a mano en success sobre el último commit de main
# ...
```

Se suman `ci-trend-script`, `ci-metrics-triggers`, `ci-metrics-read-only`, `ci-metrics-summary`,
`workflows-lint`, `budget-variable`, `ci-metrics-ran-after-ci` y `ci-metrics-trend-ran`: once en
verde. Las cuatro de retención y limpieza llegan con la práctica 04, y al fusionarla las dos
remotas de `ci-metrics` miran un commit nuevo: el `ci` de ese merge vuelve a disparar el
`workflow_run`, y la tendencia se relanza a mano al final.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `ci-metrics` no corre nunca tras `ci` | El archivo aún no está en `main`, o el `name:` de `ci.yml` no es `ci` | `workflows: [ci]` usa el `name:`, no el archivo; paso 3 |
| `ci-metrics` corre tras el `ci` de cada PR y de la cola | Falta `branches: [main]` (`TODO 5`) | Paso 2 |
| El job `run` falla con `HTTP 403` | Falta `actions: read` en el job | Paso 2 |
| El p95 sale igual que el máximo | Sigue `$s \| max` en lugar de `pct(0.95)` (`TODO 3`); con menos de 20 runs coinciden de verdad | Paso 1 |
| La tabla del resumen contiene `::warning` | El aviso va a stdout | `>&2` en el `TODO 4` |
| `zizmor` marca `dangerous-triggers` | Falta el comentario `# zizmor: ignore[...]` del starter en la línea de `workflow_run` | Restáuralo tal cual: va en la misma línea |
| `ci-metrics-ran-after-ci` en rojo tras otra fusión | El check mira el último commit de `main` | Espera al `ci` de ese commit: `ci-metrics` corre solo |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Práctica 02 — Caché y paralelismo medidos](02-cache-y-paralelismo-medidos.md) | [Práctica 04 — Retención y limpieza](04-retencion-y-limpieza.md) |
