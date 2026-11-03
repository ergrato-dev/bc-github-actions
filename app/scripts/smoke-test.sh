#!/usr/bin/env bash
#
# smoke-test.sh — comprueba que tablero responde de punta a punta.
#
# Uso: ./scripts/smoke-test.sh [URL_BASE]     (por defecto http://127.0.0.1:8080)
#
# Pasa por la web (nginx) para probar también el proxy hacia la API.

set -euo pipefail

base="${1:-http://127.0.0.1:8080}"

echo "health:"
curl -fsS "$base/api/health"
echo

titulo="smoke $(date +%s)"
id=$(curl -fsS -X POST "$base/api/tasks" -H 'Content-Type: application/json' \
       -d "{\"title\": \"$titulo\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
echo "creada la tarea $id"

curl -fsS "$base/api/tasks" | grep -q "$titulo"
echo "la tarea aparece en el listado"

curl -fsS -X DELETE "$base/api/tasks/$id" -o /dev/null
echo "borrada. Smoke test OK"
