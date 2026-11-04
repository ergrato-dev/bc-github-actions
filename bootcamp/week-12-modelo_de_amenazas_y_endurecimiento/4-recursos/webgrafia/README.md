# 🌐 Webgrafía — Semana 12

Documentación oficial y avisos de seguridad de referencia. Son para consultar, no para leer de
corrido.

## Modelo de amenazas e incidentes

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use) | La guía oficial de endurecimiento de Actions: la lista de controles que la semana recorre frontera a frontera | 2026-11-03 |
| [Managing GitHub Actions settings for a repository: forks in public repositories](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository#controlling-changes-from-forks-to-workflows-in-public-repositories) | Las opciones de aprobación de workflows de forks, incluida la que activas en la práctica 01 | 2026-11-03 |
| [GHSA-mrrh-fwg8-r2c3 (CVE-2025-30066)](https://github.com/advisories/GHSA-mrrh-fwg8-r2c3) — GitHub Advisory Database | El aviso de `tj-actions/changed-files`: las versiones afectadas y por qué el SHA protegía | 2026-11-03 |
| [CVE-2025-30066](https://nvd.nist.gov/vuln/detail/CVE-2025-30066) — NVD | La misma vulnerabilidad en el registro del NIST, con su puntuación. Responde 403 a los bots; en el navegador abre | 2026-11-03 |
| [GHSA-69fq-xp46-6x23](https://github.com/aquasecurity/trivy/security/advisories/GHSA-69fq-xp46-6x23) — aquasecurity/trivy | El aviso del compromiso de Trivy de marzo de 2026: por qué la regla 9 prohíbe `0.69.4` y `trivy-action` por tag | 2026-11-03 |

## Permisos e inyección

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [GITHUB_TOKEN](https://docs.github.com/en/actions/concepts/security/github_token) | Qué es el token de cada job, cuándo caduca y qué puede hacer | 2026-11-03 |
| [Workflow syntax: `permissions`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#permissions) | La tabla de scopes y niveles, los atajos `read-all`, `write-all` y `{}`, y el recorte en forks. La base de la teoría 02 | 2026-11-03 |
| [Use GITHUB_TOKEN for authentication in workflows](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token) | Cómo se usa el token desde `gh` y desde una action, y cómo se ajustan sus permisos | 2026-11-03 |
| [Script injections](https://docs.github.com/en/actions/concepts/security/script-injections) | La explicación oficial de la inyección de scripts y de los contextos no confiables, teoría 03 | 2026-11-03 |

## Triggers, caché y artefactos

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Events: `pull_request_target`](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request_target) | Qué workflow corre, qué `GITHUB_SHA` recibe y el aviso oficial contra construir código del PR | 2026-11-03 |
| [Events: `workflow_run`](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run) | Las condiciones del trigger y los campos de `github.event.workflow_run` que filtra `pr-report` | 2026-11-03 |
| [actions/labeler](https://github.com/actions/labeler) | El README de la action: formato de `.github/labeler.yml` desde la v5 y por qué el PR que la añade no se etiqueta | 2026-11-03 |
| [Dependency caching: cache access for low-trust workflow triggers](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching#cache-access-for-low-trust-workflow-triggers) | Qué triggers pueden escribir en la caché de la rama por defecto y cómo funciona `cache-mode`, teoría 05 | 2026-11-03 |
| [rhysd/actionlint#762](https://github.com/rhysd/actionlint/issues/762) | actionlint aún rechaza `cache-mode`: por qué `tablero` no la escribe. El PR [#745](https://github.com/rhysd/actionlint/issues/745) añade el soporte | 2026-11-03 |

## Dependencias y análisis estático

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Keeping your actions up to date with Dependabot](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/keeping-your-actions-up-to-date-with-dependabot) | El ecosistema `github-actions` y cómo Dependabot actualiza un `uses:` fijado por SHA | 2026-11-03 |
| [Dependabot options reference: `cooldown`](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference#cooldown-) | `default-days`, los días por tipo de versión, `include` y `exclude`, y el resto de claves de `dependabot.yml` | 2026-11-03 |
| [github/gh-actions-lock](https://github.com/github/gh-actions-lock) | La extensión que genera y verifica `actions.lock`, el lockfile de workflows de la teoría 06 | 2026-11-03 |
| [zizmor: audit rules](https://docs.zizmor.sh/audits/) | Cada auditoría con ejemplos y su arreglo. Empieza por [`template-injection`](https://docs.zizmor.sh/audits/#template-injection), [`dangerous-triggers`](https://docs.zizmor.sh/audits/#dangerous-triggers) e [`impostor-commit`](https://docs.zizmor.sh/audits/#impostor-commit) | 2026-11-03 |
| [zizmor: ignoring results](https://docs.zizmor.sh/usage/#ignoring-results) | La sintaxis de `# zizmor: ignore[...]` y el archivo de configuración. Justo debajo, `--no-ignores` | 2026-11-03 |
| [About code scanning with CodeQL](https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning-with-codeql) | Qué hace CodeQL, cómo se suben los resultados y cómo viven las alertas | 2026-11-03 |
| [Configuring advanced setup for code scanning](https://docs.github.com/en/code-security/how-tos/scan-code-for-vulnerabilities/configure-code-scanning/configuring-advanced-setup-for-code-scanning) | El workflow `codeql` a mano, como en `tablero`: `init`, `analyze` y las suites de consultas | 2026-11-03 |
| [CodeQL queries for GitHub Actions](https://codeql.github.com/codeql-query-help/actions/) | El catálogo de consultas del lenguaje `actions`, con severidad y precisión. Por ejemplo, [`actions/code-injection/critical`](https://codeql.github.com/codeql-query-help/actions/actions-code-injection-critical/) y [`actions/untrusted-checkout/critical`](https://codeql.github.com/codeql-query-help/actions/actions-untrusted-checkout-critical/) | 2026-11-03 |
| [github/codeql-action](https://github.com/github/codeql-action) | El repo de la action: inputs de `init` y `analyze` en el SHA que fijas | 2026-11-03 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
