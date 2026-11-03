# 🗺️ Mapa de funcionalidades

Qué funcionalidad de GitHub Actions se introduce en cada semana. Lo usan el skill
`verify-progression` (para que ninguna semana use algo que se enseña después) y el agente
`curriculum-coherence-reviewer`.

La columna GH-200 usa los cuatro dominios del examen tal como se publicaron hasta 2025. **Se
comprueban contra la guía de estudio vigente antes de escribir la Semana 20** y esta tabla se
corrige si han cambiado.

| Dominio GH-200 | Abreviatura |
|---|---|
| Author and maintain workflows | D1 |
| Consume workflows | D2 |
| Author and maintain actions | D3 |
| Manage GitHub Actions in the enterprise | D4 |

## Por semana

| Sem | Se introduce | GH-200 |
|:--:|---|:--:|
| 01 | `on: push / pull_request / workflow_dispatch`, `branches` en push, `jobs`, `steps`, `run`, `uses`, `name`, `runs-on`, `permissions` en la raíz (solo `contents: read`), `persist-credentials`, logs, `gh run list/view/watch/rerun`, `gh workflow run`, actionlint, pinning por SHA y `sha_pinning_required`, ajustes de Actions del repo (token por defecto, aprobación de forks) | D1, D2, D4 |
| 02 | Expresiones `${{ }}`, contextos, funciones, `if:`, funciones de estado, `env:`, `vars.`, `defaults:`, `$GITHUB_OUTPUT`, `$GITHUB_ENV`, `$GITHUB_STEP_SUMMARY`, `continue-on-error`, `steps.<id>.outcome` / `conclusion`, `needs:`, `outputs:` de job | D1 |
| 03 | `astral-sh/setup-uv`, `uv sync --locked`, ruff, pytest con cobertura, `actions/cache`, `gh cache list/delete` | D1 |
| 04 | `pnpm/action-setup`, `actions/setup-node`, `strategy.matrix` (`include`, `exclude`, `fail-fast`, `max-parallel`, `fromJSON`), `upload-artifact` / `download-artifact`, retención | D1, D2 |
| 05 | `services:` (`image`, `env`, `ports`, `options`), `container:`, contexto `job.services`, `docker compose` en CI, healthchecks | D1 |
| 06 | `docker/setup-buildx-action`, `build-push-action`, `metadata-action`, `login-action`, GHCR, `packages: write`, `secrets.GITHUB_TOKEN`, caché `type=gha` | D1, D2 |
| 07 | Filtros `branches` / `paths` / `tags`, `schedule:`, `workflow_dispatch.inputs`, `workflow_run`, `repository_dispatch`, `concurrency:`, `timeout-minutes`, `actions/github-script` | D1 |
| 08 | zizmor (primer contacto), act, `ACTIONS_STEP_DEBUG` / `ACTIONS_RUNNER_DEBUG`, `::error` / `::warning` / `::group`, problem matchers | D1, D2 |
| 09 | `on: workflow_call` (inputs, secrets, outputs), llamada con `uses:` a nivel de job, `secrets: inherit` (y por qué no), límites de anidamiento | D1, D2 |
| 10 | `action.yml`, `runs.using: composite / node / docker`, `pre` / `post`, `$GITHUB_STATE`, `@actions/core` con pnpm, empaquetado de `dist/` | D3 |
| 11 | Publicar y versionar actions, releases inmutables, repo central de CI, workflow templates (`.github/workflow-templates`), políticas de actions de la org, rulesets que exigen workflows | D3, D4 |
| 12 | Permisos del `GITHUB_TOKEN` por job, inyección de scripts, `pull_request_target`, `workflow_run` seguro, cache poisoning, Dependabot para actions, zizmor a fondo, CodeQL para workflows | D2, D4 |
| 13 | Secretos de repo, environment y org, enmascarado (`::add-mask::`), `environment:`, reglas de protección, `permissions: id-token: write`, token OIDC y sus claims, personalización de `sub` | D2, D4 |
| 14 | release-please, imágenes por versión, SBOM, `actions/attest`, `gh attestation verify`, Trivy, `dependency-review-action` | D2, D4 |
| 15 | `runs-on: [self-hosted, …]`, etiquetas, runner JIT, runner en contenedor, runner groups | D4 |
| 16 | kind, kubectl, Helm (lo justo), ARC: controller, scale sets, modos de contenedor, autenticación con GitHub App | D4 |
| 17 | Despliegue por digest, environments en el despliegue, deployments de GitHub, rollout y rollback, promoción staging → production | D1, D2 |
| 18 | Rulesets, checks requeridos, job puerta, `on: merge_group`, merge queue, CI de lo afectado, CODEOWNERS para `.github/` | D1, D4 |
| 19 | Facturación y minutos, camino crítico, caché a fondo, sharding, métricas con `gh api`, `gh cache`, retención y limpieza | D2, D4 |
| 20 | Integración de todo lo anterior | D1-D4 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto hilo conductor: tablero](proyecto-hilo-conductor.md) | [Reglas de seguridad de workflows](reglas-de-seguridad-de-workflows.md) |
