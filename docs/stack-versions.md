# Versiones del stack

Última revisión: 2026-11-02. Regla: versión completa fijada, nunca `latest`. Toda action, además,
por SHA resuelto con `scripts/resolve-sha.sh`.

Antes de fijar una versión hay que comprobar tres cosas: que el tag existe, que no tiene avisos de
seguridad sin parchear y que es compatible con el resto del stack. Procedimiento completo en
[`politica-versiones.md`](politica-versiones.md).

## Fijadas: lo que usa el repositorio hoy

### Actions

| Action | Tag | SHA | Desde | Verificación |
|---|---|---|:--:|---|
| `actions/checkout` | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` | 01 | `resolve-sha.sh` (2026-11-02). Release del 2026-07-20, el mismo SHA que fija bc-makefile |
| `astral-sh/setup-uv` | v10.3.3 | `68559e99cc807c1eb7e9238fd43a15bba460eec2` | 03 | `resolve-sha.sh` (2026-11-02). Release del 2026-10-28. Inputs `version`, `enable-cache`, `cache-dependency-glob` comprobados en su `action.yml` |
| `actions/cache` | v6.1.0 | `55cc8345863c7cc4c66a329aec7e433d2d1c52a9` | 03 | `resolve-sha.sh` (2026-11-02). Release del 2026-06-26, runtime node24 |
| `pnpm/action-setup` | v6.1.0 | `ea17c68df8912ef543352723c149a84f56e3d413` | 04 | `resolve-sha.sh` (2026-11-02). Input `package_json_file` comprobado en su `action.yml` |
| `actions/setup-node` | v7.1.0 | `949feb2413d6458794dcd2491c4babbbce0c15c1` | 04 | `resolve-sha.sh` (2026-11-02). Input `node-version` comprobado en su `action.yml` |
| `actions/upload-artifact` | v7.0.2 | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` | 04 | `resolve-sha.sh` (2026-11-02). Runtime node24 |
| `actions/download-artifact` | v8.0.2 | `9000827ccba6bdab643e8b6fd33ac0654aef8333` | 04 | `resolve-sha.sh` (2026-11-02). Runtime node24 |
| `docker/setup-buildx-action` | v4.4.1 | `f87e5991a6d7451dcb8d9637bfbc97413f497069` | 06 | `resolve-sha.sh` (2026-11-02). Release del 2026-09-16, runtime node24. Driver por defecto `docker-container` |
| `docker/metadata-action` | v6.2.0 | `dc802804100637a589fabce1cb79ff13a1411302` | 06 | `resolve-sha.sh` (2026-11-02). Inputs `images`, `tags`, `flavor`; outputs `tags`, `labels`, `version`. Pasa el nombre de la imagen a minúsculas |
| `docker/login-action` | v4.7.0 | `81c6f93d4bc991e510b342a00b419b3bb4efc5c6` | 06 | `resolve-sha.sh` (2026-11-02). Release del 2026-10-23. Inputs `registry`, `username`, `password` |
| `docker/build-push-action` | v7.4.0 | `c3c9e263c25d99ce0380d002d59b67737d91b0dc` | 06 | `resolve-sha.sh` (2026-11-02). Release del 2026-09-15. Inputs `context`, `push`, `load`, `tags`, `labels`, `cache-from`, `cache-to`; outputs `digest`, `imageid`, `metadata`. `push` y `load` valen `false` por defecto |
| `actions/github-script` | v9.0.0 | `3a2844b7e9c422d3c10d287c895573f7108da1b3` | 07 | `resolve-sha.sh` (2026-11-02). Release del 2026-04-09, runtime node24. Inputs `script`, `github-token`, `result-encoding`, `retries`; output `result`. En v9 `require('@actions/github')` ya no funciona y `getOctokit` viene inyectado |

### Herramientas

| Pieza | Versión | Desde | Verificación |
|---|---|:--:|---|
| gh | 2.103.3 o superior | 01 | Release del 2026-10-26 |
| git | 2.40 o superior | 01 | El de la distro |
| jq | 1.6 o superior | 01 | El de la distro. `check-week.sh` está probado con 1.6 |
| yq (mikefarah) | v4.54.1 | 01 | Release del 2026-09-29. Descarga con digest probada (2026-11-02). La imagen `ubuntu-24.04` del runner trae la misma versión (README de actions/runner-images, 2026-11-02) |
| actionlint | 1.7.12 | 01 | Release del 2026-03-30. Descarga con digest probada (2026-11-02) |
| zizmor | 1.31.1 | 08 (se instala en 01) | Release del 2026-10-15. `uv tool install zizmor==1.31.1`; `--offline` probado sobre el CI propio: sin hallazgos |
| uv | 0.13.6 | 03 | Release del 2026-10-27. El tarball trae `uv` y `uvx` |
| pnpm | 12.16.1 | 04 | Release del 2026-10-27. Ejecutable autónomo `pnpm-linux-x64.tar.gz`, descarga con digest probada. `pnpm env` está deprecado en favor de `pnpm runtime` |
| Node | 26 LTS (26.13.0); la web admite `>=24` (24.22.2, LTS Krypton) y el CI prueba las dos | 04 | `nodejs.org/dist/index.json`: 26.13.0, línea LTS "Lithium" (2026-11-02). Instalado con `pnpm runtime set node 26 -g`, probado |
| Python | 3.15 (3.15.2) | 03 | endoflife.date (2026-11-02). Lo instala uv según `.python-version` |
| Docker Engine | 29.9.2 como referencia | 05 | moby v29.9.2 (2026-10-20) |
| Docker buildx | v0.38.1 como referencia | 06 | `docker buildx version` en el equipo del autor (2026-11-02). Plugin que viene con Docker Engine |
| Docker Compose | v5.6.1 como referencia | 05 | `docker compose version` en el equipo del autor (2026-11-02). Plugin, nunca `docker-compose`. El runner `ubuntu-24.04` (imagen 20261026.354.1) trae Docker 28.0.4 y Compose 2.38.2 <!-- antipatron --> |
| kind | v0.33.0 | 16 | Release del 2026-08-26 |
| Nodo de kind | `kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5` | 16 | Imagen por defecto de kind v0.33.0; el mismo digest que fija bc-kubernetes (2026-10-30) |
| kubectl | v1.37.2 | 16 | Último patch de 1.37 (2026-10-28) |

### Dependencias de `app/` (fijadas en `api/uv.lock` y `web/pnpm-lock.yaml`)

| Pieza | Versión | Nota |
|---|---|---|
| FastAPI · Starlette · Pydantic | 0.162.0 · 1.10.0 · 2.14.2 | |
| uvicorn · psycopg | 0.54.0 · 3.3.6 | psycopg con extra `binary` (hay wheels para CPython 3.15) |
| ruff · pytest · pytest-cov | 0.17.3 · 9.2.0 · 7.1.0 | |
| httpx2 | 2.16.0 | `starlette.testclient` marca `httpx` como deprecado y pide `httpx2` (2026-11-02) |
| React · Vite · Vitest | 19.3.1 · 8.3.5 · 5.0.5 | |
| TypeScript | 6.0.3 | **No la 7**: typescript-eslint 8.72.1 exige `>=4.8.4 <6.1.0` (`pnpm peers check`, 2026-11-02) |
| ESLint · typescript-eslint · jsdom | 10.14.0 · 8.72.1 · 30.1.3 | |

### Imágenes

| Imagen | Tag | Desde | Verificación |
|---|---|:--:|---|
| `postgres` | `17.11-alpine` | 05 | Docker Hub, último parche de la 17 (2026-11-02) |
| `nginxinc/nginx-unprivileged` | `1.31.7-alpine` | 06 | Docker Hub, último `X.Y.Z-alpine` (2026-11-02) |
| `python` | `3.15.2-slim-trixie` | 06 | Base de la imagen de la API (2026-11-02) |
| `ghcr.io/astral-sh/uv` | `0.13.6` | 06 | Solo en la etapa de build de la API |
| `node` | `26.13.0-trixie-slim` | 06 | Solo en la etapa de build de la web; pnpm entra con `ADD --checksum` |

## Referencia: se fija al escribir su semana

Versiones vigentes hoy. Cada fila pasa a la tabla de arriba, con su SHA resuelto y verificado de
nuevo, en la tanda que escribe la semana que la usa.

| Pieza | Vigente (2026-11-02) | Semana | Nota |
|---|---|:--:|---|
| act | v0.2.94 | 08 | `act_Linux_x86_64.tar.gz`. Comprobar qué imagen usa para `ubuntu-24.04` |
| `googleapis/release-please-action` | v5.0.0 | 14 | |
| `actions/attest-build-provenance` | v4.2.2 | 14 | Comprobar si ya es un alias de `actions/attest` |
| `actions/attest` | v4.2.2 | 14 | |
| `anchore/sbom-action` | v0.24.3 | 14 | |
| syft | v1.56.0 | 14 | |
| `actions/dependency-review-action` | v5.0.0 | 14 | |
| Trivy | v0.76.1 | 14 | **Nunca v0.69.4** (GHSA-69fq-xp46-6x23, compromiso del 2026-03-19). Revisar los avisos de 2026-06 (GHSA-mcj4-mphf-j9ff y otros). Binario con checksum, nunca `trivy-action` por tag |
| `github/codeql-action` | bundle v2.27.4 | 12 | Las actions se fijan por el tag `vN.x.y` de la action, no por el del bundle |
| actions/runner | v2.338.2 | 15 | Imagen `ghcr.io/actions/actions-runner` |
| ARC (`gha-runner-scale-set-controller`, `gha-runner-scale-set`) | 0.15.1 | 16 | Charts OCI en `ghcr.io/actions/actions-runner-controller-charts` |
| Helm | v4.3.1 | 16 | |
| PyJWT | — | 13 | Se fija en el `uv.lock` de `tools/oidc-verifier/` |

### Plataforma: comprobar al escribir la semana

| Qué | Semana | Por qué |
|---|:--:|---|
| Runtime vigente de las actions JavaScript (`node24`?) | 10 | `using:` en `action.yml` |
| Estado de `ubuntu-24.04` frente a una imagen más nueva en los runners alojados | 01 | Si sale una nueva, se decide aquí y se cambia en todo el repo |
| Límites de caché por repo y política de expulsión | 03, 19 | |
| Retención por defecto de artefactos y logs | 04, 19 | |
| Límites de anidamiento y de llamadas de workflows reutilizables | 09 | |
| Merge queue, rulesets que exigen workflows y revisores de environment en una org gratuita con repo público | 11, 13, 18 | Lo decide el spike, ver `decision-laboratorio.md` |
| Dominios vigentes del examen GH-200 | 20 | `mapa-funcionalidades.md` |

## Retirado: no se usa

| Pieza | Motivo |
|---|---|
| `::set-output`, `::save-state` | Deshabilitados: se sustituyen por `$GITHUB_OUTPUT` y `$GITHUB_STATE` |
| `actions/upload-artifact@v3` y `download-artifact@v3` | Retirados |
| `docker-compose` v1 | Retirado: se usa el plugin `docker compose` <!-- antipatron --> |
| `corepack enable` para pnpm | corepack ya no viene incluido desde Node 25 |
| Trivy v0.69.4 y `aquasecurity/trivy-action` por tag | Compromiso del 2026-03-19 (GHSA-69fq-xp46-6x23) |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Reglas de seguridad de workflows](reglas-de-seguridad-de-workflows.md) | [Política de versiones](politica-versiones.md) |
