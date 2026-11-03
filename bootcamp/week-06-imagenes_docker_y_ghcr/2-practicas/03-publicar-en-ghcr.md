# Práctica 03 — Publicar en GHCR

> La imagen de la práctica 02 moría con el runner. Ahora la API se queda en GitHub Container
> Registry: `images.yml` calcula sus etiquetas, inicia sesión con el `GITHUB_TOKEN` y publica en
> cada push a `main`, nunca desde un PR. Terminas con un paquete público que cualquiera descarga
> por etiqueta o por digest sin iniciar sesión.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `images.yml` con un job `build` que construye y publica `tablero-api`
- `packages: write` solo en el job, con la raíz en `contents: read`
- Etiquetas `sha-<sha corto>` y `main` calculadas por `metadata-action`, sin `latest`
- Login y push que solo ocurren fuera de los pull requests
- `ghcr.io/<tu-org>/tablero-api` enlazado a `tablero`, público, y descargado por digest

## 📋 Antes de empezar

Terminaste la [práctica 02](02-primer-build-en-actions.md) y no hay cambios pendientes:

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
o=$(gh repo view --json owner --jq '.owner.login | ascii_downcase'); echo "$o"
# <tu-org> en minúsculas
```

`$o` es tu organización en minúsculas, como la escribe `metadata-action` en el nombre de la imagen.
Lo usas en toda la práctica; si abres otra terminal, vuelve a calcularlo.

> ⚠️ **No publiques `tablero-api` a mano desde tu máquina**, ni antes ni después del workflow. Un
> `docker push` con tu usuario crea el paquete **sin enlace** a `tablero`, y a partir de ahí el
> `GITHUB_TOKEN` del workflow no puede escribir en él: el push falla con
> `denied: permission_denied: write_package`
> ([teoría 04](../1-teoria/04-ghcr-y-github-token.md#el-paquete-que-creaste-a-mano)). El paquete
> lo tiene que crear el workflow.

Comprueba que todavía no existe. `gh` necesita el scope `read:packages` para ver paquetes:

```bash
gh auth refresh -s read:packages
gh api "/orgs/$o/packages/container/tablero-api" >/dev/null 2>&1; echo "exit $?"
# exit 1
```

`exit 1` es lo esperado: el paquete no existe. Si sale `exit 0`, alguien lo creó antes; mira la
tabla del final.

---

## Paso 1: Disparadores, permisos y etiquetas

**Por qué**: el workflow escucha los tres eventos del proyecto: `push` a `main` y
`workflow_dispatch` publican, `pull_request` solo construye
([teoría 07](../1-teoria/07-construir-en-pr-publicar-en-main.md#por-qué--y-no-)). Publicar en GHCR
exige `packages: write`, y se lo das **solo al job**. Al declarar `permissions` en un job, sustituye
entero al de la raíz: si no repites `contents: read`, el checkout se queda sin permiso para leer el
repo ([teoría 04](../1-teoria/04-ghcr-y-github-token.md#el-permiso-packages-write-y-por-qué-el-job-repite-contents-read)).

`metadata-action` convierte el evento en etiquetas y labels OCI
([teoría 05](../1-teoria/05-etiquetas-con-metadata-action.md#las-reglas-de-tablero)): `type=sha`
da `sha-<7 caracteres>`, que no se mueve nunca; `type=ref,event=branch` da `main`, que avanza con
cada commit; `type=ref,event=pr` da `pr-<número>`. `flavor: latest=false` apaga la etiqueta
`latest` que la action añadiría por su cuenta ([teoría 05](../1-teoria/05-etiquetas-con-metadata-action.md#latest-y-flavor)).
Además pasa el nombre a minúsculas, que es lo único que acepta el registro.

**Comando**: crea `.github/workflows/images.yml`.

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
    name: Imagen tablero-api
    runs-on: ubuntu-24.04
    # Los permisos de un job sustituyen a los de la raíz: contents se repite.
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Calcular etiquetas y labels
        id: meta
        uses: docker/metadata-action@dc802804100637a589fabce1cb79ff13a1411302 # v6.2.0
        with:
          images: ghcr.io/${{ github.repository_owner }}/tablero-api
          flavor: |
            latest=false
          tags: |
            type=sha
            type=ref,event=branch
            type=ref,event=pr
```

**Verifica**:

```bash
actionlint .github/workflows/images.yml; echo "exit $?"
# exit 0
yq '(.permissions.contents // "") + "," + (.permissions.packages // "none") + "," + (.jobs.build.permissions.packages // "")' .github/workflows/images.yml
# read,none,write
yq '.jobs.build.steps[1].with.flavor' .github/workflows/images.yml
# latest=false
```

La segunda orden es la de `images-packages-write`. No lo subas todavía: no construye nada.

---

## Paso 2: Login y publicación, solo fuera de los PR

**Por qué**: en un PR desde un fork el `GITHUB_TOKEN` es de solo lectura, declare lo que declare
el job; y en un PR desde una rama tuya publicar código sin revisar es lo que quieres evitar
([teoría 07](../1-teoria/07-construir-en-pr-publicar-en-main.md#el-token-en-cada-evento)). La
misma condición va en dos sitios: como `if:` en el login, para que el step se salte, y como valor
de `push` en el build, para que el PR **construya** igual pero no exporte nada
([teoría 07](../1-teoria/07-construir-en-pr-publicar-en-main.md#una-condición-dos-sitios)).

`login-action` recibe el `GITHUB_TOKEN` por `secrets.GITHUB_TOKEN`; el runner lo enmascara en el
log y caduca al acabar el job ([teoría 04](../1-teoria/04-ghcr-y-github-token.md#dockerlogin-action)).
`tags` y `labels` salen del step `meta`: nunca escribes el nombre de la imagen dos veces.

**Comando**: añade tres steps al final del job.

```yaml
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
          context: api
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

Fíjate en que no hay `load: true`: nadie hace `docker run` después, y cargar la imagen solo
gastaría tiempo ([teoría 03](../1-teoria/03-buildkit-y-buildx.md#push-load-o-ninguno)).

**Verifica**:

```bash
actionlint .github/workflows/images.yml; echo "exit $?"
# exit 0
yq '[.jobs.build.steps[] | select((.uses // "") | test("docker/login-action")) | .if] | join(" ")' .github/workflows/images.yml
# ${{ github.event_name != 'pull_request' }}
yq '[.jobs.build.steps[] | select((.uses // "") | test("docker/build-push-action")) | .with.push] | join(" ")' .github/workflows/images.yml
# ${{ github.event_name != 'pull_request' }}
```

---

## Paso 3: Push a `main` y primer paquete

**Por qué**: el push a `main` es un evento de confianza: el login corre, el build publica y, como
el paquete no existe, GHCR lo crea **privado** y **enlazado** a `tablero`, porque lo creó el
`GITHUB_TOKEN` de un workflow de ese repo
([teoría 04](../1-teoria/04-ghcr-y-github-token.md#enlace-con-el-repo-y-permisos-del-paquete)).
Esperas al run de **tu** commit, no al último que haya: `--commit` filtra por SHA.

**Comando**:

```bash
git add .github/workflows/images.yml
git commit -m "ci: publish tablero-api to ghcr from main"
git push
sleep 5
id=$(gh run list --workflow images.yml --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status; echo "exit $?"
# ... ✓ Construir y, fuera de los PR, publicar
# exit 0
```

**Verifica**:

```bash
gh run view "$id" --json jobs \
  --jq '.jobs[0].steps[] | select(.name == "Iniciar sesión en GHCR") | .conclusion'
# success
gh api "/orgs/$o/packages/container/tablero-api" --jq '"\(.visibility) \(.repository.full_name)"'
# private <tu-org>/tablero
gh api "/orgs/$o/packages/container/tablero-api/versions" --jq '.[0].metadata.container.tags | sort | join(",")'
# main,sha-<sha corto>
git rev-parse --short=7 HEAD
# <sha corto>
```

El SHA de la etiqueta y el de tu commit coinciden: esa imagen es ese commit. El paquete aparece
también en la columna **Packages** de la portada de `<tu-org>/tablero`.

---

## Paso 4: Comprobar que, privado, nadie lo descarga

**Por qué**: el paquete hereda los **permisos** del repo, no su **visibilidad**
([teoría 04](../1-teoria/04-ghcr-y-github-token.md#visibilidad)). Que `tablero` sea público no hace
público el paquete, y la Semana 17 necesita que kind lo baje sin secretos. Lo compruebas como lo
hará `check-week.sh`: un token anónimo de GHCR y una petición al manifiesto de `main`. `docker
logout` asegura que tu `docker pull` tampoco usa credenciales guardadas.

**Comando**:

```bash
docker logout ghcr.io
docker pull "ghcr.io/$o/tablero-api:main" 2>&1 | tail -1
# Error response from daemon: ... denied ...
```

**Verifica**:

```bash
docker image ls -q "ghcr.io/$o/tablero-api:main" | wc -l
# 0
```

El texto exacto del error cambia según la versión de Docker; lo que importa es que no se descarga.

---

## Paso 5: Hacerlo público

**Por qué**: una imagen pública se descarga sin iniciar sesión. Es lo que comprueba
`ghcr-api-public` y lo que permitirá desplegarla en kind sin un secreto de registro. La
visibilidad no se cambia desde la API ni desde `gh`: se cambia en la página del paquete.

> ⚠️ **Es irreversible.** GitHub lo avisa así: *"Once you make a package public, you cannot make it
> private again."* Publica en este paquete solo lo que ya está en tu repo público `tablero`: el
> código de la API, sin secretos. Si dudas de algo de la imagen, revísalo con `docker history` (práctica
> 01, paso 2) **antes** de cambiar la visibilidad.

**Comando**: en GitHub, abre `<tu-org>/tablero`, entra en el paquete `tablero-api` desde
**Packages** y sigue **Package settings → Danger Zone → Change visibility → Public**. GitHub te pide
confirmarlo escribiendo el nombre del paquete. Si la opción **Public** no aparece, la organización
no permite paquetes públicos: actívalo en **Settings → Packages** de la org.

```bash
gh api "/orgs/$o/packages/container/tablero-api" --jq .visibility
# public
```

**Verifica**: es la orden exacta del check `ghcr-api-public`.

```bash
t=$(curl -fsS "https://ghcr.io/token?scope=repository:$o/tablero-api:pull" | jq -r .token)
curl -sS -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $t" \
  -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json' \
  "https://ghcr.io/v2/$o/tablero-api/manifests/main"
# 200
```

El token lo pides sin usuario ni contraseña, y con un paquete público basta para leer el manifiesto:
es justo lo que hará kind en la Semana 17.

---

## Paso 6: Descargar por digest

**Por qué**: `main` es una etiqueta y avanza con cada commit; el digest es el hash de los bytes y
no se mueve ([teoría 08](../1-teoria/08-digest-y-consumo.md#pull-por-digest)). `imagetools
inspect` lee el índice en el registro sin bajar ninguna capa. Si `main` y `sha-<corto>` apuntan al
mismo digest, son la misma imagen con dos nombres.

**Comando**:

```bash
d=$(docker buildx imagetools inspect "ghcr.io/$o/tablero-api:main" --format '{{.Manifest.Digest}}')
echo "$d"
# sha256:<64 caracteres hexadecimales>
docker pull "ghcr.io/$o/tablero-api@$d" | tail -2
# Digest: sha256:...
# Status: Downloaded newer image for ghcr.io/<tu-org>/tablero-api@sha256:...
```

**Verifica**:

```bash
s=$(docker buildx imagetools inspect "ghcr.io/$o/tablero-api:sha-$(git rev-parse --short=7 HEAD)" \
  --format '{{.Manifest.Digest}}')
[ "$s" = "$d" ] && echo "mismo digest"
# mismo digest
```

Ese digest es lo que la práctica 04 escribirá en el resumen de cada run, y lo que la Semana 17
desplegará.

---

## ✅ Resultado

- [ ] `images.yml` está en `main` con un job `build` para la API
- [ ] La raíz pide `contents: read` y solo el job sube a `packages: write`
- [ ] `metadata-action` calcula `sha-<corto>` y `main`, con `latest=false`
- [ ] Login con el `GITHUB_TOKEN` y push, los dos condicionados a `github.event_name != 'pull_request'`
- [ ] `tablero-api` aparece en **Packages** de `tablero`, enlazado al repo y creado por el workflow
- [ ] El paquete es público y el `curl` anónimo devuelve `200`
- [ ] Has descargado la imagen por digest y comprobado que `main` y `sha-<corto>` son la misma

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 06
```

Ya pasan, entre otros, `images-packages-write`, `images-login-ghcr`, `images-push-not-on-pr` y
`ghcr-api-public`. `images-matrix` y los de caché siguen en rojo: son la práctica 04.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `denied: installation not allowed to Create organization package` | El job no tiene `packages: write` | Paso 1: el permiso va en `jobs.build.permissions` |
| `denied: permission_denied: write_package` | El paquete ya existía, creado a mano y sin enlace | **Package settings → Manage Actions access → Add repository**, `tablero` con rol *Write*; o bórralo si no guarda nada y relanza |
| `repository name must be lowercase` | Escribiste el nombre de la imagen a mano en `tags` | Usa `steps.meta.outputs.tags` |
| `gh api` responde `403` con un mensaje sobre scopes | A tu sesión de `gh` le falta `read:packages` | `gh auth refresh -s read:packages` |
| El `curl` anónimo da `401` o `403` | El paquete sigue privado | Paso 5 |
| No aparece la opción **Public** | La org no permite paquetes públicos | **Settings → Packages** de la org |
| `imagetools inspect` dice `not found` para `sha-…` | El run que publicó era de otro commit | Usa el SHA del run: `gh run view "$id" --json headSha --jq .headSha` |
| El run falla con `startup_failure` | Tienes `sha_pinning_required` activo y una `uses:` va por tag | `scripts/resolve-sha.sh` (Semana 01, práctica 04, paso 3) |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Primer build en Actions](02-primer-build-en-actions.md) | [Matriz y caché de capas](04-matriz-y-cache-de-capas.md) |
