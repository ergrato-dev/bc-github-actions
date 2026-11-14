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
| 08 | zizmor (primer contacto), act, `ACTIONS_STEP_DEBUG` / `ACTIONS_RUNNER_DEBUG`, `::error` / `::warning` / `::notice` / `::debug` / `::group`, `::add-mask`, `::stop-commands`, problem matchers (`::add-matcher` / `::remove-matcher`), `runner.debug`, `gh run rerun --failed --debug`, `gh run view --log-failed` | D1, D2 |
| 09 | `on: workflow_call` (inputs, secrets, outputs), llamada con `uses:` a nivel de job (`./`, `$/` (sintaxis y por qué `tablero` sigue en `./`) y `owner/repo/...@sha`), `secrets: inherit` (y por qué no), contexto `github` y permisos en el llamado, `cache-mode`, límites de anidamiento | D1, D2 |
| 10 | `action.yml` (`inputs`, `outputs`, `runs`), `runs.using: composite / node24 / docker`, `shell:` obligatorio en composite, `pre` / `post` / `post-if`, `$GITHUB_STATE`, `@actions/core` con pnpm, empaquetado de `dist/` con esbuild, `INPUT_<NOMBRE>` en Docker, actions locales con `uses: ./` | D3 |
| 11 | Repo central de CI, `$/` en steps de un reutilizable llamado desde otro repo y su tolerancia en actionlint, contexto `job.workflow_*`, configuración de actionlint (`paths.ignore`), SemVer de actions y tag mayor, releases inmutables y `gh release verify`, publicar en el Marketplace (`branding`), acceso a actions de repos privados, workflow templates (`workflow-templates/` del repo `.github`, `.properties.json`, `$default-branch`), políticas de actions de la org (`allowed_actions`, patrones, `sha_pinning_required`, token por defecto), rulesets que exigen workflows (solo teoría: plan Team) | D3, D4 |
| 12 | Modelo de amenazas, permisos del `GITHUB_TOKEN` (`permissions: {}`, por job, techo de los reutilizables, recorte en forks), aprobación de workflows de colaboradores externos, inyección de scripts y `env:`, `pull_request_target` y `workflow_run` con el patrón seguro (`actions/labeler`, artefacto entre runs), cache poisoning, ámbitos de caché y `cache-mode`, artifact poisoning, commits impostores, Dependabot para actions con `cooldown` y `groups`, lockfiles de workflows (teoría), zizmor online y excepciones justificadas, CodeQL para workflows y code scanning | D2, D3, D4 |
| 13 | Secretos de repo, environment y org (precedencia, visibilidad, `gh secret set --env/--org`), enmascarado a fondo (`::add-mask::` llega en la 08), variables de environment, `environment:`, reglas de protección (revisores, wait timer, ramas permitidas, `prevent_self_review`), aprobación con la API de `pending_deployments`, `permissions: id-token: write`, token OIDC y sus claims, `sub` por defecto e inmutable, personalización de `sub` (`include_claim_keys`), verificación del JWT contra el JWKS del emisor | D2, D4 |
| 14 | release-please en modo manifest (`release-please-config.json`, `.release-please-manifest.json`, outputs `release_created`/`version`/`tag_name`, `Release-As`), permiso de `GITHUB_TOKEN` para crear PR y por qué sus releases no disparan workflows, imágenes por versión en el mismo run, imágenes base, `COPY --from` y de services fijadas por tag y digest, Dependabot `docker`, SBOM SPDX con syft (binario con checksum), `actions/attest` (procedencia SLSA y SBOM, `push-to-registry`, permisos `attestations` y `artifact-metadata`), Sigstore (Fulcio, Rekor), `gh attestation verify` (`--repo`, `--signer-workflow`, `--predicate-type`), Trivy (binario con checksum, `--severity`, `--ignore-unfixed`, `--exit-code`), dependency graph y sus límites (`uv.lock`, lockfile de pnpm 11+), API de dependency submission, `dependency-review-action` (`fail-on-severity`, `retry-on-snapshot-warnings`) | D2, D4 |
| 15 | `runs-on: [self-hosted, …]` y `group:`, etiquetas por defecto y propias (`actionlint.yaml`), registro y sondeo del runner, actualizaciones (63 días), runner persistente, `--ephemeral` y JIT (`generate-jitconfig`, `ACTIONS_RUNNER_INPUT_JITCONFIG`), imagen `ghcr.io/actions/actions-runner` en contenedor endurecido, runners de repo y de org, runner groups (Team), política de runners de repositorio de la org, runner propio en repo público y aprobación de forks | D4 |
| 16 | kind, kubectl, Helm (lo justo: charts OCI, releases, values), ARC: controller, listener, scale sets (`runnerScaleSetName`, `scaleSetLabels`, `minRunners`/`maxRunners`), runners efímeros, modos de contenedor (`dind`, `kubernetes`, `kubernetes-novolume`), autenticación con GitHub App, pod del runner endurecido (`securityContext`, `automountServiceAccountToken`) | D4 |
| 17 | Despliegue por digest, environments en el despliegue, deployments de GitHub, rollout y rollback, promoción staging → production | D1, D2 |
| 18 | Rulesets, checks requeridos, job puerta, `on: merge_group`, merge queue, CI de lo afectado, CODEOWNERS para `.github/`, revisión obligatoria en el ruleset (cierra `can_approve_pull_request_reviews` de la S14) y release-please con el token de una GitHub App para que su PR pase los checks requeridos | D1, D4 |
| 19 | Facturación y minutos, camino crítico, caché a fondo, sharding, métricas con `gh api`, `gh cache`, retención y limpieza | D2, D4 |
| 20 | Integración de todo lo anterior | D1-D4 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto hilo conductor: tablero](proyecto-hilo-conductor.md) | [Reglas de seguridad de workflows](reglas-de-seguridad-de-workflows.md) |
