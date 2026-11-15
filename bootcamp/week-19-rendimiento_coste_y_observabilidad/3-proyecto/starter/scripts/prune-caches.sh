#!/usr/bin/env bash
# Copia en <tu-org>/tablero como scripts/prune-caches.sh (con bit de ejecución).
# Borra las cachés de Actions cuyo ref ya no sirve: PR cerrados y ramas que ya no existen
# (entre ellas las gh-readonly-queue/ de la merge queue). Las de main y los tags se quedan.
# Con DRY_RUN=true solo dice qué borraría. Necesita GH_TOKEN con actions: write.
set -euo pipefail

dry_run="${DRY_RUN:-false}"

branches=$(gh api 'repos/{owner}/{repo}/branches?per_page=100' --paginate --jq '.[].name')
open_prs=$(gh pr list --state open --limit 1000 --json number --jq '.[].number')

deleted=0
while read -r id ref; do
  [[ -n "$id" ]] || continue
  case "$ref" in
    refs/pull/*/merge)
      # TODO 7: si el número del PR está en open_prs, la caché sigue sirviendo: continue.
      ;;
    refs/heads/*)
      # TODO 8: borra solo si la rama ya no está en branches; si existe, continue.
      continue ;;
    *) continue ;;
  esac
  # TODO 9: con dry_run=true, imprime "se borraría <id> (<ref>)" sin llamar a gh cache delete.
  gh cache delete "$id"
  echo "borrada $id ($ref)"
  deleted=$((deleted + 1))
done < <(gh cache list --limit 1000 --json id,ref --jq '.[] | "\(.id) \(.ref)"')

echo "cachés sin dueño: $deleted"
