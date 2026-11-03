# 🎬 Videografía — Semana 02

Vídeos en inglés. Varios son anteriores a 2023 o usan `ubuntu-latest` y actions por tag: <!-- antipatron -->
quédate con el concepto y aplica las reglas del bootcamp. Si un vídeo enseña `::set-output`, está
desfasado: hoy se usa `$GITHUB_OUTPUT` (teoría 05).

| Vídeo | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Introduction to GitHub Actions - Part 3 - The GitHub Context Object and Variables](https://www.youtube.com/watch?v=nNItXK3xd2s) — Mickey Gousset | Recorre el contexto `github` y usa `toJSON` para verlo entero, igual que la práctica 01. Fíjate en qué campos imprime: tú solo sacas los que necesitas | 2026-11-02 |
| [GitHub Actions Workflow Logic Explained \| Filters, Contexts, Variables & Expressions](https://www.youtube.com/watch?v=KIH79Y3xJ8c) — Cloud With VarJosh | Contextos, variables y expresiones en un solo vídeo, con ejemplos de `if:`. La parte de filtros es de la Semana 07 | 2026-11-02 |
| [Expressions Follow Along: Advanced Expression Usage](https://www.youtube.com/watch?v=MdjyWei7ZKo) — ExamPro | Funciones (`contains`, `format`, `fromJSON`) y funciones de estado escritas en directo. Forma parte de un curso orientado al GH-200 | 2026-11-02 |
| [avoiding shell injection in github actions](https://www.youtube.com/watch?v=7w0Ns8C1shQ) — anthonywritescode | Cinco minutos que enseñan por qué `${{ }}` dentro de `run:` es una inyección y cómo `env:` la evita. La teoría 02 en la pantalla de otro | 2026-11-02 |
| [Keeping your GitHub Actions and workflows secure](https://www.youtube.com/watch?v=Jn0kfAuJI2o) — GitHub | Charla oficial con casos reales de workflows vulnerables. Esta semana mira la parte de datos no confiables; el resto lo verás en la Semana 12 | 2026-11-02 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [eBooks gratuitos](../ebooks-free/README.md) | [Webgrafía](../webgrafia/README.md) |
