# GHCR y el GITHUB_TOKEN

> Para publicar en un registro hace falta una credencial con permiso de escritura. En GitHub
> Container Registry esa credencial ya existe en cada job: es el `GITHUB_TOKEN`, y basta con
> pedirle un permiso más.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué es GHCR, a quién pertenece un paquete y cómo se nombra
- Dar al `GITHUB_TOKEN` de un solo job el permiso `packages: write` sin abrirlo al resto
- Explicar por qué el job repite `contents: read` al declarar sus permisos
- Iniciar sesión en `ghcr.io` con `docker/login-action`
- Saber cuándo un paquete queda enlazado a su repo, qué visibilidad tiene y cómo cambiarla
- Arreglar un paquete creado a mano en el que el workflow no puede escribir

## 1. Qué problema resuelve

Un `docker push` necesita autenticarse. Las alternativas de siempre son malas en CI:

- **Un token personal (PAT)** guardado como secreto: vale para todos tus repos, dura meses y, si se
  filtra, publica en nombre tuyo. La tabla de "lo que no se enseña como vigente" lo descarta.
- **Docker Hub con usuario y contraseña**: otra cuenta, otro secreto que rotar y límites de
  descarga anónima para quien consuma tus imágenes.

El `GITHUB_TOKEN` resuelve las dos cosas: lo crea GitHub para cada job, solo vale para el repo del
workflow, caduca al terminar el job y sus permisos se declaran en el propio YAML. GHCR lo acepta
como contraseña.

## 2. Cómo funciona

### GHCR y sus nombres

GitHub Container Registry vive en `ghcr.io` y guarda imágenes OCI como **paquetes** de tipo
`container`. Un paquete pertenece a una **cuenta** (tu organización), no a un repo:

| Trozo de `ghcr.io/<tu-org>/tablero-api` | Qué es |
|---|---|
| `ghcr.io` | El registro |
| `<tu-org>` | El dueño del paquete: tu organización |
| `tablero-api` | El nombre del paquete |

Por eso `images.yml` construye el nombre con `github.repository_owner` y no con
`github.repository`: `tablero-api` y `tablero-web` son dos paquetes de la organización, no dos
carpetas del repo.

### El permiso `packages: write` y por qué el job repite `contents: read`

Desde la Semana 01, todo workflow de `tablero` empieza con `permissions:` en la raíz y
`contents: read`: el `GITHUB_TOKEN` de cualquier job puede leer el código y nada más. Para publicar
en GHCR hace falta `packages: write`, y la pregunta es dónde ponerlo.

```yaml
# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  build:
    # Los permisos de un job sustituyen a los de la raíz: contents se repite.
    permissions:
      contents: read
      packages: write
```

Dos reglas explican este bloque:

1. **Los permisos de un job sustituyen a los de la raíz, no se suman.** Si el job declara solo
   `packages: write`, su token se queda **sin** `contents: read` y `actions/checkout` falla al
   clonar. Por eso el job lo repite. Lo que no declares en un bloque `permissions:` vale `none`.
2. **El permiso va en el job que lo necesita, no en la raíz.** Si mañana `images.yml` gana un job
   de pruebas, ese job hereda solo `contents: read`. Un permiso de escritura en la raíz se lo da a
   todos los jobs, incluidos los que ejecutan código de terceros.

| Dónde pones `packages: write` | Qué token puede publicar |
|---|---|
| En la raíz | El de todos los jobs del workflow |
| En el job `build`, repitiendo `contents: read` | Solo el de `build` ✅ |
| En el job `build`, sin repetir `contents: read` | Solo el de `build`, que además no puede hacer checkout ❌ |

El check `images-packages-write` comprueba exactamente la fila buena: raíz con `contents: read` y
sin `packages`, job `build` con `packages: write`. El modelo completo de permisos llega en la
Semana 12.

### `docker/login-action`

Escribe la credencial en el `~/.docker/config.json` del runner para que el `push` posterior la use.
Tres inputs:

| Input | Valor en `tablero` | Por qué |
|---|---|---|
| `registry` | `ghcr.io` | Sin él, inicia sesión en Docker Hub |
| `username` | `${{ github.actor }}` | GHCR lo exige pero no lo usa para autorizar con el `GITHUB_TOKEN`: manda el token |
| `password` | `${{ secrets.GITHUB_TOKEN }}` | El token del job, con los permisos del bloque de arriba |

Un post-step cierra la sesión al terminar el job (`logout: true` por defecto), así que en un runner
propio (Semana 15) la credencial no se queda en disco. El token aparece enmascarado en el log como
cualquier secreto.

### Enlace con el repo y permisos del paquete

Cuando un workflow publica un paquete **nuevo** con el `GITHUB_TOKEN`, GitHub lo enlaza
automáticamente al repo del workflow. El paquete aparece en la pestaña **Packages** de
`<tu-org>/tablero` y **hereda los permisos de acceso del repo**: quien puede escribir en el repo
puede escribir en el paquete, y el `GITHUB_TOKEN` de los workflows de ese repo también.

Hereda los permisos, **no la visibilidad**. Que `tablero` sea público no hace público el paquete.

### Visibilidad

- La **primera publicación** crea el paquete **privado**. Hasta que lo cambies, un `docker pull`
  sin sesión devuelve `unauthorized` o `denied`.
- Se cambia en la página del paquete: **Package settings → Danger Zone → Change visibility**.
- **Una vez público, no se puede volver a privado.** GitHub lo avisa y es definitivo.
- Una imagen pública se descarga **sin iniciar sesión**: es lo que comprueban los checks
  `ghcr-api-public` y `ghcr-web-public`, y lo que permite que kind la baje en la Semana 17 sin
  secretos.
- Si la opción de público no aparece, la organización no permite paquetes públicos: **Settings →
  Packages** de la org.

### El paquete que creaste a mano

Si alguna vez hiciste `docker push ghcr.io/<tu-org>/tablero-api:...` desde tu máquina con un PAT,
el paquete existe **sin** enlace al repo. El `GITHUB_TOKEN` del workflow no puede escribir en él y
el push falla con `denied: permission_denied: write_package`. Se arregla en el paquete:
**Package settings → Manage Actions access → Add repository**, con `tablero` y rol *Write*. O, si
el paquete no tiene nada que conservar, se borra y deja que el workflow lo cree.

## 3. Cómo se usa

Un workflow que publica la API en cada push a `main`, etiquetada con el SHA completo del commit.
Todavía sin `metadata-action` (teoría 05), para ver qué resuelve:

```yaml
name: publish-api

on:
  push:
    branches: [main]
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  publish:
    name: Publicar tablero-api
    runs-on: ubuntu-24.04
    # Los permisos de un job sustituyen a los de la raíz: contents se repite.
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Nombre de la imagen en minúsculas
        id: name
        env:
          OWNER: ${{ github.repository_owner }}
        run: echo "image=ghcr.io/${OWNER,,}/tablero-api" >> "$GITHUB_OUTPUT"

      - uses: docker/setup-buildx-action@f87e5991a6d7451dcb8d9637bfbc97413f497069 # v4.4.1

      - name: Iniciar sesión en GHCR
        uses: docker/login-action@81c6f93d4bc991e510b342a00b419b3bb4efc5c6 # v4.7.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Construir y publicar
        uses: docker/build-push-action@c3c9e263c25d99ce0380d002d59b67737d91b0dc # v7.4.0
        with:
          context: api
          push: true
          tags: ${{ steps.name.outputs.image }}:${{ github.sha }}
```

`${OWNER,,}` es la expansión de bash que pasa a minúsculas: si tu organización se llama
`Mi-Org`, el registro rechazaría `ghcr.io/Mi-Org/...`. Este step existe solo por eso, y es una de
las cosas que `metadata-action` hace sola.

### Comprobar el paquete desde la terminal

`gh` necesita el scope `read:packages` para ver paquetes:

```bash
gh auth refresh -s read:packages
gh api /orgs/<tu-org>/packages/container/tablero-api --jq '"\(.visibility) \(.repository.full_name)"'
# private <tu-org>/tablero
```

El repo te dice que el enlace se hizo; la visibilidad, si falta el paso de hacerlo público. Después de
**Change visibility → Public**:

```bash
docker logout ghcr.io
docker pull ghcr.io/<tu-org>/tablero-api:main
# main: Pulling from <tu-org>/tablero-api
# ...
# Status: Downloaded newer image for ghcr.io/<tu-org>/tablero-api:main
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Un PAT como secreto para publicar | Vale para todos tus repos, dura meses y publica en tu nombre | `GITHUB_TOKEN` con `packages: write` |
| `packages: write` en la raíz | Todos los jobs, presentes y futuros, pueden publicar | En el job que publica |
| Job con `packages: write` y sin `contents: read` | El checkout falla: los permisos del job sustituyen a los de la raíz | Repetir `contents: read` en el job |
| `permissions: write-all` | Todo el token con escritura sobre todo | Permisos uno a uno |
| Publicar la primera versión a mano desde tu máquina | El paquete nace sin enlace y el workflow no puede escribir | Que lo cree el workflow |
| Nombre de imagen con `github.repository_owner` sin pasar a minúsculas | `repository name must be lowercase` con orgs en mayúsculas | `metadata-action`, o `${OWNER,,}` |

## 5. Trucos

- **`gh api /orgs/<tu-org>/packages?package_type=container --jq '.[].name'`** lista todos los
  paquetes de contenedor de tu organización en una línea por paquete.
- **El enlace al repo también se declara en la imagen**: el label
  `org.opencontainers.image.source` con la URL del repo, que `metadata-action` pone solo
  (teoría 05). Es lo que GitHub usa para enlazar una imagen publicada desde fuera de Actions.
- **Un paquete enlazado aparece en la barra lateral del repo**, bajo *Packages*. Si no está ahí
  tras el primer run verde, el enlace no se hizo: mira si el paquete existía de antes.

Verificado con docker/login-action@v4.7.0 y ubuntu-24.04, noviembre 2026.

## 📚 Recursos Adicionales

- [GitHub Docs: Working with the Container registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [GitHub Docs: Configuring a package's access control and visibility](https://docs.github.com/en/packages/learn-github-packages/configuring-a-packages-access-control-and-visibility)
- [GitHub Docs: Publishing Docker images](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images)
- [docker/login-action](https://github.com/docker/login-action)

## ✅ Checklist de Verificación

- [ ] Sé que un paquete de GHCR pertenece a la organización, no al repo
- [ ] Sé por qué `packages: write` va en el job y no en la raíz
- [ ] Sé por qué el job repite `contents: read`
- [ ] Sé qué hace cada input de `login-action` y que el token se cierra al acabar
- [ ] Sé que el primer publish es privado y que hacerlo público no tiene vuelta atrás
- [ ] Sé arreglar un paquete creado a mano con *Manage Actions access*

---

| ← Anterior | Siguiente → |
|:---|---:|
| [BuildKit y buildx](03-buildkit-y-buildx.md) | [Etiquetas con metadata-action](05-etiquetas-con-metadata-action.md) |
