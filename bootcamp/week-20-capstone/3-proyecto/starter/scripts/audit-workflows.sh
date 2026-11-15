#!/usr/bin/env bash
# Copia en <tu-org>/tablero como scripts/audit-workflows.sh (con bit de ejecución).
# Audita la política de tablero sobre uno o varios repos (por defecto, el actual): lo que
# actionlint y zizmor no exigen pero el bootcamp sí. Una línea por hallazgo,
# "ruta: regla: detalle", y código de salida 1 si hay alguno. Necesita yq.
# Uso: scripts/audit-workflows.sh [raíz-de-repo ...]
set -euo pipefail

findings=0
report() {
  echo "$1: $2: $3"
  findings=$((findings + 1))
}

audit_workflow() {
  local f="$1" item
  [[ "$(yq 'has("permissions")' "$f")" == true ]] || report "$f" permissions-root "sin permissions en la raíz"
  if yq -e '.. | select(. == "write-all")' "$f" >/dev/null 2>&1; then
    report "$f" write-all "permissions: write-all"
  fi
  # TODO 3: regla timeout. Cada job con runs-on y sin timeout-minutes es un hallazgo
  # "job <nombre> sin timeout-minutes". Un job que llama a un reutilizable no tiene runs-on.

  # TODO 4: regla runner-latest. Un job cuyo runs-on (texto o lista) tiene una etiqueta que
  # termina en -latest es un hallazgo "job <nombre> usa una etiqueta -latest".

  while read -r item; do
    [[ "$item" == ./* || "$item" == \$/* ]] && continue
    # TODO 5: también se aceptan un SHA de 40 caracteres al final y docker://imagen@sha256:<64>.
    report "$f" unpinned-uses "$item"
  done < <(yq -r '.jobs[] | (.uses, (.steps[]? | .uses)) | select(. != null)' "$f")
  # TODO 6: regla image-digest para las imágenes de services y de container (texto o
  # mapa con image). Sin @sha256: es un hallazgo; una imagen con ${{ }} se salta.
}

audit_dockerfile() {
  local f="$1" stages=" " kw image as name
  while read -r kw image as name; do
    if [[ "${kw^^}" == FROM ]]; then
      [[ "${as^^}" == AS ]] && stages+="$name "
      [[ "$stages" == *" $image "* || "$image" == scratch || "$image" == *@sha256:* ]] && continue
      report "$f" image-digest "FROM $image"
    else
      # TODO 7: COPY --from=<etapa> es local y se salta; COPY --from=<imagen> sin @sha256:
      # trae código de un registro sin fijar: hallazgo "COPY --from=<imagen>".
      :
    fi
  done < <(grep -iE '^(FROM|COPY --from=)' "$f" | sed -E 's/^(COPY) (--from=[^ ]+).*/\1 \2/I')
}

for root in "${@:-.}"; do
  for f in "$root"/.github/workflows/*.yml "$root"/.github/workflows/*.yaml; do
    [[ -f "$f" ]] && audit_workflow "$f"
  done
  while read -r f; do
    audit_dockerfile "$f"
  done < <(find "$root" -name Dockerfile -not -path '*/node_modules/*' -not -path '*/.venv/*')
done

echo "$findings hallazgos"
[[ "$findings" -eq 0 ]]
