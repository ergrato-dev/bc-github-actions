# Práctica 02 — Imágenes versionadas y escaneo

> Una release que no publica nada que se pueda ejecutar es solo un tag. En esta práctica, cada
> release de `tablero` publica `tablero-api` y `tablero-web` con su versión como tag y las pasa
> por Trivy. La primera vez la puerta se cierra de verdad: la base de la web trae una CVE
> crítica, y la arreglas con un `fix` que es a su vez la siguiente release.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- El job `images` en `release.yml`, que solo corre cuando release-please crea una release
- `tablero-api` y `tablero-web` publicadas en GHCR con la versión de la release como tag
- syft y Trivy instalados como binario de su release con checksum, en el runner y en local
- Una release roja por CVE-2026-111497 y la siguiente, `v0.3.1`, en verde con la base parcheada

## 📋 Antes de empezar

Terminaste la [práctica 01](01-release-please-y-versionado-semantico.md): la release `v0.2.0`
existe. Leíste la [teoría 02](../1-teoria/02-tags-digests-e-imagenes-versionadas.md) y la
[teoría 06](../1-teoria/06-escaneo-de-vulnerabilidades-con-trivy.md).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
o=$(gh repo view --json owner --jq '.owner.login | ascii_downcase'); echo "$o"
# tu-org
gh release view --json tagName --jq .tagName
# v0.2.0
gh api "/orgs/$o/packages/container/tablero-web" --jq '"\(.visibility) \(.repository.full_name)"'
# public <tu-org>/tablero
```

El último comando necesita el scope `read:packages` de la Semana 06. Si el paquete no está
vinculado a `tablero`, el `docker push` del job fallará por permisos.

---

## Paso 1: El job `images`, solo cuando hay release

**Por qué**: la release la crea `GITHUB_TOKEN`, y nada de lo que hace ese token dispara otros
workflows: un `images.yml` con `on: release` nunca correría. Por eso las imágenes se publican en
el mismo run, en un job que necesita a `release-please` y lee su output `created`. Los outputs
de un job son **cadenas**: se compara con `'true'` entre comillas, y un `true` sin comillas
nunca coincide. La matriz con `fail-fast: false` deja que la API termine aunque la web falle.
El nombre de la imagen va en minúsculas porque GHCR no acepta mayúsculas y el nombre de tu org
puede tenerlas; lo calcula un step con `${OWNER,,}`, y el dueño llega por `env:` como cualquier
dato del contexto. De permisos, por ahora solo `packages: write` para publicar.

**Comando**: en `.github/workflows/release.yml`, debajo del job `release-please`:

```yaml
  images:
    name: Imagen tablero-${{ matrix.component }}
    needs: release-please
    # La release la crea GITHUB_TOKEN, que no dispara otros workflows: las imágenes salen aquí.
    if: ${{ needs.release-please.outputs.created == 'true' }}
    runs-on: ubuntu-24.04
    timeout-minutes: 30
    permissions:
      contents: read
      packages: write
    strategy:
      fail-fast: false
      matrix:
        component: [api, web]
    env:
      VERSION: ${{ needs.release-please.outputs.version }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Nombre de la imagen en minúsculas
        id: name
        env:
          OWNER: ${{ github.repository_owner }}
          COMPONENT: ${{ matrix.component }}
        run: echo "image=ghcr.io/${OWNER,,}/tablero-${COMPONENT}" >> "$GITHUB_OUTPUT"
```

**Verifica**: la orden de `images-gated-by-release` y actionlint:

```bash
yq '"needs=" + ([.jobs.images.needs] | flatten | join(",")) + " if=" + .jobs.images.if' .github/workflows/release.yml
# needs=release-please if=${{ needs.release-please.outputs.created == 'true' }}
actionlint .github/workflows/release.yml && echo ok
# ok
```

---

## Paso 2: Construir y publicar con la versión como tag

**Por qué**: la versión de la release es el nombre que una persona usa para pedir una imagen:
`tablero-api:0.3.0`. Va sin la `v`, que es la costumbre de los tags de imagen; el output
`version` de release-please ya viene así (`tag_name` es el que la lleva). Nada de `latest`: no
dice qué hay dentro ni cuándo cambió. El `context` es la carpeta del componente, donde está su
Dockerfile, y el login usa el `GITHUB_TOKEN` del run con el `packages: write` del paso 1.

**Comando**: a continuación del step del nombre:

```yaml
      - uses: docker/setup-buildx-action@f87e5991a6d7451dcb8d9637bfbc97413f497069 # v4.4.1

      - uses: docker/login-action@81c6f93d4bc991e510b342a00b419b3bb4efc5c6 # v4.7.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Construir y publicar la versión
        id: build
        uses: docker/build-push-action@c3c9e263c25d99ce0380d002d59b67737d91b0dc # v7.4.0
        with:
          context: ${{ matrix.component }}
          push: true
          tags: ${{ steps.name.outputs.image }}:${{ env.VERSION }}
```

**Verifica**: la orden de `images-versioned`:

```bash
yq '"matrix=" + (.jobs.images.strategy.matrix.component | join(",")) + " " + (.jobs.images.steps[] | select(.uses // "" | test("^docker/build-push-action@[0-9a-f]{40}$")) | "push=" + (.with.push | tostring) + " tags=" + .with.tags)' .github/workflows/release.yml
# matrix=api,web push=true tags=${{ steps.name.outputs.image }}:${{ env.VERSION }}
```

---

## Paso 3: syft y Trivy con checksum

**Por qué**: el escáner es la herramienta que decide si una imagen sale; si alguien la cambia,
decide él. Trivy lo vivió: la `v0.69.4` y los tags de `trivy-action` se comprometieron el
2026-03-19. Así que ni action por tag ni `curl | bash`: el binario de la release, comprobado con
el digest que GitHub calcula para cada asset, con la misma función `download_verified` de
[`docs/setup-entorno.md`](../../../docs/setup-entorno.md). syft lo instalas ya aunque no lo uses
hasta la práctica 03. Las versiones viven una sola vez, en `env:` del job.

**Comando**: en el job `images`, el `env:` pasa a tener tres variables:

```yaml
    env:
      VERSION: ${{ needs.release-please.outputs.version }}
      SYFT_VERSION: v1.57.0
      TRIVY_VERSION: v0.76.2
```

Y entre el step del nombre y `setup-buildx-action`, el de la instalación:

```yaml
      - name: Instalar syft y trivy desde su release, con checksum
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          download_verified() {
            local repo="$1" tag="$2" file="$3" expected
            expected=$(gh api "repos/$repo/releases/tags/$tag" \
              --jq ".assets[] | select(.name == \"$file\") | .digest" | sed 's/^sha256://')
            [[ -n "$expected" ]] || { echo "Sin digest para $file" >&2; return 1; }
            gh release download "$tag" --repo "$repo" --pattern "$file"
            echo "$expected  $file" | sha256sum -c
          }
          mkdir -p "$RUNNER_TEMP/bin" && cd "$RUNNER_TEMP"
          download_verified anchore/syft "$SYFT_VERSION" "syft_${SYFT_VERSION#v}_linux_amd64.tar.gz"
          download_verified aquasecurity/trivy "$TRIVY_VERSION" "trivy_${TRIVY_VERSION#v}_Linux-64bit.tar.gz"
          tar -xzf "syft_${SYFT_VERSION#v}_linux_amd64.tar.gz" -C bin syft
          tar -xzf "trivy_${TRIVY_VERSION#v}_Linux-64bit.tar.gz" -C bin trivy
          echo "$RUNNER_TEMP/bin" >> "$GITHUB_PATH"
```

Las mismas dos herramientas, en tu máquina. Define `download_verified` copiándola de
`docs/setup-entorno.md` (apartado 1) en tu terminal y:

```bash
cd "$(mktemp -d)"
download_verified anchore/syft v1.57.0 syft_1.57.0_linux_amd64.tar.gz
# syft_1.57.0_linux_amd64.tar.gz: OK
download_verified aquasecurity/trivy v0.76.2 trivy_0.76.2_Linux-64bit.tar.gz
# trivy_0.76.2_Linux-64bit.tar.gz: OK
tar -xzf syft_1.57.0_linux_amd64.tar.gz syft && tar -xzf trivy_0.76.2_Linux-64bit.tar.gz trivy
install -m 0755 syft trivy ~/.local/bin/
cd ~/code/tablero
```

**Verifica**: las versiones locales y la orden de `tools-with-checksum`:

```bash
syft --version && trivy --version | head -1
# syft 1.57.0
# Version: 0.76.2
f=.github/workflows/release.yml; printf 'checksum=%s trivy-action=%s bad=%s trivy=%s syft=%s\n' "$(grep -c 'sha256sum -c' $f)" "$(grep -c 'trivy-action' $f)" "$(grep -c '0\.69\.4' $f)" "$(yq '.jobs.images.env.TRIVY_VERSION' $f)" "$(yq '.jobs.images.env.SYFT_VERSION' $f)"
# checksum=1 trivy-action=0 bad=0 trivy=v0.76.2 syft=v1.57.0
```

---

## Paso 4: La puerta de Trivy, y la primera release con imágenes

**Por qué**: Trivy escanea la imagen **publicada, por su digest**: lo que analiza son los bytes
que se desplegarán, no una copia local que podría diferir. `--severity CRITICAL` con
`--ignore-unfixed` rompe solo por lo grave **que tiene arreglo**: con `HIGH`, la API de
`tablero` tendría decenas de avisos sin parche posible y la puerta estaría siempre cerrada, que
es lo mismo que no tenerla. `--exit-code 1` convierte el hallazgo en un job rojo.

Antes del push lo pruebas en local. La primera vez Trivy baja su base de datos de avisos y
tarda un poco.

**Comando**: a continuación del step `build`:

```yaml
      - name: Escanear la imagen publicada
        env:
          REF: ${{ steps.name.outputs.image }}@${{ steps.build.outputs.digest }}
        run: trivy image --no-progress --exit-code 1 --severity CRITICAL --ignore-unfixed "$REF"
```

```bash
docker build -q -t tablero-api:local api > /dev/null && docker build -q -t tablero-web:local web > /dev/null
trivy image -q --exit-code 1 --severity CRITICAL --ignore-unfixed tablero-api:local > /dev/null && echo api sin-criticas
# api sin-criticas
trivy image -q --severity CRITICAL --ignore-unfixed --format json tablero-web:local |
  jq -r '.Results[].Vulnerabilities[]? | .PkgName + " " + .InstalledVersion + " " + .VulnerabilityID + " " + .FixedVersion'
# brotli-libs 1.2.0-r1 CVE-2026-111497 1.2.1-r0
```

La base `nginxinc/nginx-unprivileged:1.31.7-alpine` trae `brotli-libs` 1.2.0-r1, con una
escritura fuera de límites en el decodificador; Alpine ya publicó 1.2.1-r0, pero en noviembre
de 2026 no hay imagen nueva de nginx con ella. La release que vas a crear **va a fallar**, y es
lo que quieres ver una vez: dónde se para, y qué queda publicado.

> Si cuando hagas esto la web sale sin hallazgos, la base ya viene arreglada: la release saldrá
> en verde, el parche del paso 5 no hace falta y puedes saltar al Resultado.

Publicar imágenes con cada release es una capacidad nueva: el commit es un `feat` y
release-please propondrá `0.3.0`.

```bash
actionlint
git commit -am "feat(release): publish versioned api and web images"
git push
sleep 5
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
# release ok
pr=$(gh pr list --label "autorelease: pending" --json number --jq '.[0].number')
gh pr merge "$pr" --squash --delete-branch
git pull --ff-only && sleep 5
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null || echo release con fallos
# release con fallos
```

**Verifica**: qué job cayó, por qué, y qué quedó publicado:

```bash
gh run view "$run" --json jobs --jq '.jobs[] | .name + " " + .conclusion' | sort
# Imagen tablero-api success
# Imagen tablero-web failure
# Release PR o release success
gh run view "$run" --log-failed | grep -oE 'CVE-2026-111497' | sort -u
# CVE-2026-111497
gh release view --json tagName --jq .tagName
# v0.3.0
for c in api web; do docker buildx imagetools inspect "ghcr.io/$o/tablero-$c:0.3.0" > /dev/null && echo "$c publicada"; done
# api publicada
# web publicada
```

La release `v0.3.0` existe y `tablero-web:0.3.0` también: el escaneo va después del push. Lo que
la puerta impide es lo que viene detrás, que añades en la práctica 03: sin escaneo en verde no
hay attestations, y la Semana 17 solo despliega lo que pasa `gh attestation verify`.

---

## Paso 5: El parche, como `fix`, y la release `v0.3.1`

**Por qué**: bajar la severidad o ignorar la CVE para pasar es apagar la alarma. El arreglo
existe en Alpine, así que lo aplicas en tu imagen: `apk upgrade` solo de `brotli-libs`. La base
corre como el usuario `nginx` (uid 101); para instalar hace falta `root` un momento y luego se
vuelve a `nginx`, o la imagen acabaría corriendo como root. El comentario dice qué, cuándo y
cuándo quitarlo. Y el commit es un `fix(web)`: corrige algo que afecta a quien usa la imagen,
así que release-please propone `0.3.1` y la imagen arreglada sale con su propia versión.

**Comando**: en `web/Dockerfile`, justo debajo de la línea `FROM nginxinc/nginx-unprivileged...`:

```dockerfile
# Parche de la base (2026-11): brotli-libs 1.2.0-r1 trae CVE-2026-111497 (CRITICAL, corregido en
# 1.2.1-r0) y aún no hay imagen nueva de nginx-unprivileged. Quitar cuando Dependabot suba el digest.
USER root
RUN apk upgrade --no-cache brotli-libs
USER nginx
```

```bash
docker build -q -t tablero-web:local web > /dev/null
trivy image -q --exit-code 1 --severity CRITICAL --ignore-unfixed tablero-web:local > /dev/null && echo web sin-criticas
# web sin-criticas
docker run --rm --entrypoint id tablero-web:local -u
# 101
git commit -am "fix(web): patch brotli-libs for CVE-2026-111497"
git push
sleep 5
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
# release ok
pr=$(gh pr list --label "autorelease: pending" --json number --jq '.[0].number')
gh pr merge "$pr" --squash --delete-branch
git pull --ff-only && sleep 5
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
# release ok
```

**Verifica**: la release nueva, los tres jobs en verde y la orden de `trivy-gate`:

```bash
gh release view --json tagName --jq .tagName
# v0.3.1
gh run view "$run" --json jobs --jq '.jobs[] | .name + " " + .conclusion' | sort
# Imagen tablero-api success
# Imagen tablero-web success
# Release PR o release success
yq '[.jobs.images.steps[] | select((.run // "" | test("trivy image .*--exit-code 1")) and (.env.REF // "" | test("steps\.build\.outputs\.digest")))] | length' .github/workflows/release.yml
# 1
```

---

## ✅ Resultado

- [ ] El job `images` necesita a `release-please` y solo corre si `created == 'true'`
- [ ] `tablero-api` y `tablero-web` se publican con la versión sin `v` como tag
- [ ] syft y Trivy se instalan con checksum y sus versiones están una sola vez, en `env:`
- [ ] Viste la puerta cerrarse por CVE-2026-111497 en `v0.3.0`
- [ ] `web/Dockerfile` parchea `brotli-libs` con un comentario que dice cuándo quitarlo
- [ ] `v0.3.1` publicada con los tres jobs en verde

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 14
# ...
# ✅ El job images de release.yml necesita a release-please y solo corre si se creó una release
# ✅ El job images publica api y web con la versión de la release como tag
# ...
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| Tras fusionar el PR de release, `images` aparece como saltado | El `if:` compara con `true` sin comillas o el output no se llama `created` | Paso 1, y los `outputs:` del job `release-please` de la práctica 01 |
| `invalid reference format: repository name must be lowercase` | La imagen se nombró con `github.repository_owner` sin pasar a minúsculas | Usa `steps.name.outputs.image` (paso 1) |
| `denied: permission_denied: write_package` en el push | El paquete de GHCR no da acceso de escritura a `tablero`, o falta `packages: write` | Package settings → Manage Actions access, como en la Semana 06 |
| `Sin digest para trivy_...` | Versión o nombre del asset mal escrito | Compara con `gh release view v0.76.2 --repo aquasecurity/trivy --json assets --jq '.assets[].name'` |
| `sha256sum: WARNING: 1 computed checksum did NOT match` | Descarga corrupta o asset distinto del esperado | No instales ese binario; repite la descarga y revisa el nombre |
| La web pasa Trivy en local y falla en el runner | Tu base de datos local de Trivy es más vieja que la del runner | `trivy image --download-db-only` y repite |
| `docker run ... id -u` da `0` | Falta el `USER nginx` después del `RUN apk upgrade` | Paso 5: la imagen no puede quedarse como root |
| release-please no abre PR tras el `fix(web)` | El commit no sigue el formato (`fix(web):` con dos puntos y espacio) | `git commit --amend` antes del push, o un commit nuevo bien escrito |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [release-please y versionado semántico](01-release-please-y-versionado-semantico.md) | [SBOM y attestations](03-sbom-y-attestations.md) |
