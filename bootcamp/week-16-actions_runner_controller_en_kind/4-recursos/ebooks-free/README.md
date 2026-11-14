# 📚 eBooks y material gratuito — Semana 16

Guías largas y gratuitas para profundizar en lo que la teoría resume. Ninguna es obligatoria. Las
de seguridad en Kubernetes se leen mejor con `ops/arc/values.yaml` abierto al lado, campo por
campo.

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html) — OWASP | Las reglas que aplica la plantilla del pod en una lista: sin root, sin escalada, sin token montado, límites de recursos y cuidado con los secrets | 2026-11-14 |
| [OWASP Kubernetes Top Ten](https://owasp.org/www-project-kubernetes-top-ten/) — OWASP | Los riesgos más comunes de un clúster con nombre propio: cargas de trabajo inseguras, RBAC de más y secrets mal guardados, el fondo de las teorías 01 y 07 | 2026-11-14 |
| [Cloud Native Security Whitepaper v2](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/CNCF_cloud-native-security-whitepaper-May2022-v2.pdf) — CNCF TAG Security | La visión completa de la seguridad nativa en la nube, del código al runtime: dónde encaja un runner efímero en un clúster | 2026-11-14 |
| [CICD-SEC-6: Insufficient Credential Hygiene](https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-06-Insufficient-Credential-Hygiene) — OWASP | El riesgo que evita elegir una GitHub App en vez de un PAT y guardar la clave fuera del repo (teoría 04) | 2026-11-14 |
| [Kubernetes Security Checklist](https://kubernetes.io/docs/concepts/security/security-checklist/) — Kubernetes | La lista oficial para revisar un clúster: compárala con lo que tu kind hace y no hace, y verás qué falta para producción | 2026-11-14 |
| [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) — Kelsey Hightower | Montar un clúster pieza a pieza, sin kind ni instaladores: para entender qué te ahorra `lab-up.sh` (teoría 01) | 2026-11-14 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Rúbrica de evaluación](../../rubrica-evaluacion.md) | [Videografía](../videografia/README.md) |
