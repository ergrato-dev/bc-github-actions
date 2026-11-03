---
name: verify-progression
description: Comprueba que una semana del bootcamp GitHub Actions no usa funcionalidades que se enseñan en una semana posterior (matrices antes de la 04, services antes de la 05, workflow_call antes de la 09, pull_request_target antes de la 12...). Úsalo sobre la teoría, las prácticas y el starter de cualquier semana antes de publicarla.
allowed-tools: Read Grep Glob
---

# Verificar progresión

El bootcamp empieza en cero. Un `workflow_call` en la Semana 03 o un `environment:` en la 06 no es un atajo: el alumno lo copia sin saber qué es y no puede depurarlo cuando falla.

## 1. Cuándo se introduce cada funcionalidad

| Semana | Se introduce | Patrón de búsqueda |
|:--:|---|---|
| 01 | `on:`, `jobs`, `steps`, `run`, `uses`, `runs-on`, `gh run`, actionlint, pinning por SHA | — |
| 02 | expresiones, contextos, `if:`, funciones de estado, `env:`, `vars.`, `defaults:`, `GITHUB_OUTPUT/ENV/STEP_SUMMARY`, `needs:`, `outputs:` | `needs:\|GITHUB_OUTPUT\|GITHUB_ENV\|STEP_SUMMARY\|vars\.\|always\(\)\|failure\(\)` |
| 03 | setup-uv, `uv sync`, ruff, pytest, `actions/cache` | `setup-uv\|actions/cache` |
| 04 | `pnpm/action-setup`, `setup-node`, `strategy.matrix`, artefactos | `matrix:\|upload-artifact\|download-artifact\|pnpm/action-setup` |
| 05 | `services:`, `container:`, `docker compose` | `services:\|container:\|docker compose` |
| 06 | buildx, `build-push-action`, `metadata-action`, `login-action`, GHCR, `packages: write` | `build-push-action\|ghcr\.io\|packages: write` |
| 07 | `paths:`, `schedule:`, `workflow_dispatch` con `inputs`, `workflow_run`, `repository_dispatch`, `concurrency:`, `timeout-minutes`, `github-script` | `paths:\|schedule:\|workflow_run\|repository_dispatch\|concurrency:\|github-script` |
| 08 | zizmor, act, debug logging, comandos de workflow (`::error`, `::group`) | `zizmor\|\bact \|ACTIONS_STEP_DEBUG\|::error\|::group` |
| 09 | `workflow_call`, llamada a reutilizable a nivel de job, `secrets: inherit` | `workflow_call\|uses: \./\.github/workflows/` |
| 10 | `action.yml`, `using: composite\|node\|docker`, `pre`/`post`, `GITHUB_STATE` | `using: \|GITHUB_STATE\|@actions/core` |
| 11 | reutilizable de otro repo, workflow templates, políticas de la org, rulesets que exigen workflows | `workflow-templates\|uses: [^.][^ ]*/\.github/workflows/` |
| 12 | `pull_request_target`, permisos por job a fondo, Dependabot, CodeQL | `pull_request_target\|dependabot\|codeql` |
| 13 | `environment:`, `id-token: write`, `::add-mask::`, secretos de environment | `environment:\|id-token\|add-mask` |
| 14 | release-please, attestations, SBOM, Trivy, dependency-review | `release-please\|attest\|sbom\|trivy\|dependency-review` |
| 15 | `self-hosted`, etiquetas propias, runner JIT, runner groups | `self-hosted\|generate-jitconfig\|runner-groups` |
| 16 | kind, kubectl, Helm, ARC | `kubectl\|helm \|scale-set\|kind create` |
| 17 | despliegue a Kubernetes, deployments de GitHub, rollback | `kubectl rollout\|/deployments` |
| 18 | `merge_group`, rulesets, CODEOWNERS | `merge_group\|rulesets\|CODEOWNERS` |
| 19 | métricas por API, retención de repo u organización | `actions/runs.*timing\|actions/permissions/artifact-and-log-retention` |

Excepciones legítimas que **no** cuentan como hallazgo:

- `permissions:` con `contents: read` desde la 01, anotado "lo verás a fondo en la Semana 12".
- `persist-credentials: false` en checkout desde la 01, anotado igual.
- `secrets.GITHUB_TOKEN` desde la 06 (login a GHCR): el token automático se explica ahí; los secretos propios esperan a la 13.
- `timeout-minutes` antes de la 07 si va anotado "lo verás en la Semana 07".
- `retention-days` en la 04 (artefactos): la limpieza a fondo es de la 19.
- `scripts/`, `lab/`, `app/` y el CI propio del bootcamp: son infraestructura, no contenido.

## 2. Cómo buscar

Para la semana `NN`, busca en su teoría, sus prácticas y su proyecto todos los patrones de las semanas posteriores:

```bash
w=bootcamp/week-NN-*
grep -rnE 'workflow_call|pull_request_target|environment:' $w/1-teoria $w/2-practicas $w/3-proyecto
```

Ignora `4-recursos/` y `5-glosario/`.

## 3. Veredictos

| Caso | Veredicto |
|---|---|
| Funcionalidad futura explicada como si ya se supiera | 🔴 |
| Funcionalidad futura en un workflow que el alumno escribe o completa | 🔴 |
| Funcionalidad futura con la anotación "lo verás en la Semana NN" | ✅ |
| Funcionalidad en su semana o después | ✅ |

## 4. Informe

```
ruta:línea: 🔴 adelantado: "<cita literal>". Se enseña en la Semana NN. Anotar o sustituir por <alternativa>.
```

Cita literalmente. Si no hay hallazgos, di qué patrones buscaste y en qué archivos.
