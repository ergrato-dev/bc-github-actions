# 🌐 Webgrafía — Semana 07

Documentación oficial y artículos de referencia. Las referencias son para consultar, no para leer de
corrido.

## Eventos y filtros

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows) | Cada evento con sus tipos de actividad, el `GITHUB_SHA` y el `GITHUB_REF` que recibe. Mira `schedule`, `workflow_dispatch`, `repository_dispatch` y `workflow_run` | 2026-11-02 |
| [Workflow syntax: `on.<event>.paths`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onpushpull_requestpull_request_targetpathspaths-ignore) | `paths`, `paths-ignore`, los diff de dos y tres puntos y los límites de 1.000 commits y 3.000 archivos | 2026-11-02 |
| [Workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) | La referencia de `on`, `concurrency` y `timeout-minutes`, en el nivel del workflow y en el del job | 2026-11-02 |
| [Triggering a workflow](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow) | Por qué un evento del `GITHUB_TOKEN` no crea runs y sus dos excepciones, con los filtros de ramas y rutas | 2026-11-02 |
| [Troubleshooting required status checks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks) | Por qué un check obligatorio de un workflow saltado por `paths` deja el PR en estado "Pending" y bloquea la fusión | 2026-11-02 |
| [Webhook events and payloads](https://docs.github.com/en/webhooks/webhook-events-and-payloads) | Qué trae `github.event` en cada evento, incluidos `workflow_run` y `repository_dispatch` | 2026-11-02 |

## Cron y lanzamiento manual

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [crontab.guru](https://crontab.guru/) | Pega una expresión de cinco campos y te la lee en inglés con las próximas ejecuciones. Recuerda que GitHub la evalúa en UTC salvo con `timezone` | 2026-11-02 |
| [List of tz database time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) | Los nombres IANA válidos para `timezone`, como `Europe/Madrid` o `America/Bogota` | 2026-11-02 |
| [Manually running a workflow](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow) | El botón, `gh workflow run` y la API, y quién puede lanzar | 2026-11-02 |
| [Disabling and enabling a workflow](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/disable-and-enable-workflows) | Apagar un cron sin tocar el YAML y la desactivación por 60 días de inactividad | 2026-11-02 |
| [`gh workflow run`](https://cli.github.com/manual/gh_workflow_run) | `-f`, `-F`, `--ref` y `--json` por la entrada estándar, como en la práctica 03 | 2026-11-02 |
| [`gh workflow disable`](https://cli.github.com/manual/gh_workflow_disable) | El comando del paso 6 de la práctica 03 | 2026-11-02 |

## Concurrencia, timeouts y cancelación

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Concurrency](https://docs.github.com/en/actions/concepts/workflows-and-actions/concurrency) | El concepto: un run en curso, uno pendiente, y el pendiente que se sustituye | 2026-11-02 |
| [Control the concurrency of workflows and jobs](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency) | Ejemplos de grupos por workflow y ref y de `cancel-in-progress` con expresión | 2026-11-02 |
| [Workflow cancellation](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-cancellation) | La secuencia exacta al cancelar: reevaluar `if:`, `SIGINT`, 7,5 s, `SIGTERM`, 2,5 s y kill | 2026-11-02 |
| [Canceling a workflow run](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/cancel-a-workflow-run) | Cancelar un run desde la UI, y en qué estado quedan sus jobs y steps | 2026-11-02 |
| [`gh run cancel`](https://cli.github.com/manual/gh_run_cancel) | Incluye `--force`, para cuando un step con `always()` no deja morir el run | 2026-11-02 |
| [Using conditions to control job execution](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-jobs-with-conditions) | Cómo un `if:` en el job decide si corre, también tras una cancelación | 2026-11-02 |
| [Expressions: status check functions](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions) | `success()`, `failure()`, `cancelled()` y `always()`, y por qué una cadena no vacía es verdadera | 2026-11-02 |
| [Actions limits](https://docs.github.com/en/actions/reference/limits) | Las 6 horas por job, el tiempo máximo en cola y los 100 runs por grupo de concurrencia que admite `queue` | 2026-11-02 |

## Encadenar y github-script

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [actions/github-script](https://github.com/actions/github-script) | `github`, `context`, `core`, `result-encoding`, `retries` y los cambios de v9. Léelo en el SHA fijado | 2026-11-02 |
| [Octokit REST.js](https://octokit.github.io/rest.js/) | Los métodos de `github.rest.*` que usas dentro de `script:` | 2026-11-02 |
| [REST API: Workflows](https://docs.github.com/en/rest/actions/workflows) | El endpoint `POST .../workflows/{workflow_id}/dispatches` que llama `nightly.yml` | 2026-11-02 |
| [REST API: Repositories](https://docs.github.com/en/rest/repos/repos) | El endpoint `POST /repos/{owner}/{repo}/dispatches` de `repository_dispatch`, con `event_type` y `client_payload` | 2026-11-02 |
| [REST API: Workflow runs](https://docs.github.com/en/rest/actions/workflow-runs) | Leer un run y sus jobs, como en el paso 6 de la práctica 04 | 2026-11-02 |
| [`GITHUB_TOKEN`](https://docs.github.com/en/actions/concepts/security/github_token) | Los permisos del token y por qué sus eventos no disparan workflows | 2026-11-02 |
| [Contexts](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts) | `inputs`, `github.event.inputs` y en qué claves está disponible cada contexto, como en `concurrency` | 2026-11-02 |
| [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use) | La inyección por expresiones, también dentro de `script:` | 2026-11-02 |
| [zizmor: audits](https://docs.zizmor.sh/audits/#template-injection) | La regla `template-injection`, que detecta `${{ }}` dentro de `run:` y de `script:` | 2026-11-02 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
