# Práctica 04 — Matriz y caché de capas

> `images.yml` ya publica la API. Esta práctica le añade la web con una matriz, hace que la segunda
> vez no se reconstruya lo que no cambió, comprueba en un PR que se construye sin publicar y deja el
> digest de cada imagen en el resumen del run. Al terminar, el archivo cumple todo el proyecto.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Una matriz `image: [api, web]` con `fail-fast: false`: dos jobs paralelos, un paquete cada uno
- Caché de capas `type=gha` con un `scope` por imagen y `mode=max`
- La diferencia medida entre un run con la caché fría y otro con la caché caliente
- Un PR de prueba en el que las dos imágenes construyen, el login se salta y nada se publica
- El digest de cada imagen en el resumen del job, llevado por `env:`
- `tablero-web` público, y `check-week.sh 06` en 17/17

## 📋 Antes de empezar

Terminaste la [práctica 03](03-publicar-en-ghcr.md): `tablero-api:main` es público y no hay
cambios pendientes:

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
o=$(gh repo view --json owner --jq '.owner.login | ascii_downcase')
gh api "/orgs/$o/packages/container/tablero-api" --jq .visibility
# public
```

---

## Paso 1: Una matriz, una imagen por entrada

**Por qué**: la API y la web se construyen igual; cambian la carpeta, el nombre del paquete y, en
el paso 2, el scope de la caché. Con `matrix.image` en esos sitios, un solo job sirve para las dos
([teoría 07](../1-teoria/07-construir-en-pr-publicar-en-main.md#una-matriz-una-imagen-por-entrada)).
Cada entrada corre en un runner distinto y en paralelo, con los permisos del job. `fail-fast:
false` evita que un fallo de la web cancele a medias la publicación de la API: cada imagen falla o
pasa por su cuenta, y el rojo se ve aislado.

**Comando**: sustituye `.github/workflows/images.yml` por esta versión. Cambian el `name:` del job,
la `strategy`, `images:` y `context:`.

```yaml
name: images

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  build:
    name: Imagen tablero-${{ matrix.image }}
    runs-on: ubuntu-24.04
    # Los permisos de un job sustituyen a los de la raíz: contents se repite.
    permissions:
      contents: read
      packages: write
    strategy:
      fail-fast: false
      matrix:
        image: [api, web]
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Calcular etiquetas y labels
        id: meta
        uses: docker/metadata-action@dc802804100637a589fabce1cb79ff13a1411302 # v6.2.0
        with:
          images: ghcr.io/${{ github.repository_owner }}/tablero-${{ matrix.image }}
          flavor: |
            latest=false
          tags: |
            type=sha
            type=ref,event=branch
            type=ref,event=pr

      - uses: docker/setup-buildx-action@f87e5991a6d7451dcb8d9637bfbc97413f497069 # v4.4.1

      - name: Iniciar sesión en GHCR
        if: ${{ github.event_name != 'pull_request' }}
        uses: docker/login-action@81c6f93d4bc991e510b342a00b419b3bb4efc5c6 # v4.7.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Construir y, fuera de los PR, publicar
        id: build
        uses: docker/build-push-action@c3c9e263c25d99ce0380d002d59b67737d91b0dc # v7.4.0
        with:
          context: ${{ matrix.image }}
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

La carpeta (`api/`, `web/`), el sufijo del paquete (`tablero-api`, `tablero-web`) y la entrada de
la matriz se llaman igual a propósito: si un día renombras una, rompes las otras dos.

**Verifica**:

```bash
actionlint .github/workflows/images.yml; echo "exit $?"
# exit 0
yq '.jobs.build.strategy.matrix.image // [] | sort | join(",")' .github/workflows/images.yml
# api,web
yq '.jobs.build.strategy.fail-fast' .github/workflows/images.yml
# false
```

No lo subas todavía: el primer push tiene que llevar ya la caché, para medirla en el paso 3.

---

## Paso 2: Caché de capas `type=gha`

**Por qué**: cada runner arranca con un builder vacío, así que sin caché cada run reconstruye todo,
`uv sync` y `pnpm install` incluidos. `cache-to: type=gha` guarda las capas en la caché de Actions
del repo y `cache-from` las recupera en el run siguiente
([teoría 06](../1-teoria/06-cache-de-capas-type-gha.md#cache-from-y-cache-to)). Dos detalles
deciden si funciona:

- **`scope=${{ matrix.image }}`**, el mismo en lectura y escritura. Sin scope, las dos entradas de
  la matriz escriben el mismo índice y cada una pisa la caché de la otra
  ([teoría 06](../1-teoria/06-cache-de-capas-type-gha.md#scope-un-índice-por-imagen)).
- **`mode=max`**. El modo por defecto solo guarda las capas de la imagen final, y en un multi-stage
  eso deja fuera la etapa `build`, que es justo donde están `uv sync` y `pnpm install`
  ([teoría 06](../1-teoria/06-cache-de-capas-type-gha.md#modemin-frente-a-modemax)).

**Comando**: añade dos líneas al final del `with:` del step `build`.

```yaml
          cache-from: type=gha,scope=${{ matrix.image }}
          cache-to: type=gha,mode=max,scope=${{ matrix.image }}
```

**Verifica**:

```bash
actionlint .github/workflows/images.yml; echo "exit $?"
# exit 0
yq '[.jobs.build.steps[] | select((.uses // "") | test("docker/build-push-action")) | .with.cache-from + " | " + .with.cache-to] | join(" ")' .github/workflows/images.yml
# type=gha,scope=${{ matrix.image }} | type=gha,mode=max,scope=${{ matrix.image }}
```

---

## Paso 3: Caché fría y caché caliente, medidas

**Por qué**: "parece más rápido" no es una medida. Comparas dos runs del **mismo commit**: el del
push, con la caché vacía, y uno lanzado a mano justo después, que encuentra lo que el primero
guardó ([teoría 06](../1-teoria/06-cache-de-capas-type-gha.md#medir-que-funciona)). El run del push
también publica por primera vez `tablero-web`: GHCR lo crea privado y enlazado, como pasó con la
API.

**Comando**: el run frío.

```bash
git add .github/workflows/images.yml
git commit -m "ci: build api and web images in a matrix with gha layer cache"
git push
sleep 5
cold=$(gh run list --workflow images.yml --commit "$(git rev-parse HEAD)" --event push --json databaseId --jq '.[0].databaseId')
gh run watch "$cold" --exit-status; echo "exit $?"
# exit 0
```

El run caliente, sobre el mismo commit:

```bash
gh workflow run images.yml --ref main && sleep 5
warm=$(gh run list --workflow images.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$warm" --exit-status; echo "exit $?"
# exit 0
for id in "$cold" "$warm"; do
  gh run view "$id" --json jobs \
    --jq '.jobs[] | "\(.name)\t\((.completedAt | fromdate) - (.startedAt | fromdate))s"'
done
# Imagen tablero-api	<segundos del frío>s
# Imagen tablero-web	<segundos del frío>s
# Imagen tablero-api	<segundos del caliente>s
# Imagen tablero-web	<segundos del caliente>s
```

Las cifras dependen del runner que te toque; la web, con `pnpm install`, es la que más baja.

**Verifica**: en el run caliente, el `uv sync` de dependencias y el `pnpm install` salen de caché.

```bash
# BuildKit puede intercalar pasos: se cuenta el "#N CACHED" del mismo número N que el RUN.
cached() {
  for job in $(gh run view "$1" --json jobs --jq '.jobs[].databaseId'); do
    gh run view --job "$job" --log | awk '
      match($0, /#[0-9]+ \[build [0-9]+\/[0-9]+\] RUN (uv sync --locked --no-dev --no-install-project|pnpm install --frozen-lockfile)$/) { split(substr($0, RSTART), a, " "); id = a[1] }
      id != "" && index($0, id " CACHED") { print; id = "" }'
  done | wc -l
}
cached "$warm"
# 2
```

Repite con `cached "$cold"`: sale `0`, porque en el primer run no había nada que leer. El
resumen de build de cada job dice lo mismo con más detalle: ábrelo con `gh run view "$warm" --web`.

---

## Paso 4: Un PR que construye y no publica

**Por qué**: en `pull_request` el login se salta y `push` vale `false`: las dos imágenes se
construyen, lo que detecta un `Dockerfile` roto antes del merge, y nada llega a GHCR
([teoría 07](../1-teoria/07-construir-en-pr-publicar-en-main.md#abrir-un-pr-y-comprobar-que-no-publica)).
La rama del PR lee la caché de `main`, así que el build es rápido, pero escribe en un ámbito propio
que `main` no ve ([teoría 06](../1-teoria/06-cache-de-capas-type-gha.md#qué-caché-ve-cada-rama)).
Un commit vacío basta: `images.yml` corre en todo PR.

**Comando**:

```bash
git switch -c test/images-pr
git commit --allow-empty -m "test: build images in a pull request"
git push -u origin test/images-pr
gh pr create --title "test: build images in a pull request" --body "Comprueba que images.yml no publica desde un PR."
sleep 10
gh pr checks --watch
```

**Verifica**:

```bash
gh pr checks --json name,bucket --jq '.[] | select(.name | startswith("Imagen")) | "\(.name) \(.bucket)"' | sort
# Imagen tablero-api pass
# Imagen tablero-web pass
pr=$(gh run list --workflow images.yml --branch test/images-pr --event pull_request --limit 1 --json databaseId --jq '.[0].databaseId')
gh run view "$pr" --json jobs \
  --jq '[.jobs[].steps[] | select(.name == "Iniciar sesión en GHCR") | .conclusion] | join(",")'
# skipped,skipped
gh api "/orgs/$o/packages/container/tablero-api/versions" \
  --jq '[.[].metadata.container.tags[] | select(startswith("pr-"))] | length'
# 0
```

> ⚠️ El cierre siguiente **borra la rama `test/images-pr`** en local y en GitHub. Solo tiene el
> commit vacío de este paso; si le añadiste algo que quieras conservar, sácalo antes con
> `git cherry-pick` en otra rama.

```bash
git switch main
gh pr close test/images-pr --delete-branch
git branch --list test/images-pr | wc -l
# 0
```

---

## Paso 5: El digest al resumen, por `env:`

**Por qué**: el output `digest` del step `build` es la referencia que no se mueve, y el resumen del
run es donde lo lee una persona ([teoría 08](../1-teoria/08-digest-y-consumo.md#al-resumen-por-env)).
Llega al shell por `env:`, como todo dato que no escribiste tú (regla 4): así es una variable, no
texto pegado dentro del script. `PUSHED` reutiliza la condición de `push` para que el resumen solo
ofrezca un `docker pull` cuando hay algo que bajar. `${IMAGE,,}` pasa el nombre a minúsculas, que
es lo que acepta el registro; `${IMAGE##*-}` se queda con lo que va tras el último guion, `api` o
`web`.

**Comando**: añade un último step al job.

```yaml
      - name: Digest en el resumen
        env:
          IMAGE: ghcr.io/${{ github.repository_owner }}/tablero-${{ matrix.image }}
          DIGEST: ${{ steps.build.outputs.digest }}
          PUSHED: ${{ github.event_name != 'pull_request' }}
        run: |
          {
            echo "### tablero-${IMAGE##*-}"
            echo
            echo "- Digest: \`$DIGEST\`"
            echo "- Publicada: $PUSHED"
            if [[ "$PUSHED" == "true" ]]; then
              echo "- Pull: \`docker pull ${IMAGE,,}@$DIGEST\`"
            fi
          } >> "$GITHUB_STEP_SUMMARY"
```

```bash
actionlint .github/workflows/images.yml; echo "exit $?"
# exit 0
grep -c 'steps.build.outputs.digest' .github/workflows/images.yml
# 1
git add .github/workflows/images.yml
git commit -m "ci: write image digests to the job summary"
git push
sleep 5
id=$(gh run list --workflow images.yml --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status; echo "exit $?"
# exit 0
```

**Verifica**: el `grep` de arriba solo encuentra la expresión en el `env:`; la orden de
`images-digest-summary` lo confirma.

```bash
yq '[.jobs.build.steps[] | select((.run // "") | test("GITHUB_STEP_SUMMARY")) | .env // {} | .[]] | join(" ")' .github/workflows/images.yml
# ghcr.io/${{ github.repository_owner }}/tablero-${{ matrix.image }} ${{ steps.build.outputs.digest }} ${{ github.event_name != 'pull_request' }}
docker buildx imagetools inspect "ghcr.io/$o/tablero-api:main" --format '{{.Manifest.Digest}}'
# sha256:... (el mismo que enseña el resumen: gh run view "$id" --web)
```

---

## Paso 6: `tablero-web`, público

**Por qué**: el run del paso 3 creó `tablero-web` privado, igual que pasó con la API. Hasta que
cambies su visibilidad, `ghcr-web-public` sigue en rojo y kind no podrá bajarla en la Semana 17.

> ⚠️ **Es irreversible**, como en la práctica 03: *"Once you make a package public, you cannot make
> it private again."* La imagen solo lleva el `dist` de la web y la configuración de nginx de tu
> repo público.

**Comando**: en `<tu-org>/tablero`, entra en el paquete `tablero-web` desde **Packages** y sigue
**Package settings → Danger Zone → Change visibility → Public**, como en la
[práctica 03, paso 5](03-publicar-en-ghcr.md).

**Verifica**: es la orden del check `ghcr-web-public`.

```bash
t=$(curl -fsS "https://ghcr.io/token?scope=repository:$o/tablero-web:pull" | jq -r .token)
curl -sS -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $t" \
  -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json' \
  "https://ghcr.io/v2/$o/tablero-web/manifests/main"
# 200
```

---

## ✅ Resultado

- [ ] El job `build` recorre `api` y `web` con una matriz y `fail-fast: false`
- [ ] `cache-from` y `cache-to` usan `type=gha` con `scope=${{ matrix.image }}`, y `cache-to` lleva `mode=max`
- [ ] Has medido el run frío y el caliente del mismo commit, y visto `uv sync` y `pnpm install` en `CACHED`
- [ ] En un PR las dos imágenes construyen, el login sale `skipped` y no se publica ninguna etiqueta `pr-`
- [ ] El resumen de cada job enseña el digest, llevado por `env:`
- [ ] `tablero-api` y `tablero-web` son públicos y están enlazados a `tablero`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 06
# 17/17 comprobaciones superadas.
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| Solo aparece el job `Imagen tablero-api` | La matriz sigue en `[api]` | Paso 1 |
| `tablero-web` falla con `denied: installation not allowed to Create organization package` | La org no deja crear paquetes, o falta `packages: write` en el job | **Settings → Packages** de la org; paso 1 |
| El run caliente tarda lo mismo que el frío | Falta `cache-to`, o los `scope` de lectura y escritura no coinciden | Paso 2: el mismo `scope=${{ matrix.image }}` en los dos |
| El resumen dice `Digest:` vacío | El `id:` del step de build no es `build` | `DIGEST` lee `steps.build.outputs.digest` |
| `ghcr-web-public` en rojo con `401` o `403` | `tablero-web` sigue privado | Paso 6 |
| El run falla con `startup_failure` | Tienes `sha_pinning_required` activo y una `uses:` va por tag | `scripts/resolve-sha.sh` (Semana 01, práctica 04, paso 3) |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Publicar en GHCR](03-publicar-en-ghcr.md) | [Proyecto: capa 06 de tablero](../3-proyecto/README.md) |
