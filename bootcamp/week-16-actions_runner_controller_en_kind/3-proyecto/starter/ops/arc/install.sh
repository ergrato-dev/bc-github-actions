#!/usr/bin/env bash
#
# install.sh — instala ARC en el clúster kind del laboratorio (contexto kind-gha).
# Se copia a ops/arc/install.sh de <tu-org>/tablero.
#
# Necesita APP_CLIENT_ID, APP_INSTALLATION_ID y APP_PRIVATE_KEY_FILE (ruta al .pem, fuera del repo).

set -euo pipefail
: "${APP_CLIENT_ID:?falta APP_CLIENT_ID}"
: "${APP_INSTALLATION_ID:?falta APP_INSTALLATION_ID}"
: "${APP_PRIVATE_KEY_FILE:?falta APP_PRIVATE_KEY_FILE}"

CHARTS=oci://ghcr.io/actions/actions-runner-controller-charts
KUBE=(--kube-context kind-gha)

# TODO 1: fija la versión de ARC en ARC_VERSION y pásala con --version a los dos charts.
helm upgrade --install arc "${KUBE[@]}" --namespace arc-systems --create-namespace \
  "$CHARTS/gha-runner-scale-set-controller" --wait

kubectl --context kind-gha create namespace arc-runners --dry-run=client -o yaml \
  | kubectl --context kind-gha apply -f -
# TODO 2: crea el secret tablero-arc-app en arc-runners con github_app_id,
# github_app_installation_id y github_app_private_key.

helm upgrade --install tablero-runners "${KUBE[@]}" --namespace arc-runners \
  "$CHARTS/gha-runner-scale-set" -f "$(dirname "$0")/values.yaml" --wait
