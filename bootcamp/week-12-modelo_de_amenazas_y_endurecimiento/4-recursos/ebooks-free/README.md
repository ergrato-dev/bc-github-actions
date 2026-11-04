# 📚 eBooks y material gratuito — Semana 12

Guías largas y gratuitas para profundizar en lo que la teoría resume. Ninguna es obligatoria. La
serie de GitHub Security Lab es anterior a algunas funciones de la semana (`cache-mode`, zizmor,
CodeQL para Actions): quédate con los ataques y escribe los workflows como en la teoría.

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Keeping your GitHub Actions and workflows secure Part 1: Preventing pwn requests](https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/) — GitHub Security Lab | El artículo que dio nombre a la «pwn request»: `pull_request_target`, el checkout del head y el patrón con `workflow_run` y artefactos de la teoría 04 | 2026-11-03 |
| [Keeping your GitHub Actions and workflows secure Part 2: Untrusted input](https://securitylab.github.com/resources/github-actions-untrusted-input/) — GitHub Security Lab | La inyección de scripts con los contextos que controla un atacante y la defensa con `env:`: la teoría 03 con más ejemplos | 2026-11-03 |
| [Keeping your GitHub Actions and workflows secure Part 3: How to trust your building blocks](https://securitylab.github.com/resources/github-actions-building-blocks/) — GitHub Security Lab | Mínimo privilegio para el `GITHUB_TOKEN` y cómo referenciar actions de terceros: las teorías 02 y 06 en un solo artículo | 2026-11-03 |
| [Keeping your GitHub Actions and workflows secure Part 4: New vulnerability patterns and mitigation strategies](https://securitylab.github.com/resources/github-actions-new-patterns-and-mitigations/) — GitHub Security Lab | Los fallos frecuentes con `pull_request_target`, la frontera de `workflow_run` e `issue_comment`, con las mitigaciones que funcionan y las que no. Apoya las teorías 04 y 05 | 2026-11-03 |
| [OWASP Top 10 CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/) — OWASP | Un modelo de amenazas de CI/CD independiente de GitHub. Compara sus diez riesgos con las cuatro fronteras de la teoría 01 | 2026-11-03 |
| [Study guide for Exam GH-200: GitHub Actions](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/gh-200) — Microsoft Learn | La guía oficial del examen. Repasa los objetivos de seguridad: permisos del `GITHUB_TOKEN`, actions de terceros y triggers peligrosos | 2026-11-03 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Rúbrica de evaluación](../../rubrica-evaluacion.md) | [Videografía](../videografia/README.md) |
