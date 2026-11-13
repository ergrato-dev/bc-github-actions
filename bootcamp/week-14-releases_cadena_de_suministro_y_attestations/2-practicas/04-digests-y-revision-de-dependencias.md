# Práctica 04 — Digests y revisión de dependencias

> Firmar lo que publicas sirve de poco si lo que entra por debajo cambia sin que nadie lo decida.
> Fijas por digest las bases y el PostgreSQL de servicio, Dependabot las mantiene al día, el
> dependency graph aprende lo que no sabe leer y un PR con una dependencia vulnerable queda rojo.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `FROM` y `COPY --from` de `api/` y `web/` fijados por tag y digest
- El PostgreSQL de `deploy-gate.yml` fijado igual, y Dependabot vigilando el ecosistema `docker`
- `dependency-review.yml`: snapshot de syft y un PR con `lodash@4.17.20` frenado
- actionlint y zizmor limpios con todo lo de la semana

## 📋 Antes de empezar

Terminaste la [práctica 03](03-sbom-y-attestations.md) y leíste la
[teoría 02](../1-teoria/02-tags-digests-e-imagenes-versionadas.md) y la [07](../1-teoria/07-dependency-graph-y-dependency-review.md).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
gh run list --workflow deploy-gate.yml --status waiting --json databaseId --jq '.[].databaseId' |
  xargs -r -n1 gh run cancel
```

---

## Paso 1: Las bases de los Dockerfiles, por digest

**Por qué**: Docker Hub puede apuntar mañana `python:3.15.2-slim-trixie` a otra imagen; el
digest es el hash del contenido y no se mueve. Escribes los dos, `tag@sha256:...`: el tag para
las personas y para Dependabot, el digest para la máquina, que ignora el tag si hay digest. Va el
digest del **índice** multiarquitectura. La imagen de `uv` del `COPY --from` también es una base.

**Comando**: saca los digests de hoy:

```bash
digest() { docker buildx imagetools inspect "$1" --format '{{json .Manifest}}' | jq -r .digest; }
for i in python:3.15.2-slim-trixie ghcr.io/astral-sh/uv:0.13.6 node:26.13.0-trixie-slim \
         nginxinc/nginx-unprivileged:1.31.7-alpine postgres:17.11-alpine; do
  echo "$i@$(digest "$i")"
done
# python:3.15.2-slim-trixie@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928
# ghcr.io/astral-sh/uv:0.13.6@sha256:af22a52f5eafef3d78e551599d405c02df61919d18028f0cea8eda93bc9986d0
# node:26.13.0-trixie-slim@sha256:5adad64f9a1fca2d51972caa65983634c8a774eb300d72b20f7f2a0f60368072
# nginxinc/nginx-unprivileged:1.31.7-alpine@sha256:b5047b9b76845eac124358373c6852377c52e4b05834a47647e955dd91cb8f1e
# postgres:17.11-alpine@sha256:e5d2edd28b1f8d40a0a6c0c9cdc545b19b56a0d5d88f94bc11a97d970d4700d0
```

Son los del 2026-11-13; si el tag se reconstruyó, te saldrán otros: **usa siempre los tuyos**.

Añade `@sha256:...` detrás del tag en las dos líneas `FROM` y en el `COPY --from` de `uv` de
`api/Dockerfile`, y en las dos `FROM` de `web/Dockerfile`. Cada una queda así:

```dockerfile
COPY --from=ghcr.io/astral-sh/uv:0.13.6@sha256:af22a52f5eafef3d78e551599d405c02df61919d18028f0cea8eda93bc9986d0 /uv /usr/local/bin/uv
```

El `COPY --from=build` no se toca: `build` es una etapa del propio Dockerfile, no una imagen.

**Verifica**: las dos imágenes construyen y la orden de `base-images-by-digest` no encuentra
ninguna línea sin digest:

```bash
docker build -q -t tablero-api:local api > /dev/null && docker build -q -t tablero-web:local web > /dev/null && echo construyen
# construyen
grep -hE '^(FROM |COPY --from=[^ ]*[:/])' api/Dockerfile web/Dockerfile | grep -vE '^(FROM |COPY --from=)[^ ]+:[^ @]+@sha256:[0-9a-f]{64}( |$)' | wc -l
# 0
```

---

## Paso 2: El PostgreSQL de servicio, por digest

**Por qué**: el `services:` de `deploy-gate.yml` es la base contra la que ensayas el despliegue;
si cambia sola, un ensayo verde de hoy no dice nada de mañana. Dependabot no vigila los
`services:` de los workflows de `tablero`: este digest lo subes tú, con la función `digest` del
paso 1. Fijar también el PostgreSQL del `_python.yml` central es una mejora opcional.

**Comando**: en `.github/workflows/deploy-gate.yml`, en los dos jobs (`staging` y `production`):

```yaml
    services:
      postgres:
        image: postgres:17.11-alpine@sha256:e5d2edd28b1f8d40a0a6c0c9cdc545b19b56a0d5d88f94bc11a97d970d4700d0
```

**Verifica**: la orden de `services-by-digest`:

```bash
yq -N '.jobs[].services[]?.image' .github/workflows/*.yml | grep -vE '^[^ ]+:[^ @]+@sha256:[0-9a-f]{64}$' | wc -l
# 0
```

---

## Paso 3: Dependabot para el ecosistema `docker`

**Por qué**: un digest fijado es una foto; si nadie la renueva, tu base acumula las CVE que el
publicador ya arregló. El ecosistema `docker` de Dependabot lee las líneas `FROM` y abre un PR
cuando el tag apunta a un digest nuevo o sale una versión nueva, con 7 días de `cooldown` como
el resto desde la Semana 12. Es el PR que te dirá cuándo quitar el parche de `brotli-libs`.

**Comando**: en `.github/dependabot.yml`, al final de `updates:`:

```yaml
  # Mueve el digest de las líneas FROM cuando la imagen base publica uno nuevo bajo el mismo tag.
  - package-ecosystem: docker
    directories:
      - /api
      - /web
    schedule:
      interval: weekly
    cooldown:
      default-days: 7
```

El commit es un `build:`, que no abre release. El push dispara `deploy-gate` con el PostgreSQL
fijado: lo apruebas como en la Semana 13.

```bash
actionlint
git add api/Dockerfile web/Dockerfile .github/workflows/deploy-gate.yml .github/dependabot.yml
git commit -m "build: pin base images and postgres service by digest"
git push
sleep 5
run=$(gh run list --workflow deploy-gate.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
pending="repos/{owner}/{repo}/actions/runs/$run/pending_deployments"
until [ "$(gh api "$pending" --jq length)" -gt 0 ]; do sleep 10; done
env_id=$(gh api "$pending" --jq '.[0].environment.id')
gh api -X POST "$pending" -F "environment_ids[]=$env_id" \
  -f state=approved -f comment='PostgreSQL fijado por digest' > /dev/null
gh run watch "$run" --exit-status > /dev/null && echo deploy-gate ok
# deploy-gate ok
```

**Verifica**: la orden de `dependabot-docker`:

```bash
yq '.updates[] | select(."package-ecosystem" == "docker") | (.directories // [.directory] | sort | join(",")) + " cooldown=" + (.cooldown."default-days" // 0 | tostring)' .github/dependabot.yml
# /api,/web cooldown=7
```

---

## Paso 4: El snapshot de syft para el dependency graph

**Por qué**: dependency review solo sabe lo que sabe el dependency graph, y el grafo no lee
`uv.lock` ni el `pnpm-lock.yaml` de dos documentos de pnpm 11+: un PR que mete una librería
vulnerable en la API o en la web pasaría sin aviso. Con la API de dependency submission le
envías tú lo que falta: syft cataloga los dos `uv.lock` y el `pnpm-lock.yaml` en el formato de
GitHub, con `sha`, `ref` y `job` vacíos que rellena `jq`. En un PR, el snapshot va al commit de
**cabeza**, el que compara dependency review. Enviarlo exige `contents: write`; el token de un PR
desde un fork es de solo lectura, y en ese caso el job se salta.

**Comando**: escribe a mano `.github/workflows/dependency-review.yml`:

```yaml
# Revisión de dependencias: el dependency graph de GitHub no lee uv.lock ni el pnpm-lock.yaml de
# dos documentos de pnpm 11+, así que syft se los lee y envía el resultado como snapshot. En un PR,
# dependency-review compara los snapshots de la base y de la cabeza y falla si entra una
# dependencia con un aviso grave.
name: dependency-review
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
permissions: {}
jobs:
  snapshot:
    name: Snapshot de dependencias
    # El token de un PR desde un fork es de solo lectura: el envío fallaría. Ese PR se revisa
    # solo con lo que el grafo ve por su cuenta.
    if: ${{ github.event_name == 'push' || github.event.pull_request.head.repo.full_name == github.repository }}
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    permissions:
      # La API de dependency submission exige escritura en contents.
      contents: write
    env:
      SYFT_VERSION: v1.57.0
      # En un PR el snapshot va al commit de cabeza, que es el que mira dependency-review.
      SHA: ${{ github.event.pull_request.head.sha || github.sha }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
          ref: ${{ env.SHA }}

      - name: Instalar syft desde su release, con checksum
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          file="syft_${SYFT_VERSION#v}_linux_amd64.tar.gz"
          expected=$(gh api "repos/anchore/syft/releases/tags/$SYFT_VERSION" \
            --jq ".assets[] | select(.name == \"$file\") | .digest" | sed 's/^sha256://')
          gh release download "$SYFT_VERSION" --repo anchore/syft --pattern "$file" --dir "$RUNNER_TEMP"
          echo "$expected  $RUNNER_TEMP/$file" | sha256sum -c
          tar -xzf "$RUNNER_TEMP/$file" -C "$RUNNER_TEMP" syft
          echo "$RUNNER_TEMP" >> "$GITHUB_PATH"

      - name: Enviar el snapshot al dependency graph
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          syft scan dir:. -q -o "github-json=$RUNNER_TEMP/snapshot.json"
          jq --arg sha "$SHA" --arg ref "$GITHUB_REF" \
             --arg correlator "${GITHUB_WORKFLOW}_${GITHUB_JOB}" --arg id "$GITHUB_RUN_ID" \
             '.sha = $sha | .ref = $ref | .job = {correlator: $correlator, id: $id}' \
             "$RUNNER_TEMP/snapshot.json" |
            gh api "repos/$GITHUB_REPOSITORY/dependency-graph/snapshots" --input - --jq .message
```

El `correlator` identifica a este job: un snapshot nuevo con el mismo correlator sustituye al
anterior en vez de sumarse.

Antes del push apuntas cuántos paquetes ve hoy el grafo, en `before`:

```bash
before=$(gh api 'repos/{owner}/{repo}/dependency-graph/sbom' --jq '.sbom.packages | length')
actionlint
git add .github/workflows/dependency-review.yml
git commit -m "ci: submit syft dependency snapshot"
git push
sleep 5
run=$(gh run list --workflow dependency-review.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo snapshot ok
# snapshot ok
```

**Verifica**: el grafo ve ahora más paquetes que antes (procesar el snapshot tarda unos
segundos), y la orden de `dependency-snapshot`:

```bash
sleep 30; after=$(gh api 'repos/{owner}/{repo}/dependency-graph/sbom' --jq '.sbom.packages | length')
[ "$after" -gt "$before" ] && echo el grafo ve más
# el grafo ve más
yq '.jobs[] | select([.steps[]?.run // ""] | join(" ") | test("syft scan .*github-json")) | select([.steps[]?.run // ""] | join(" ") | test("dependency-graph/snapshots")) | "contents=" + .permissions.contents' .github/workflows/dependency-review.yml
# contents=write
```

---

## Paso 5: La revisión en cada PR, y un PR que tiene que quedar rojo

**Por qué**: con los snapshots de la base y de la cabeza, `dependency-review-action` sabe qué
dependencias añade un PR y qué avisos tienen; `fail-on-severity: high` rompe con `high` o
`critical`. El job solo lee. Necesita a `snapshot`, pero corre aunque se salte (PR desde un
fork): por eso el `if:` empieza por `!cancelled()`. Y como el snapshot tarda unos segundos en
procesarse, `retry-on-snapshot-warnings` espera en vez de comparar a medias.

**Comando**: en `dependency-review.yml`, debajo del job `snapshot`:

```yaml
  review:
    name: Revisión de dependencias
    needs: snapshot
    # Corre aunque snapshot se salte (PR desde un fork); no si se canceló el run.
    if: ${{ !cancelled() && github.event_name == 'pull_request' }}
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    permissions:
      contents: read
    steps:
      - name: Comparar dependencias entre base y cabeza
        uses: actions/dependency-review-action@a1d282b36b6f3519aa1f3fc636f609c47dddb294 # v5.0.0
        with:
          fail-on-severity: high
          # El snapshot llega por la API unos segundos después: espera en vez de comparar a medias.
          retry-on-snapshot-warnings: true
```

Lo subes a `main` y abres el PR de prueba. `lodash@4.17.20` tiene dos avisos `high`:
GHSA-35jh-r3h4-6jhm (inyección de comandos) y GHSA-r5fr-rjxr-66jc (inyección de código vía
`_.template`). El `gh api /advisories` lo comprueba antes de usarlo:

```bash
actionlint
git commit -am "ci: review dependencies on pull requests"
git push
gh api '/advisories?ecosystem=npm&affects=lodash@4.17.20' --jq '.[] | select(.severity == "high") | .ghsa_id' | sort
# GHSA-35jh-r3h4-6jhm
# GHSA-r5fr-rjxr-66jc
git switch -c test/vulnerable-lodash
(cd web && pnpm add lodash@4.17.20)
git commit -am "test: add vulnerable lodash to try dependency review"
git push -u origin test/vulnerable-lodash
gh pr create --base main --title "test: vulnerable lodash" --body "PR de prueba de la práctica 04: se cierra sin fusionar."
pr=$(gh pr view --json number --jq .number)
sleep 5
run=$(gh run list --workflow dependency-review.yml --branch test/vulnerable-lodash --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null || echo revision en rojo
# revision en rojo
```

**Verifica**: qué check falló, por qué avisos, y la orden de `dependency-review-gate`:

```bash
gh pr checks "$pr" --json name,bucket --jq '.[] | select(.name | test("dependencias")) | .name + " " + .bucket' | sort
# Revisión de dependencias fail
# Snapshot de dependencias pass
gh run view "$run" --log-failed | grep -oE 'GHSA-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}' | sort -u
# GHSA-35jh-r3h4-6jhm
# GHSA-r5fr-rjxr-66jc
yq '"pr=" + (.on.pull_request.branches | join(",")) + " " + (.jobs[] | select([.steps[]?.uses // ""] | join(" ") | test("actions/dependency-review-action@[0-9a-f]{40}")) | "contents=" + .permissions.contents + " severity=" + (.steps[] | select(.uses // "" | test("dependency-review-action")) | .with."fail-on-severity"))' .github/workflows/dependency-review.yml
# pr=main contents=read severity=high
```

> ⚠️ **Vas a cerrar el PR y borrar la rama `test/vulnerable-lodash`, en GitHub y en local.** No
> hay nada que conservar: `git log --oneline main..test/vulnerable-lodash` muestra un solo commit.

```bash
git switch main
gh pr close "$pr" --delete-branch
git branch -D test/vulnerable-lodash 2>/dev/null; git pull --ff-only
gh pr view "$pr" --json state --jq .state
# CLOSED
git ls-remote --heads origin test/vulnerable-lodash | wc -l
# 0
```

---

## Paso 6: actionlint y zizmor sobre toda la semana

**Por qué**: esta semana añadió dos workflows con permisos de escritura y herramientas que se
descargan en el runner. zizmor online comprueba, entre otras cosas, que cada SHA fijado sea del
repo que dice, y `dependabot-cooldown`, que el ecosistema nuevo espera sus 7 días.

**Comando**:

```bash
actionlint && GH_TOKEN=$(gh auth token) zizmor -q .github/ && echo limpio
# limpio
```

**Verifica**: `release.yml` sigue en verde sobre el último commit de `main` (la orden de
`release-published`):

```bash
git fetch -q origin main && sha=$(git rev-parse origin/main) && printf 'tag=%s release=%s\n' "$(gh release view --json tagName --jq .tagName)" "$(gh run list --workflow release.yml --commit "$sha" --json conclusion --jq '.[0].conclusion')"
# tag=v0.4.0 release=success
```

---

## ✅ Resultado

- [ ] Bases de `api/` y `web/`, imagen de `uv` y PostgreSQL de `deploy-gate` fijados por tag y digest
- [ ] Dependabot vigila `docker` en `/api` y `/web` con 7 días de cooldown
- [ ] `dependency-review.yml` envía el snapshot de syft y el grafo ve las dependencias de uv y pnpm
- [ ] Un PR con `lodash@4.17.20` quedó en rojo y está cerrado sin rama; actionlint y zizmor limpios

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 14
# ...
# 18/18 comprobaciones superadas.
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El paso 4 no muestra más paquetes | El grafo aún no procesó el snapshot | Espera un minuto y repite el `gh api` |
| `Resource not accessible by integration` al enviar el snapshot | El job `snapshot` no tiene `contents: write`, o el PR viene de un fork | Paso 4; en un fork el `if:` lo salta |
| `dependency-review` pasa en verde con `lodash@4.17.20` | El PR no salió de `main` actualizado y la base no tiene snapshot, o el lockfile no cambió | `git switch main && git pull` antes de crear la rama; comprueba `git diff main -- web/pnpm-lock.yaml` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [SBOM y attestations](03-sbom-y-attestations.md) | [Proyecto: capa 14 de tablero](../3-proyecto/README.md) |
