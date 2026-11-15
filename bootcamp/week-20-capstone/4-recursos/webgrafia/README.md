# 🌐 Webgrafía — Semana 20

Documentación oficial por temas: el examen, la auditoría, la defensa y lo que el examen pregunta
y `tablero` no usó. La documentación de GitHub cambia de ruta a menudo: si un enlace falla, busca
el título en docs.github.com.

### El examen

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Study guide for Exam GH-200](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/gh-200) — Microsoft Learn | Los cinco dominios y sus pesos, la fuente de la teoría 06 y del reparto del simulacro | 2026-11-14 |
| [Workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) | El temario de D1 clave a clave: léelo de arriba abajo y comprueba que reconoces cada una | 2026-11-14 |
| [Contexts](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts) | Qué contexto existe en qué clave: la fuente de las preguntas de sintaxis | 2026-11-14 |

### Auditar el pipeline

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use) | Las reglas de endurecimiento de las que salen `permissions-root`, `write-all` y `unpinned-uses` | 2026-11-14 |
| [actionlint](https://github.com/rhysd/actionlint) | Qué comprueba y qué no: la primera columna de "Qué ve cada herramienta" (teoría 03) | 2026-11-14 |
| [zizmor](https://docs.zizmor.sh/) | Las auditorías offline y online, y cómo trata las anclas de YAML | 2026-11-14 |
| [yq](https://github.com/mikefarah/yq) | El procesador que usa `audit-workflows.sh`: su sintaxis de operadores, donde está la trampa de la coma y la tubería (teoría 03) | 2026-11-14 |
| [REST API endpoints for GitHub Actions permissions](https://docs.github.com/en/rest/actions/permissions) | Permiso por defecto del token, aprobación de forks y retención: la capa de ajustes de la auditoría | 2026-11-14 |
| [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets) | Cómo se combinan las reglas de un ruleset: la base de "un único check requerido" | 2026-11-14 |
| [gh workflow view](https://cli.github.com/manual/gh_workflow_view) | `--ref` y `--yaml`: auditar lo que de verdad está en `main` (truco de la semana) | 2026-11-14 |

### Defender el pipeline

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Using artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations) | Generar y verificar attestations: la evidencia de la pregunta 3 de la defensa | 2026-11-14 |
| [gh attestation verify](https://cli.github.com/manual/gh_attestation_verify) | `--repo`, `--signer-workflow` y `--predicate-type`, los flags del check `worker-image-attested` | 2026-11-14 |
| [gh run list](https://cli.github.com/manual/gh_run_list) | `--commit`, `--event` y `--json url`: sacar los enlaces de las evidencias sin la UI | 2026-11-14 |
| [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) — Michael Nygard | El texto que dio forma a los registros de decisiones: contexto, decisión y consecuencias, como tu sección "Decisiones" | 2026-11-14 |

### Lo que el examen pregunta y aún no viste

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Reusing workflow configurations](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations) | Anclas y alias junto a reutilizables, composites y plantillas: cuándo usar cada uno | 2026-11-14 |
| [Actions: YAML anchors and non-public workflow templates](https://github.blog/changelog/2025-09-18-actions-yaml-anchors-and-non-public-workflow-templates/) — GitHub Changelog | El anuncio del 18 de septiembre de 2025 de las anclas y de las plantillas en un `.github` privado o interno | 2026-11-14 |
| [GitHub Actions finally supports YAML anchors (but not really)](https://frenck.dev/github-actions-yaml-anchors-aliases-merge-keys/) — Franck Nijhof | Qué funciona y qué no con las anclas, incluida la clave de fusión `<<`, con ejemplos: contrástalo con lo que dice actionlint | 2026-11-14 |
| [actions/runner-images](https://github.com/actions/runner-images) | El software de cada imagen alojada y sus notas de release, adonde enlaza el grupo "Runner Image" | 2026-11-14 |
| [GitHub-hosted runners reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) | Las etiquetas de cada imagen y su hardware: qué fijas en lugar de `-latest` | 2026-11-14 |
| [Managing allowed IP addresses for your organization](https://docs.github.com/en/organizations/keeping-your-organization-secure/managing-security-settings-for-your-organization/managing-allowed-ip-addresses-for-your-organization) | La lista de IP permitidas, su efecto en Actions y la opción para las GitHub Apps | 2026-11-14 |
| [REST API endpoints for meta data](https://docs.github.com/en/rest/meta/meta) | `GET /meta` y sus rangos `actions`: por qué una lista de IP no encaja con runners alojados | 2026-11-14 |
| [github/roadmap #592: immutable actions](https://github.com/github/roadmap/issues/592) · [actions/publish-immutable-action](https://github.com/actions/publish-immutable-action) | El estado de las immutable actions: el roadmap y la herramienta aún no lista para uso general | 2026-11-14 |
| [Disabling and enabling a workflow](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/disable-and-enable-workflows) · [gh workflow disable](https://cli.github.com/manual/gh_workflow_disable) | Deshabilitar frente a borrar, desde la UI y desde la terminal | 2026-11-14 |
| [gh run rerun](https://cli.github.com/manual/gh_run_rerun) | `--job`, `--failed` y `--debug`: reejecutar solo lo que hace falta | 2026-11-14 |
| [Adding a workflow status badge](https://docs.github.com/en/actions/how-tos/monitor-workflows/add-a-status-badge) | La URL del badge y sus parámetros `branch` y `event` | 2026-11-14 |
| [GitHub Actions for VS Code](https://marketplace.visualstudio.com/items?itemName=GitHub.vscode-github-actions) | La extensión que cita la guía, con autocompletado y validación del YAML. El bootcamp no la ha probado | 2026-11-14 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
