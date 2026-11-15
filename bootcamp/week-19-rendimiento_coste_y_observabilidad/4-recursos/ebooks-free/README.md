# 📚 eBooks y material gratuito — Semana 19

Guías largas y gratuitas para profundizar en lo que la teoría resume. Ninguna es obligatoria. Los
libros de SRE de Google hablan de servicios en producción, no de CI: quédate con las ideas
(medir antes de decidir, percentiles y no medias, un objetivo que avisa) y aplícalas al tiempo de
tu pipeline.

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/) — Google, *Site Reliability Engineering*, cap. 6 | Las "cuatro señales doradas" y por qué la latencia se mira por percentiles: la base de `ci-trend.sh` y de la teoría 06 | 2026-11-14 |
| [Service Level Objectives](https://sre.google/sre-book/service-level-objectives/) — Google, *Site Reliability Engineering*, cap. 4 | Qué es un objetivo medible y por qué se fija sobre un percentil: el mismo razonamiento que `CI_P95_BUDGET_SECONDS` | 2026-11-14 |
| [Implementing SLOs](https://sre.google/workbook/implementing-slos/) — Google, *The Site Reliability Workbook*, cap. 2 | Cómo elegir el número del objetivo a partir de lo medido y no de un valor redondo, el criterio de calidad del presupuesto | 2026-11-14 |
| [Build Systems and Build Philosophy](https://abseil.io/resources/swe-book/html/ch18.html) — Google, *Software Engineering at Google*, cap. 18 | Caché de resultados, paralelismo y construir solo lo que cambió, a escala de miles de ingenieros: el horizonte de las teorías 03 a 05 | 2026-11-14 |
| [Git Internals — Git Objects](https://git-scm.com/book/en/v2/Git-Internals-Git-Objects) — Scott Chacon y Ben Straub, *Pro Git* | Commits, árboles y blobs explicados desde dentro: por qué `git diff --name-only` no necesita blobs (teoría 05) | 2026-11-14 |
| [FinOps Framework](https://www.finops.org/framework/) — FinOps Foundation | Medir, asignar y optimizar el gasto en la nube como práctica de equipo: el marco de la teoría 01 cuando el CI deja de ser gratis | 2026-11-14 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Rúbrica de evaluación](../../rubrica-evaluacion.md) | [Videografía](../videografia/README.md) |
