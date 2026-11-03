#!/usr/bin/env bash
#
# resolver-sha.sh — convierte "owner/repo vX.Y.Z" en la linea uses: fijada por SHA.
#
# Uso:
#   ./scripts/resolver-sha.sh actions/checkout v7.0.1
#   # uses: actions/checkout@<sha de 40 caracteres> # v7.0.1
#
#   ./scripts/resolver-sha.sh actions/checkout          sin tag: usa el ultimo release
#
# Nunca escribas un SHA a mano ni lo copies de otro repo: resuelvelo aqui.
# Un tag anotado apunta a un objeto "tag", no al commit; el script lo deshace.

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's|^# \?||'
  exit 1
fi

repo="$1"
tag="${2:-$(gh api "repos/$repo/releases/latest" --jq .tag_name)}"

read -r tipo sha < <(gh api "repos/$repo/git/ref/tags/$tag" --jq '.object.type + " " + .object.sha')
if [[ "$tipo" == "tag" ]]; then
  sha=$(gh api "repos/$repo/git/tags/$sha" --jq .object.sha)
fi

if ! [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "No se pudo resolver $repo@$tag a un commit." >&2
  exit 1
fi

echo "uses: $repo@$sha # $tag"
