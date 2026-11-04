#!/usr/bin/env bash
# entrypoint.sh — capa 10 de tablero. Cópialo a .github/actions/sql-lint/entrypoint.sh.
set -euo pipefail

# TODO 8: lee el input exclude-rules (llega como variable de entorno con guion) y escribe
# files=<número de archivos .sql> en $GITHUB_OUTPUT. Si exclude-rules no está vacío, pásalo
# a sqlfluff con --exclude-rules.

mapfile -t files < <(find "$INPUT_PATH" -name '*.sql' | sort)

if [ "${#files[@]}" -eq 0 ]; then
  echo "::warning::No hay archivos .sql en '$INPUT_PATH'"
  exit 0
fi

sqlfluff lint --dialect "$INPUT_DIALECT" --format github-annotation-native "${files[@]}"
