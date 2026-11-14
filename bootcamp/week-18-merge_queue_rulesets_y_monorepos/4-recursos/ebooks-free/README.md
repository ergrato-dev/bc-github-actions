# 📚 eBooks y material gratuito — Semana 18

Guías largas y gratuitas para profundizar en lo que la teoría resume. Ninguna es obligatoria. Los
capítulos de Google hablan de un monorepo con miles de ingenieros: quédate con las ideas (una sola
rama principal siempre verde, probar antes de entrar, dueños por ruta) y no con su escala.

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Continuous Integration](https://abseil.io/resources/swe-book/html/ch23.html) — Google, *Software Engineering at Google*, cap. 23 | Por qué un CI que prueba antes de fusionar mantiene verde la rama principal y cómo se decide qué tests correr en un monorepo: el problema de las teorías 04 y 05 | 2026-11-14 |
| [Version Control and Branch Management](https://abseil.io/resources/swe-book/html/ch16.html) — Google, *Software Engineering at Google*, cap. 16 | El argumento de una única rama principal en un monorepo, la base de proteger `main` con un ruleset y no con ramas de larga vida | 2026-11-14 |
| [Code Review](https://abseil.io/resources/swe-book/html/ch09.html) — Google, *Software Engineering at Google*, cap. 9 | Qué aporta la revisión obligatoria y la figura del dueño de un directorio: la configuración de equipo de la teoría 06 | 2026-11-14 |
| [Trunk Based Development](https://trunkbaseddevelopment.com/) — Paul Hammant y colaboradores | Ramas cortas que vuelven pronto a la principal, el flujo que la merge queue hace seguro cuando muchos PR llegan a la vez | 2026-11-14 |
| [Monorepo Explained](https://monorepo.tools/) — monorepo.tools | Qué gana y qué cuesta un monorepo, y cómo las herramientas deciden qué construir según lo que cambió: el siguiente paso después de `changed-areas.sh` | 2026-11-14 |
| [CICD-SEC-1: Insufficient Flow Control Mechanisms](https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-01-Insufficient-Flow-Control-Mechanisms) — OWASP | El riesgo de que un cambio llegue a la rama principal sin pasar por las puertas: lo que cierran el ruleset sin bypass y `ci-gate` | 2026-11-14 |
| [CICD-SEC-2: Inadequate Identity and Access Management](https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-02-Inadequate-Identity-And-Access-Management) — OWASP | Identidades con permisos de más y credenciales que no caducan: por qué una App con dos permisos y no un PAT (teoría 07) | 2026-11-14 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Rúbrica de evaluación](../../rubrica-evaluacion.md) | [Videografía](../videografia/README.md) |
