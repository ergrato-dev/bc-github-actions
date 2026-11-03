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
- `bootcamp/week-01-primer_workflow_y_modelo_de_ejecucion/`: Semana 01, primer workflow y modelo de ejecución
- `bootcamp/week-02-expresiones_contextos_y_flujo_de_datos/`: Semana 02, expresiones, contextos y flujo de datos
- `bootcamp/week-06-imagenes_docker_y_ghcr/`: Semana 06, imágenes Docker y GHCR
- `bootcamp/week-05-service_containers_y_postgresql/`: Semana 05, service containers y PostgreSQL
- `bootcamp/week-04-ci_de_frontend_pnpm_matrices_y_artefactos/`: Semana 04, CI de frontend con pnpm, matrices y artefactos
- `bootcamp/week-03-ci_de_python_con_uv/`: Semana 03, CI de Python con uv
- Pie de navegación en tabla (← Anterior | Siguiente →) en las semanas y en `docs/`
- `scripts/`: `check-week.sh` (autograding con `gh` y `GH_REPO`), `check-repo.sh`
  (13 comprobaciones), `resolve-sha.sh`, `lab-up.sh` y `lab-down.sh`
- `app/`: app de referencia `tablero` (API FastAPI con uv, web React con pnpm, PostgreSQL 17,
  Compose) con `scripts/check.sh` y `scripts/smoke-test.sh`, verificada de punta a punta
- `lab/kind-config.yaml` con imagen de nodo fijada por digest
- `.claude/`: revisor de coherencia curricular y skills de estructura, workflows y progresión
- `.github/`: plantillas, Dependabot para `github-actions` y CI propio `verify.yml`
