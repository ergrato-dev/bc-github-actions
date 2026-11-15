# Práctica 02 — Imagen y release del worker

> El worker ya se prueba. Ahora tiene que existir como imagen: construida en cada PR, publicada,
> escaneada y firmada en cada release, igual que la API y el frontend. En esta práctica no
> escribes cadena de suministro nueva. Fijas su Dockerfile por digest y lo añades a lo que ya
> tenías.

**Tiempo estimado**: 1.5 h

## 🎯 Qué vas a conseguir

- `worker/Dockerfile` con la base y `uv` fijadas por tag y digest
- `images.yml` construyendo `tablero-worker` con `_image.yml` del central, con su fila en el resumen
- `worker` en la matriz de `release.yml`: Trivy, SBOM y las dos attestations sin una línea nueva
- Dependabot vigilando el Dockerfile del worker
- Una release publicada con `tablero-worker:<versión>` y sus attestations verificadas

## 📋 Antes de empezar

Terminaste la [práctica 01](01-integrar-el-worker.md): el worker está en `main` y su CI pasa. Si
hace falta, repasa la [teoría 02](../1-teoria/02-integrar-un-componente-sin-escribir-ci.md),
apartado "Imagen y release". Necesitas Docker en marcha y las dos funciones de aprobación de la
Semana 17, porque la release lanza el despliegue y production espera tu visto bueno:

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
org=${GH_REPO%%/*}
approve() {
  local pending="repos/{owner}/{repo}/actions/runs/$1/pending_deployments"
  until [ "$(gh api "$pending" --jq length)" -gt 0 ]; do sleep 10; done
  gh api -X POST "$pending" -F "environment_ids[]=$(gh api "$pending" --jq '.[0].environment.id')" \
    -f state=approved -f comment="$2" > /dev/null
  gh run watch "$1" --exit-status > /dev/null && echo "deploy ok"
}
last_deploy() { gh run list --workflow deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId'; }
gh pr list --label "autorelease: pending" --json number,title --jq '.[] | "\(.number) \(.title)"'
# <n> chore(main): release <X.Y.Z>
```

El PR de release ya existe: lo abrió release-please con el `feat(worker):` de la práctica 01.
No lo fusiones todavía. Si saliera ahora, la release publicaría la API y el frontend, pero no el
worker.

---

## Paso 1: El Dockerfile del worker, por digest

**Por qué**: `app/worker/Dockerfile` llega como llegó `app/api/Dockerfile` antes de la Semana 14,
con tags y sin digest. Fijarlo es tarea tuya. Un tag como `3.15.2-slim-trixie` lo puede mover
quien publica la imagen: lo que construyes hoy y lo que construyes mañana con el mismo Dockerfile
pueden ser distintos. El digest no se mueve. Son tres líneas: las dos `FROM` y el
`COPY --from` de `uv`, que también trae código de un registro. `COPY --from=build` no se toca,
porque `build` es una etapa del propio Dockerfile. El digest es el del **índice**
multiarquitectura, como en la
[práctica 04 de la Semana 14](../../week-14-releases_cadena_de_suministro_y_attestations/2-practicas/04-digests-y-revision-de-dependencias.md).

**Comando**:

```bash
git switch -c feat/worker-image
digest() { docker buildx imagetools inspect "$1" --format '{{json .Manifest}}' | jq -r .digest; }
for i in python:3.15.2-slim-trixie ghcr.io/astral-sh/uv:0.13.6; do echo "$i@$(digest "$i")"; done
# python:3.15.2-slim-trixie@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928
# ghcr.io/astral-sh/uv:0.13.6@sha256:af22a52f5eafef3d78e551599d405c02df61919d18028f0cea8eda93bc9986d0
```

Son los del 2026-11-14; si el tag se reconstruyó, te saldrán otros: **usa siempre los tuyos**.
Deberían coincidir con los de `api/Dockerfile`. Si no coinciden, Dependabot tiene un PR
pendiente en la API. Las tres líneas quedan así:

```dockerfile
FROM python:3.15.2-slim-trixie@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928 AS build
COPY --from=ghcr.io/astral-sh/uv:0.13.6@sha256:af22a52f5eafef3d78e551599d405c02df61919d18028f0cea8eda93bc9986d0 /uv /usr/local/bin/uv
FROM python:3.15.2-slim-trixie@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928
```

**Verifica**: la imagen construye, corre como uid 10001, y la orden de `worker-base-by-digest`
no encuentra ninguna línea sin digest:

```bash
docker build -q -t tablero-worker:local worker > /dev/null && echo construye
# construye
docker image inspect tablero-worker:local --format '{{.Config.User}} {{json .Config.Cmd}}'
# 10001 ["tablero-worker"]
grep -iE '^(FROM|COPY --from=[^ ]*[/:])' worker/Dockerfile | grep -vc '@sha256:[0-9a-f]\{64\}'
# 0
```

---

## Paso 2: `images.yml` con el worker

**Por qué**: `images.yml` construye cada imagen en cada PR que toca su carpeta, sin publicarla,
y la publica en cada push a `main`. Todo eso lo hace `_image.yml` del central. El worker solo
necesita un job más, idéntico al de `web` salvo `component`, y su ruta en los dos filtros
`paths`. Sin la ruta, un PR que cambia solo `worker/` no construye la imagen y un Dockerfile roto
llega a la release sin que nadie lo haya construido. El job `summary` necesita el digest del
worker para la tabla del resumen.

**Comando**: en `.github/workflows/images.yml`, en `paths` de `push` **y** de `pull_request`:

```yaml
      - "worker/**"
```

El job nuevo, después de `web`, con la misma línea `uses:` que ya tienen `api` y `web`:

```yaml
  worker:
    name: Worker
    permissions:
      contents: read
      packages: write
    uses: <tu-org>/actions-tablero/.github/workflows/_image.yml@<sha-de-v1.0.0> # v1.0.0
    with:
      component: worker
      push: ${{ github.event_name != 'pull_request' }}
    secrets:
      registry-password: ${{ secrets.GITHUB_TOKEN }}
```

En `summary`, `needs` y el step:

```yaml
    needs: [api, web, worker]
```

```yaml
          WORKER_DIGEST: ${{ needs.worker.outputs.digest }}
```

```bash
            echo "| tablero-worker | \`$WORKER_DIGEST\` |"
```

El digest llega al shell por `env:`, como los otros dos: es un output, no lo interpoles en `run:`.
La línea del `echo` va dentro del bloque `run`, debajo de la de `tablero-web`.

**Verifica**: la orden de `images-worker`:

```bash
actionlint .github/workflows/images.yml && echo limpio
# limpio
yq '[(.on.push.paths | contains(["worker/**"])), .jobs.worker.with.component, (.jobs.worker.uses | test("/actions-tablero/\.github/workflows/_image\.yml@[0-9a-f]{40}$")), (.jobs.summary.needs | contains(["worker"]))] | join(" ")' .github/workflows/images.yml
# true worker true true
```

---

## Paso 3: El worker en la matriz de `release.yml`

**Por qué**: el job `images` de `release.yml` ya hace por componente todo lo de la Semana 14.
Construye y publica `tablero-<componente>:<versión>`, la escanea con Trivy (falla con CVE
críticas que tengan arreglo), genera el SBOM con syft y firma dos attestations, la de procedencia
y la del SBOM. Todo depende de `matrix.component`. Con una palabra más, el worker recibe la cadena
completa. `fail-fast: false` sigue importando: si Trivy para al worker, la API y el frontend se
publican igual y sabes cuál falló.

`deploy.yml` no cambia. El chart de `deploy/k8s` despliega la API y el frontend, y el worker es
un proceso que se lanza y termina. Lo correcto sería un `CronJob`, y esa decisión la anotas en la
[práctica 04](04-defensa-del-pipeline.md).

**Comando**: en `.github/workflows/release.yml`, job `images`:

```yaml
    strategy:
      fail-fast: false
      matrix:
        component: [api, web, worker]
```

**Verifica**: la orden de `release-worker`:

```bash
yq '.jobs.images.strategy.matrix.component | join(",")' .github/workflows/release.yml
# api,web,worker
```

---

## Paso 4: Dependabot para el Dockerfile del worker

**Por qué**: un digest fijado es una foto. Si nadie la renueva, tu base acumula las CVE que el
publicador ya arregló, y Trivy acabará parando la release. El ecosistema `docker` lee las líneas
`FROM` y abre un PR cuando el tag apunta a un digest nuevo. Con `uv`, de la práctica 01, el
worker queda vigilado igual que la API.

**Comando**: en `.github/dependabot.yml`, en la entrada `docker`:

```yaml
  - package-ecosystem: docker
    directories:
      - /api
      - /web
      - /worker
      - /ops/runner
```

**Verifica**: la orden de `dependabot-worker`:

```bash
yq '[.updates[] | select(."package-ecosystem" == "uv" or ."package-ecosystem" == "docker") | ."package-ecosystem" + "=" + ((.directories // [.directory]) | contains(["/worker"]) | tostring)] | join(" ")' .github/dependabot.yml
# uv=true docker=true
```

---

## Paso 5: El PR, y después la release

**Por qué**: son dos merges y el orden importa. Primero entra este PR, y en él `images` construye
`tablero-worker` sin publicarla: es la prueba de que el Dockerfile construye en un runner limpio.
Al entrar en `main`, release-please actualiza su PR con el segundo `feat(worker):`. Después
fusionas el PR de release, también por la cola, y `release.yml` publica las tres imágenes de esa
versión. Si fusionaras el PR de release antes que este, la versión saldría sin el worker y
tendrías que esperar a la siguiente.

> ⚠️ **Una release no se deshace.** El tag y las imágenes de esa versión quedan publicados. Antes
> de fusionar el PR de release, comprueba que `release.yml` de `main` ya tiene `worker` en la
> matriz: es la última línea del primer bloque de abajo.

**Comando**: el PR de la imagen:

```bash
git add worker/Dockerfile .github/workflows/images.yml .github/workflows/release.yml .github/dependabot.yml
git commit -m "feat(worker): publish, scan and sign the worker image"
git push -u origin feat/worker-image
gh pr create --fill
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch --required > /dev/null
gh pr checks "$pr" --json name,bucket --jq '.[] | select(.name | startswith("Worker / Imagen")) | "\(.name) \(.bucket)"'
# Worker / Imagen tablero-worker pass
gh pr merge "$pr"
until [ "$(gh pr view "$pr" --json state --jq .state)" = MERGED ]; do sleep 15; done
git switch main && git pull --ff-only
yq '.jobs.images.strategy.matrix.component | join(",")' .github/workflows/release.yml
# api,web,worker
```

El PR de release, cuando release-please lo haya actualizado:

```bash
sleep 60
rp=$(gh pr list --label "autorelease: pending" --json number --jq '.[0].number')
gh pr checks "$rp" --watch --required > /dev/null && gh pr merge "$rp"
until [ "$(gh pr view "$rp" --json state --jq .state)" = MERGED ]; do sleep 15; done
git pull --ff-only && sleep 10
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
# release ok
sleep 5; approve "$(last_deploy)" "Release de la capa 20"
# deploy ok
```

**Verifica**: los jobs de la release, y la versión publicada:

```bash
gh run view "$run" --json jobs --jq '.jobs[] | .name + " " + .conclusion' | sort
# Imagen tablero-api success
# Imagen tablero-web success
# Imagen tablero-worker success
# Lanzar el despliegue success
# Release PR o release success
gh release view --json tagName --jq .tagName
# v<X.Y.Z>
gh run view "$run" --json url --jq .url | tee -a ~/code/evidencias-20.txt
# https://github.com/<tu-org>/tablero/actions/runs/<id>
```

Este merge cambió el último commit de `main`. Vuelve a lanzar el `ci` completo del
[paso 6 de la práctica 01](01-integrar-el-worker.md#paso-6-pr-por-la-cola-y-un-ci-completo)
cuando termines la semana. No hace falta hacerlo ahora.

---

## Paso 6: Verificar lo que firmó `release.yml`

**Por qué**: "la imagen está firmada" no es una evidencia, es una afirmación. La evidencia es
`gh attestation verify` aceptando la imagen con las mismas restricciones que usa `deploy.yml`.
`--repo` exige que el código fuente sea de `tablero`. `--signer-workflow` exige además que la
firma la hiciera `release.yml`, y no otro workflow del repo ni un reutilizable ajeno. Se
comprueban los dos predicados: procedencia (cómo se construyó) y SBOM (qué lleva dentro). La
imagen se nombra por tag, sin la `v`, y `gh` la resuelve a su digest antes de verificar.

**Comando**:

```bash
v=$(gh release view --json tagName --jq .tagName)
img="oci://ghcr.io/${org,,}/tablero-worker:${v#v}"
for p in https://slsa.dev/provenance/v1 https://spdx.dev/Document/v2.3; do
  gh attestation verify "$img" --repo "$GH_REPO" \
    --signer-workflow "$GH_REPO/.github/workflows/release.yml" --predicate-type "$p" > /dev/null 2>&1 &&
    echo "aceptada $p" || echo "rechazada $p"
done
# aceptada https://slsa.dev/provenance/v1
# aceptada https://spdx.dev/Document/v2.3
```

**Verifica**: quién firmó, y la orden de `worker-image-attested`:

```bash
gh attestation verify "$img" --repo "$GH_REPO" --format json \
  --jq '.[0].verificationResult.signature.certificate.subjectAlternativeName'
# https://github.com/<tu-org>/tablero/.github/workflows/release.yml@refs/heads/main
for p in https://slsa.dev/provenance/v1 https://spdx.dev/Document/v2.3; do gh attestation verify "$img" --repo "$GH_REPO" --signer-workflow "$GH_REPO/.github/workflows/release.yml" --predicate-type "$p" >/dev/null 2>&1 && printf 'ok ' || printf 'mal '; done; echo
# ok ok
```

Guarda el comando en tu `docs/pipeline.md` de la práctica 04: cualquiera lo puede repetir y es
la mejor respuesta a "¿cómo sé que esta imagen la construyó tu pipeline?".

---

## ✅ Resultado

- [ ] `worker/Dockerfile` con las dos `FROM` y el `COPY --from` de `uv` por digest
- [ ] `images.yml` construye `tablero-worker` en los PR que tocan `worker/` y la publica en `main`
- [ ] `release.yml` con `component: [api, web, worker]`
- [ ] Dependabot vigila `/worker` en `uv` y en `docker`
- [ ] Una release con `Imagen tablero-worker` en verde y el despliegue aprobado
- [ ] `gh attestation verify` acepta procedencia y SBOM de `tablero-worker:<versión>`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 20
# ...
#   ✅ worker/Dockerfile trae su imagen base y uv fijadas por digest
#   ✅ images.yml construye tablero-worker con _image.yml del repo central y lo resume con los otros dos digests
#   ✅ release.yml publica, escanea y firma tablero-worker en la misma matriz que api y web
#   ✅ Dependabot vigila el uv.lock y el Dockerfile de worker/
#   ...
#   ✅ tablero-worker de la última release tiene attestations de procedencia y de SBOM firmadas por release.yml
# ...
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `worker-base-by-digest` da `1` | Te dejaste la segunda `FROM` (la de la etapa final) | Paso 1: son tres líneas, dos `FROM` y un `COPY --from` |
| El PR no tiene check `Worker / Imagen tablero-worker` | Falta `worker/**` en `paths` de `pull_request` | Paso 2: en los dos filtros, `push` y `pull_request` |
| `images` no arranca: el job pide `packages: write` | El job `worker` no declara sus `permissions` | Copia el bloque `permissions` del job `web` |
| La tabla del resumen sale con el digest del worker vacío | `WORKER_DIGEST` no está en `env` o `worker` no está en `needs` de `summary` | Paso 2 |
| La release publicó api y web, pero no el worker | El PR de release entró antes que el de este paso | Haz otro `fix(worker):` y fusiona el siguiente PR de release |
| `Imagen tablero-worker` falla en "Escanear la imagen publicada" | Trivy encontró una CVE crítica con arreglo en la base | Renueva el digest con el PR de Dependabot o con la función `digest` del paso 1 |
| `rechazada https://spdx.dev/Document/v2.3` | El job del worker falló antes del paso del SBOM | Mira el log de `Imagen tablero-worker`: sin SBOM no hay segunda attestation |
| `approve` se queda esperando | `deploy.yml` aún no ha arrancado o ya lo aprobaste en la UI | `gh run list --workflow deploy.yml --limit 1` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Práctica 01 — Integrar el worker](01-integrar-el-worker.md) | [Práctica 03 — Auditoría completa](03-auditoria-completa.md) |
