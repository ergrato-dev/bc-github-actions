# 🔒 Política de Seguridad

Este repositorio es **material educativo**, no un producto en producción. Aun así enseña a dar
permisos al `GITHUB_TOKEN`, a manejar secretos, a operar runners propios y a instalar herramientas
en la máquina del alumno. Un error en el material se copia tal cual en cientos de pipelines, así
que los reportes de seguridad se tratan con seriedad.

## Qué reportar

| Tipo | Ejemplo | Canal |
|---|---|---|
| Secreto expuesto en este repo | Un token, una clave de GitHub App o un JWT comiteados por error | **Privado** (ver abajo) |
| Script de `scripts/` o `lab/` que pueda dañar datos o el host | Un `rm` sobre una ruta mal expandida | **Privado** |
| Action, herramienta o imagen que no es lo que dice | Un tag movido, una release comprometida, un SHA que no corresponde a su tag, un checksum que no cuadra | **Privado** |
| Ejemplo que enseña una práctica insegura sin marcarla | `${{ github.event.* }}` dentro de `run:`, `permissions: write-all`, una `uses:` por tag, `pull_request_target` con checkout del head | Issue público |
| Funcionalidad retirada presentada como vigente | `::set-output`, `ubuntu-latest`, artifacts v3 | Issue público <!-- antipatron --> |
| Errata, workflow que no corre, enlace roto | Cualquier error de contenido | Issue público |

Regla: si publicarlo aumenta el daño, va en privado. Si publicarlo solo mejora el material, va en
un issue público.

## Cómo reportar en privado

1. **Preferido**: en la pestaña `Security` del repositorio, `Report a vulnerability` (private
   vulnerability reporting).
2. Alternativa: correo a **elparcheti@gmail.com** con el asunto
   `[SECURITY] bc-github-actions: <resumen>`.

Incluye el archivo y la línea, el impacto concreto, las versiones (`gh --version`, la action y su
SHA) y los pasos para reproducirlo.

**Tiempo de respuesta esperado**: primer acuse de recibo en 7 días naturales.

## Lo que el material garantiza

- **Actions fijadas por SHA** con el tag en comentario, resueltas con `scripts/resolver-sha.sh`.
  Un tag de action no cuenta como versión: se puede mover. Pasó con `tj-actions/changed-files`
  en marzo de 2025 y con `trivy-action` el 2026-03-19 (GHSA-69fq-xp46-6x23).
- **`permissions:` mínimos** en todo workflow y datos no confiables solo por `env:`.
- **Versiones fijadas y verificadas.** Cada herramienta lleva versión exacta, fecha de
  comprobación y estado de avisos en [`docs/stack-versions.md`](docs/stack-versions.md).
- **Descargas con checksum.** Nunca `curl | bash`.
- **Runners propios efímeros y restringidos**, nunca al alcance de PRs de forks.
- **Nada expuesto a la red pública.** Compose y kind escuchan en `127.0.0.1`.
- **Ningún secreto real.** Las credenciales de ejemplo valen `cambiame` y son desechables.

## Fuera de alcance

- Vulnerabilidades de GitHub Actions, de los runners alojados o de actions de terceros:
  repórtalas a GitHub o a su proyecto.
- La seguridad de organizaciones y repos que no sean los del laboratorio del bootcamp.

## Reconocimientos

Quien reporte de forma responsable aparecerá aquí, si da su consentimiento.

_Ningún reporte hasta la fecha._
