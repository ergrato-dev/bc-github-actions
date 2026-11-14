# 🌐 Webgrafía — Semana 18

Documentación oficial de GitHub, por temas: rulesets, checks obligatorios, merge queue, CODEOWNERS
y tokens. La documentación de GitHub cambia de ruta a menudo: si un enlace falla, busca el título
en docs.github.com.

### Rulesets

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets) | Rulesets frente a protección de rama, cómo se suman varios, quién los ve y en qué planes existen (teoría 01) | 2026-11-14 |
| [Available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets) | Qué hace cada regla, de "Restrict deletions" a "Require merge queue" (teoría 02) | 2026-11-14 |
| [Creating rulesets for a repository](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository) | El mismo ruleset desde la UI, con la lista de bypass y los patrones de rama | 2026-11-14 |
| [Managing rulesets for a repository](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/managing-rulesets-for-a-repository) | Editar, exportar e importar rulesets y ver su historial de cambios | 2026-11-14 |
| [REST API endpoints for rules](https://docs.github.com/en/rest/repos/rules) | El cuerpo del `POST` y el `PUT`, los parámetros de cada regla y `rules/branches/{branch}`, que usan la práctica 02 y `ruleset-active` | 2026-11-14 |
| [Creating rulesets for repositories in your organization](https://docs.github.com/en/organizations/managing-organization-settings/creating-rulesets-for-repositories-in-your-organization) | Los rulesets de organización, que piden Team o Enterprise: el paso siguiente cuando hay muchos repos | 2026-11-14 |

### Checks obligatorios y jobs saltados

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Status checks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/about-status-checks) | Qué es un check, de dónde sale su nombre y cómo se ve en el PR | 2026-11-14 |
| [Troubleshooting required status checks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks) | Qué estados cuentan como éxito y la regla de los siete días para elegir un check (teoría 03) | 2026-11-14 |
| [Using conditions to control job execution](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-jobs-with-conditions) | La frase clave de la semana: un job saltado informa "Success", aunque sea obligatorio | 2026-11-14 |
| [Workflow syntax for GitHub Actions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) | Los filtros `paths` y el aviso de que un workflow saltado deja sus checks en "Pending" | 2026-11-14 |
| [Reusing workflow configurations](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations) | El contexto `github` del llamante dentro de un reutilizable y el aviso sobre los grupos de `concurrency` (teoría 04) | 2026-11-14 |

### Merge queue

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Managing a merge queue](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue) | Disponibilidad, el "must" de `merge_group`, las ramas `gh-readonly-queue` y por qué la cola saca un PR (teoría 05) | 2026-11-14 |
| [Merging a pull request with a merge queue](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/merging-a-pull-request-with-a-merge-queue) | La cola vista desde el autor del PR: meterlo, sacarlo y qué ve mientras espera | 2026-11-14 |
| [Events that trigger workflows: merge_group](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#merge_group) | El tipo `checks_requested`, `GITHUB_SHA` y `GITHUB_REF` de un grupo y los filtros de ramas | 2026-11-14 |
| [Webhook events and payloads: merge_group](https://docs.github.com/en/webhooks/webhook-events-and-payloads#merge_group) | Los campos `base_sha`, `head_sha` y `head_ref` del payload, el de `changes` | 2026-11-14 |
| [gh pr merge](https://cli.github.com/manual/gh_pr_merge) | Cómo se comporta con una cola: auto-merge si los checks no han pasado, a la cola si sí, y `--admin` | 2026-11-14 |
| [gh pr checks](https://cli.github.com/manual/gh_pr_checks) | `--required` y `--watch`, para ver solo `ci-gate` y esperar a que termine | 2026-11-14 |
| [How GitHub uses merge queue to ship hundreds of changes every day](https://github.blog/engineering/engineering-principles/how-github-uses-merge-queue-to-ship-hundreds-of-changes-every-day/) — The GitHub Blog | Por qué GitHub construyó la cola para su propio monorepo y qué problema le quitó | 2026-11-14 |

### CODEOWNERS

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [About code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) | Dónde va el archivo, el último patrón gana, los dueños con escritura y la sintaxis (teoría 06) | 2026-11-14 |
| [List CODEOWNERS errors](https://docs.github.com/en/rest/repos/repos#list-codeowners-errors) | El endpoint de `codeowners-valid` y la forma de cada error | 2026-11-14 |

### Tokens, GitHub Apps y release-please

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [GITHUB_TOKEN](https://docs.github.com/en/actions/concepts/security/github_token) | Qué eventos de `GITHUB_TOKEN` crean runs, incluido el estado approval-required de sus PR (teoría 07) | 2026-11-14 |
| [Managing GitHub Actions settings for a repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository) | El ajuste "Allow GitHub Actions to create and approve pull requests" y cómo lo hereda el repo de la org | 2026-11-14 |
| [REST API endpoints for GitHub Actions permissions](https://docs.github.com/en/rest/actions/permissions) | `can_approve_pull_request_reviews` en la org y en el repo, lo que leen `actions-cannot-approve` y la práctica 04 | 2026-11-14 |
| [Registering a GitHub App](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app) | Cada campo del formulario de la práctica 04, paso 1 | 2026-11-14 |
| [Choosing permissions for a GitHub App](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/choosing-permissions-for-a-github-app) | Cómo elegir solo los permisos que la App usa | 2026-11-14 |
| [Making authenticated API requests with a GitHub App in a GitHub Actions workflow](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/making-authenticated-api-requests-with-a-github-app-in-a-github-actions-workflow) | La guía oficial del patrón de `release.yml`: clave en un secreto y token por job | 2026-11-14 |
| [actions/create-github-app-token](https://github.com/actions/create-github-app-token) | Los inputs `client-id`, `private-key` y `permission-*`, y la revocación del token al terminar el job | 2026-11-14 |
| [googleapis/release-please-action](https://github.com/googleapis/release-please-action) | El input `token` y por qué un token distinto de `GITHUB_TOKEN` deja que el PR de release dispare el CI | 2026-11-14 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
