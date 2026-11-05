# 🌐 Webgrafía — Semana 13

Documentación oficial de referencia. Es para consultar, no para leer de corrido.

## Secretos y variables

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Secrets](https://docs.github.com/en/actions/concepts/security/secrets) | Qué es un secreto en Actions, sus niveles y quién los recibe: la base de la teoría 01 | 2026-11-04 |
| [Secrets reference](https://docs.github.com/en/actions/reference/security/secrets) | Límites, reglas de nombres, precedencia y redacción en el log, con las frases que citan las teorías 01 y 02 | 2026-11-04 |
| [Using secrets in GitHub Actions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets) | Crear secretos de repo, environment y org, y usarlos en un workflow, también en una condición | 2026-11-04 |
| [Variables reference](https://docs.github.com/en/actions/reference/workflows-and-actions/variables) | El contexto `vars` y los niveles de las variables, donde vive `OIDC_SUB` | 2026-11-04 |
| [Workflow commands](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands) | `::add-mask::` y el resumen del job, los dos sitios donde la teoría 02 controla qué llega al log | 2026-11-04 |
| [REST API endpoints for GitHub Actions Secrets](https://docs.github.com/en/rest/actions/secrets) | Los endpoints de secretos de repo, environment y org, con la visibilidad y los repos seleccionados | 2026-11-04 |
| [`gh secret set`](https://cli.github.com/manual/gh_secret_set) | Los flags `--env`, `--org`, `--visibility` y `--repos`, y la lectura del valor por stdin | 2026-11-04 |
| [`gh variable set`](https://cli.github.com/manual/gh_variable_set) | Cómo se guarda `OIDC_SUB` en cada environment con `--env` | 2026-11-04 |

## Environments

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Deployment environments](https://docs.github.com/en/actions/concepts/workflows-and-actions/deployment-environments) | Qué es un environment y qué reglas admite, con los límites por plan: la teoría 03 | 2026-11-04 |
| [Deployments and environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments) | Referencia de revisores, wait timer, ramas permitidas y secretos de environment | 2026-11-04 |
| [Managing environments for deployment](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments) | Crear y configurar environments desde la UI, incluida la casilla de bypass para administradores | 2026-11-04 |
| [Reviewing deployments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/review-deployments) | Aprobar o rechazar un job que espera, lo que la práctica 02 hace por la API | 2026-11-04 |
| [REST API endpoints for deployment environments](https://docs.github.com/en/rest/deployments/environments) | El `PUT` con `reviewers`, `prevent_self_review`, `wait_timer` y `deployment_branch_policy` de la práctica 01 | 2026-11-04 |
| [REST API endpoints for deployment branch policies](https://docs.github.com/en/rest/deployments/branch-policies) | La política `{"name":"main","type":"branch"}` y por qué exige `custom_branch_policies` | 2026-11-04 |
| [REST API endpoints for workflow runs](https://docs.github.com/en/rest/actions/workflow-runs) | `pending_deployments`: leer qué espera aprobación y aprobarlo con un comentario | 2026-11-04 |

## OIDC

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [OpenID Connect](https://docs.github.com/en/actions/concepts/security/openid-connect) | Por qué OIDC sustituye a las credenciales estáticas y cómo encaja la confianza entre GitHub y la nube: la teoría 04 | 2026-11-04 |
| [OpenID Connect reference](https://docs.github.com/en/actions/reference/security/oidc) | Los claims, el `sub` por defecto, el formato inmutable y la personalización: la fuente de las teorías 05 y 06 | 2026-11-04 |
| [REST API endpoints for GitHub Actions OIDC](https://docs.github.com/en/rest/actions/oidc) | La plantilla del `sub` de repo y de org, con `use_default` e `include_claim_keys` | 2026-11-04 |
| [Documento de descubrimiento del emisor](https://token.actions.githubusercontent.com/.well-known/openid-configuration) | El JSON real con `issuer`, `jwks_uri`, `RS256` y `claims_supported`: lo que el verificador descarga | 2026-11-04 |
| [Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws) | La trust policy con `aud` y `sub`: compárala con los comodines peligrosos de la teoría 06 | 2026-11-04 |
| [Configuring OpenID Connect in Azure](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-azure) | La federated credential con el `sub` exacto | 2026-11-04 |
| [Configuring OpenID Connect in Google Cloud Platform](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-google-cloud-platform) | Workload Identity Federation con attribute mapping y attribute condition sobre los claims | 2026-11-04 |
| [Trusted publishers](https://docs.pypi.org/trusted-publishers/) — PyPI | Publicar en PyPI sin token: PyPI verifica repo, workflow y environment del token OIDC | 2026-11-04 |
| [PyJWT](https://pyjwt.readthedocs.io/en/stable/) | La librería de `oidc-verifier`: `algorithms`, `audience`, `issuer`, `leeway` y `options` de `jwt.decode` | 2026-11-04 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
