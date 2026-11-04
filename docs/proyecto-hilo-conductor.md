# 📋 Proyecto hilo conductor: `tablero`

Un solo proyecto atraviesa las 20 semanas. `tablero` es un gestor de tareas pequeño, escrito para
este bootcamp, organizado como **monorepo**:

| Parte | Stack | Qué expone |
|---|---|---|
| `api/` | Python + FastAPI, gestionado con **uv** (`pyproject.toml` + `uv.lock`) | `/api/health` (con la versión) y CRUD `/api/tasks` |
| `web/` | React + Vite + TypeScript, gestionado con **pnpm** (`pnpm-lock.yaml`) | La interfaz, servida por nginx sin privilegios |
| base de datos | **PostgreSQL 17** | Tabla `tasks`, migraciones SQL al arrancar |
| `compose.yaml` | **Docker Compose** | `db`, `api` y `web` en local, puertos solo en `127.0.0.1` |

El código completo vive en [`app/`](../app/) de este repositorio. **No tiene `.github/`**: los
workflows son lo que escribes tú. En el bootcamp no programas la app; escribes todo lo que la
rodea.

## Por qué esta app

- **Dos ecosistemas en un repo.** Python con uv y Node con pnpm obligan a dos CIs distintos, a
  filtros de ruta, a matrices de imagen y a reutilizar sin copiar. Con una sola tecnología medio
  bootcamp no tendría sentido.
- **Tiene estado.** Sin PostgreSQL no hay tests de integración ni service containers, y el
  despliegue no tendría nada que pueda romperse de verdad.
- **Es pequeña a propósito.** Cada minuto que pasas leyendo la app es un minuto que no pasas en
  el pipeline.
- **Corre como no root desde el principio**, así que el despliegue a Kubernetes de la Semana 17 no
  obliga a reescribir nada.

## Dónde trabaja el alumno

En la Semana 01 creas una **organización gratuita** `<tu-org>` y dentro el **repo público
`<tu-org>/tablero`**, donde copias el contenido de `app/`. Ese repo es tu entrega durante las 20
semanas: el autograding lee sus archivos y sus ejecuciones (ver [`autograding.md`](autograding.md)).

Cada semana copias los archivos del `3-proyecto/starter/` de la semana a la ruta que dice su
cabecera (casi siempre `.github/workflows/`), completas los `TODO` y subes los cambios.

## Capas por semana

| Semana | Capa que se añade al pipeline |
|:--:|---|
| 01 | Org y repo `tablero` creados, con token de solo lectura, aprobación de forks y SHA obligatorio; `ci.yml` (push a `main`, `pull_request`, `workflow_dispatch`) con los jobs `runner-info` y `structure` en paralelo, `contents: read` y `actions/checkout` fijado por SHA |
| 02 | Variable `PROJECT_NAME`; `ci.yml` con `defaults.run.shell: bash`, job `version` que publica `<versión de api/pyproject.toml>+<sha corto>` como output y job `summary` (`needs` de los otros tres, `if: !cancelled()`) que escribe el resumen en `$GITHUB_STEP_SUMMARY` y falla si alguno falló |
| 03 | `ci-api.yml` (push a `main`, `pull_request`, `workflow_dispatch`; `working-directory: api`) con los jobs `lint` (ruff check y format) y `test` (pytest de `tests/unit`, cobertura mínima del 60 %) en paralelo; `setup-uv` con versión fijada y caché atada a `api/uv.lock`; `uv sync --locked` siempre |
| 04 | `ci-web.yml` (`working-directory: web`): `lint`, `test` en matriz con Node 24 y 26 sin `fail-fast`, `build` (necesita los dos) que sube `web/dist` como artefacto `web-dist` durante 7 días y `dist-report`, que lo descarga y resume su tamaño; pnpm con `--frozen-lockfile` y caché del store |
| 05 | `ci-api.yml` gana `integration` (`needs: test`): `postgres:17.11-alpine` como service container con healthcheck `pg_isready`, `DATABASE_URL` a `localhost:5432`, migraciones, `pytest tests/integration -rs` y `docker logs` del servicio con `if: failure()`. Nuevo `smoke.yml`: `docker compose up --build --wait`, `scripts/smoke-test.sh` a través de nginx, logs al fallar y `down --volumes` con `always()` |
| 06 | `images.yml`: job `build` en matriz `api`/`web` (`fail-fast: false`, `packages: write` solo en el job); `metadata-action` con `type=sha` y `type=ref`, sin `latest`; login a GHCR y push solo fuera de los PR; caché `type=gha` con `scope` por imagen y `mode=max`; digest al resumen por `env:`. `tablero-api` y `tablero-web` públicas en `ghcr.io/<tu-org>/` |
| 07 | `paths` en `ci-api`, `ci-web`, `smoke` e `images` (su carpeta y su propio YAML; `ci.yml` sigue corriendo siempre); `concurrency` por workflow y ref con `cancel-in-progress` solo en PR; `timeout-minutes` en todo job. Nuevo `nightly.yml`: cron `17 3 * * *` y `workflow_dispatch` con input `target` (choice); `github-script` con `actions: write` solo en el job lanza `ci-api`, `ci-web` y `smoke` sobre `main` |
| 08 | `lint-workflows.yml` con `paths` en `.github/workflows/**` y `.github/actionlint-matcher.json`: job `actionlint` (1.7.12 desde la release con checksum y `.github/actionlint-matcher.json` registrado) y job `zizmor` (1.31.1 con `uv tool install`, `--offline --format=github`), los errores como anotaciones del PR. `scripts/ci-local.sh` envuelve act 0.2.94 con `catthehacker/ubuntu:act-24.04-20260815` |
| 09 | Reutilizables `_python.yml` (inputs `working-directory`, `package`, `coverage-min`, `integration`), `_node.yml` (`node-versions` como lista JSON, output `artifact-name`) e `_image.yml` (`component`, `push`, secreto `registry-password`, output `digest`), solo con `workflow_call`. `ci-api`, `ci-web` e `images` pasan a llamarlos con `./` y su reutilizable en `paths`; `images` concede `packages: write` por job y resume los dos digests; sin `secrets: inherit` |
| 10 | Actions en `.github/actions/`: `setup-tablero` (composite: uv o pnpm con Node y el lockfile; inputs `stack`, `working-directory`, `node-version`; output `tool-version`), usada por los seis jobs de `_python.yml` y `_node.yml`; `coverage-report` (JavaScript `node24` con `@actions/core` 3.0.1, pnpm y esbuild a `dist/*.cjs` comiteado; resumen del job, output `percent`, mínimo 60 %, post con `$GITHUB_STATE`) en el job `coverage` de `ci-web`; `sql-lint` (Docker con sqlfluff 4.5.0, anotaciones en el diff, `exclude-rules: LT01`) en el job `sql` de `ci`. Nuevo `test-actions.yml`: tests de `coverage-report` y `git diff --exit-code -- dist` |
| 11 | Repo central `<tu-org>/actions-tablero`: las tres actions en su raíz y `_python.yml`, `_node.yml` e `_image.yml` en `.github/workflows/`, cuyos jobs preparan el entorno con `$/setup-tablero`; su `ci.yml` (actionlint con `.github/actionlint.yaml` que tolera `$/`, zizmor sobre todo el repo, tests y `dist/` de `coverage-report`, humo de `sql-lint`) y release inmutable `v1.0.0`. `tablero` borra `.github/actions/`, sus `_*.yml` y `test-actions.yml`, y `ci-api`, `ci-web`, `images` y `ci` llaman al central por el SHA de `v1.0.0`. Repo `<tu-org>/.github` con la plantilla `ci-python`. Política de la org: actions seleccionadas (GitHub + patrones explícitos), SHA obligatorio, `GITHUB_TOKEN` de solo lectura |
| 12 | Permisos por job, zizmor sin hallazgos, Dependabot para actions, `uv` y pnpm (ecosistema `npm` de Dependabot) |
| 13 | Environments `staging` y `production` con secretos propios; `tools/oidc-verifier/` valida el token OIDC del job |
| 14 | `release.yml`: release-please, imágenes versionadas, SBOM, attestation de procedencia, escaneo y dependency-review. Imágenes base y de services fijadas por digest |
| 15 | Runner propio efímero (JIT) en Docker, en un runner group restringido a `tablero` |
| 16 | Scale set `tablero-runners` de ARC en kind, autenticado con una GitHub App |
| 17 | `deploy.yml`: despliegue por digest a kind, staging automático, production con aprobación y rollback automático |
| 18 | Ruleset en `main`, job puerta `ci-gate` como único check requerido, merge queue con `merge_group` |
| 19 | Línea base de tiempos medida y optimizada; `ci-metrics.yml` con métricas por API; limpieza programada de cachés y artefactos |
| 20 | Capstone: componente nuevo `worker/` integrado solo con llamadas a los reutilizables, auditoría completa y defensa |

## Regla de continuidad

- **Cada capa parte de la anterior ya entregada.** El starter de una semana trae el workflow de la
  semana anterior tal como quedó resuelto, con los huecos de la capa nueva. Si te quedaste atrás,
  primero cierras la semana anterior.
- **El starter solo contiene lo que la capa añade o cambia.** Los workflows que no cambian siguen
  en tu repo como los dejaste.
- **Ninguna capa pide algo que todavía no se enseñó.** Si una semana necesita un concepto
  posterior, lo trae escrito y anotado "lo verás en la Semana NN".
- **`app/` evoluciona solo cuando una capa lo necesita**: `tools/oidc-verifier/` llega en la S13,
  `deploy/k8s/` en la S17 y `worker/` en la S20. Cada semana dice qué copiar de nuevo.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Autograding](autograding.md) | [Mapa de funcionalidades](mapa-funcionalidades.md) |
