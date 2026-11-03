# Práctica 03 — Secretos y outputs

> Publicar una imagen pide una credencial y devuelve un digest. En esta práctica escribes
> `_image.yml`, que declara el secreto que necesita y devuelve el digest, y conviertes `images.yml`
> en dos llamadas y un resumen que junta los dos digests.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `_image.yml`, con los inputs `component` y `push`, el secreto obligatorio `registry-password` y
  el output `digest`
- `images.yml` con los jobs `api` y `web`, que llaman con `packages: write` y el secreto explícito
- Un job `summary` que recibe los dos digests por `env:`
- `secrets: inherit` cazado por zizmor en tu máquina, y deshecho

## 📋 Antes de empezar

Terminaste la [práctica 02](02-inputs-tipados-y-matrices.md): `_python.yml` y `_node.yml` están
en `main`. El `images.yml` de la Semana 06 construye las dos imágenes con una matriz.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git switch -c ci/reusable-image
yq '.jobs.build.strategy.matrix.image | join(",")' .github/workflows/images.yml
# api,web
```

---

## Paso 1: `_image.yml` y su secreto

**Por qué**: un reutilizable no ve los secretos del llamador salvo los que declara en
`on.workflow_call.secrets` y el llamador le pasa uno a uno
([teoría 04](../1-teoria/04-secretos-en-reutilizables.md#declarar-secretos-en-el-reutilizable)).
`required: true` convierte el olvido en un error antes de ejecutar nada. El `GITHUB_TOKEN` llega
solo, pero declarar `registry-password` deja el reutilizable listo para cualquier registro. El
techo de la raíz es lo que necesita para publicar: `packages: write`.

**Comando**: crea `.github/workflows/_image.yml`: los steps de la matriz de `images.yml`, con
`inputs.component` en lugar de `matrix.image` y el login condicionado a `inputs.push`.

```yaml
# Reutilizable: construye una imagen Docker de tablero y, si se pide, la publica en GHCR.
# Solo se ejecuta cuando otro workflow lo llama.
name: _image

on:
  workflow_call:
    inputs:
      component:
        description: Carpeta con el Dockerfile; la imagen se llama tablero-<component>
        type: string
        required: true
      push:
        description: Publicar la imagen en GHCR además de construirla
        type: boolean
        default: false
    secrets:
      registry-password:
        description: Contraseña o token con permiso de escritura en GHCR
        required: true

# Techo de permisos del reutilizable: el llamador puede dar menos, nunca más.
permissions:
  contents: read
  packages: write

jobs:
  build:
    name: Imagen tablero-${{ inputs.component }}
    runs-on: ubuntu-24.04
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Calcular etiquetas y labels
        id: meta
        uses: docker/metadata-action@dc802804100637a589fabce1cb79ff13a1411302 # v6.2.0
        with:
          images: ghcr.io/${{ github.repository_owner }}/tablero-${{ inputs.component }}
          flavor: |
            latest=false
          tags: |
            type=sha
            type=ref,event=branch
            type=ref,event=pr

      - uses: docker/setup-buildx-action@f87e5991a6d7451dcb8d9637bfbc97413f497069 # v4.4.1

      - name: Iniciar sesión en GHCR
        if: ${{ inputs.push }}
        uses: docker/login-action@81c6f93d4bc991e510b342a00b419b3bb4efc5c6 # v4.7.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.registry-password }}

      - name: Construir y, si se pide, publicar
        id: build
        uses: docker/build-push-action@c3c9e263c25d99ce0380d002d59b67737d91b0dc # v7.4.0
        with:
          context: ${{ inputs.component }}
          push: ${{ inputs.push }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha,scope=${{ inputs.component }}
          cache-to: type=gha,mode=max,scope=${{ inputs.component }}
```

`github.repository_owner` y `github.actor` son los del **llamador**: el contexto `github` es suyo.

**Verifica**: la orden de `image-secret` y actionlint sobre el archivo.

```bash
yq '.on.workflow_call.secrets["registry-password"].required' .github/workflows/_image.yml
# true
actionlint .github/workflows/_image.yml && echo "actionlint ok"
# actionlint ok
```

---

## Paso 2: El digest, en tres saltos

**Por qué**: `build-push-action` deja el digest como output del step `build`. Para que llegue al
llamador hace falta subirlo dos veces más: del step al job y del job al workflow
([teoría 03](../1-teoria/03-inputs-y-outputs.md#devolver-outputs)). Es el dato que la matriz de
la Semana 06 no podía devolver con nombre: los outputs de una matriz se pisan entre sí y queda el
del último job que termina ([teoría 03](../1-teoria/03-inputs-y-outputs.md#por-qué-images-no-usa-una-matriz-de-llamadas)).
Con una llamada por imagen, cada digest vuelve por su job.

**Comando**: en `on.workflow_call`, debajo de `secrets:` y a su misma altura:

```yaml
    outputs:
      digest:
        description: Digest de la imagen construida
        value: ${{ jobs.build.outputs.digest }}
```

Y en el job `build`, debajo de `timeout-minutes: 30`:

```yaml
    outputs:
      digest: ${{ steps.build.outputs.digest }}
```

**Verifica**: la orden de `image-digest-output`, el salto del job y actionlint.

```bash
yq '.on.workflow_call.outputs.digest.value' .github/workflows/_image.yml
# ${{ jobs.build.outputs.digest }}
yq '.jobs.build.outputs.digest' .github/workflows/_image.yml
# ${{ steps.build.outputs.digest }}
actionlint .github/workflows/_image.yml && echo "actionlint ok"
# actionlint ok
```

---

## Paso 3: `images.yml`, dos llamadas

**Por qué**: el llamador decide tres cosas. **Cuándo publicar**: `push` es `true` en `main` y
`false` en un PR. **Con qué credencial**: el secreto va por su nombre y el reutilizable no recibe
ningún otro. **Con qué permiso**: solo los jobs que llaman conceden `packages: write`; un
reutilizable solo puede mantener o bajar lo que recibe
([teoría 05](../1-teoria/05-contexto-permisos-y-concurrencia.md#permisos-que-solo-bajan)). Los
permisos de un job sustituyen a los de la raíz: por eso `contents: read` se repite.

**Comando**: en `images.yml` deja `name`, `on`, `concurrency` y `permissions`, y sustituye todo
`jobs:` (la matriz y su step de resumen) por esto:

```yaml
jobs:
  api:
    name: API
    # El reutilizable pide packages: write; si este job no lo concede, el run no arranca.
    permissions:
      contents: read
      packages: write
    uses: ./.github/workflows/_image.yml # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
    with:
      component: api
      push: ${{ github.event_name != 'pull_request' }}
    secrets:
      registry-password: ${{ secrets.GITHUB_TOKEN }}

  web:
    name: Web
    permissions:
      contents: read
      packages: write
    uses: ./.github/workflows/_image.yml # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
    with:
      component: web
      push: ${{ github.event_name != 'pull_request' }}
    secrets:
      registry-password: ${{ secrets.GITHUB_TOKEN }}
```

**Verifica**: las órdenes de `images-calls-image` e `images-permissions`, y actionlint sin los
`secrets:`, que es lo que `required: true` compra (en macOS, `sed -i ''`).

```bash
yq '[.jobs.api, .jobs.web] | map((.uses // "") + "|" + (.with.component // "") + "|" + (.secrets["registry-password"] // "")) | join(",")' .github/workflows/images.yml
# ./.github/workflows/_image.yml|api|${{ secrets.GITHUB_TOKEN }},./.github/workflows/_image.yml|web|${{ secrets.GITHUB_TOKEN }}
yq '[(.permissions | to_entries | map(.key + ":" + .value) | join(";")), .jobs.api.permissions.packages, .jobs.web.permissions.packages] | join(",")' .github/workflows/images.yml
# contents:read,write,write
cp .github/workflows/images.yml /tmp/images.yml
sed -i '/^    secrets:$/,+1d' .github/workflows/images.yml
actionlint 2>&1 | grep -v '^ '
# .github/workflows/images.yml:34:11: secret "registry-password" is required by "./.github/workflows/_image.yml" reusable workflow [workflow-call]
# .github/workflows/images.yml:44:11: secret "registry-password" is required by "./.github/workflows/_image.yml" reusable workflow [workflow-call]
mv /tmp/images.yml .github/workflows/images.yml && actionlint && echo "actionlint ok"
# actionlint ok
```

---

## Paso 4: Los dos digests en un resumen

**Por qué**: `summary` es un job normal del llamador: con `needs: [api, web]` espera a las dos
llamadas y lee `needs.api.outputs.digest`. Los digests llegan al shell por `env:` (regla 4).
`PUSHED` repite la expresión del input `push`. No publica: se queda en el `contents: read` de la raíz.

**Comando**: añade el job al final de `images.yml`.

```yaml
  summary:
    name: Digests
    needs: [api, web]
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - name: Digests en el resumen
        env:
          OWNER: ${{ github.repository_owner }}
          API_DIGEST: ${{ needs.api.outputs.digest }}
          WEB_DIGEST: ${{ needs.web.outputs.digest }}
          PUSHED: ${{ github.event_name != 'pull_request' }}
        run: |
          {
            echo "| Imagen | Digest |"
            echo "|---|---|"
            echo "| tablero-api | \`$API_DIGEST\` |"
            echo "| tablero-web | \`$WEB_DIGEST\` |"
            echo
            echo "Publicadas: $PUSHED"
            if [[ "$PUSHED" == "true" ]]; then
              echo
              echo "\`docker pull ghcr.io/${OWNER,,}/tablero-api@$API_DIGEST\`"
            fi
          } >> "$GITHUB_STEP_SUMMARY"
```

`${OWNER,,}` pasa el dueño a minúsculas: GHCR no acepta mayúsculas en el nombre de la imagen.

**Verifica**: la orden de `images-digests-summary` y actionlint.

```bash
yq '(.jobs.summary.needs | sort | join(",")) + " " + ([.jobs.summary.steps[].env // {} | .[]] | join(" "))' .github/workflows/images.yml
# api,web ${{ github.repository_owner }} ${{ needs.api.outputs.digest }} ${{ needs.web.outputs.digest }} ${{ github.event_name != 'pull_request' }}
actionlint && echo "actionlint ok"
# actionlint ok
```

---

## Paso 5: `secrets: inherit`, cazado en local

**Por qué**: `secrets: inherit` pasa **todos** los secretos del repo y de la organización al
reutilizable, los use o no ([teoría 04](../1-teoria/04-secretos-en-reutilizables.md#secrets-inherit)).
Es cómodo y actionlint lo da por bueno; zizmor no. Ninguno de tus workflows lo usa
(`no-secrets-inherit`), pero conviene ver el aviso una vez para reconocerlo en un PR ajeno.

**Comando**: con una copia delante; `yq -i` reescribe el archivo y quita las líneas en blanco,
así que se vuelve a la copia, no se edita a mano.

```bash
cp .github/workflows/images.yml /tmp/images.yml
yq -i '.jobs.api.secrets = "inherit"' .github/workflows/images.yml
actionlint && echo "actionlint ok"
# actionlint ok
zizmor --offline .github/workflows/images.yml 2>&1 | grep -E '^warning|-->'
# warning[secrets-inherit]: secrets unconditionally inherited by called workflow
#   --> .github/workflows/images.yml:30:11
mv /tmp/images.yml .github/workflows/images.yml
```

Es un hallazgo `medium`: zizmor sale con código 13 y `lint-workflows` pondría el PR en rojo.

**Verifica**: el archivo vuelve a estar limpio para los dos linters.

```bash
grep -c 'inherit' .github/workflows/images.yml
# 0
actionlint && zizmor --offline -q .github/workflows/ && echo "linters ok"
# No findings to report. Good job! (4 ignored, 6 suppressed)
# linters ok
```

---

## Paso 6: PR, `main` y los digests

**Por qué**: en el PR, `push` vale `false`: se construyen las dos imágenes sin publicarlas y el
resumen dice `Publicadas: false`. En `main`, `push` es `true` y el resumen lista los dos digests
publicados. El PR dispara `images` porque toca `images.yml`.

**Comando**:

```bash
git add .github/workflows/_image.yml .github/workflows/images.yml
git commit -m "ci(images): extract image build into reusable workflow"
git push -u origin ci/reusable-image
gh pr create --fill
sleep 10
id=$(gh run list --workflow images.yml --branch ci/reusable-image --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
gh run view "$id" --json jobs --jq '.jobs[].name' | sort
# API / Imagen tablero-api
# Digests
# Web / Imagen tablero-web
```

**Verifica**: en `main`, `images` publica y termina en verde sobre tu commit. El resumen con los
dos digests está en la página del run, abajo.

```bash
gh pr merge --squash --delete-branch
git switch main && git pull --ff-only
sleep 10
id=$(gh run list --workflow images.yml --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
```

---

## ✅ Resultado

- [ ] `_image.yml` declara `component`, `push`, el secreto obligatorio `registry-password` y el
  output `digest`
- [ ] `images.yml` llama dos veces, con `packages: write` solo en `api` y `web`
- [ ] `summary` recibe los dos digests por `env:` y los deja en el resumen
- [ ] Viste el aviso `secrets-inherit` de zizmor y el archivo volvió a estar limpio
- [ ] `images` está en verde sobre el último commit de `main`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 09
# ✅ _image.yml declara el secreto registry-password como obligatorio
# ✅ _image.yml devuelve el digest de la imagen como output digest, sacado del job build
# ✅ images.yml llama a _image.yml desde dos jobs, api y web, y les pasa registry-password de forma explícita
# ✅ En images.yml solo los jobs api y web conceden packages: write; la raíz se queda en contents: read
# ✅ El job summary de images.yml espera a api y web y recibe sus digests por env:
# ...
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `secret "registry-password" is required by ...` | El job que llama no tiene `secrets:` | Paso 3: `registry-password: ${{ secrets.GITHUB_TOKEN }}` |
| `input "image" is not defined in ...` | El `with:` usa `image` | El input se llama `component` |
| `images` falla sin crear jobs | El job que llama no concede `packages: write` | Paso 3: `permissions` en `api` y en `web` |
| `docker/login-action` falla con usuario o contraseña vacíos | El secreto no llega al reutilizable | Declarado en `_image.yml` y pasado por nombre en `images.yml` |
| El resumen enseña los digests vacíos | Falta un salto del output: step → job → workflow | Paso 2: los dos bloques `outputs:` |
| `warning[secrets-inherit]` en `lint-workflows` | Alguien pasó `secrets: inherit` | Declara y pasa cada secreto por su nombre |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Inputs tipados y matrices](02-inputs-tipados-y-matrices.md) | [Límites y depuración](04-limites-y-depuracion.md) |
