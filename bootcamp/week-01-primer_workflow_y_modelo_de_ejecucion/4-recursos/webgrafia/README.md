# 🌐 Webgrafía — Semana 01

Documentación oficial y artículos de referencia. Las referencias de sintaxis son para consultar,
no para leer de corrido.

## Documentación de GitHub Actions

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Understand GitHub Actions](https://docs.github.com/en/actions/get-started/understand-github-actions) | El modelo evento → workflow → job → step → runner con las palabras oficiales. Base de la teoría 01 | 2026-11-02 |
| [Quickstart for GitHub Actions](https://docs.github.com/en/actions/get-started/quickstart) | El primer workflow según GitHub. Compáralo con tu `hello.yml` de la práctica 02 | 2026-11-02 |
| [Workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) | Todas las claves de un workflow. Consúltala cada vez que dudes de un campo: lo que no está aquí no existe | 2026-11-02 |
| [Events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows) | Qué `GITHUB_SHA` y `GITHUB_REF` trae cada evento. La tabla de `pull_request` explica el commit de merge de la teoría 05 | 2026-11-02 |
| [GitHub-hosted runners (referencia)](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) | Etiquetas disponibles y recursos de cada máquina (CPU, memoria, disco) según el tipo de repo | 2026-11-02 |
| [Using workflow run logs](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs) | Buscar en el log, descargarlo y verlo con marcas de tiempo, desde la UI | 2026-11-02 |
| [Re-running workflows and jobs](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs) | Qué repite un re-run y qué no (mismo SHA, mismo evento). Pregunta 10 de la rúbrica | 2026-11-02 |
| [Manually running a workflow](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow) | `workflow_dispatch` desde la UI y desde `gh`, y por qué el archivo tiene que estar en la rama por defecto | 2026-11-02 |
| [GITHUB_TOKEN](https://docs.github.com/en/actions/concepts/security/github_token) | Qué es el token de cada job, cuándo caduca y cómo se limitan sus permisos | 2026-11-02 |
| [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use) | La guía oficial de endurecimiento. Esta semana lee la sección de actions de terceros y pinning por SHA | 2026-11-02 |
| [REST API: GitHub Actions permissions](https://docs.github.com/en/rest/actions/permissions) | Los endpoints que lee `check-week.sh 01`: token por defecto, aprobación de forks y `sha_pinning_required` | 2026-11-02 |
| [Creating a new organization from scratch](https://docs.github.com/en/organizations/collaborating-with-groups-in-organizations/creating-a-new-organization-from-scratch) | Paso 1 de la práctica 01 según la documentación oficial | 2026-11-02 |

## Runners y actions

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [actions/runner-images](https://github.com/actions/runner-images) | A qué imagen apunta cada etiqueta hoy (`ubuntu-latest`, `ubuntu-24.04`, `ubuntu-26.04`) y el software exacto que trae cada una | 2026-11-02 <!-- antipatron --> |
| [actions/checkout](https://github.com/actions/checkout) | El README de la primera action que usas, con `persist-credentials` explicado | 2026-11-02 |
| [GitHub Actions policy now supports blocking and SHA pinning actions](https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/) — GitHub Changelog | El anuncio de la política que activas en la práctica 04 | 2026-11-02 |

## Herramientas

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [actionlint](https://github.com/rhysd/actionlint) | El linter de workflows que usarás todo el bootcamp | 2026-11-02 |
| [actionlint — Checks](https://github.com/rhysd/actionlint/blob/main/docs/checks.md) | Cada error que detecta, con ejemplo. Útil cuando un mensaje no se entiende | 2026-11-02 |
| [gh run](https://cli.github.com/manual/gh_run) | Manual de `gh run list`, `view`, `watch` y `rerun` de la práctica 03 | 2026-11-02 |
| [gh workflow run](https://cli.github.com/manual/gh_workflow_run) | Lanzar un `workflow_dispatch` desde la terminal, con `--ref` y campos | 2026-11-02 |

## YAML y seguridad

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [YAML 1.2.2](https://yaml.org/spec/1.2.2/) | La especificación. Consulta los capítulos de escalares y bloques literales cuando un valor no se lea como esperas | 2026-11-02 |
| [The Norway Problem](https://hitchdev.com/strictyaml/why/implicit-typing-removed/) — HitchDev | Por qué `NO` y `on` se convierten en booleanos en YAML 1.1: la trampa de la teoría 02 | 2026-11-02 |
| [GHSA-mw4p-6x4p-x5m5](https://github.com/tj-actions/changed-files/security/advisories/GHSA-mw4p-6x4p-x5m5) — tj-actions/changed-files | El aviso oficial del ataque de marzo de 2025 a una action fijada por tag | 2026-11-02 |
| [tj-actions/changed-files supply chain attack](https://www.wiz.io/blog/github-action-tj-actions-changed-files-supply-chain-attack-cve-2025-30066) — Wiz | Cómo se movieron los tags y qué se filtró, paso a paso. El caso real detrás de la teoría 07 | 2026-11-02 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
