# 📚 eBooks y material gratuito — Semana 14

Especificaciones y guías largas y gratuitas para profundizar en lo que la teoría resume. Ninguna
es obligatoria. Las especificaciones (SLSA, SPDX, in-toto) se leen mejor con una attestation o un
SBOM de `tablero` abierto al lado, campo por campo.

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [SLSA specification v1.0](https://slsa.dev/spec/v1.0/) — OpenSSF | La especificación completa de la que la teoría 03 resume el track de build: requisitos de cada nivel y modelo de amenazas | 2026-11-13 |
| [SLSA: Security levels](https://slsa.dev/spec/v1.0/levels) — OpenSSF | Qué exige y qué frena cada nivel de Build L0 a L3: la tabla de la teoría 03 con el razonamiento entero | 2026-11-13 |
| [SLSA: Provenance](https://slsa.dev/spec/v1.0/provenance) — OpenSSF | El formato del predicado `https://slsa.dev/provenance/v1` que firma `actions/attest`: `buildDefinition`, `runDetails` y qué significa cada campo | 2026-11-13 |
| [in-toto Attestation Framework](https://github.com/in-toto/attestation) — in-toto | El sobre de toda attestation: `subject`, `predicateType` y `predicate`. Explica por qué una misma imagen lleva procedencia y SBOM como afirmaciones distintas | 2026-11-13 |
| [SPDX Specification 2.3](https://spdx.github.io/spdx-spec/v2.3/) — Linux Foundation | La versión que genera syft y la que verificas con `--predicate-type https://spdx.dev/Document/v2.3`; útil para leer `packages`, `versionInfo` y los identificadores | 2026-11-13 |
| [CycloneDX Specification Overview](https://cyclonedx.org/specification/overview/) — OWASP | El otro formato estándar de SBOM, para compararlo con SPDX (teoría 04) y entender por qué una herramienta puede pedirte uno u otro | 2026-11-13 |
| [CycloneDX Guides](https://cyclonedx.org/guides/) — OWASP | Guías gratuitas sobre SBOM y su uso en la gestión de vulnerabilidades, más allá de generarlo | 2026-11-13 |
| [Semantic Versioning 2.0.0](https://semver.org/lang/es/) | La especificación en español: qué significa cada número y por qué antes de `1.0.0` todo puede cambiar (`bump-minor-pre-major`, teoría 01) | 2026-11-13 |
| [Conventional Commits 1.0.0](https://www.conventionalcommits.org/es/v1.0.0/) | La convención que release-please lee para calcular la versión: tipos, alcance, `!` y el pie `BREAKING CHANGE` | 2026-11-13 |
| [CICD-SEC-3: Dependency Chain Abuse](https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-03-Dependency-Chain-Abuse) — OWASP | El riesgo de CI/CD que frenan dependency-review, el cooldown y los digests: dependencias confundidas, secuestradas o maliciosas | 2026-11-13 |
| [CICD-SEC-9: Improper Artifact Integrity Validation](https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-09-Improper-Artifact-Integrity-Validation) — OWASP | El riesgo que cierran las attestations y `gh attestation verify`: desplegar algo sin comprobar de dónde viene | 2026-11-13 |
| [Concise Guide for Evaluating Open Source Software](https://best.openssf.org/Concise-Guide-for-Evaluating-Open-Source-Software) — OpenSSF | Qué mirar antes de añadir una dependencia: la revisión humana que dependency-review no sustituye | 2026-11-13 |
| [Study guide for Exam GH-200: GitHub Actions](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/gh-200) — Microsoft Learn | La guía oficial del examen. Repasa los objetivos de seguridad y de cadena de suministro antes del minisimulacro de la Fase 4 | 2026-11-13 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Rúbrica de evaluación](../../rubrica-evaluacion.md) | [Videografía](../videografia/README.md) |
