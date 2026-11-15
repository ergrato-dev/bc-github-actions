# Práctica 01 — Medir la línea base

> "El CI va lento" no es un dato. En esta práctica mides tres runs de `ci` en `main` con la API,
> conviertes los jobs en una tabla de cola, duración y minutos facturables, quitas lo que cuesta
> sin aportar y vuelves a medir para demostrar cuánto has ganado.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Los tiempos de un run de `ci` leídos con `gh run view --json jobs` y con el endpoint `timing`
- `scripts/job-timings.sh` completo (`TODO 1` y `TODO 2`), probado con un JSON fijo y con un run real
- Una línea base de tres runs de `ci` en `main`, escrita en la descripción del PR
- `ci.yml` sin el job `runner-info` y con el job `changes` clonando sin blobs
- Tres runs después del cambio y la comparación, en el mismo PR

## 📋 Antes de empezar

`check-week.sh 18` está en verde y leíste las teorías
[02](../1-teoria/02-anatomia-del-tiempo-de-un-run.md) y
[05](../1-teoria/05-recortar-el-camino-critico.md). Desde la Semana 18, todo llega a `main` por PR
y por la merge queue.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
S=~/code/bc-github-actions/bootcamp/week-19-rendimiento_coste_y_observabilidad/3-proyecto/starter
mkdir -p ~/code/perf-19
yq '.jobs | has("runner-info")' .github/workflows/ci.yml
# true
```

`~/code/perf-19` guarda las mediciones fuera del repo: son notas tuyas, no código de `tablero`.

---

## Paso 1: Medir un run a mano

**Por qué**: antes de automatizar una medida, la haces a mano para saber qué devuelve cada
fuente. `gh run view --json jobs` da inicio y fin de cada job, pero no cuándo se encoló: eso solo
lo tiene la API de jobs (`created_at`). El endpoint `timing` da el reloj del run y lo facturable,
que en un repo público vale 0: no pagas, pero el mismo run en un repo privado sí pagaría, y esa
cuenta la harás tú en el paso 2 ([teoría 01](../1-teoria/01-cuanto-cuesta-un-minuto.md)).

**Comando**:

```bash
run=$(gh run list --workflow ci.yml --branch main --status success --limit 1 \
  --json databaseId --jq '.[0].databaseId'); echo "$run"
# <id-del-run>
gh run view "$run" --json jobs --jq '.jobs[] | select(.conclusion != "skipped")
  | "\(.name): \((.completedAt | fromdate) - (.startedAt | fromdate)) s"'
# Información del runner: 4 s
# Áreas que cambian: 9 s
# web / Web / Node 24: 48 s
# ...
```

Los nombres y los segundos de esta práctica son de ejemplo: los pone tu run.

**Verifica**: el reloj del run y lo facturable, desde `timing`:

```bash
gh api "repos/{owner}/{repo}/actions/runs/$run/timing" \
  --jq '"facturable=\(.billable.UBUNTU.total_ms // 0) ms reloj=\(.run_duration_ms / 1000) s"'
# facturable=0 ms reloj=<n> s
```

---

## Paso 2: `job-timings.sh`

**Por qué**: GitHub redondea **cada job** al minuto siguiente. Un run con diez jobs de 20 s no
factura 4 minutos (200 s entre 60) sino 10. Por eso el script redondea job a job y suma después.
El reloj del run va del primer job creado al último terminado: es lo que esperas tú, no lo que
paga nadie. El script lee de stdin, así que lo pruebas con un JSON guardado sin tocar GitHub.

**Comando**: copia el script del starter en una rama nueva y mira cómo falla:

```bash
git switch -c perf/baseline
cp "$S/scripts/job-timings.sh" scripts/
fixture='{"name":"api / Tests","created_at":"2026-11-14T10:00:00Z","started_at":"2026-11-14T10:00:05Z","completed_at":"2026-11-14T10:01:35Z"}{"name":"changes","created_at":"2026-11-14T10:00:00Z","started_at":"2026-11-14T10:00:03Z","completed_at":"2026-11-14T10:00:43Z"}{"name":"web","created_at":"2026-11-14T10:00:00Z","started_at":"2026-11-14T10:00:00Z","completed_at":"2026-11-14T10:00:00Z"}'
printf '%s' "$fixture" | scripts/job-timings.sh
# | Job | Cola (s) | Duración (s) | Minutos facturables |
# |---|--:|--:|--:|
# | api / Tests | 5 | 90 | 1 |
# | changes | 3 | 40 | 0 |
# | web | 0 | 0 | 0 |
```

`floor` trunca: 90 s salen a 1 minuto y 40 s a 0. Rellena el **TODO 1** con el redondeo hacia
arriba en aritmética entera, que deja un job saltado (0 s) en 0:

```jq
    | .billable = ((.run + 59) / 60 | floor)
```

En el **TODO 2**, antes de la cabecera, calcula los extremos del run y escribe la línea del
reloj. `select(. != null)` deja fuera un job que aún no ha terminado:

```jq
  | ([.[].created] | min) as $first | ([.[].ended | select(. != null)] | max) as $last
  | "Reloj del run: \($last - $first) s · minutos facturables: \(map(.billable) | add)",
    "",
```

Al final de la tabla añade la fila `| **Total** | ... |` con `map(.queue) | add`,
`map(.run) | add` y `map(.billable) | add`.

**Verifica**: el mismo JSON, y después un run real:

```bash
printf '%s' "$fixture" | scripts/job-timings.sh
# Reloj del run: 95 s · minutos facturables: 3
#
# | Job | Cola (s) | Duración (s) | Minutos facturables |
# |---|--:|--:|--:|
# | api / Tests | 5 | 90 | 2 |
# | changes | 3 | 40 | 1 |
# | web | 0 | 0 | 0 |
# | **Total** | 8 | 130 | 3 |
gh api "repos/{owner}/{repo}/actions/runs/$run/jobs" --paginate --jq '.jobs[]' \
  | scripts/job-timings.sh | head -1
# Reloj del run: <s> s · minutos facturables: <n>
```

Fíjate en el total: 130 s de trabajo entre 60 darían 3 minutos por casualidad; con dos jobs de
61 s darían 3 y el script dirá 4.

---

## Paso 3: La línea base

**Por qué**: un run solo engaña, porque la cola y la descarga de la caché varían. Tres runs
comparables son el mínimo. Comparables significa que corren las mismas áreas: con
`workflow_dispatch` no hay base del diff y `changed-areas.sh` activa todas, así que los tres runs
hacen el mismo trabajo. Se lanzan de uno en uno: con el grupo de `concurrency` de `ci`, un tercer
run pendiente cancelaría al segundo.

**Comando**:

```bash
phase=before
for i in 1 2 3; do
  gh workflow run ci.yml --ref main
  sleep 10
  id=$(gh run list --workflow ci.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')
  gh run watch "$id" --exit-status > /dev/null
  t=$(gh api "repos/{owner}/{repo}/actions/runs/$id/jobs" --paginate --jq '.jobs[]' | scripts/job-timings.sh)
  printf '| %s | %s | %s |\n' "$id" "$(head -1 <<<"$t" | sed 's/^Reloj del run: //')" \
    "$(sed -n '5,7p' <<<"$t" | cut -d'|' -f2 | sed 's/^ //; s/ $//' | paste -sd, -)"
done | tee ~/code/perf-19/$phase.md
# | <id-1> | 318 s · minutos facturables: 21 | web / Web / Node 26,web / Web / Node 24,smoke / Smoke |
# | <id-2> | 296 s · minutos facturables: 21 | ... |
# | <id-3> | 305 s · minutos facturables: 21 | ... |
```

Cada línea guarda el run, el reloj con los minutos facturables y los tres jobs más largos (las
filas 5 a 7 de la tabla, que va ordenada por duración).

**Verifica**:

```bash
wc -l < ~/code/perf-19/before.md
# 3
```

Si un reloj se aleja mucho de los otros dos, mira su cola: un pico de cola es ruido de GitHub, no
de tu CI. Repite ese run.

---

## Paso 4: Fuera `runner-info`

**Por qué**: `runner-info` imprime el sistema, la CPU y la memoria del runner desde la Semana 01.
Sirvió para aprender qué es un runner; hoy corre en cada run, ocupa un runner, factura un minuto
redondeado y ningún job usa lo que imprime. Solo `summary` lo espera en su `needs`, y un job
borrado que siguiera en un `needs` rompería el workflow entero
([teoría 05](../1-teoria/05-recortar-el-camino-critico.md#jobs-que-sobran)).

**Comando**: borra el job `runner-info` completo de `ci.yml` y deja así el principio de `summary`:

```yaml
  summary:
    name: Resumen
    needs: [structure, version, sql]
    if: ${{ !cancelled() }}
```

```bash
grep -rn 'runner-info' .github/ || echo "sin referencias"
# sin referencias
actionlint && echo limpio
# limpio
git add scripts/job-timings.sh .github/workflows/ci.yml
git commit -m "ci: drop runner-info job"
```

**Verifica**: la orden de `no-runner-info`:

```bash
yq '[.jobs | has("runner-info"), (.jobs.summary.needs | sort | join(","))] | join(" ")' .github/workflows/ci.yml
# false sql,structure,version
```

`ci-gate` no esperaba a `runner-info`, así que el ruleset no cambia.

---

## Paso 5: `changes` sin blobs

**Por qué**: `changes` necesita toda la historia (`fetch-depth: 0`) porque la base del diff puede
estar muchos commits atrás, pero `git diff --name-only` solo compara árboles: nunca lee el
contenido de un archivo. `filter: blob:none` trae commits y árboles completos y deja los blobs
fuera, salvo los del commit que se saca. El input `filter` de `actions/checkout` hace un clon
parcial. Las dos claves van juntas: sin `fetch-depth: 0` la base no está en el clon y todas las
áreas salen `true`.

**Comando**: en el job `changes` de `ci.yml`, el checkout queda así:

```yaml
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          # La base del diff puede estar muchos commits atrás. Sin blobs: git diff --name-only
          # solo compara árboles, y el clon deja de crecer con el tamaño de los archivos.
          fetch-depth: 0
          filter: blob:none
          persist-credentials: false
```

Compruébalo en local antes de que lo haga el runner:

```bash
tmp=$(mktemp -d)
git clone -q --filter=blob:none "https://github.com/$GH_REPO" "$tmp/blobless"
(cd "$tmp/blobless" && scripts/changed-areas.sh HEAD~3)
# api=<true|false>
# web=<true|false>
# ...
# workflows=<true|false>
rm -rf "$tmp"
git commit -am "ci: clone changes job without blobs"
```

Que salgan las cinco líneas sin error demuestra que el diff funciona en un clon sin blobs.

**Verifica**: la orden de `changes-blobless`:

```bash
yq '.jobs.changes.steps[] | select(.uses // "" | test("^actions/checkout@")) | "depth=" + (.with."fetch-depth" | tostring) + " filter=" + (.with.filter // "none")' .github/workflows/ci.yml
# depth=0 filter=blob:none
```

---

## Paso 6: PR, cola y tres runs después

**Por qué**: un cambio de rendimiento sin medida detrás es una opinión. La línea base va en la
descripción del PR antes de fusionar y la medida de después se añade al mismo PR: quien lo lea
dentro de seis meses verá el antes y el después juntos. Los dos recortes tocan jobs distintos
(`runner-info` desaparece, `changes` cambia de duración), así que la tabla por job separa el
efecto de cada uno aunque viajen en el mismo PR.

**Comando**:

```bash
git push -u origin perf/baseline
{
  echo "Capa 19, práctica 01: quita runner-info y clona changes sin blobs."
  echo; echo "## Antes (3 runs de ci en main, workflow_dispatch)"; echo
  echo "| Run | Reloj y minutos | Jobs más largos |"; echo "|---|---|---|"
  cat ~/code/perf-19/before.md
} > ~/code/perf-19/pr-body.md
gh pr create --title "ci: drop runner-info and clone changes without blobs" --body-file ~/code/perf-19/pr-body.md
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch --required > /dev/null && gh pr merge "$pr"
until [ "$(gh pr view "$pr" --json state --jq .state)" = MERGED ]; do sleep 15; done
git switch main && git pull --ff-only
sleep 10
gh run watch "$(gh run list --workflow ci.yml --event push --limit 1 --json databaseId --jq '.[0].databaseId')" > /dev/null
```

El último `watch` espera al `ci` del push: si lanzaras los runs de medida mientras corre, el
primero mediría también su espera. Ahora repite el bucle del paso 3 con `phase=after` y añade el
resultado al PR:

```bash
phase=after
# ... el mismo bucle for del paso 3, que escribe ~/code/perf-19/after.md ...
{
  cat ~/code/perf-19/pr-body.md
  echo; echo "## Después (3 runs)"; echo
  echo "| Run | Reloj y minutos | Jobs más largos |"; echo "|---|---|---|"
  cat ~/code/perf-19/after.md
  echo; echo "Resultado: <una frase con lo que cambió y cuánto>"
} > ~/code/perf-19/pr-body-final.md
gh pr edit "$pr" --body-file ~/code/perf-19/pr-body-final.md
```

Escribe tú la frase final con tus números: por ejemplo, "un minuto facturable menos por run y
el reloj igual, porque `runner-info` no estaba en el camino crítico". Que el reloj no baje es un
resultado válido: el minuto ahorrado es real aunque no lo notes esperando.

**Verifica**: el PR tiene las seis filas medidas y los dos cambios están en `main`:

```bash
gh pr view "$pr" --json body --jq '.body' | grep -c '^| [0-9]'
# 6
yq '.jobs | has("runner-info")' .github/workflows/ci.yml
# false
```

---

## ✅ Resultado

- [ ] Sabes leer un run con `gh run view --json jobs` y con el endpoint `timing`
- [ ] `scripts/job-timings.sh` redondea cada job al minuto y da el reloj y la fila de totales
- [ ] Tres runs antes y tres después, en la descripción del PR, con una frase de conclusión
- [ ] `ci.yml` sin `runner-info` y con `changes` clonando sin blobs, en `main` por la cola

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 19
# ...
#   ✅ ci.yml ya no tiene el job runner-info: solo imprimía datos del runner y costaba un job por run
#   ✅ El job changes de ci.yml clona el historial completo sin blobs (filter: blob:none)
#   ✅ scripts/job-timings.sh calcula cola, duración y minutos facturables redondeados por job, y el reloj del run
# ...
```

Quedan en verde `no-runner-info`, `changes-blobless` y `job-timings-script`, y también
`workflows-lint` si tus workflows ya estaban limpios. El resto llega con las prácticas 03 y 04.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| Los minutos facturables salen menos que la suma de duraciones entre 60 | Sigue el `floor` del starter, sin sumar 59 (`TODO 1`) | Paso 2 |
| `jq: error ... cannot be subtracted` en la línea del reloj | Un job sin terminar deja `ended` en `null` | El `select(. != null)` del `TODO 2` |
| `actionlint`: `job "summary" needs job "runner-info" which does not exist in this workflow` | Borraste el job pero no lo quitaste de `needs` | Paso 4 |
| `changes` marca todas las áreas `true` tras el paso 5 | Quitaste `fetch-depth: 0` al añadir `filter` | Las dos claves juntas, paso 5 |
| Uno de los tres runs del paso 3 sale `cancelled` | Lanzaste el siguiente sin esperar y el grupo de `concurrency` lo sustituyó | Repite el bucle; el `gh run watch` está para eso |
| `check-week.sh 01` y `02` marcan `ci-jobs` y `ci-summary-needs` en rojo | Esas comprobaciones esperan `runner-info` | Es lo esperado: [comprobaciones superadas por capas posteriores](../../../docs/autograding.md#comprobaciones-superadas-por-capas-posteriores) |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Retención y limpieza](../1-teoria/07-retencion-y-limpieza.md) | [Práctica 02 — Caché y paralelismo medidos](02-cache-y-paralelismo-medidos.md) |
