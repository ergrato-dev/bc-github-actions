# Práctica 03 — Auditoría completa

> actionlint valida la sintaxis y zizmor busca vulnerabilidades, pero ninguno de los dos exige
> las reglas que llevas veinte semanas aplicando. Aquí las escribes como política, la pasas por
> `tablero` y por el repo central, corriges el central en una v1.1.0 y la dejas en el CI.

**Tiempo estimado**: 1.5 h

## 🎯 Qué vas a conseguir

- `scripts/audit-workflows.sh` completo (`TODO 3` a `TODO 7`), probado contra un repo roto
- `tablero` sin hallazgos y los 3 hallazgos reales de `actions-tablero` v1.0.0
- `actions-tablero` v1.1.0 inmutable y sin hallazgos, con todo `tablero` apuntando a su commit
- El job `policy` en `lint-workflows.yml`, y zizmor online y los ajustes auditados

## 📋 Antes de empezar

Terminaste la [práctica 02](02-imagen-y-release-del-worker.md), leíste la [teoría 03](../1-teoria/03-auditar-un-pipeline.md)
y tienes los dos repos clonados uno junto al otro en `~/code`:

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
org=${GH_REPO%%/*}
S=~/code/bc-github-actions/bootcamp/week-20-capstone/3-proyecto/starter
git -C ../actions-tablero fetch -q --tags && git -C ../actions-tablero switch -q --detach v1.0.0
v100=$(gh api "repos/$org/actions-tablero/commits/v1.0.0" --jq .sha)
test "$(git -C ../actions-tablero rev-parse HEAD)" = "$v100" && echo "central en v1.0.0"
# central en v1.0.0
```

El central queda en v1.0.0 y no en `main`: auditas lo que ejecuta `tablero`.

---

## Paso 1: Por qué una política propia

**Por qué**: actionlint comprueba que el YAML es un workflow válido. zizmor busca patrones
explotables: inyección, credenciales persistidas, `uses:` sin fijar. `ubuntu-24.04` en lugar de
`-latest`, `timeout-minutes` en todo job e imágenes por digest son decisiones de `tablero`, no
vulnerabilidades. Un workflow puede romperlas todas y salir limpio de las dos herramientas.

**Comando**: un workflow con tres reglas de `tablero` rotas (sin timeout, `-latest`, sin digest):

```bash
d=$(mktemp -d) && mkdir -p "$d/.github/workflows" && git -C "$d" init -q
cat > "$d/.github/workflows/demo.yml" <<'EOF'
on: push
permissions:
  contents: read
jobs:
  build:
    runs-on: ubuntu-latest # antipatron: etiqueta que cambia de imagen
    container: node:26.13.0-trixie-slim
    steps:
      - run: node --version
EOF
```

**Verifica**: las tres están rotas, y ninguna de las dos herramientas lo detecta:

```bash
(cd "$d" && actionlint && echo "actionlint limpio" && zizmor --offline -q .github/)
# actionlint limpio
# No findings to report. Good job! (3 suppressed)
yq '.jobs.build | [has("timeout-minutes"), (."runs-on" | test("-latest$")), (.container | test("@sha256:"))] | join(" ")' "$d/.github/workflows/demo.yml"
# false true false
```

---

## Paso 2: `audit-workflows.sh`

**Por qué**: cada regla es una consulta de yq sobre cada workflow, más un recorrido de las líneas
`FROM` y `COPY --from` de cada Dockerfile. El starter trae el formato, el contador, el código de
salida y las reglas `permissions-root` y `write-all`. `runs-on` puede ser texto o lista. En el
TODO 6, las tres fuentes de imagen van entre paréntesis: en yq, `,` cede ante `|`.

**Comando**: `git switch -c ci/audit-policy`, copia el starter con
`cp "$S/scripts/audit-workflows.sh" scripts/` y completa. **TODO 3** y **TODO 4**, en lugar de
sus comentarios:

```bash
  # Un job que llama a un reutilizable no tiene runs-on: su timeout lo pone el reutilizable.
  while read -r item; do
    [[ -n "$item" ]] && report "$f" timeout "job $item sin timeout-minutes"
  done < <(yq -r '.jobs | to_entries[] | select(.value."runs-on" != null and .value."timeout-minutes" == null) | .key' "$f")
  while read -r item; do
    [[ -n "$item" ]] && report "$f" runner-latest "job $item usa una etiqueta -latest"
  done < <(yq -r '.jobs | to_entries[] | select([.value."runs-on" | .. | select(tag == "!!str")] | any_c(test("-latest$"))) | .key' "$f")
```

**TODO 5** es una línea, en el bucle de `unpinned-uses`, debajo de la que salta `./` y `$/`:
`[[ "$item" =~ ^docker://.+@sha256:[0-9a-f]{64}$ || "$item" =~ @[0-9a-f]{40}$ ]] && continue`.
**TODO 6**, después de ese bucle:

```bash
  while read -r item; do
    # Una imagen calculada con una expresión no se puede auditar en estático.
    # shellcheck disable=SC2016
    [[ "$item" == *'${{'* || "$item" == *@sha256:* ]] && continue
    report "$f" image-digest "$item"
  done < <(yq -r '.jobs[] | ((.services[]? | .image), (.container | select(tag == "!!str")), (.container | select(tag == "!!map") | .image)) | select(. != null)' "$f")
```

**TODO 7**, en la rama `else` de `audit_dockerfile`, en lugar de `:`:

```bash
      # COPY --from=<etapa> es local; COPY --from=<imagen> trae código de un registro.
      image="${image#--from=}"
      [[ "$stages" == *" $image "* || "$image" == *@sha256:* ]] && continue
      report "$f" image-digest "COPY --from=$image"
```

**Verifica**: el repo roto de `audit-script`, con cada regla incumplida al menos una vez:

```bash
d=$(mktemp -d); mkdir -p "$d/.github/workflows"
printf 'on: push\njobs:\n  a:\n    runs-on: [ubuntu-latest]\n    permissions: write-all\n    container: node:26\n    steps:\n      - uses: actions/checkout@v7\n      - uses: ./local\n  b:\n    uses: o/r/.github/workflows/x.yml@main\n' > "$d/.github/workflows/bad.yml"  # antipatron: fallos a propósito
printf 'FROM python:3.15 AS build\nCOPY --from=ghcr.io/astral-sh/uv:0.13.6 /uv /uv\nFROM build\nCOPY --from=build /a /a\n' > "$d/Dockerfile"
scripts/audit-workflows.sh "$d" | sed "s|$d|\$d|"; echo "rc=${PIPESTATUS[0]}"
# $d/.github/workflows/bad.yml: permissions-root: sin permissions en la raíz
# $d/.github/workflows/bad.yml: write-all: permissions: write-all
# $d/.github/workflows/bad.yml: timeout: job a sin timeout-minutes
# ...
# $d/Dockerfile: image-digest: COPY --from=ghcr.io/astral-sh/uv:0.13.6
# 9 hallazgos
# rc=1
```

En `...`: `runner-latest`, dos `unpinned-uses` y dos `image-digest` más. No salen, y no deben
salir: `./local`, `FROM build` y `COPY --from=build`.

---

## Paso 3: La política sobre `tablero`

**Por qué**: la política describe lo que `tablero` ya cumple. Un hallazgo es una regla mal
escrita o un hueco del repo, y se arregla antes de que `policy` entre en el CI. El Dockerfile del
worker de `app/` daría 3 hallazgos, pero la práctica 02 ya lo fijó.

**Comando**:

```bash
git add scripts/audit-workflows.sh && git commit -qm "ci: add workflow and dockerfile policy audit"
```

**Verifica**: la orden de `audit-clean`:

```bash
scripts/audit-workflows.sh | tail -1
# 0 hallazgos
```

---

## Paso 4: La política sobre el repo central

**Por qué**: el código de `actions-tablero` corre dentro de los jobs de `tablero`: un service
container sin digest en `_python.yml` lo es en tu CI. La Semana 14 fijó `tablero`, no el central.

**Comando**:

```bash
scripts/audit-workflows.sh ../actions-tablero; echo "exit $?"
# ../actions-tablero/.github/workflows/_python.yml: image-digest: postgres:17.11-alpine
# ../actions-tablero/sql-lint/Dockerfile: image-digest: FROM python:3.15.2-slim-trixie
# ../actions-tablero/sql-lint/Dockerfile: image-digest: COPY --from=ghcr.io/astral-sh/uv:0.13.6
# 3 hallazgos
# exit 1
```

**Verifica**: son reales: el Dockerfile de `sql-lint` no lleva ni un digest.

```bash
grep -c '@sha256:' ../actions-tablero/sql-lint/Dockerfile
# 0
```

---

## Paso 5: Corregir el central y publicar v1.1.0

**Por qué**: lo que falla en el central se corrige en el central, con un PR y una release. Si lo
parchearas en `tablero`, el próximo repo que use `_python.yml` heredaría el problema. No cambia
ningún input, pero endurece lo que ejecutan todos los consumidores: **v1.1.0**, inmutable como la
v1.0.0 de la [Semana 11](../../week-11-actions_a_escala_de_organizacion/2-practicas/01-repo-central-y-primera-release.md),
sobre un commit en verde. Los digests son los de la práctica 02: **usa los tuyos**. `GH_REPO`
sigue en `tablero`, así que cada `gh` nombra el central con `--repo` o con la URL del PR.

**Comando**:

```bash
cd ../actions-tablero && git switch -q main && git pull -q --ff-only && git switch -c fix/pin-images-by-digest
pg=postgres:17.11-alpine@sha256:e5d2edd28b1f8d40a0a6c0c9cdc545b19b56a0d5d88f94bc11a97d970d4700d0
py=python:3.15.2-slim-trixie@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928
uv=ghcr.io/astral-sh/uv:0.13.6@sha256:af22a52f5eafef3d78e551599d405c02df61919d18028f0cea8eda93bc9986d0
sed -i "s|image: postgres:17.11-alpine$|image: $pg|" .github/workflows/_python.yml
sed -i "s|^FROM python:3.15.2-slim-trixie$|FROM $py|; s|^COPY --from=ghcr.io/astral-sh/uv:0.13.6 |COPY --from=$uv |" sql-lint/Dockerfile
../tablero/scripts/audit-workflows.sh . | tail -1
# 0 hallazgos
git commit -qam "fix: pin postgres service and sql-lint base images by digest"
git push -u origin fix/pin-images-by-digest
url=$(gh pr create --repo "$org/actions-tablero" --head fix/pin-images-by-digest --fill)
gh pr checks "$url" --watch > /dev/null && gh pr merge "$url" --squash --delete-branch
git switch main && git pull --ff-only && sha=$(git rev-parse HEAD); sleep 10
gh run watch --repo "$org/actions-tablero" "$(gh run list --repo "$org/actions-tablero" --workflow ci.yml --commit "$sha" --json databaseId --jq '.[0].databaseId')" --exit-status > /dev/null && echo central-verde
# central-verde
```

> ⚠️ **Lo que publiques ya no tiene vuelta atrás.** Después del `gh release edit`, `v1.1.0`
> queda fija en `$sha`. Si te equivocas, publicas `v1.1.1`. Revisa `gh release view` antes.

```bash
gh release create v1.1.0 --repo "$org/actions-tablero" --draft --target "$sha" --title "v1.1.0" --notes "PostgreSQL de _python.yml, base y uv de sql-lint fijados por digest. Sin cambios de inputs."
gh release view v1.1.0 --repo "$org/actions-tablero" --json tagName,isDraft,targetCommitish
gh release edit v1.1.0 --repo "$org/actions-tablero" --draft=false
```

**Verifica**: inmutable, attestation sobre el commit en verde y la orden de `central-clean`:

```bash
gh api "repos/$org/actions-tablero/releases/latest" --jq '"\(.tag_name) immutable=\(.immutable) draft=\(.draft)"'
# v1.1.0 immutable=true draft=false
gh release verify v1.1.0 --repo "$org/actions-tablero" 2>&1 | grep -q "$sha" && echo "la attestation apunta al commit en verde"
# la attestation apunta al commit en verde
cd ../tablero
d=$(mktemp -d); gh repo clone "$org/actions-tablero" "$d" -- -q --depth 1 --branch v1.1.0 && scripts/audit-workflows.sh "$d" | tail -1
# 0 hallazgos
```

---

## Paso 6: `tablero` en v1.1.0, todo a la vez

**Por qué**: una release del central no cambia nada en `tablero` hasta que mueves las
referencias. Van **todas** en un commit: `ci-api`, `ci-web` (reutilizable y dos actions),
`ci-tools`, `ci-worker`, `images` (tres jobs) y el `sql-lint` de `ci.yml`, diez líneas en seis
archivos. Dos versiones del central son dos políticas en el mismo repo. El SHA se resuelve.

**Comando**:

```bash
~/code/bc-github-actions/scripts/resolve-sha.sh "$org/actions-tablero" v1.1.0
# uses: <tu-org>/actions-tablero@<sha-de-v1.1.0> # v1.1.0
v110=$(gh api "repos/$org/actions-tablero/commits/v1.1.0" --jq .sha)
grep -rl "actions-tablero/.*@$v100" .github | xargs sed -i "s|@$v100 # v1.0.0|@$v110 # v1.1.0|"
git diff --stat | tail -1
# 6 files changed, 10 insertions(+), 10 deletions(-)
git commit -qam "ci: move every central reference to actions-tablero v1.1.0"
```

**Verifica**: la orden de `central-pinned-v1.1.0`:

```bash
have=$(grep -rhoE 'actions-tablero/[^@ ]+@[0-9a-f]{40}' .github | sed 's/.*@//' | sort -u | tr '\n' ' ')
[[ "$have" == "$v110 " ]] && echo v1.1.0 || echo "$have"
# v1.1.0
```

---

## Paso 7: La política en el CI

**Por qué**: una política que solo se pasa a mano deja de cumplirse en el tercer PR. En
`lint-workflows.yml`, que `ci.yml` llama desde el área `workflows`, un fallo de `policy` tumba
`ci-gate` y la cola no deja entrar el PR. El área también tiene que mirar el script, que vive
fuera de `.github/`: quien relaje la política pasa por el CI. yq ya viene en `ubuntu-24.04`.

**Comando**: en `.github/workflows/lint-workflows.yml`, después del job `zizmor`:

```yaml
  policy:
    name: Política de tablero
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      # yq viene en la imagen ubuntu-24.04: el script no instala nada.
      - name: Workflows y Dockerfiles contra la política
        run: scripts/audit-workflows.sh
    permissions:
      contents: read
```

En `scripts/changed-areas.sh`, la última línea pasa de `echo "workflows=$all"` a
`echo "workflows=$(area '^scripts/audit-workflows\.sh$')"`.

```bash
actionlint && git commit -qam "ci: run the policy audit in lint-workflows" && git push -u origin ci/audit-policy
gh pr create --fill
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch --required > /dev/null
gh pr checks "$pr" --json name,bucket --jq '.[] | select(.name | endswith("Política de tablero")) | "\(.name) \(.bucket)"'
# workflows / Política de tablero pass
gh pr merge "$pr"
until [ "$(gh pr view "$pr" --json state --jq .state)" = MERGED ]; do sleep 15; done
git switch main && git pull --ff-only
```

**Verifica**: la orden de `audit-in-ci`:

```bash
yq '[.jobs[].steps[]? | .run // "" | select(test("scripts/audit-workflows\.sh"))] | length' .github/workflows/lint-workflows.yml
# 1
```

---

## Paso 8: zizmor online y los ajustes, por API

**Por qué**: hay dos capas que no se ven en un archivo. zizmor online consulta GitHub y detecta
lo que el modo offline no puede ver: commits impostores, actions con vulnerabilidades conocidas o
un comentario de tag que no coincide con el SHA. Los **ajustes** no están en ningún YAML: la
política de actions de la org, el ruleset de `main`, los environments y la retención. Se leen
por API, y las respuestas, con fecha, van a la defensa de la [práctica 04](04-defensa-del-pipeline.md).

**Comando**:

```bash
GH_TOKEN=$(gh auth token) zizmor -q .github/ && (cd ../actions-tablero && GH_TOKEN=$(gh auth token) zizmor -q .)
# No findings to report. Good job! (...)
# No findings to report. Good job! (...)
{
  date +%F
  gh api 'orgs/{owner}/actions/permissions' --jq '"org actions: \(.allowed_actions) sha_pinning_required=\(.sha_pinning_required)"'
  gh api 'repos/{owner}/{repo}/rules/branches/main' --jq '"main: \([.[].type] | unique | join(","))"'
  gh api 'repos/{owner}/{repo}/environments/production' --jq '"production reviewers=\([.protection_rules[] | select(.type == "required_reviewers") | .reviewers | length] | add // 0)"'
  gh api 'repos/{owner}/{repo}/actions/permissions/artifact-and-log-retention' --jq '"retención: \(.days) días"'
} | tee ~/code/ajustes-20.txt
# <fecha>
# org actions: selected sha_pinning_required=true
# main: deletion,merge_queue,non_fast_forward,pull_request,required_status_checks
# production reviewers=1
# retención: 14 días
```

**Verifica**: la orden de `workflows-lint`, sobre `main`:

```bash
actionlint && GH_TOKEN=$(gh auth token) zizmor -q .github/ > /dev/null && echo limpio
# limpio
```

---

## ✅ Resultado

- [ ] `audit-workflows.sh` detecta las seis reglas en el repo de prueba y sale con 1
- [ ] `tablero` da `0 hallazgos`; el central v1.0.0 daba 3
- [ ] `actions-tablero` v1.1.0 inmutable y sin hallazgos, con las diez referencias de `tablero` en ella
- [ ] El job `policy` en verde en el PR que lo añadió
- [ ] zizmor online limpio en los dos repos y los ajustes en `~/code/ajustes-20.txt`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 20
# ...
#   ✅ Todas las referencias de tablero al repo central apuntan al commit de v1.1.0
# ...
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `image-digest: null` o `unpinned-uses: null` | Filtro de yq sin agrupar: `,` tiene menos precedencia que `\|` | `(a, b, c) \| select(. != null)`, como en el TODO 6 |
| `central-pinned-v1.1.0` imprime dos SHA | Quedó una referencia en v1.0.0 | `grep -rn "$v100" .github` y repite el paso 6 |
| `central-clean` da 1 hallazgo | Fijaste `sql-lint` pero no el PostgreSQL, o al revés | Corrige en el central; v1.1.0 ya es inmutable, así que publicas `v1.1.1` |
| zizmor online da `ref-version-mismatch` | El comentario `# v1.1.0` no casa con el SHA | `resolve-sha.sh` y vuelve a pegar la línea |
| Una línea de `ajustes-20.txt` no coincide | Alguien cambió un ajuste fuera de su semana | Busca qué semana lo configuró y decide: arreglo o riesgo aceptado |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Práctica 02 — Imagen y release del worker](02-imagen-y-release-del-worker.md) | [Práctica 04 — Defensa del pipeline](04-defensa-del-pipeline.md) |
