# Dockerfile — capa 10 de tablero. Cópialo a .github/actions/sql-lint/Dockerfile.
FROM python:3.15.2-slim-trixie

COPY --from=ghcr.io/astral-sh/uv:0.13.6 /uv /usr/local/bin/uv

ENV UV_TOOL_DIR=/opt/uv-tools UV_TOOL_BIN_DIR=/usr/local/bin
# TODO 7: instala sqlfluff 4.5.0 como herramienta de uv, con la versión fijada.

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
