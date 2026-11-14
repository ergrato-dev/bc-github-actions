#!/usr/bin/env bash
#
# Starter de la Semana 17: se copia a ops/deploy/github-token.sh de <tu-org>/tablero.
# Plugin exec de kubeconfig.yaml: entrega a Helm un token OIDC de GitHub.
set -euo pipefail

# TODO 17: pide el token con la audiencia que acepta el apiserver de kind-gha
token=$(curl -sSf -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL" | jq -r .value)

jq -n --arg token "$token" --arg exp "$(date -u -d '+4 min' +%Y-%m-%dT%H:%M:%SZ)" '{
  apiVersion: "client.authentication.k8s.io/v1",
  kind: "ExecCredential",
  status: {token: $token, expirationTimestamp: $exp}
}'
