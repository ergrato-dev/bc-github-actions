# 🌐 Webgrafía — Semana 19

Documentación oficial, por temas: facturación, tiempos de un run, caché, paralelismo, clon
parcial, métricas y retención. Los precios y los cupos cambian: antes de estimar un coste, vuelve a
las dos primeras páginas. La documentación de GitHub cambia de ruta a menudo: si un enlace falla,
busca el título en docs.github.com.

### Facturación

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions) | Qué consume y qué no, el cupo de cada plan, el redondeo por job y el almacenamiento de artefactos y caché (teoría 01) | 2026-11-14 |
| [Actions runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing) | El precio por minuto de cada tipo de runner, la cifra que multiplica tu estimación | 2026-11-14 |
| [Setting up budgets](https://docs.github.com/en/billing/how-tos/set-up-budgets) | Presupuestos y alertas de gasto, y qué se detiene al agotarlos | 2026-11-14 |

### Tiempos de un run

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [REST API endpoints for workflow jobs](https://docs.github.com/en/rest/actions/workflow-jobs) | `created_at`, `started_at` y `completed_at` de cada job y de cada step: la entrada de `job-timings.sh` | 2026-11-14 |
| [REST API endpoints for workflow runs](https://docs.github.com/en/rest/actions/workflow-runs) | La lista de runs que lee `ci-trend.sh`, `run_started_at` y el endpoint `timing` | 2026-11-14 |
| [gh run view](https://cli.github.com/manual/gh_run_view) | Los campos de `--json jobs` para medir un run a mano (práctica 01, paso 1) | 2026-11-14 |

### Caché

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Dependency caching reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching) | Orden de búsqueda, alcance por ref, eventos que solo leen la rama por defecto, expulsión y límites: la fuente de la teoría 03 | 2026-11-14 |
| [Managing caches](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manage-caches) | Ver y borrar cachés desde la UI, y el ejemplo oficial de limpiar las de un PR cerrado | 2026-11-14 |
| [REST API endpoints for GitHub Actions cache](https://docs.github.com/en/rest/actions/cache) | `usage`, `retention-limit`, `storage-limit` y los `DELETE` por clave o por id (prácticas 02 y 04) | 2026-11-14 |
| [actions/cache](https://github.com/actions/cache) | Los inputs `key` y `restore-keys` y la salida `cache-hit`, en el `action.yml` de la versión fijada | 2026-11-14 |
| [Tips and workarounds de actions/cache](https://github.com/actions/cache/blob/main/tips-and-workarounds.md) | Casos raros de la caché: claves que no casan, entradas inmutables, ramas que no comparten | 2026-11-14 |
| [gh cache list](https://cli.github.com/manual/gh_cache_list) · [gh cache delete](https://cli.github.com/manual/gh_cache_delete) | `--json id,ref`, `--ref` y por qué borrar por id: los dos comandos de `prune-caches.sh` | 2026-11-14 |
| [uv: caching in continuous integration](https://docs.astral.sh/uv/concepts/cache/) | Qué guarda la caché de uv y cómo podarla antes de subirla | 2026-11-14 |
| [pnpm: continuous integration](https://pnpm.io/continuous-integration) | La caché del store de pnpm en CI, la que restaura `setup-node` en `web` | 2026-11-14 |

### Paralelismo y clon parcial

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Running variations of jobs in a workflow](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations) | Matrices, `fail-fast` y `max-parallel`: el mecanismo de los shards | 2026-11-14 |
| [Vitest: improving performance](https://vitest.dev/guide/improving-performance.html) | `--shard`, el reporter `blob` y `--merge-reports` con un ejemplo para Actions (teoría 04) | 2026-11-14 |
| [Vitest CLI](https://vitest.dev/guide/cli.html) | La sintaxis exacta de `--shard <index>/<count>` | 2026-11-14 |
| [actions/checkout](https://github.com/actions/checkout) | Los inputs `fetch-depth` y `filter` del job `changes` | 2026-11-14 |
| [Partial clone](https://git-scm.com/docs/partial-clone) | El diseño del clon parcial en git y cómo pide los objetos que faltan | 2026-11-14 |
| [Get up to speed with partial clone and shallow clone](https://github.blog/open-source/git/get-up-to-speed-with-partial-clone-and-shallow-clone/) — GitHub Blog | Clon sin blobs, sin árboles y superficial comparados, con cuándo cada uno sale caro (teoría 05) | 2026-11-14 |

### Métricas y observabilidad

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [About GitHub Actions metrics](https://docs.github.com/en/actions/concepts/metrics) | Qué miden Actions Performance Metrics y Actions Usage Metrics, y qué no | 2026-11-14 |
| [Viewing GitHub Actions metrics](https://docs.github.com/en/actions/how-tos/administer/view-metrics) | Dónde están en Insights de la org y cómo filtrarlas (práctica 03, paso 5) | 2026-11-14 |
| [Actions Performance Metrics are generally available](https://github.blog/changelog/2025-03-14-actions-performance-metrics-are-generally-available-and-enterprise-level-metrics-are-in-public-preview/) — GitHub Changelog | El anuncio que las abre a todos los planes de GitHub Cloud | 2026-11-14 |
| [Events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows) | `workflow_run`: solo desde la rama por defecto y su filtro `branches` (teoría 06) | 2026-11-14 |
| [Workflow commands](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands) | `::warning` con `title` y `$GITHUB_STEP_SUMMARY`, los dos destinos de `ci-trend.sh` | 2026-11-14 |
| [gh variable set](https://cli.github.com/manual/gh_variable_set) | Crear `CI_P95_BUDGET_SECONDS` desde la terminal | 2026-11-14 |

### Retención y limpieza

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [REST API endpoints for GitHub Actions permissions](https://docs.github.com/en/rest/actions/permissions) | `artifact-and-log-retention` del repo, lo que leen `artifact-retention` y la práctica 04 | 2026-11-14 |
| [Managing GitHub Actions settings for a repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository) | El mismo ajuste de retención desde la UI y cómo lo limita la org | 2026-11-14 |
| [Configuring the retention period for artifacts and logs in your organization](https://docs.github.com/en/organizations/managing-organization-settings/configuring-the-retention-period-for-github-actions-artifacts-and-logs-in-your-organization) | La retención a nivel de org, el techo de la del repo | 2026-11-14 |
| [REST API endpoints for GitHub Actions artifacts](https://docs.github.com/en/rest/actions/artifacts) | Listar y borrar los artefactos de un run (práctica 04, paso 5) | 2026-11-14 |
| [Removing workflow artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/remove-workflow-artifacts) · [Deleting a workflow run](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/delete-a-workflow-run) | Lo mismo desde la UI, con el aviso de que no se puede deshacer | 2026-11-14 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
