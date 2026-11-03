# 🌐 Webgrafía — Semana 06

Documentación oficial y artículos de referencia. Las referencias son para consultar, no para leer de
corrido.

## Docker Build y BuildKit

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Docker Build](https://docs.docker.com/build/) | La entrada a toda la documentación de buildx y BuildKit: builders, caché, exportadores y CI | 2026-11-02 |
| [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/) | Etapas con nombre, `COPY --from` y `--target`, la base de los dos `Dockerfile` de `tablero` | 2026-11-02 |
| [Build context](https://docs.docker.com/build/concepts/context/) | Qué se envía a BuildKit, contexto local frente a Git context y la sintaxis de `.dockerignore` | 2026-11-02 |
| [Build cache invalidation](https://docs.docker.com/build/cache/invalidation/) | Qué invalida cada instrucción (`COPY`, `RUN`, `ARG`) y por qué todo lo de detrás se rehace | 2026-11-02 |
| [Optimize cache usage in builds](https://docs.docker.com/build/cache/optimize/) | Orden de capas, contexto mínimo y caché externa, con ejemplos que puedes comparar con la práctica 01 | 2026-11-02 |
| [Build drivers](https://docs.docker.com/build/builders/drivers/) | `docker` frente a `docker-container`: qué exporta cada uno y por qué el segundo necesita `--load` | 2026-11-02 |
| [Exporters](https://docs.docker.com/build/exporters/) | `image`, `registry`, `docker` y `oci`: lo que hay detrás de `push` y `load` | 2026-11-02 |
| [`docker buildx build`](https://docs.docker.com/reference/cli/docker/buildx/build/) | Todos los flags, incluidos `--metadata-file`, `--cache-from`, `--cache-to` y `--load` | 2026-11-02 |
| [`docker buildx imagetools inspect`](https://docs.docker.com/reference/cli/docker/buildx/imagetools/inspect/) | Leer un índice y sus manifiestos sin descargar capas, con `--raw` y `--format` | 2026-11-02 |
| [Dockerfile reference](https://docs.docker.com/reference/dockerfile/) | La referencia de cada instrucción; mira `COPY --chown`, `USER` y `ADD --checksum` | 2026-11-02 |
| [Cache storage backends](https://docs.docker.com/build/cache/backends/) | Los backends de caché externa y los parámetros comunes `mode`, `ref` y `ignore-error` | 2026-11-02 |
| [GitHub Actions cache backend](https://docs.docker.com/build/cache/backends/gha/) | `type=gha`: `scope`, `mode=max`, límites y qué token usa | 2026-11-02 |
| [Attestations](https://docs.docker.com/build/metadata/attestations/) y [Attestation storage](https://docs.docker.com/build/metadata/attestations/attestation-storage/) | Por qué el índice lleva un manifiesto `unknown/unknown` y qué anotaciones lo enlazan con la imagen | 2026-11-02 |
| [Using uv in Docker](https://docs.astral.sh/uv/guides/integration/docker/) — uv | De dónde salen `COPY --from=ghcr.io/astral-sh/uv` y el `uv sync --no-install-project` en dos pasos | 2026-11-02 |
| [Working with Docker](https://pnpm.io/docker) — pnpm | Cómo instalar con pnpm dentro de un `Dockerfile` aprovechando la caché, como hace `tablero-web` | 2026-11-02 |

## Docker en GitHub Actions

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Docker Build GitHub Actions](https://docs.docker.com/build/ci/github-actions/) | La guía oficial de las actions de Docker, con un ejemplo por caso de uso | 2026-11-02 |
| [docker/build-push-action](https://github.com/docker/build-push-action) | Todos los inputs (`context`, `push`, `load`, `tags`, `labels`, `cache-from`, `cache-to`) y los outputs `digest` y `metadata`. Léelo en el SHA fijado | 2026-11-02 |
| [docker/metadata-action](https://github.com/docker/metadata-action) | Las reglas `type=sha`, `type=ref`, `flavor` y las labels OCI que genera | 2026-11-02 |
| [docker/login-action](https://github.com/docker/login-action) | Los inputs `registry`, `username` y `password`, y el ejemplo para GHCR | 2026-11-02 |
| [docker/setup-buildx-action](https://github.com/docker/setup-buildx-action) | Qué builder crea, con qué driver, y cómo fijar la versión de buildx | 2026-11-02 |
| [Manage tags and labels](https://docs.docker.com/build/ci/github-actions/manage-tags-labels/) | `metadata-action` conectada a `build-push-action` en un workflow completo | 2026-11-02 |
| [Cache management with GitHub Actions](https://docs.docker.com/build/ci/github-actions/cache/) | `type=gha` frente a `type=registry` y `type=inline` en un workflow | 2026-11-02 |
| [Build summary](https://docs.docker.com/build/ci/github-actions/build-summary/) | Qué enseña el resumen de build, el artefacto `.dockerbuild` y cómo desactivarlo | 2026-11-02 |

## GHCR y GitHub Packages

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Working with the Container registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry) | Autenticación con el `GITHUB_TOKEN`, nombres de imagen y labels que reconoce GHCR | 2026-11-02 |
| [Configuring a package's access control and visibility](https://docs.github.com/en/packages/learn-github-packages/configuring-a-packages-access-control-and-visibility) | Por qué un paquete nace privado y cómo hacerlo público o dar acceso a un repo | 2026-11-02 |
| [Connecting a repository to a package](https://docs.github.com/en/packages/learn-github-packages/connecting-a-repository-to-a-package) | El enlace con el repo por la label `org.opencontainers.image.source` | 2026-11-02 |
| [Publishing Docker images](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images) | El tutorial oficial de GitHub para publicar en GHCR. Compara sus permisos y sus etiquetas con los tuyos | 2026-11-02 |
| [REST API: Packages](https://docs.github.com/en/rest/packages/packages) | Los endpoints de `gh api` para listar paquetes, versiones y etiquetas | 2026-11-02 |
| [`GITHUB_TOKEN`](https://docs.github.com/en/actions/concepts/security/github_token) | Qué permisos recibe el token en cada evento, y por qué en un PR desde un fork es de solo lectura | 2026-11-02 |
| [Workflow syntax: `permissions`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#permissions) | Por qué los permisos de un job sustituyen a los de la raíz | 2026-11-02 |

## OCI

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [OCI Image Format Specification](https://github.com/opencontainers/image-spec) | El repositorio de la especificación de imagen, con sus versiones | 2026-11-02 |
| [Image manifest](https://github.com/opencontainers/image-spec/blob/main/manifest.md) e [Image index](https://github.com/opencontainers/image-spec/blob/main/image-index.md) | Los dos documentos JSON que `imagetools inspect` te enseña, campo a campo | 2026-11-02 |
| [Pre-defined annotation keys](https://github.com/opencontainers/image-spec/blob/main/annotations.md) | Las claves `org.opencontainers.image.*` que `metadata-action` rellena como labels | 2026-11-02 |
| [OCI Distribution Specification](https://github.com/opencontainers/distribution-spec/blob/main/spec.md) | Cómo pide un cliente un manifiesto por etiqueta o por digest al registro | 2026-11-02 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
