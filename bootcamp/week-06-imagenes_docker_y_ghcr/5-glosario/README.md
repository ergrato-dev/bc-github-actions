# 📖 Glosario — Semana 06

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **Attestation** (atestación): documento que describe cómo se construyó una imagen.
  BuildKit añade por defecto una de procedencia al índice, como un manifiesto `unknown/unknown`.

## B

- **Blob**: contenido binario de un registro o de una caché, identificado por su digest. Cada capa
  es un blob; en la caché `type=gha` su clave es `buildkit-blob-1-sha256:…`.
- **BuildKit**: el motor de build de Docker. Resuelve el `Dockerfile` como un grafo, ejecuta en
  paralelo lo que puede y decide qué pasos salen `CACHED`.
- **buildx**: el cliente de línea de órdenes de BuildKit (`docker buildx build`). Gestiona
  builders, drivers, exportadores y caché externa.
- **Builder**: instancia de BuildKit a la que buildx envía los builds. `setup-buildx-action` crea
  uno con el driver `docker-container` en el runner.

## C

- **`cache-from` / `cache-to`**: inputs de `build-push-action` que dicen de dónde leer la caché de
  capas antes del build y dónde escribirla al terminar. Hacen falta los dos.
- **`CACHED`**: marca del log de BuildKit en un paso cuya capa ya estaba en la caché y no se
  ejecutó otra vez.
- **Capa** (*layer*): diferencia de sistema de archivos que produce una instrucción del
  `Dockerfile`, guardada como un tar comprimido e identificada por su digest.
- **Contexto de build** (*build context*): archivos que se envían a BuildKit para que `COPY` y
  `ADD` los usen. En `tablero`, la carpeta `app/api` o `app/web`, filtrada por `.dockerignore`.

## D

- **Digest**: hash `sha256:…` del contenido de una capa, un manifiesto o un índice. No se puede
  mover: si cambia un byte, cambia el digest. El output `digest` de `build-push-action` es el del
  índice.
- **`.dockerignore`**: archivo que excluye rutas del contexto de build, como `.venv` o
  `node_modules`.
- **Driver**: el modo en que corre un builder. `docker` usa el motor local y deja la imagen en él;
  `docker-container` corre BuildKit en un contenedor aparte y necesita `load` para dejarla.

## E

- **Etapa** (*stage*): cada bloque `FROM … AS nombre` de un `Dockerfile` multi-stage. Solo la
  última acaba en la imagen; las demás aportan lo que se copia con `COPY --from`.
- **Etiqueta** (*tag*): nombre móvil que el registro asocia a un manifiesto (`main`,
  `sha-1a2b3c4`). Se reasigna con cada push.

## G

- **GHCR** (*GitHub Container Registry*): el registro de contenedores de GitHub, en `ghcr.io`.
  Guarda imágenes OCI como paquetes de una cuenta u organización.

## I

- **Índice** (*image index*): documento OCI que lista varios manifiestos, uno por plataforma más
  los de attestation. Es lo que apunta una etiqueta multiplataforma.

## L

- **Labels OCI**: metadatos `org.opencontainers.image.*` de la imagen (`source`, `revision`,
  `created`). `metadata-action` los calcula; `source` enlaza el paquete con su repo.
- **`load`**: input de `build-push-action` que importa la imagen al Docker del runner para que un
  `docker run` posterior la encuentre.

## M

- **Manifiesto** (*image manifest*): documento JSON que lista la configuración y las capas de una
  imagen para una plataforma, cada una por su digest.
- **`metadata-action`**: `docker/metadata-action`, que calcula etiquetas y labels a partir del
  evento y del commit. En `tablero`, `type=sha`, `type=ref,event=branch` y `latest=false`.
- **`mode=max`**: modo de `cache-to` que exporta las capas de todas las etapas, no solo las de la
  imagen final (`mode=min`, por defecto).
- **Multi-stage**: `Dockerfile` con varias etapas, donde una construye y la final solo recibe el
  resultado. Deja fuera de la imagen publicada compiladores, gestores y cachés.

## O

- **OCI** (*Open Container Initiative*): el estándar abierto del formato de imagen y del protocolo
  de distribución que siguen Docker, GHCR y Kubernetes.

## P

- **Paquete** (*package*): lo que GHCR crea al recibir el primer push de una imagen. Pertenece a la
  organización, nace privado y se enlaza a un repo.
- **`packages: write`**: permiso del `GITHUB_TOKEN` para publicar en GHCR. Va solo en el job que
  publica, que además repite `contents: read`.
- **Procedencia** (*provenance*): attestation que dice con qué fuente, builder y parámetros se
  construyó la imagen. La verificarás en la Semana 14.
- **Pull por digest**: `docker pull imagen@sha256:…`, que descarga exactamente ese contenido aunque
  la etiqueta se haya movido.
- **`push`**: input de `build-push-action` que envía la imagen al registro. En `images.yml` vale
  `${{ github.event_name != 'pull_request' }}`.

## R

- **Registro** (*registry*): servidor que guarda y sirve imágenes OCI por nombre, etiqueta y
  digest: `ghcr.io`, Docker Hub.

## S

- **`scope`**: atributo de la caché `type=gha` que separa un índice por imagen
  (`scope=${{ matrix.image }}`). Tiene que ser el mismo en `cache-from` y en `cache-to`.

## T

- **`type=gha`**: backend de caché de BuildKit que guarda capas en la caché de Actions, con su
  cuota de 10 GB por repo y su aislamiento por rama.
- **`type=sha`**: regla de `metadata-action` que genera una etiqueta `sha-<sha corto>` por commit.

## U

- **`unknown/unknown`**: plataforma que enseñan GHCR y `imagetools inspect` para el manifiesto de
  attestation. No es una imagen rota.

## V

- **Visibilidad** (*visibility*): si un paquete se descarga sin sesión (`public`) o no (`private`).
  Un paquete nuevo de GHCR nace privado aunque el repo sea público.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Semana 07 — Disparadores, filtros y concurrencia](../../week-07-disparadores_filtros_y_concurrencia/README.md) |
