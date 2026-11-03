#!/usr/bin/env bash
# ci-local.sh — ejecuta un workflow (o un job) de tablero en tu máquina con act, en Docker.
# Se copia a <tu-org>/tablero/scripts/ci-local.sh (con chmod +x).
# Uso: scripts/ci-local.sh --list
#      scripts/ci-local.sh <workflow> [job] [argumentos extra de act]
set -euo pipefail

ACT_VERSION="0.2.94"
# TODO 6: fija la imagen de catthehacker/ubuntu para ubuntu-24.04 con un tag con fecha (act-24.04-AAAAMMDD).
RUNNER_IMAGE=""
EVENT="${EVENT:-pull_request}"

if ! command -v act >/dev/null; then
  echo "act no está instalado: Semana 08, práctica 04, paso 1" >&2
  exit 1
fi
if [[ "$(act --version)" != "act version ${ACT_VERSION}" ]]; then
  echo "Aviso: se espera act ${ACT_VERSION}, tienes '$(act --version)'" >&2
fi

# TODO 7: con --list como primer argumento, lista los jobs de todos los workflows con act y termina.

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 --list | <workflow> [job] [argumentos de act]" >&2
  exit 2
fi

workflow=".github/workflows/$1.yml"
shift
[[ -f "$workflow" ]] || { echo "No existe $workflow" >&2; exit 2; }

args=("$EVENT" -W "$workflow" -P "ubuntu-24.04=${RUNNER_IMAGE}")
# Sin esto, en un Mac con Apple Silicon act intentaría una imagen arm64 que no existe.
args+=(--container-architecture linux/amd64)
if [[ $# -gt 0 && "$1" != -* ]]; then
  args+=(-j "$1")
  shift
fi

exec act "${args[@]}" "$@"
