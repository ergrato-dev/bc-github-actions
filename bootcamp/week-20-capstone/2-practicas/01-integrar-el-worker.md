# Práctica 01 — Integrar el worker

> `tablero` estrena componente: un worker que purga las tareas hechas antiguas. En esta práctica
> lo metes en el CI sin escribir un solo job propio. `ci-worker.yml` llama a `_python.yml` del
> repo central, `ci.yml` lo llama cuando su área cambia y `ci-gate` lo espera.

**Tiempo estimado**: 1.25 h

## 🎯 Qué vas a conseguir

- `worker/` copiado de `app/` a `tablero`, con sus tests en verde en local
- `ci-worker.yml` completo (`TODO 1` y `TODO 2`), con un único job que llama al reutilizable central
- El área `worker` en `scripts/changed-areas.sh`, también disparada por `api/migrations/`
- `ci.yml` con el output, el job, la puerta y la estructura del worker
- Dependabot vigilando el `uv.lock` del worker
- El PR fusionado por la merge queue y un `ci` completo lanzado a mano, con los tres jobs del
  worker en verde

## 📋 Antes de empezar

Tienes `check-week.sh 19` en verde. Leíste la
[teoría 02](../1-teoria/02-integrar-un-componente-sin-escribir-ci.md): el contrato de
`_python.yml` y los seis sitios que tocas. Todo entra en `main` por PR y por la cola.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
org=${GH_REPO%%/*}
S=~/code/bc-github-actions/bootcamp/week-20-capstone/3-proyecto/starter
v100=$(gh api "repos/$org/actions-tablero/commits/v1.0.0" --jq .sha)
grep -c "_python.yml@$v100" .github/workflows/ci-api.yml
# 1
```

Si sale `0`, tu `ci-api.yml` apunta a otro commit del central. Revisa la
[práctica 02 de la Semana 11](../../week-11-actions_a_escala_de_organizacion/2-practicas/02-consumir-el-repo-central.md)
antes de seguir: el worker tiene que llamar al mismo commit que la API.

---

## Paso 1: El worker en el repo

**Por qué**: el worker es un proceso corto. Borra las tareas `done` con más de `RETENTION_DAYS`
días (30 por defecto) y termina. Si `RETENTION_DAYS` vale 0, es negativo o no es un número, falla
con `ValueError` antes de tocar la base: un valor mal escrito nunca debe borrar todo. Trae lo que
`_python.yml` espera de un componente: `pyproject.toml` con `uv.lock`, ruff, tests unitarios en
`tests/unit` y de integración en `tests/integration`. El esquema no es suyo. `migrate.py` aplica
las migraciones de `../api/migrations/`, así que el worker solo funciona dentro del monorepo, al
lado de `api/`.

**Comando**:

```bash
git switch -c feat/worker
cp -r ~/code/bc-github-actions/app/worker .
grep -n "MIGRATIONS =" worker/src/tablero_worker/migrate.py
# 15:MIGRATIONS = Path(__file__).resolve().parents[3] / "api" / "migrations"
(cd worker && uv sync --locked -q && uv run --locked ruff check . && uv run --locked pytest tests/unit -q | tail -1)
# All checks passed!
# 9 passed in <t>s
```

La integración necesita PostgreSQL. La pasará `_python.yml` en el CI, con su service container.

El `.gitignore` de la raíz nombra cada directorio (`api/.venv/`...), así que el `uv sync` de
arriba dejó un `worker/.venv/` que Git todavía ve. Añade lo del worker antes de comitear nada:

```bash
printf '%s\n' worker/.venv/ worker/.coverage worker/.pytest_cache/ worker/.ruff_cache/ >> .gitignore
```

**Verifica**: la orden de `worker-component`, y que en el commit no entrará el entorno virtual:

```bash
ls worker/uv.lock worker/Dockerfile worker/src/tablero_worker/purge.py worker/tests/unit worker/tests/integration >/dev/null && echo completo
# completo
git status --short --untracked-files=all worker | grep -c '\.venv/'
# 0
```

---

## Paso 2: `ci-worker.yml`, solo llamadas

**Por qué**: lint, tests, cobertura e integración contra PostgreSQL ya están escritos, probados y
versionados en `_python.yml` del repo central. Lo usan `ci-api.yml` y `ci-tools.yml`. El worker
solo tiene que decir **qué** probar: su directorio, su paquete, su cobertura mínima y si lleva
integración. `workflow_call` hace falta para que `ci.yml` lo pueda llamar. Sin él, `ci` ni
arranca (`startup_failure`). `workflow_dispatch` te deja lanzarlo solo. La raíz se queda en
`permissions: {}` y el job sube a `contents: read`, lo único que pide el reutilizable.

Si un día necesitas un step propio aquí, lo que falta es un input en `_python.yml`. Se añade
allí, con una release del central. Copiar el job no es la solución.

**Comando**: copia el starter y completa los `TODO 1` y `TODO 2`:

```bash
mkdir -p .github/workflows
cp "$S/.github/workflows/ci-worker.yml" .github/workflows/
sed -i "s|<tu-org>|$org|; s|<sha-de-v1.0.0>|$v100|" .github/workflows/ci-worker.yml
```

El archivo queda así, con tu org y el SHA de tu `v1.0.0` en la línea `uses:`:

```yaml
# Copia en <tu-org>/tablero como .github/workflows/ci-worker.yml.
# CI del worker sin jobs propios: lint, tests unitarios e integración los pone el reutilizable
# de Python del repo central, el mismo que ya usan ci-api.yml y ci-tools.yml.
name: ci-worker
on:
  # Lo llama ci.yml cuando cambia worker/ o el esquema de la API, que el worker usa.
  workflow_call:
  workflow_dispatch:
permissions: {}
jobs:
  worker:
    name: Worker
    uses: <tu-org>/actions-tablero/.github/workflows/_python.yml@<sha-de-v1.0.0> # v1.0.0
    with:
      working-directory: worker
      package: tablero_worker
      coverage-min: 60
      integration: true
    permissions:
      contents: read
```

`package` es el nombre del paquete importable, con guion bajo: es lo que mide `--cov`. El
proyecto se llama `tablero-worker`. Con ese nombre, la cobertura sale `Module ... was never
imported` y el job falla.

```bash
actionlint .github/workflows/ci-worker.yml && echo limpio
# limpio
```

**Verifica**: la orden de `ci-worker-reusable-only`:

```bash
yq '[(.on | keys | sort | join(",")), (.jobs | length), (.jobs[] | (has("steps"), (.uses | test("/actions-tablero/\.github/workflows/_python\.yml@[0-9a-f]{40}$")), .with."working-directory", .with.package, .with.integration))] | join(" ")' .github/workflows/ci-worker.yml
# workflow_call,workflow_dispatch 1 false true worker tablero_worker true
```

---

## Paso 3: El área `worker`

**Por qué**: `changes` decide qué áreas corren en cada PR. El worker tiene que correr si cambia
`worker/` y también si cambia `api/migrations/`. Una migración que renombra una columna rompe la
purga aunque nadie toque `worker/`. Al revés no hace falta: un cambio en el worker no altera la
API. Un cambio en `.github/` sigue corriendo todas las áreas, el worker incluido.

**Comando**: en `scripts/changed-areas.sh`, entre la línea de `tools` y la de `smoke`:

```bash
# El worker no tiene esquema propio: usa el de la API, así que sus migraciones también lo prueban.
echo "worker=$(area '^(worker/|api/migrations/)')"
```

```bash
bash -n scripts/changed-areas.sh && scripts/changed-areas.sh | grep ^worker=
# worker=true
```

Sin base, el script corre todo: es lo que verá el `workflow_dispatch` del paso 6.

**Verifica**: la orden de `changed-areas-worker`, en un repo desechable con una migración y luego
un cambio solo en `web/`:

```bash
s=$PWD/scripts/changed-areas.sh; d=$(mktemp -d)
(
  cd "$d" && export GIT_AUTHOR_NAME=ci GIT_AUTHOR_EMAIL=ci@example.invalid \
    GIT_COMMITTER_NAME=ci GIT_COMMITTER_EMAIL=ci@example.invalid
  git init -q && git commit -q --allow-empty -m base
  mkdir -p api/migrations web && touch api/migrations/002_x.sql && git add . && git commit -qm m
  a=$("$s" HEAD~1 | grep ^worker=)
  touch web/a.ts && git add . && git commit -qm w
  echo "$a $("$s" HEAD~1 | grep ^worker=)"
)
# worker=true worker=false
```

---

## Paso 4: `ci.yml` llama al worker

**Por qué**: un área que nadie lee no hace nada. Son cuatro cambios y cada uno cierra un hueco.
El **output** lleva el resultado de `changes` a los demás jobs. El **job** llama a
`ci-worker.yml` con `./`, que corre en el mismo commit que `ci.yml` y ya está fijado. La
**puerta**: si `worker` no entra en `needs` de `ci-gate`, un fallo del worker no bloquea ningún
merge. Saltado sí cuenta como bueno: un PR que solo toca `web/` no tiene por qué esperar al
worker. La **estructura**: `structure` comprueba que `worker/uv.lock` existe, como los lockfiles
de la API y del frontend.

**Comando**: en `.github/workflows/ci.yml`, el bucle del job `structure`:

```bash
          for f in api/uv.lock web/pnpm-lock.yaml worker/uv.lock compose.yaml; do
```

En `outputs` del job `changes`, después de `tools`:

```yaml
      worker: ${{ steps.diff.outputs.worker }}
```

El job nuevo, después de `tools`:

```yaml
  worker:
    needs: changes
    if: needs.changes.outputs.worker == 'true'
    uses: ./.github/workflows/ci-worker.yml # zizmor: ignore[self-repository]
    permissions:
      contents: read
```

Y en `ci-gate`:

```yaml
    needs: [structure, version, sql, changes, api, web, tools, worker, smoke, workflows]
```

```bash
actionlint && GH_TOKEN=$(gh auth token) zizmor -q .github/ && echo limpio
# No findings to report. Good job! (...)
# limpio
```

**Verifica**: la orden de `ci-calls-worker`:

```bash
yq '"output=" + (.jobs.changes.outputs | has("worker") | tostring) + " uses=" + .jobs.worker.uses + " if=" + .jobs.worker.if + " gate=" + (.jobs."ci-gate".needs | contains(["worker"]) | tostring)' .github/workflows/ci.yml
# output=true uses=./.github/workflows/ci-worker.yml if=needs.changes.outputs.worker == 'true' gate=true
```

---

## Paso 5: Dependabot para el `uv.lock` del worker

**Por qué**: un lockfile que nadie actualiza se queda con las vulnerabilidades que sus
dependencias ya arreglaron. El ecosistema `uv` de Dependabot vigila desde la Semana 12 los
lockfiles de `/api` y `/tools/oidc-verifier`. El worker es un directorio más, con el mismo
`cooldown` de 7 días. Su Dockerfile entra en el ecosistema `docker` en la
[práctica 02](02-imagen-y-release-del-worker.md), cuando lo fijes por digest.

**Comando**: en `.github/dependabot.yml`, en la entrada `uv`:

```yaml
  - package-ecosystem: uv
    directories:
      - /api
      - /tools/oidc-verifier
      - /worker
```

**Verifica**:

```bash
yq '.updates[] | select(."package-ecosystem" == "uv") | .directories | join(",")' .github/dependabot.yml
# /api,/tools/oidc-verifier,/worker
```

---

## Paso 6: PR por la cola y un `ci` completo

**Por qué**: el PR toca `.github/`, así que su `ci` corre todas las áreas. Es la primera vez que
el worker pasa por `_python.yml` en GitHub, con PostgreSQL de verdad. El título `feat(worker):`
le dice a release-please que prepare una versión menor: la release que publicará la imagen del
worker llega en la práctica 02. Después del merge, un `ci` de `push` solo corre las áreas que
cambian. Un `workflow_dispatch` no tiene base, así que corre **todas**. Es el run que pide el
check `ci-full-run-green`, y tiene que ser sobre el **último** commit de `main`. Lo repetirás
al final de la semana, después del último merge (práctica 04, paso 4).

**Comando**:

```bash
git add .gitignore worker .github/workflows/ci-worker.yml .github/workflows/ci.yml .github/dependabot.yml scripts/changed-areas.sh
git commit -m "feat(worker): add retention worker tested by the central python reusable"
git push -u origin feat/worker
gh pr create --fill
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch --required > /dev/null && gh pr merge "$pr"
until [ "$(gh pr view "$pr" --json state --jq .state)" = MERGED ]; do sleep 15; done
git switch main && git pull --ff-only
gh workflow run ci.yml --ref main
sleep 5
run=$(gh run list --workflow ci.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo ci-completo-ok
# ci-completo-ok
```

**Verifica**: los tres jobs del worker, y la orden de `ci-full-run-green`:

```bash
gh run view "$run" --json jobs --jq '.jobs[] | select(.name | startswith("worker /")) | .name + " " + .conclusion'
# worker / Worker / Lint y formato (ruff) success
# worker / Worker / Tests unitarios success
# worker / Worker / Tests de integración (PostgreSQL 17) success
git fetch -q origin main && id=$(gh run list --workflow ci.yml --event workflow_dispatch --commit "$(git rev-parse origin/main)" --json databaseId,conclusion --jq '[.[] | select(.conclusion == "success")][0].databaseId') && gh run view "$id" --json jobs --jq '[.jobs[] | select(.name | startswith("worker /")) | .conclusion] | "\(length) \(unique | join(","))"'
# 3 success
```

Guarda el enlace: es tu primera evidencia para el documento de defensa de la
[práctica 04](04-defensa-del-pipeline.md).

```bash
gh run view "$run" --json url --jq .url | tee -a ~/code/evidencias-20.txt
# https://github.com/<tu-org>/tablero/actions/runs/<id>
```

---

## ✅ Resultado

- [ ] `worker/` en `main`, con 9 tests unitarios en verde en local
- [ ] `ci-worker.yml` con un único job, sin steps, que llama a `_python.yml` del central por SHA
- [ ] El área `worker` sale `true` con una migración y `false` con un cambio solo en `web/`
- [ ] `ci.yml` con el output, el job `worker`, `worker` en `ci-gate` y `worker/uv.lock` en `structure`
- [ ] Dependabot vigila `/worker` en el ecosistema `uv`
- [ ] Un `ci` lanzado a mano sobre `main`, con los tres jobs `worker / …` en verde

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 20
# ...
#   ✅ worker/ está en tablero con su uv.lock, su Dockerfile y sus tests unitarios y de integración
#   ✅ ci-worker.yml no tiene steps propios: su único job llama a _python.yml del repo central por SHA, con integración
#   ✅ scripts/changed-areas.sh marca worker si cambia worker/ o api/migrations/, y no si solo cambia web/
#   ✅ ci.yml llama a ci-worker.yml cuando el área worker cambia y ci-gate lo espera
# ...
```

`ci-full-run-green` también sale en verde ahora. Volverá a rojo con el siguiente merge, hasta
que lances otro `ci` completo sobre el nuevo último commit.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `ci` termina en `startup_failure` y señala a `ci-worker.yml` | Falta `workflow_call` en `on` | Paso 2, `TODO 1` |
| `Module tablero-worker was never imported` y la cobertura falla | `package` con guion en lugar de guion bajo | `package: tablero_worker` |
| `No module named tablero_worker.migrate` o tests sin encontrar | `working-directory` distinto de `worker` | Paso 2, `TODO 2` |
| La integración falla con `relation "tasks" does not exist` | No hay `api/migrations/` al lado de `worker/` | El worker lee `../api/migrations/`: no lo saques del monorepo |
| Un PR con una migración nueva no corre el worker | El patrón del área solo mira `^worker/` | Paso 3: `'^(worker/\|api/migrations/)'` |
| El worker falla y la cola deja entrar el PR | `worker` no está en `needs` de `ci-gate` | Paso 4 |
| `3 success` no sale y `id` está vacío | El último `ci` de `main` es de `push`, o de un commit anterior | `gh workflow run ci.yml --ref main` después del último merge |
| `0 ` en la verificación del paso 6 | El área `worker` salió `false` en ese run | Mira el log de `changes`: con `workflow_dispatch` todas deben salir `true` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [El examen GH-200](../1-teoria/06-el-examen-gh-200.md) | [Práctica 02 — Imagen y release del worker](02-imagen-y-release-del-worker.md) |
