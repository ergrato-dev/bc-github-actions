# 🌐 Webgrafía — Semana 02

Documentación oficial y artículos de referencia. Las referencias son para consultar con un
workflow abierto al lado, no para leer de corrido.

## Referencias de sintaxis

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Contexts reference](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts) | Cada contexto con sus campos y, sobre todo, la tabla de **disponibilidad**: qué contexto puedes usar en `runs-on`, en `if:` de job o en `env:` de step. Base de la teoría 01 | 2026-11-02 |
| [Evaluate expressions in workflows and actions](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions) | Literales, operadores, conversión a booleano, funciones y funciones de estado. La referencia de la teoría 02 y la 03 | 2026-11-02 |
| [Variables reference](https://docs.github.com/en/actions/reference/workflows-and-actions/variables) | Las variables de entorno por defecto (`GITHUB_SHA`, `RUNNER_TEMP`...) y las reglas de nombres de las variables de configuración | 2026-11-02 |
| [Workflow commands for GitHub Actions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands) | `$GITHUB_OUTPUT`, `$GITHUB_ENV`, `$GITHUB_PATH`, `$GITHUB_STEP_SUMMARY` y el delimitador para valores multilínea. Base de la teoría 05 | 2026-11-02 |

## Cómo se hace

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Store information in variables](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-variables) | Variables de entorno en tres niveles y variables de configuración (`vars.`) de repo y de organización. Es lo que haces en la práctica 01, paso 3 | 2026-11-02 |
| [Setting a default shell and working directory](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/set-default-values-for-jobs) | `defaults.run` a nivel de workflow y de job. Explica el `TODO 1` del proyecto | 2026-11-02 |
| [Using conditions to control job execution](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-jobs-with-conditions) | `if:` a nivel de job y qué significa un job saltado para los que dependen de él | 2026-11-02 |
| [Using jobs in a workflow](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs) | `needs:` y el orden de ejecución, con un ejemplo de jobs que corren aunque falle uno anterior | 2026-11-02 |
| [Passing information between jobs](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/pass-job-outputs) | El patrón step → `$GITHUB_OUTPUT` → `outputs:` del job → `needs.<job>.outputs`. El job `version` del proyecto, paso a paso | 2026-11-02 |
| [Adding scripts to your workflow](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/add-scripts) | Cuándo sacar un `run:` largo a un script del repo. Útil si el resumen del job `summary` te crece | 2026-11-02 |

## Seguridad: datos no confiables

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Script injections](https://docs.github.com/en/actions/concepts/security/script-injections) | La explicación oficial de por qué un `${{ github.event.* }}` dentro de `run:` es código ejecutable, y la solución con `env:`. Lo comprueba `no-expressions-in-run` | 2026-11-02 |
| [Keeping your GitHub Actions and workflows secure Part 2: Untrusted input](https://securitylab.github.com/resources/github-actions-untrusted-input/) — GitHub Security Lab | El artículo de referencia: qué campos de un evento controla un atacante (títulos, ramas, cuerpos de PR) y ejemplos reales explotados. Lectura obligada antes de la Semana 12 | 2026-11-02 |

## Historia y novedades

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Deprecating save-state and set-output commands](https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/) — GitHub Changelog | Por qué se retiraron `::set-output` y `::save-state` y con qué se sustituyen. Te servirá para migrar workflows antiguos que encuentres por ahí | 2026-11-02 |
| [Supercharging GitHub Actions with Job Summaries](https://github.blog/news-insights/product-news/supercharging-github-actions-with-job-summaries/) — The GitHub Blog | Presentación de `$GITHUB_STEP_SUMMARY` con ejemplos de tablas en Markdown, como la del job `summary` | 2026-11-02 |
| [The Set Builtin](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html) — GNU Bash Manual | Qué hacen exactamente `-e` y `-o pipefail`, la diferencia entre el shell por defecto y `shell: bash` (teoría 04) | 2026-11-02 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
