# 🌐 Webgrafía — Semana 04

Documentación oficial y artículos de referencia. Las referencias son para consultar, no para leer de
corrido.

## pnpm y Node

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Continuous Integration](https://pnpm.io/continuous-integration) — pnpm | La guía oficial de pnpm en CI, con la receta de GitHub Actions. Compárala con tu `ci-web.yml` | 2026-11-02 |
| [pnpm install](https://pnpm.io/cli/install) — pnpm | `--frozen-lockfile` y cuándo se activa solo con `CI=true` | 2026-11-02 |
| [package.json](https://pnpm.io/package_json) — pnpm | Los campos que pnpm lee de `package.json`, entre ellos `packageManager` y `engines` | 2026-11-02 |
| [pnpm store](https://pnpm.io/cli/store) — pnpm | `pnpm store path` y `pnpm store prune`: dónde está el store que cachea setup-node | 2026-11-02 |
| [pnpm why](https://pnpm.io/cli/why) — pnpm | Qué dependencia trajo un paquete transitivo, como en la práctica 01, paso 5 | 2026-11-02 |
| [pnpm/action-setup](https://github.com/pnpm/action-setup) | El README de la action: `version`, `package_json_file` y por qué sin `version` lee `packageManager`. Léelo en el SHA que fijas | 2026-11-02 |
| [actions/setup-node](https://github.com/actions/setup-node) | `node-version`, `cache: pnpm`, `cache-dependency-path` y los outputs `node-version` y `cache-hit` | 2026-11-02 |
| [setup-node: advanced usage](https://github.com/actions/setup-node/blob/main/docs/advanced-usage.md) | La caché con pnpm explicada por la propia action, y por qué pnpm tiene que estar instalado antes | 2026-11-02 |
| [Node.js releases](https://nodejs.org/en/about/previous-releases) — Node.js | Qué versiones son LTS y hasta cuándo: el criterio para elegir 24 y 26 en la matriz | 2026-11-02 |

## Lint, tests y build

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [ESLint documentation](https://eslint.org/docs/latest/) | Reglas, configuración plana (`eslint.config.js`) y cómo leer un error de `pnpm lint` | 2026-11-02 |
| [Test environment](https://vitest.dev/guide/environment) — Vitest | Qué es `environment: "jsdom"` y por qué domina el tiempo de los tests de componentes | 2026-11-02 |
| [Coverage](https://vitest.dev/guide/coverage) — Vitest | `@vitest/coverage-v8`, umbrales y por qué un umbral no cumplido falla el comando | 2026-11-02 |
| [Building for Production](https://vite.dev/guide/build) — Vite | Qué hace `vite build`, el contenido de `dist/` y los nombres con hash | 2026-11-02 |
| [TSConfig reference](https://www.typescriptlang.org/docs/handbook/compiler-options.html) — TypeScript | Las opciones del compilador, incluida `--noEmit`, que el build usa para comprobar tipos sin generar JavaScript | 2026-11-02 |

## Matrices

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Running variations of jobs in a workflow](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations) | La guía oficial de matrices: varios ejes, `include`, `exclude`, `fail-fast`, `max-parallel` y matrices desde un output | 2026-11-02 |
| [Workflow syntax: `jobs.<job_id>.strategy`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) | La referencia exacta del orden en que se aplican `exclude` e `include` y el límite de 256 jobs | 2026-11-02 |

## Artefactos y caché

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Storing and sharing data from a workflow](https://docs.github.com/en/actions/tutorials/store-and-share-data) | El tutorial oficial de subir y descargar artefactos entre jobs, el patrón de `build` → `dist-report` | 2026-11-02 |
| [Workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts) | Qué es un artefacto, cuánto dura y en qué se diferencia de una caché, según GitHub | 2026-11-02 |
| [Downloading workflow artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts) | Descargar desde la UI, `gh run download` y la API | 2026-11-02 |
| [Removing workflow artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/remove-workflow-artifacts) | Borrar un artefacto antes de que caduque, como en la práctica 04, paso 5 | 2026-11-02 |
| [actions/upload-artifact](https://github.com/actions/upload-artifact) | Todos los inputs (`if-no-files-found`, `retention-days`, `include-hidden-files`, `overwrite`) y los outputs `artifact-id` y `artifact-digest` | 2026-11-02 |
| [upload-artifact: migración a v4 y posteriores](https://github.com/actions/upload-artifact/blob/main/docs/MIGRATION.md) | Qué cambió con la v4: artefactos inmutables, nombres únicos por run y cómo migrar matrices. Contexto histórico de lo que ya no se hace | 2026-11-02 |
| [actions/download-artifact](https://github.com/actions/download-artifact) | `name`, `path`, `pattern` y `merge-multiple`, y cómo descargar de otro run con `run-id` | 2026-11-02 |
| [gh run download](https://cli.github.com/manual/gh_run_download) | `-n` para un artefacto concreto y `-D` para elegir directorio | 2026-11-02 |
| [Dependency caching reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching) | Claves, ámbito por rama, 10 GB y 7 días: lo que la caché del store de pnpm no te garantiza | 2026-11-02 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
