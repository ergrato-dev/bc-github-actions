# 🌐 Webgrafía — Semana 05

Documentación oficial y artículos de referencia. Las referencias son para consultar, no para leer de
corrido.

## GitHub Actions

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Workflow syntax: `jobs.<job_id>.services`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idservices) | La referencia de `services`: `image`, `ports`, `env`, `options`, `credentials` y `volumes`. Contrasta con ella cada campo de tu `integration` | 2026-11-02 |
| [Contexts: `job`](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#job-context) | Qué expone `job.services.<id>`: `id`, `network` y `ports`, de donde sale el puerto aleatorio de la práctica 03 | 2026-11-02 |
| [Creating PostgreSQL service containers](https://docs.github.com/en/actions/tutorials/use-containerized-services/create-postgresql-service-containers) | El tutorial oficial con los dos casos, job en contenedor y job en el runner. Compara su healthcheck con el tuyo | 2026-11-02 |
| [Communicating with Docker service containers](https://docs.github.com/en/actions/tutorials/use-containerized-services/use-docker-service-containers) | La red puente del job y por qué la dirección cambia entre `localhost` y el nombre del servicio | 2026-11-02 |
| [Running jobs in a container](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/run-jobs-in-a-container) | La clave `container:` de un job: imagen, opciones y qué cambia en los steps | 2026-11-02 |
| [Status check functions](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions#status-check-functions) | `failure()` y `always()`, las dos condiciones de los logs y del `down` | 2026-11-02 |
| [Ubuntu 24.04 image README](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md) — actions/runner-images | Las versiones de Docker y Compose que trae el runner esta semana. Cambia con cada publicación semanal | 2026-11-02 |

## Docker y Compose

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [What is a container?](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/) y [What is an image?](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-an-image/) | Las dos piezas de la teoría 01, explicadas por Docker en una página cada una | 2026-11-02 |
| [`docker container run`](https://docs.docker.com/reference/cli/docker/container/run/) | Todos los flags de `docker run`, incluidos `-p`, `-v` y los `--health-*` que el runner pasa en `options` | 2026-11-02 |
| [Dockerfile reference: HEALTHCHECK](https://docs.docker.com/reference/dockerfile/#healthcheck) | Cómo calcula Docker `starting`, `healthy` y `unhealthy` con `interval`, `timeout`, `retries` y `start-period` | 2026-11-02 |
| [Bridge network driver](https://docs.docker.com/engine/network/drivers/bridge/) | Por qué en una red puente definida por el usuario los contenedores se encuentran por nombre y en la red por defecto no | 2026-11-02 |
| [Volumes](https://docs.docker.com/engine/storage/volumes/) | Qué guarda un volumen, cuánto vive y cómo se borra | 2026-11-02 |
| [Compose file reference](https://docs.docker.com/reference/compose-file/) y [Services](https://docs.docker.com/reference/compose-file/services/) | La especificación de `compose.yaml`: `build`, `ports`, `healthcheck`, `depends_on` y `condition: service_healthy` | 2026-11-02 |
| [Control startup order](https://docs.docker.com/compose/how-tos/startup-order/) | Por qué `depends_on` sin `service_healthy` solo ordena el arranque y no espera a que el servicio esté listo | 2026-11-02 |
| [`docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/) | `--build`, `--wait`, `--wait-timeout` y `--quiet-pull`, los flags de `smoke.yml` | 2026-11-02 |
| [`docker compose down`](https://docs.docker.com/reference/cli/docker/compose/down/) | `--volumes` y `--rmi local`: qué borra cada uno | 2026-11-02 |
| [Specify a project name](https://docs.docker.com/compose/how-tos/project-name/) | El orden de precedencia entre `-p`, `COMPOSE_PROJECT_NAME` y `name:` del archivo | 2026-11-02 |

## PostgreSQL y pytest

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [postgres](https://hub.docker.com/_/postgres) — Docker Hub | La imagen oficial: tags disponibles y las variables `POSTGRES_USER`, `POSTGRES_PASSWORD` y `POSTGRES_DB` | 2026-11-02 |
| [pg_isready](https://www.postgresql.org/docs/17/app-pg-isready.html) — PostgreSQL 17 | Qué comprueba, qué no, y sus códigos de salida 0, 1, 2 y 3 | 2026-11-02 |
| [Connection URIs](https://www.postgresql.org/docs/17/libpq-connect.html#LIBPQ-CONNSTRING-URIS) — PostgreSQL 17 | El formato `postgresql://usuario:contraseña@host:puerto/base` de `DATABASE_URL` | 2026-11-02 |
| [Exit codes](https://docs.pytest.org/en/stable/reference/exit-codes.html) — pytest | Los seis códigos de salida, y por qué el 5 significa que no se ejecutó ningún test | 2026-11-02 |
| [How to use skip and xfail](https://docs.pytest.org/en/stable/how-to/skipping.html) — pytest | `skip`, `skipif` y `pytest.skip(allow_module_level=True)`, el mecanismo del falso verde | 2026-11-02 |
| [Managing pytest's output](https://docs.pytest.org/en/stable/how-to/output.html) — pytest | Qué hace `-r` con cada letra; `-rs` es el resumen de los saltados | 2026-11-02 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
