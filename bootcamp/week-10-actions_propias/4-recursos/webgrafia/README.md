# 🌐 Webgrafía — Semana 10

Documentación oficial y artículos de referencia. Las referencias son para consultar, no para leer de
corrido.

## Actions en GitHub Docs

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [About custom actions](https://docs.github.com/en/actions/concepts/workflows-and-actions/custom-actions) | Los tres tipos de action comparados, con en qué runners corre cada uno: la base de la teoría 01 | 2026-11-03 |
| [Metadata syntax reference](https://docs.github.com/en/actions/reference/workflows-and-actions/metadata-syntax) | Todas las claves de `action.yml`: `inputs`, `outputs`, `runs` para cada tipo, `pre`, `post`, `post-if` y `branding`. La fuente de casi toda la semana | 2026-11-03 |
| [Metadata syntax: `runs.post-if`](https://docs.github.com/en/actions/reference/workflows-and-actions/metadata-syntax#runspost-if) | Por qué el `post` corre aunque falle el `main`: el `always()` por defecto | 2026-11-03 |
| [Creating a composite action](https://docs.github.com/en/actions/tutorials/create-actions/create-a-composite-action) | El tutorial oficial de composite, con `shell` obligatorio en cada `run:` | 2026-11-03 |
| [Creating a JavaScript action](https://docs.github.com/en/actions/tutorials/create-actions/create-a-javascript-action) | El tutorial oficial de una action JavaScript y por qué el código empaquetado se comitea | 2026-11-03 |
| [Creating a Docker container action](https://docs.github.com/en/actions/tutorials/use-containerized-services/create-a-docker-container-action) | El tutorial oficial de una action Docker: Dockerfile, entrypoint e inputs | 2026-11-03 |
| [Dockerfile support for GitHub Actions](https://docs.github.com/en/actions/reference/workflows-and-actions/dockerfile-support) | Qué hace el runner con `USER`, `WORKDIR`, `ENTRYPOINT` y `CMD` de tu Dockerfile | 2026-11-03 |
| [Workflow commands: sending values to the pre and post actions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#sending-values-to-the-pre-and-post-actions) | `$GITHUB_STATE` y la variable `STATE_<nombre>` que recibe el `post` | 2026-11-03 |
| [Setting exit codes for actions](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/set-exit-codes) | Cuándo una action falla: código de salida distinto de 0, lo que hacen `setFailed` y el `exit 1` del entrypoint | 2026-11-03 |
| [Managing custom actions](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/manage-custom-actions) | Dónde guardar una action y cómo organizarla en el repo | 2026-11-03 |

## Plantillas y librerías oficiales

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [actions/toolkit: `@actions/core`](https://github.com/actions/toolkit/tree/main/packages/core) | `getInput`, `setOutput`, `saveState`, `getState`, `summary` y `setFailed` con ejemplos | 2026-11-03 |
| [actions/javascript-action](https://github.com/actions/javascript-action) | La plantilla oficial en JavaScript, con `using: node24` y `dist/` comiteado. Empaqueta con npm y rollup: tú lo haces con pnpm y esbuild | 2026-11-03 |
| [actions/typescript-action](https://github.com/actions/typescript-action) | La misma plantilla en TypeScript, con un workflow que comprueba que `dist/` está al día, como `test-actions.yml` | 2026-11-03 |
| [actions/container-action](https://github.com/actions/container-action) | La plantilla oficial de action Docker, con `image: Dockerfile` | 2026-11-03 |

## Herramientas de la semana

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [esbuild: API](https://esbuild.github.io/api/) | `--bundle`, `--platform`, `--target`, `--format` y `--out-extension`, los flags del script `build` | 2026-11-03 |
| [esbuild: format CommonJS](https://esbuild.github.io/api/#format-commonjs) | Por qué `dist/` sale en CommonJS y no en ESM | 2026-11-03 |
| [Node.js: modules, packages](https://nodejs.org/api/packages.html) | `"type": "module"` y por qué la extensión `.cjs` fuerza CommonJS dentro de ese paquete | 2026-11-03 |
| [Node.js: test runner](https://nodejs.org/api/test.html) | `node --test` sin dependencias, el que prueba `src/evaluate.js` | 2026-11-03 |
| [pnpm: settings, `allowBuilds`](https://pnpm.io/settings#allowbuilds) | La clave de `pnpm-workspace.yaml` que evita `ERR_PNPM_IGNORED_BUILDS` con esbuild | 2026-11-03 |
| [uv: using uv in Docker](https://docs.astral.sh/uv/guides/integration/docker/) | El `COPY --from=ghcr.io/astral-sh/uv` del Dockerfile de `sql-lint` | 2026-11-03 |
| [SQLFluff documentation](https://docs.sqlfluff.com/en/stable/) | El linter de SQL que empaqueta `sql-lint` | 2026-11-03 |
| [SQLFluff CLI reference](https://docs.sqlfluff.com/en/stable/reference/cli.html) | `--dialect`, `--exclude-rules` y `--format github-annotation-native` | 2026-11-03 |
| [SQLFluff rules: LT01](https://docs.sqlfluff.com/en/stable/reference/rules.html#rule-LT01) | La regla de espaciado que dispara las columnas alineadas de `001_tasks.sql` | 2026-11-03 |

## Linters y pruebas locales

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [actionlint: inputs de actions locales](https://github.com/rhysd/actionlint/blob/main/docs/checks.md#check-local-action-inputs) | Cómo actionlint lee el `action.yml` de `./.github/actions/...` y avisa de un input que falta o no existe | 2026-11-03 |
| [zizmor: `template-injection`](https://docs.zizmor.sh/audits/#template-injection) | La auditoría que marca `${{ inputs.* }}` dentro de `run:`, también en una composite | 2026-11-03 |
| [zizmor: `self-repository`](https://docs.zizmor.sh/audits/#self-repository) | Por qué cada `uses: ./.github/actions/...` lleva su ignore con motivo | 2026-11-03 |
| [act user guide](https://nektosact.com/) | act ejecuta las tres actions locales, la Docker incluida | 2026-11-03 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
