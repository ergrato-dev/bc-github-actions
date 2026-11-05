#!/usr/bin/env bash
#
# check.sh — lo que tiene que pasar para que tablero esté sano:
#   1. API: dependencias exactas, lint, formato y tests unitarios
#      (y lo mismo para tools/oidc-verifier)
#   2. Web: dependencias exactas, lint, tests y build
#   3. Todo junto: imágenes construidas, compose levantado y smoke test
#
# Uso: ./scripts/check.sh            (desde app/ o desde cualquier sitio)
#      SKIP_COMPOSE=1 ./scripts/check.sh   salta el paso 3
#
# Es el mismo script en tu máquina y en el CI propio del bootcamp: lo que
# pasa aquí pasa allí.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "== 1. API =="
(
  cd api
  uv sync --locked
  uv run --no-sync ruff check .
  uv run --no-sync ruff format --check .
  uv run --no-sync pytest tests/unit -q
)

echo "== 1b. tools/oidc-verifier =="
(
  cd tools/oidc-verifier
  uv sync --locked
  uv run --no-sync ruff check .
  uv run --no-sync ruff format --check .
  uv run --no-sync pytest tests/unit -q
)

echo "== 2. Web =="
(
  cd web
  pnpm install --frozen-lockfile
  pnpm lint
  pnpm test
  pnpm build
)

if [[ "${SKIP_COMPOSE:-}" == 1 ]]; then
  echo "SKIP_COMPOSE=1: se omite el paso 3."
  exit 0
fi

echo "== 3. Compose y smoke test =="
project="tablero-check-$$"
# Volumen e imágenes del proyecto temporal se borran al salir, pase lo que pase.
trap 'docker compose -p "$project" down -v --rmi local --remove-orphans >/dev/null 2>&1 || true' EXIT
docker compose -p "$project" up --build --wait --quiet-pull
./scripts/smoke-test.sh http://127.0.0.1:8080
