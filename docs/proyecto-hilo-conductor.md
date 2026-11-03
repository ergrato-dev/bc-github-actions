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
| 01 | Org y repo `tablero` creados; `ci.yml` que pasa actionlint, con `contents: read` y toda `uses:` fijada por SHA |
| 02 | Grafo de jobs con `needs`, versión calculada y pasada como output de job, resumen en `$GITHUB_STEP_SUMMARY` |
| 03 | `ci-api.yml`: `uv sync --locked`, ruff, pytest con cobertura mínima y caché de uv |
| 04 | `ci-web.yml`: `pnpm install --frozen-lockfile`, lint, tests y build; matriz de versiones; `dist` como artefacto |
| 05 | Job `integration` contra PostgreSQL 17 como service container; smoke test con `docker compose up --wait` |
| 06 | `images.yml`: imágenes `tablero-api` y `tablero-web` construidas en cada PR y publicadas en GHCR desde `main`, con caché de capas y digest |
| 07 | Cada workflow corre solo si cambia su carpeta; `concurrency` cancela runs obsoletos de PR; `nightly.yml` con cron y `workflow_dispatch` |
| 08 | `lint-workflows.yml` (actionlint + zizmor en cada PR) y `scripts/ci-local.sh` con act |
| 09 | Reutilizables `_python.yml`, `_node.yml` e `_image.yml`; los CI de la capa 07 pasan a llamarlos |
| 10 | Actions propias: `setup-tablero` (composite), `coverage-report` (JavaScript con pnpm) y `sql-lint` (Docker) |
| 11 | Repo central `<tu-org>/actions-tablero` con v1 publicada y consumida por SHA; workflow templates y políticas de actions de la org |
| 12 | Permisos por job, zizmor sin hallazgos, Dependabot para actions, `uv` y pnpm (ecosistema `npm` de Dependabot) |
| 13 | Environments `staging` y `production` con secretos propios; `tools/oidc-verifier/` valida el token OIDC del job |
| 14 | `release.yml`: release-please, imágenes versionadas, SBOM, attestation de procedencia, escaneo y dependency-review |
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

[← Volver al índice de documentación](README.md)
