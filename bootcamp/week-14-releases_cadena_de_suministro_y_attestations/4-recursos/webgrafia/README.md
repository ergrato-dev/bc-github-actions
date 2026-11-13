# 🌐 Webgrafía — Semana 14

Documentación oficial de referencia. Es para consultar, no para leer de corrido.

## Releases y versionado

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [googleapis/release-please-action](https://github.com/googleapis/release-please-action) | Inputs, outputs y permisos de la action; léelo en el SHA que fijas, no en `main` | 2026-11-13 |
| [Manifest Driven release-please](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md) | El modo manifest de `tablero`: `release-please-config.json`, `.release-please-manifest.json`, `include-component-in-tag` y `bootstrap-sha` | 2026-11-13 |
| [Triggering a workflow from a workflow](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow) | La regla por la que la release creada con `GITHUB_TOKEN` no dispara otros workflows, y por qué las imágenes salen en el mismo run | 2026-11-13 |
| [REST API endpoints for releases](https://docs.github.com/en/rest/releases/releases) | Leer la release, su autor y sus notas desde `gh api`, como hacen `release-published` y el minisimulacro | 2026-11-13 |

## Imágenes y digests

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Building best practices: pin base image versions](https://docs.docker.com/build/building/best-practices/#pin-base-image-versions) — Docker | Por qué fijar la base por digest y cómo convive con el tag (teoría 02) | 2026-11-13 |
| [OCI Image Spec: Descriptors](https://github.com/opencontainers/image-spec/blob/main/descriptor.md) | Qué es exactamente un digest y cómo apunta un índice a sus manifiestos | 2026-11-13 |
| [Dependabot options reference](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference) | El ecosistema `docker`, `directories` y `cooldown` de `dependabot.yml` | 2026-11-13 |

## Attestations y Sigstore

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Artifact attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations) | El concepto en la documentación de GitHub: qué firma, con qué identidad y dónde se guarda | 2026-11-13 |
| [Using artifact attestations to establish provenance for builds](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations) | Firmar procedencia y SBOM de binarios e imágenes, con los permisos que pide cada caso | 2026-11-13 |
| [Increasing the security rating of your builds](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/increase-security-rating) | Cómo llegar a SLSA Build L3 con un reutilizable y verificar su firmante | 2026-11-13 |
| [actions/attest](https://github.com/actions/attest) | Los tres modos (procedencia, SBOM, predicado propio), `push-to-registry` y `create-storage-record` | 2026-11-13 |
| [gh attestation verify](https://cli.github.com/manual/gh_attestation_verify) | Todos los flags: `--repo`, `--owner`, `--signer-workflow`, `--signer-repo`, `--predicate-type`, `--format json` | 2026-11-13 |
| [Sigstore overview](https://docs.sigstore.dev/about/overview/) | Cómo encajan Fulcio, Rekor y las firmas sin clave (teoría 05) | 2026-11-13 |
| [Fulcio](https://docs.sigstore.dev/certificate_authority/overview/) — Sigstore | La autoridad que convierte el token OIDC del job en un certificado de corta vida | 2026-11-13 |
| [Rekor](https://docs.sigstore.dev/logging/overview/) — Sigstore | El log de transparencia donde queda cada firma y por qué hace verificable un certificado ya caducado | 2026-11-13 |

## SBOM y escaneo

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [anchore/syft](https://github.com/anchore/syft) | Fuentes que escanea, catalogadores y formatos de salida (`spdx-json`, `github-json`); los assets de cada release con su checksum | 2026-11-13 |
| [Package URL (purl) specification](https://github.com/package-url/purl-spec) | El identificador `pkg:...` que llevan los paquetes del SBOM y del snapshot | 2026-11-13 |
| [Trivy documentation](https://trivy.dev/latest/docs/) | Objetivos de escaneo, bases de avisos y opciones de salida (teoría 06) | 2026-11-13 |
| [Trivy: Filtering](https://trivy.dev/latest/docs/configuration/filtering/) | `--severity`, `--ignore-unfixed` y `.trivyignore`: qué se filtra y cómo justificarlo | 2026-11-13 |
| [GHSA-69fq-xp46-6x23](https://github.com/aquasecurity/trivy/security/advisories/GHSA-69fq-xp46-6x23) — Aqua Security | El aviso del compromiso de Trivy `0.69.4` (19 de marzo de 2026), motivo de la regla 9 de seguridad | 2026-11-13 |
| [CVE Program](https://www.cve.org/) | El origen de los identificadores CVE que enseña Trivy | 2026-11-13 |
| [Common Vulnerability Scoring System](https://www.first.org/cvss/) — FIRST | De dónde sale la severidad `CRITICAL`, `HIGH`… de un aviso | 2026-11-13 |

## Dependency graph y dependency review

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Dependency graph](https://docs.github.com/en/code-security/concepts/supply-chain-security/dependency-graph) | Qué es el grafo, de dónde saca los datos y quién lo usa | 2026-11-13 |
| [Dependency graph supported package ecosystems](https://docs.github.com/en/code-security/reference/supply-chain-security/dependency-graph-supported-package-ecosystems) | La lista de lockfiles que el grafo lee, y por qué `uv.lock` y el `pnpm-lock.yaml` de pnpm 11+ necesitan el snapshot | 2026-11-13 |
| [Using the dependency submission API](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/using-the-dependency-submission-api) | Cómo enviar un snapshot desde un workflow y cómo se combina con lo que el grafo detecta | 2026-11-13 |
| [REST API endpoints for dependency submission](https://docs.github.com/en/rest/dependency-graph/dependency-submission) | El formato exacto del snapshot (`sha`, `ref`, `job`, `detector`, `manifests`) y el permiso que exige | 2026-11-13 |
| [REST API endpoints for software bill of materials (SBOM)](https://docs.github.com/en/rest/dependency-graph/sboms) | El SBOM del repo que exporta el grafo: la forma de comparar qué ve antes y después del snapshot | 2026-11-13 |
| [Exporting a software bill of materials for your repository](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/exporting-a-software-bill-of-materials-for-your-repository) | Lo mismo desde la UI y sus límites | 2026-11-13 |
| [Dependency review](https://docs.github.com/en/code-security/concepts/supply-chain-security/dependency-review) | Qué compara la revisión de dependencias y en qué se diferencia de Dependabot | 2026-11-13 |
| [actions/dependency-review-action](https://github.com/actions/dependency-review-action) | Inputs como `fail-on-severity`, `retry-on-snapshot-warnings` y las licencias; léelos en el SHA fijado | 2026-11-13 |
| [GitHub Advisory Database](https://docs.github.com/en/code-security/concepts/vulnerability-reporting-and-management/github-advisory-database) | De dónde salen los GHSA que usa dependency-review y cómo se relacionan con los CVE | 2026-11-13 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
