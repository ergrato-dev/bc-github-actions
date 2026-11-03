# 📚 eBooks y material gratuito — Semana 02

Lecturas libres para lo que esta semana pasa por el shell: comillas, variables, `jq` y `yq`.
Ninguna es obligatoria; todas te ahorran horas de depuración.

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [BashGuide](https://mywiki.wooledge.org/BashGuide) — Greg's Wiki | La guía de bash que explica bien comillas, expansión de parámetros (`${GITHUB_SHA::7}`) y por qué `"$VAR"` va siempre entre comillas. Es la base de que un valor llegue por `env:` sin romper el script | 2026-11-02 |
| [BashPitfalls](https://mywiki.wooledge.org/BashPitfalls) — Greg's Wiki | Lista de errores típicos de bash, uno por uno. Los de comillas y de tuberías son exactamente los que `pipefail` y `env:` evitan en un `run:` | 2026-11-02 |
| [jq Manual](https://jqlang.org/manual/) — jqlang | El manual completo de `jq`, que ya viene en el runner. Lo necesitas para recorrer `toJSON(needs)` en el resumen del proyecto (`to_entries`, `all`) | 2026-11-02 |
| [yq](https://mikefarah.gitbook.io/yq/) — Mike Farah | Documentación del `yq` que usan los checks y el runner. La sección de TOML explica cómo el job `version` lee `api/pyproject.toml` sin otra herramienta | 2026-11-02 |
| [Versionado Semántico 2.0.0](https://semver.org/lang/es/) — semver.org | En español. Explica qué significa el `+<sha>` de la versión que calcula el job `version`: metadatos de build, que no cambian la precedencia | 2026-11-02 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Rúbrica de evaluación](../../rubrica-evaluacion.md) | [Videografía](../videografia/README.md) |
