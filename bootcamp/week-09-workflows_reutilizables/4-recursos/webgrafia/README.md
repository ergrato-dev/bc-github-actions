# 🌐 Webgrafía — Semana 09

Documentación oficial y artículos de referencia. Las referencias son para consultar, no para leer de
corrido.

## Reutilizables en GitHub Docs

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Reusing workflow configurations (concepto)](https://docs.github.com/en/actions/concepts/workflows-and-actions/reusing-workflow-configurations) | Reutilizable, action composite y plantilla comparados: la tabla de la teoría 01 | 2026-11-03 |
| [Reusing workflow configurations (referencia)](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations) | `jobs.<job_id>.uses`, inputs, outputs, secretos, permisos, concurrencia y limitaciones: la fuente de casi toda la semana | 2026-11-03 |
| [Reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows) | Crear y llamar un reutilizable paso a paso, pasar secretos y ver qué reutilizables usa un run | 2026-11-03 |
| [Workflow syntax: `on.workflow_call`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onworkflow_call) | Las claves exactas de `inputs`, `outputs` y `secrets` y sus tipos | 2026-11-03 |
| [Contexts: `github`](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#github-context) | Qué ve el reutilizable: el contexto del llamador, `github.workflow` incluido | 2026-11-03 |
| [Expressions: `fromJSON`](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions#fromjson) | Cómo un input `string` con JSON se convierte en la matriz de `_node.yml` | 2026-11-03 |
| [Control the concurrency of workflows and jobs](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency) | Grupos y `cancel-in-progress`, para entender el interbloqueo de la teoría 05 | 2026-11-03 |

## Novedades de 2026

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Reference same-repository actions with self-repository syntax](https://github.blog/changelog/2026-07-30-reference-same-repository-actions-with-self-repository-syntax/) — GitHub Changelog | El anuncio de `$/`: mismo repo y commit sin checkout, solo en github.com | 2026-11-03 |
| [GitHub Actions: Early September 2026 updates](https://github.blog/changelog/2026-09-03-github-actions-early-september-2026-updates/) — GitHub Changelog | `job.workflow_ref` y `job.workflow_sha`: el reutilizable sabe qué archivo y commit define su job, cosa que `github.workflow_ref` (el del llamador) no dice | 2026-11-03 |

## Linters y pruebas locales

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [actionlint: reusable workflows](https://github.com/rhysd/actionlint/blob/main/docs/checks.md#check-reusable-workflows) | Qué comprueba actionlint de una llamada local: inputs, secretos y outputs contra el contrato | 2026-11-03 |
| [actionlint#711: Support the new `$/` self-repository `uses:` syntax](https://github.com/rhysd/actionlint/issues/711) | El issue abierto por el que `tablero` sigue en `./`. Vigílalo: cuando se cierre, el ignore sobra | 2026-11-03 |
| [zizmor: `secrets-inherit`](https://docs.zizmor.sh/audits/#secrets-inherit) | Por qué `secrets: inherit` es un hallazgo y cómo se arregla | 2026-11-03 |
| [zizmor: `self-repository`](https://docs.zizmor.sh/audits/#self-repository) | La auditoría que pide `$/` en lugar de `./` | 2026-11-03 |
| [act user guide](https://nektosact.com/) | La guía oficial de act, que ejecuta los reutilizables locales de `ci-local.sh` | 2026-11-03 |
| [act: usage](https://nektosact.com/usage/index.html) | `-W`, `-j` y eventos, para lanzar un llamador y sus jobs reutilizados | 2026-11-03 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
