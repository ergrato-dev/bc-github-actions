# syntax=docker/dockerfile:1
# Imagen del worker de tablero. Multi-stage: uv solo existe en la etapa de build.
# Construir desde app/:  docker build -t tablero-worker:dev worker

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
RUN uv sync --locked --no-dev

FROM python:3.15.2-slim-trixie
ARG APP_VERSION=dev
ENV PATH="/app/.venv/bin:$PATH" \
    APP_VERSION=${APP_VERSION}
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin tablero
WORKDIR /app
COPY --from=build --chown=10001:10001 /app /app
USER 10001
# Un proceso que hace su trabajo y termina: lo lanza un cron (un CronJob en Kubernetes).
CMD ["tablero-worker"]
