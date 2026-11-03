#!/usr/bin/env bash
#
# lab-up.sh — levanta el clúster kind del laboratorio (Semanas 16-20):
#   clúster "gha" (contexto kind-gha) según lab/kind-config.yaml
#
# Idempotente: si el clúster ya existe, lo reutiliza.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER="gha"

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --config "$ROOT/lab/kind-config.yaml" --wait 120s
fi

kubectl config use-context "kind-${CLUSTER}" >/dev/null
# --wait de kind solo espera al control plane: los workers tardan unos segundos mas
kubectl wait --for=condition=Ready nodes --all --timeout=180s >/dev/null
kubectl get nodes
echo
echo "Laboratorio listo: contexto kind-${CLUSTER}"
