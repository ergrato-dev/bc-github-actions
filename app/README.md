# tablero

App de referencia del bootcamp: un gestor de tareas pequeño organizado como **monorepo**. En el
bootcamp no la programas: escribes todo lo que la rodea, empezando por sus workflows.

| Carpeta | Stack | Qué hay |
|---|---|---|
| `api/` | Python 3.15 + FastAPI, con **uv** | `/api/health` y CRUD `/api/tasks`; tests `unit/` (sin base) e `integration/` (con PostgreSQL) |
| `web/` | React + Vite + TypeScript, con **pnpm** | Interfaz servida por nginx sin privilegios, que hace de proxy a `/api` |
| `compose.yaml` | Docker Compose | PostgreSQL 17, API y web, puertos solo en `127.0.0.1` |
| `scripts/` | bash | `check.sh` (todo lo que tiene que pasar) y `smoke-test.sh` |
| `tools/oidc-verifier/` | Python 3.15 + PyJWT, con **uv** | Verifica un token OIDC de GitHub Actions como lo haría la nube; llega en la Semana 13 |

Las versiones exactas están en `api/uv.lock`, `web/pnpm-lock.yaml` y
[`docs/stack-versions.md`](../docs/stack-versions.md). **No hay carpeta `.github/`**: es tu trabajo.

## En la Semana 01 la copias a tu repo

```bash
cp -r bc-github-actions/app/. ~/code/tablero/
```

La práctica 01 de la Semana 01 lo hace paso a paso, con la creación de `<tu-org>/tablero`.

## Arrancarla

```bash
docker compose up --build --wait
./scripts/smoke-test.sh
# health:
# {"status":"ok","version":"dev"}
# ...
# borrada. Smoke test OK
```

Abre <http://127.0.0.1:8080>. Para pararla: `docker compose down` (añade `-v` para borrar también
los datos de PostgreSQL).

## Trabajar por partes

```bash
# API
cd api
uv sync --locked
uv run --no-sync pytest tests/unit
DATABASE_URL=postgresql://tablero:cambiame@127.0.0.1:5432/tablero uv run --no-sync pytest tests/integration

# Web
cd web
pnpm install --frozen-lockfile
pnpm test
pnpm dev        # http://127.0.0.1:5173, con /api hacia 127.0.0.1:8000
```

Para los tests de integración en local necesitas un PostgreSQL escuchando en `127.0.0.1:5432`. En CI
lo levanta un service container (Semana 05).

## Todo de una vez

```bash
./scripts/check.sh              # API, web, imágenes, compose y smoke test
SKIP_COMPOSE=1 ./scripts/check.sh   # sin Docker
```

## Decisiones

- **Sin ORM**: psycopg y SQL directo. Hay una tabla y cuatro consultas; un ORM sería más código que la app.
- **Migraciones SQL numeradas** en `api/migrations/`, aplicadas al arrancar por `python -m tablero.migrate`.
- **Credenciales de ejemplo `cambiame`**: solo protegen tu PostgreSQL local. Nunca es una contraseña real.
- **Las imágenes corren sin root**: la API con UID 10001; la web con el usuario de `nginx-unprivileged`.
- **pnpm en la imagen sin npm ni corepack**: ejecutable autónomo descargado con `ADD --checksum`.
