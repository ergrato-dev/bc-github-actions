# 📚 eBooks y material gratuito — Semana 17

Guías largas y gratuitas para profundizar en lo que la teoría resume. Ninguna es obligatoria. Las
de Google hablan de sistemas mucho más grandes que `tablero`: quédate con las ideas (promover un
artefacto, volver atrás rápido) y no con su escala.

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Release Engineering](https://sre.google/sre-book/release-engineering/) — Google, *Site Reliability Engineering* | Builds herméticos y despliegues que promueven el mismo artefacto por cada etapa: la regla de oro de la teoría 01 contada desde Google | 2026-11-14 |
| [Canarying Releases](https://sre.google/workbook/canarying-releases/) — Google, *The Site Reliability Workbook* | Qué hace falta para desplegar a una parte antes que al resto y volver atrás sin drama: el siguiente paso natural después de staging y production | 2026-11-14 |
| [CICD-SEC-1: Insufficient Flow Control Mechanisms](https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-01-Insufficient-Flow-Control-Mechanisms) — OWASP | El riesgo de que algo llegue a producción sin pasar por las puertas: lo que cierran el environment con revisor, `verify` y las reglas sobre `ref` y `job_workflow_ref` | 2026-11-14 |
| [CICD-SEC-2: Inadequate Identity and Access Management](https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-02-Inadequate-Identity-And-Access-Management) — OWASP | Identidades con permisos de más y credenciales que no caducan: el porqué de un usuario por environment y de no guardar ningún kubeconfig (teorías 05 y 06) | 2026-11-14 |
| [Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html) — OWASP | Ya la usaste para el pod del runner en la Semana 16; ahora repasa las secciones de RBAC y de Pod Security con `ops/cluster/access.yaml` abierto | 2026-11-14 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Rúbrica de evaluación](../../rubrica-evaluacion.md) | [Videografía](../videografia/README.md) |
