# Changelog

Todos los cambios notables en este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

### Added

- Malla de 20 semanas / 200 h (10 h/semana) en 6 fases, de cero a avanzado, orientada a GH-200
- `CLAUDE.md` como guía de autoría única, con reglas de lenguaje y stack (tuteo, uv, pnpm,
  PostgreSQL, `docker compose`) y doce reglas de seguridad de workflows
- `docs/`: versiones fijadas, política de versiones, autograding contra el repo del alumno,
  proyecto hilo conductor `tablero`, ADR del laboratorio, modelo de costes, reglas de seguridad
  de workflows, mapa de funcionalidades, setup, trucos y glosario
- `scripts/`: `verificar-semana.sh` (autograding con `gh` y `GH_REPO`), `verificar-enlaces.sh`
  (13 comprobaciones), `resolver-sha.sh`, `lab-up.sh` y `lab-down.sh`
- `lab/kind-config.yaml` con imagen de nodo fijada por digest
- `.claude/`: revisor de coherencia curricular y skills de estructura, workflows y progresión
- `.github/`: plantillas, Dependabot para `github-actions` y CI propio `verificar.yml`
