# Práctica 02 — Caché y paralelismo medidos

> La caché y el paralelismo son las dos palancas que todo el mundo toca primero, y casi nadie
> mide. En esta práctica haces inventario de la caché de `tablero`, lees en los logs si acierta,
> compruebas dónde escribe un PR y pruebas a partir los tests de la web en dos shards, con
> números delante para decidir si compensa.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- El inventario de la caché del repo: entradas, refs, tamaño y límites
- Los aciertos y fallos de caché de `setup-uv` y `setup-node` leídos en un log real
- La prueba de que un PR lee la caché de `main` y escribe la suya en `refs/pull/<n>/merge`
- Un experimento de sharding en la rama `exp/shard-web`, medido con `scripts/job-timings.sh`
- Una decisión escrita con datos y el PR cerrado sin fusionar

Esta práctica no tiene comprobaciones automáticas: el experimento no llega a `main`. La
[rúbrica](../rubrica-evaluacion.md) revisa la decisión y sus números.

## 📋 Antes de empezar

Terminaste la [práctica 01](01-medir-la-linea-base.md): `scripts/job-timings.sh` está en `main`.
Leíste las teorías [03](../1-teoria/03-la-cache-a-fondo.md) y
[04](../1-teoria/04-paralelismo-y-sharding.md).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
test -x scripts/job-timings.sh && echo listo
# listo
```

Las salidas de esta práctica dependen de tu repo: ids, claves y segundos son de ejemplo.

---

## Paso 1: Inventario de la caché

**Por qué**: antes de tocar la caché sabes qué hay, de quién es y cuánto ocupa. El cupo es de
10 GB por repo y, al llenarse, GitHub expulsa por último acceso: si las entradas de PR ocupan
mucho, las primeras en caer pueden ser las de `main`. Los límites del repo se leen por API
([teoría 03](../1-teoria/03-la-cache-a-fondo.md#expulsión-y-límites)).

**Comando**:

```bash
gh api "repos/{owner}/{repo}/actions/cache/usage"
# {"full_name":"<tu-org>/tablero","active_caches_size_in_bytes":412337152,"active_caches_count":6}
gh cache list --limit 100 --json key,ref,sizeInBytes,lastAccessedAt \
  --jq '.[] | "\(.ref)  \(.sizeInBytes / 1048576 | floor) MB  \(.key)"'
# refs/heads/main  148 MB  setup-uv-1-x86_64-unknown-linux-gnu-...
# refs/heads/main  97 MB  node-cache-Linux-x64-pnpm-...
# ...
```

**Verifica**: los dos límites del repo, que valen lo mismo para todas sus cachés:

```bash
gh api "repos/{owner}/{repo}/actions/cache/retention-limit"
# {"max_cache_retention_days":7}
gh api "repos/{owner}/{repo}/actions/cache/storage-limit"
# {"max_cache_size_gb":10}
```

Apunta el número de entradas y los MB totales: los compararás en la práctica 04, después de
la limpieza.

---

## Paso 2: Aciertos y fallos en el log

**Por qué**: el output `cache-hit` vale `true` solo si la clave **exacta** existe. Si entra
por una de las `restore-keys` (un prefijo), la caché se restaura, pero `cache-hit` vale `false`,
y al final del job se guarda una entrada nueva con la clave exacta. `setup-uv` y `setup-node`
gestionan su caché solas: lo que hacen lo dicen en su log, en el step que restaura y en el
post-step que guarda.

**Comando**: el run de `ci` del PR de la práctica 01, que corrió todas las áreas porque tocaba
`.github/`:

```bash
r=$(gh run list --workflow ci.yml --event pull_request --branch perf/baseline --limit 1 \
  --json databaseId --jq '.[0].databaseId'); echo "$r"
# <id-del-run>
gh run view "$r" --log | grep -E 'Cache restored from key|Cache hit occurred|Cache not found|not saving' \
  | cut -f1,3 | cut -c1-140 | sort -u
# api / Python / Python 3.13	... Cache restored from key: setup-uv-1-x86_64-unknown-linux-gnu-...
# web / Web / Node 24	... Cache restored from key: node-cache-Linux-x64-pnpm-...
# web / Web / Node 24	... Cache hit occurred on the primary key node-cache-Linux-x64-pnpm-..., not saving cache.
```

Los textos exactos los pone cada action en su versión: si tu `grep` no saca nada, busca
`cache` sin distinguir mayúsculas (`grep -i cache`). Lo importante es la pareja: se restauró
una clave y el post-step no guardó porque ya existía.

**Verifica**: la clave que restauró el PR es una entrada de `main`:

```bash
gh cache list --ref refs/heads/main --limit 100 --json key --jq '.[].key' | grep -c '^node-cache-'
# 1
```

Si en tu log sale `Cache not found` en lugar de una restauración, la caché de `main` caducó
(7 días sin acceso) o la expulsaron: el próximo push a `main` la vuelve a crear.

---

## Paso 3: Dónde escribe un PR

**Por qué**: un run lee de su propia ref y de la rama por defecto; un PR, además, de la base. Lo
que **escribe** va a su propia ref, y en un PR esa ref es `refs/pull/<n>/merge`: solo los
re-runs de ese mismo PR podrán leerlo. Del paso 2 sale una consecuencia: un PR que no cambia
ningún lockfile acierta con la clave de `main` y no escribe nada. Un PR solo deja caché propia
cuando busca una clave que `main` no tiene, como un PR de Dependabot que cambia
`pnpm-lock.yaml` ([teoría 03](../1-teoria/03-la-cache-a-fondo.md#alcance-qué-ref-puede-leer-qué)).

**Comando**: las refs que tienen caché hoy, y las del PR de la práctica 01:

```bash
gh cache list --limit 100 --json ref --jq 'group_by(.ref)[] | "\(.[0].ref): \(length)"'
# refs/heads/main: 2
pr1=$(gh pr list --state merged --head perf/baseline --json number --jq '.[0].number')
gh cache list --ref "refs/pull/$pr1/merge" --json id --jq length
# 0
```

**Verifica**: el PR de la práctica 01 no dejó nada propio porque todo lo restauró de `main`. Lo
contrario lo verás en el paso 5: el experimento usa claves que `main` no tiene y sus entradas
aparecen bajo `refs/pull/<n>/merge`.

```bash
gh cache list --limit 100 --json ref --jq '[.[].ref | select(startswith("refs/pull/"))] | length'
# 0
```

Si sale más de 0, son de PR anteriores (Dependabot, por ejemplo): apúntalos, la práctica 04 los
limpiará si ya están cerrados.

---

## Paso 4: El experimento de sharding

**Por qué**: con `--shard=<i>/<n>`, vitest reparte los archivos de test entre `n` procesos; con
una matriz, cada shard corre en su runner. El reloj de los tests baja si el trabajo de cada shard
pesa más que el coste fijo de arrancar otro job: checkout, `setup-tablero` e instalación. Eso no
se adivina, se mide ([teoría 04](../1-teoria/04-paralelismo-y-sharding.md#el-modelo-del-coste-fijo)).
La web de `tablero` tiene dos archivos de test (`tests/api.test.ts` y `tests/App.test.tsx`): cada
shard correrá uno.

El experimento vive en un workflow aparte, `web-shards.yml`, en la rama `exp/shard-web`, y se
dispara en `pull_request`: como nunca llega a `main`, solo corre en este PR. `ci.yml` no se toca,
así que `ci-gate` sigue igual. El mismo run tiene la versión entera (`whole`) y la partida
(`shard`), con el mismo setup: la comparación es justa.

Cada job añade además la caché de resultados de vitest (`node_modules/.vite/vitest`), con el SHA
en la clave. Aquí aporta poco; está para ver dónde escribe un PR cuando su clave no existe en
`main`.

Antes de lanzarlo, **escribe la regla de decisión**. Por ejemplo: "parto los tests solo si el
reloj del test más lento baja más de un 30 % y los minutos facturables suben menos de un 50 %".

**Comando**:

```bash
git switch -c exp/shard-web
echo "Partir si el reloj baja >30 % y los minutos suben <50 %." > ~/code/perf-19/shard-rule.txt
```

Crea `.github/workflows/web-shards.yml` con el `uses:` de `setup-tablero` que ya usa tu
`ci-web.yml` (`grep -h 'setup-tablero@' .github/workflows/ci-web.yml`):

```yaml
# Experimento de la práctica 02 de la Semana 19: vive solo en exp/shard-web y no se fusiona.
name: web-shards
on:
  pull_request:
permissions:
  contents: read
defaults:
  run:
    shell: bash
    working-directory: web
jobs:
  whole:
    name: Web entera
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: <tu-org>/actions-tablero/setup-tablero@<sha-de-v1.0.0> # v1.0.0
        with:
          stack: node
          working-directory: web
      # Solo para ver dónde escribe un PR: vitest guarda ahí los resultados del último run.
      - uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
        with:
          path: web/node_modules/.vite/vitest
          key: vitest-${{ runner.os }}-whole-${{ github.sha }}
          restore-keys: |
            vitest-${{ runner.os }}-whole-
      - name: Todos los tests
        run: pnpm test
  shard:
    name: Web shard ${{ matrix.shard }}/2
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    strategy:
      matrix:
        shard: [1, 2]
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: <tu-org>/actions-tablero/setup-tablero@<sha-de-v1.0.0> # v1.0.0
        with:
          stack: node
          working-directory: web
      - uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
        with:
          path: web/node_modules/.vite/vitest
          key: vitest-${{ runner.os }}-shard-${{ matrix.shard }}-${{ github.sha }}
          restore-keys: |
            vitest-${{ runner.os }}-shard-${{ matrix.shard }}-
      - name: Tests del shard
        env:
          SHARD: ${{ matrix.shard }}
        run: pnpm test --shard="$SHARD/2"
```

`pnpm test` es `vitest run` y lo que va detrás pasa a vitest. El shard llega por `env:` como en
la teoría: un valor de la matriz es tuyo, pero así todos los `run:` siguen la misma regla.
`defaults.run.working-directory` no afecta a los `uses:`: por eso las rutas de `setup-tablero` y
de la caché empiezan por `web/`.

```bash
actionlint && GH_TOKEN=$(gh auth token) zizmor -q .github/ && echo limpio
# limpio
git add .github/workflows/web-shards.yml
git commit -m "ci: experiment with sharded web tests"
git push -u origin exp/shard-web
gh pr create --draft --title "exp: shard web tests" --body "Capa 19, práctica 02. Experimento: no se fusiona."
pr=$(gh pr view --json number --jq .number); echo "$pr" > ~/code/perf-19/exp-pr
sleep 10
w=$(gh run list --workflow web-shards.yml --branch exp/shard-web --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$w" --exit-status > /dev/null && echo shards-ok
# shards-ok
```

El PR es borrador: la merge queue no acepta borradores, y deja claro que no se fusiona. `ci`
también corre en él, entero, porque el PR toca `.github/`.

**Verifica**: cada shard corrió un solo archivo:

```bash
gh run view "$w" --log | grep -E 'Test Files' | cut -f1,3 | sed 's/\t.*Z / /'
# Web entera  Test Files  2 passed (2)
# Web shard 1/2  Test Files  1 passed (1)
# Web shard 2/2  Test Files  1 passed (1)
```

---

## Paso 5: Medir y decidir

**Por qué**: un run no basta, igual que en la línea base. `gh run rerun` repite el run entero sobre
el mismo commit y la API de jobs devuelve el último intento: tres intentos, tres medidas. Comparas
la duración de `Web entera` con la del shard **más lento** (el que manda en el reloj), y sus
minutos con la **suma** de los shards (lo que se factura).

**Comando**:

```bash
for i in 1 2 3; do
  if [ "$i" -gt 1 ]; then
    gh run rerun "$w"; sleep 10; gh run watch "$w" --exit-status > /dev/null
  fi
  gh api "repos/{owner}/{repo}/actions/runs/$w/jobs" --paginate --jq '.jobs[]' \
    | scripts/job-timings.sh | grep -E '^\| Web (entera|shard)'
  echo
done | tee ~/code/perf-19/shards.md
# | Web entera | 3 | 41 | 1 |
# | Web shard 1/2 | 4 | 38 | 1 |
# | Web shard 2/2 | 5 | 37 | 1 |
#
# | Web entera | 2 | 39 | 1 |
# ...
```

Con estos números de ejemplo: el reloj pasa de 41 s a 38 s (un 7 % menos) y los minutos, de 1 a
2 (el doble). La regla dice que no. Casi todo el job es arranque: los tests en sí tardan un
segundo, y partir un segundo en dos no compensa 35 s de setup repetidos. Con cien archivos de
test que tardan cinco minutos, la cuenta saldría al revés.

**Verifica**: la decisión, escrita en el PR antes de cerrarlo, y las cachés que dejó el
experimento en su ref:

```bash
gh pr comment "$pr" --body "Decisión: no se parte. $(cat ~/code/perf-19/shard-rule.txt) Medidas: reloj <entera> s → <shard más lento> s, minutos <n> → <m>."
gh cache list --ref "refs/pull/$pr/merge" --json key --jq '.[].key'
# vitest-Linux-shard-2-<sha>
# vitest-Linux-shard-1-<sha>
# vitest-Linux-whole-<sha>
```

Tres entradas, una por job y no tres por intento: en los re-runs la clave exacta ya existía y
no se volvió a guardar.

---

## Paso 6: Cerrar sin fusionar

**Por qué**: un experimento descartado no se fusiona, pero tampoco se deja abierto: un PR
abierto mantiene vivas sus cachés y confunde a quien llegue después. Al cerrar, la decisión
queda en el comentario del PR, que es lo que se busca dentro de seis meses.

> ⚠️ **Cierras el PR y borras la rama `exp/shard-web`, en local y en GitHub.** El workflow del
> experimento está en esta práctica; si necesitas la rama, la página del PR cerrado tiene el
> botón **Restore branch**. Sus tres cachés de `refs/pull/<n>/merge` **no** se borran: quedan
> huérfanas, sin nadie que pueda leerlas, ocupando cupo hasta que caduquen. Limpiarlas es el
> trabajo de la [práctica 04](04-retencion-y-limpieza.md).

**Comando**:

```bash
git switch main
gh pr close "$pr" --delete-branch --comment "Experimento cerrado: ver la decisión arriba."
```

**Verifica**: el PR está cerrado, la rama ya no existe y las cachés siguen ahí:

```bash
gh pr view "$pr" --json state --jq .state
# CLOSED
git ls-remote --heads origin exp/shard-web | wc -l
# 0
gh cache list --ref "refs/pull/$pr/merge" --json id --jq length
# 3
```

---

## ✅ Resultado

- [ ] Inventario de la caché apuntado: entradas, MB, refs y límites del repo
- [ ] Sabes leer en un log si `setup-uv` y `setup-node` acertaron y por qué no guardaron
- [ ] Comprobaste que un PR sin cambios de lockfile no escribe caché, y que el experimento sí
- [ ] Tres medidas del experimento en `~/code/perf-19/shards.md` y la decisión en el PR
- [ ] El PR `exp: shard web tests` cerrado sin fusionar, con su número en `~/code/perf-19/exp-pr`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 19
# ...
```

Esta práctica no cambia ninguna comprobación: siguen en verde las tres de la práctica 01. Lo
que hiciste aquí lo revisa la rúbrica.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `Unable to resolve action <tu-org>/actions-tablero...` | Dejaste el placeholder o el SHA no es el de tu `v1.0.0` | Copia el `uses:` de tu `ci-web.yml` |
| Los dos shards corren los dos archivos | Falta `--shard` o el `/2` no coincide con la matriz | Paso 4: el número de shards aparece dos veces |
| `No test files found` en un shard | Hay más shards que archivos de test | Con dos archivos, como mucho dos shards |
| `gh cache list --ref refs/pull/<n>/merge` sale vacío | El job falló antes del post-step de la caché, o la ref no lleva `/merge` | Mira el run; el formato es `refs/pull/<n>/merge` |
| `gh run rerun` dice que el run no se puede relanzar | Lo lanzaste mientras el intento anterior corría | Espera con `gh run watch` y repite |
| El PR del experimento aparece en la merge queue | Lo sacaste de borrador | `gh pr ready "$pr" --undo` y vuelve al paso 6 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Práctica 01 — Medir la línea base](01-medir-la-linea-base.md) | [Práctica 03 — Métricas del CI](03-metricas-del-ci.md) |
