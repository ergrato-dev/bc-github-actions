# 🌐 Webgrafía — Semana 11

Documentación oficial y artículos de referencia. Las referencias son para consultar, no para leer de
corrido.

## Repo central y referencias

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Reference same-repository actions with self-repository syntax](https://github.blog/changelog/2026-07-30-reference-same-repository-actions-with-self-repository-syntax/) — GitHub Changelog | El anuncio de `$/`: a qué repo y commit resuelve, dónde funciona y por qué ayuda con el pinning obligatorio. La base de la teoría 02 | 2026-11 |
| [Sharing actions and workflows with your organization](https://docs.github.com/en/actions/how-tos/reuse-automations/share-with-your-organization) | Cómo compartir actions y reutilizables entre repos de la org, y el ajuste de acceso que necesita un repo privado | 2026-11 |
| [Reusing workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows) | La sintaxis `owner/repo/.github/workflows/archivo@ref` con la que `tablero` llama al central | 2026-11 |
| [Contexts: `job` context](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#job-context) | `job.workflow_sha`, `job.workflow_repository` y compañía: qué versión del reutilizable está corriendo | 2026-11 |
| [actionlint: configuration](https://github.com/rhysd/actionlint/blob/main/docs/config.md) | `paths.<glob>.ignore` en `.github/actionlint.yaml`, la excepción para `$/` | 2026-11 |
| [rhysd/actionlint#711](https://github.com/rhysd/actionlint/issues/711) | El issue de soporte de `$/` en actionlint. Cuando se cierre, borras la excepción | 2026-11 |
| [zizmor: `self-repository`](https://docs.zizmor.sh/audits/#self-repository) | La auditoría que pide `$/` en lugar de `./`: por qué el central no lleva ningún ignore | 2026-11 |

## Versiones y releases

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Releasing and maintaining actions](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/release-and-maintain-actions) | Las recomendaciones de GitHub para versionar actions, incluida la convención del tag mayor | 2026-11 |
| [Using immutable releases and tags to manage your action's releases](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/using-immutable-releases-and-tags-to-manage-your-actions-releases) | Releases inmutables aplicadas a una action, y cómo encaja el tag mayor | 2026-11 |
| [Immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases) | Qué bloquea una release inmutable, qué no, y la attestation que firma GitHub | 2026-11 |
| [Preventing changes to your releases](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/preventing-changes-to-your-releases) | Dónde se activa la inmutabilidad, en el repo y en toda la organización | 2026-11 |
| [Immutable releases are now generally available](https://github.blog/changelog/2025-10-28-immutable-releases-are-now-generally-available/) — GitHub Changelog | El anuncio de la función, con su alcance en una página | 2026-11 |
| [REST API: releases](https://docs.github.com/en/rest/releases/releases) | `releases/latest` y los campos `immutable` y `draft` que lee el autograding | 2026-11 |
| [`gh release create`](https://cli.github.com/manual/gh_release_create) | `--draft`, `--target`, `--verify-tag` y `--generate-notes` | 2026-11 |
| [`gh release verify`](https://cli.github.com/manual/gh_release_verify) | Comprueba la attestation de una release: a qué commit resolvió el tag | 2026-11 |
| [Versionado Semántico 2.0.0](https://semver.org/lang/es/) | Qué sube el mayor, el menor y el parche | 2026-11 |

## Plantillas y gobierno de la organización

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Creating workflow templates for your organization](https://docs.github.com/en/actions/how-tos/reuse-automations/create-workflow-templates) | El repo `.github`, la carpeta `workflow-templates/`, `$default-branch` y el `.properties.json` | 2026-11 |
| [Reusing workflow configurations: workflow templates](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations#workflow-templates) | La referencia que compara plantillas, reutilizables y actions | 2026-11 |
| [Creating a default community health file](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file) | Qué más lee GitHub del repo `.github` de la organización | 2026-11 |
| [Disabling or limiting GitHub Actions for your organization](https://docs.github.com/en/organizations/managing-organization-settings/disabling-or-limiting-github-actions-for-your-organization) | Las opciones de actions permitidas, el formato de los patrones y el token por defecto, desde la UI | 2026-11 |
| [REST API: GitHub Actions permissions](https://docs.github.com/en/rest/actions/permissions) | `allowed_actions`, `sha_pinning_required`, `selected-actions` y `workflow`: los endpoints de la práctica 03 | 2026-11 |
| [GitHub Actions policy now supports blocking and SHA pinning actions](https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/) — GitHub Changelog | El anuncio del pinning obligatorio y de los patrones de exclusión con `!` | 2026-11 |
| [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use) | Por qué fijar por SHA y limitar las actions de terceros: el razonamiento detrás de las políticas | 2026-11 |
| [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets) | Rulesets de repo, organización y empresa | 2026-11 |
| [Creating rulesets for repositories in your organization](https://docs.github.com/en/organizations/managing-organization-settings/creating-rulesets-for-repositories-in-your-organization) | Cómo se crea un ruleset de organización y qué plan exige | 2026-11 |
| [Available rules: require workflows to pass before merging](https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets#require-workflows-to-pass-before-merging) | Las condiciones de un workflow exigido: eventos, filtros y CodeQL | 2026-11 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
