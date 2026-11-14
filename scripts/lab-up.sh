#!/usr/bin/env bash
#
# lab-up.sh — levanta el clúster kind del laboratorio (Semanas 16-20):
#   clúster "gha" (contexto kind-gha) según lab/kind-config.yaml
#
# Idempotente: si el clúster ya existe, lo reutiliza.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER="gha"
# Fuera del repo: es configuración de tu máquina. El apiserver la lee montada (Semana 17).
AUTH_DIR="$HOME/.config/tablero-kind"

mkdir -p "$AUTH_DIR"
[[ -f "$AUTH_DIR/authentication-config.yaml" ]] ||
  cp "$ROOT/lab/authentication-config.yaml" "$AUTH_DIR/"

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  config=$(mktemp)
  trap 'rm -f "$config"' EXIT
  sed "s|__AUTH_DIR__|$AUTH_DIR|" "$ROOT/lab/kind-config.yaml" >"$config"
  kind create cluster --config "$config" --wait 120s
elif ! docker exec "$CLUSTER-control-plane" test -d /etc/kubernetes/auth; then
  echo "El clúster $CLUSTER es anterior a la Semana 17 (sin configuración OIDC)." >&2
  echo "Recréalo: ./scripts/lab-down.sh && ./scripts/lab-up.sh" >&2
  exit 1
fi

kubectl config use-context "kind-${CLUSTER}" >/dev/null
# --wait de kind solo espera al control plane: los workers tardan unos segundos mas
kubectl wait --for=condition=Ready nodes --all --timeout=180s >/dev/null
kubectl get nodes
echo
echo "Laboratorio listo: contexto kind-${CLUSTER}"
