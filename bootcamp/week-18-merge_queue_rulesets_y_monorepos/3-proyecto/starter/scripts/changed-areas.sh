#!/usr/bin/env bash
# Copia en <tu-org>/tablero como scripts/changed-areas.sh (con bit de ejecución).
# Dice qué áreas de tablero cambian entre BASE y HEAD, una línea clave=true|false por área,
# lista para añadir a $GITHUB_OUTPUT.
set -euo pipefail

base="${1:-}"
# TODO 1: si base está vacía o no es un commit de este clon (dispatch, rama nueva), no hay
# diff posible: trata el cambio como ".github/" para que corra todo.
changed=$(git diff --name-only "$base" HEAD)

# TODO 2: si algún archivo cambiado está bajo .github/, pon all=true.
all=false

area() {
  if [[ "$all" == true ]] || grep -qE "$1" <<<"$changed"; then echo true; else echo false; fi
}

echo "api=$(area '^api/')"
echo "web=$(area '^web/')"
echo "tools=$(area '^tools/')"
# TODO 3: smoke también depende de compose.yaml y de scripts/smoke-test.sh.
echo "smoke=$(area '^(api/|web/)')"
echo "workflows=$all"
