# syntax=docker/dockerfile:1
# Imagen de la API de tablero. Multi-stage: uv solo existe en la etapa de build.
# Construir desde app/:  docker build -t tablero-api:dev api

FROM python:3.15.2-slim-trixie AS build
COPY --from=ghcr.io/astral-sh/uv:0.13.6 /uv /usr/local/bin/uv
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never
WORKDIR /app
# Primero solo las dependencias: esta capa se reutiliza mientras uv.lock no cambie.
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev --no-install-project
COPY src ./src
COPY migrations ./migrations
RUN uv sync --locked --no-dev

FROM python:3.15.2-slim-trixie
ARG APP_VERSION=dev
ENV PATH="/app/.venv/bin:$PATH" \
    APP_VERSION=${APP_VERSION}
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin tablero
WORKDIR /app
COPY --from=build --chown=10001:10001 /app /app
USER 10001
EXPOSE 8000
# Aplica las migraciones pendientes y arranca. uvicorn como PID 1 gracias a exec.
CMD ["sh", "-c", "python -m tablero.migrate && exec uvicorn tablero.main:app --host 0.0.0.0 --port 8000"]
