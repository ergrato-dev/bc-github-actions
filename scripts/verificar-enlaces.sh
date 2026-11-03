#!/usr/bin/env bash
# Verifica la integridad estructural y las reglas del bootcamp:
#   1. Nombres de carpeta week-NN-slug bien formados.
#   2. Enlaces relativos en markdown que resuelven a una ruta real.
#   3. Seccion "Navegacion" en el README de cada semana publicada.
#   4. SVG de 0-assets/ enlazados desde algun .md.
#   5. checks.json valido como JSON.
#   6. Todo .sh con shebang `env bash` y `set -euo pipefail`.
#   7. Archivos de teoria dentro del rango 200-300 lineas.
#   8. Ninguna carpeta solution/ en el repositorio.
#   9. Imagenes de contenedor fijadas: sin tag o :latest.
#  10. Toda `uses:` remota fijada por SHA de 40 caracteres con "# vX" detras.
#  11. `runs-on: ubuntu-latest` prohibido.
#  12. Reglas de lenguaje y stack: tuteo, uv, pnpm, PostgreSQL, docker compose.
#  13. Los workflows de los starters pasan actionlint.
#
# Las comprobaciones 3, 6, 7, 9, 12 y 13 sobre bootcamp/ solo se aplican a las
# semanas marcadas con ✅ en bootcamp/README.md. La 10, la 11 y la 12 se
# aplican ademas siempre a app/, lab/, docs/, scripts/ y .github/.
# Una linea con la marca "antipatron" (comentario YAML o <!-- antipatron -->)
# queda exenta de 10, 11 y 12: es un ejemplo de lo que no se hace.
#
# Uso: scripts/verificar-enlaces.sh
# Salida: lista de problemas encontrados; exit code 1 si hay al menos uno.

set -u
cd "$(dirname "$0")/.." || exit 1

fail=0

publicadas=$(grep -oE '^\| \[[0-9]{2}\]\(([a-z0-9_-]+)/README\.md\).*\| ✅ \|$' bootcamp/README.md \
             | sed -E 's/^\| \[[0-9]{2}\]\(([a-z0-9_-]+)\/README\.md\).*/\1/')

esta_publicada() {
  local ruta="$1" slug
  for slug in $publicadas; do
    case "$ruta" in *"$slug"*) return 0 ;; esac
  done
  return 1
}

# Archivos a los que se aplican 10-12: semanas publicadas + infraestructura.
en_alcance() {
  case "$1" in
    ./bootcamp/*) esta_publicada "$1" ;;
    ./CLAUDE.md|./.claude/*|./scripts/verificar-enlaces.sh) return 1 ;;   # definen los patrones prohibidos
    *) return 0 ;;
  esac
}

archivos_de_texto() {
  find . \( -path ./.git -o -path '*/node_modules' -o -path '*/.venv' -o -path '*/dist' \) -prune -o \
    -type f \( -name '*.md' -o -name '*.yml' -o -name '*.yaml' -o -name '*.json' \
               -o -name '*.toml' -o -name '*.sh' -o -name 'Dockerfile' -o -name '*.py' \) -print
}

if [ -z "$publicadas" ]; then
  echo "AVISO: ninguna semana marcada como ✅ en bootcamp/README.md."
  echo "       Se omiten las comprobaciones de contenido de las semanas."
fi

echo "== 1. Nombres de carpeta =="
while IFS= read -r d; do
  name=$(basename "$d")
  if ! [[ "$name" =~ ^week-[0-9]{2}-[a-z0-9_]+$ ]]; then
    echo "NOMBRE INVALIDO (week): $d"
    fail=1
  fi
done < <(find bootcamp -mindepth 1 -maxdepth 1 -type d -iname "week-*")

echo "== 2. Enlaces relativos en markdown =="
while IFS= read -r f; do
  content=$(awk '/^```/{c=!c; next} !c' "$f")
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    clean="${link%%#*}"
    [ -z "$clean" ] && continue
    case "$clean" in http*|\<http*|ws*|mailto:*|\#*|/*) continue ;; esac
    dir=$(dirname "$f")
    resolved=$(realpath -m "$dir/$clean")
    if [ ! -e "$resolved" ]; then
      echo "ENLACE ROTO: $f -> $link"
      fail=1
    fi
  done < <(printf '%s\n' "$content" | grep -oE '\]\([^)]+\)' | sed -E 's/^\]\(//;s/\)$//')
done < <(find . -iname "*.md" -not -path "./.git/*" -not -path "*/node_modules/*" \
           -not -path "./CLAUDE.md")
# CLAUDE.md contiene rutas de ejemplo (../0-assets/NN-nombre.svg) que no
# resuelven por diseno.

echo "== 3. Navegacion anterior/siguiente en README de cada semana publicada =="
while IFS= read -r rm; do
  esta_publicada "$rm" || continue
  if ! grep -q "Navegación" "$rm"; then
    echo "SIN NAVEGACION: $rm"
    fail=1
  fi
done < <(find bootcamp -mindepth 2 -maxdepth 2 -iname "README.md")

echo "== 3b. Pie de navegacion <- -> en cada archivo de contenido de semana publicada =="
while IFS= read -r f; do
  esta_publicada "$f" || continue
  if ! grep -qE '←.*→|←.+$|→$' "$f"; then
    echo "SIN PIE DE NAVEGACION (falta <- o ->): $f"
    fail=1
  fi
done < <(find bootcamp -path "*/1-teoria/*.md" -o -path "*/2-practicas/*.md" \
            -o -path "*/3-proyecto/README.md" -o -name "rubrica-evaluacion.md" \
            -o -path "*/4-recursos/*/README.md" -o -path "*/5-glosario/README.md")

echo "== 4. SVG huerfanos en 0-assets/ =="
while IFS= read -r svg; do
  base=$(basename "$svg")
  if ! grep -rqF "$base" --include="*.md" .; then
    echo "SVG HUERFANO (no enlazado desde ningun .md): $svg"
    fail=1
  fi
done < <(find bootcamp assets -iname "*.svg" 2>/dev/null)

echo "== 5. checks.json valido =="
if command -v jq >/dev/null 2>&1; then
  while IFS= read -r cj; do
    if ! jq -e . "$cj" > /dev/null 2>&1; then
      echo "JSON INVALIDO: $cj"
      fail=1
    fi
  done < <(find bootcamp -name "checks.json")
else
  echo "AVISO: jq no esta instalado, no se validan los checks.json"
fi

echo "== 6. Cabecera de los scripts bash =="
while IFS= read -r sh; do
  case "$sh" in bootcamp/*) esta_publicada "$sh" || continue ;; esac
  if [ "$(head -1 "$sh")" != "#!/usr/bin/env bash" ]; then
    echo "SHEBANG INCORRECTO (debe ser '#!/usr/bin/env bash'): $sh"
    fail=1
  fi
  if ! grep -q 'set -euo pipefail' "$sh"; then
    echo "SIN 'set -euo pipefail': $sh"
    fail=1
  fi
  if [ ! -x "$sh" ]; then
    echo "SIN BIT DE EJECUCION (chmod +x): $sh"
    fail=1
  fi
done < <(find bootcamp scripts app lab -name "*.sh" -not -path "*/node_modules/*" 2>/dev/null)

echo "== 7. Extension de los archivos de teoria (200-300 lineas) =="
while IFS= read -r t; do
  esta_publicada "$t" || continue
  n=$(wc -l < "$t")
  if [ "$n" -lt 200 ] || [ "$n" -gt 300 ]; then
    echo "TEORIA FUERA DE RANGO ($n lineas, se esperan 200-300): $t"
    fail=1
  fi
done < <(find bootcamp -path "*/1-teoria/*" -name "*.md" 2>/dev/null)

echo "== 8. Carpetas solution/ =="
while IFS= read -r d; do
  echo "SOLUCION COMITEABLE (no existe solution/ en este bootcamp): $d"
  fail=1
done < <(find . -type d -name solution -not -path "./.git/*")

echo "== 9. Imagenes fijadas (sin tag o :latest) =="
# Lineas "image:" en .yaml/.yml/.md. Una referencia valida lleva ":<tag>" en
# su ultimo segmento o "@sha256:".
while IFS= read -r f; do
  en_alcance "$f" || continue
  while IFS= read -r linea; do
    ref=$(sed -E 's/^[[:space:]-]*image:[[:space:]]*//; s/[[:space:]]+#.*$//; s/["'\'']//g' <<<"$linea")
    ultimo="${ref##*/}"
    case "$ref" in *'<'*|*'$'*|*'{{'*) continue ;; esac   # placeholders y expresiones
    if { [[ "$ultimo" != *:* ]] && [[ "$ref" != *@sha256:* ]]; } || [[ "$ultimo" == *:latest ]]; then
      echo "IMAGEN SIN VERSION (sin tag o :latest): $f: $linea"; fail=1
    fi
  done < <(grep -E '^[[:space:]-]*image:[[:space:]]*[^[:space:]]' "$f" | grep -v antipatron)
done < <(find . \( -path ./.git -o -path '*/node_modules' \) -prune -o \
           \( -name "*.yaml" -o -name "*.yml" -o -name "*.md" \) -print)

echo "== 10. uses: fijado por SHA con el tag en comentario =="
# Remota = ni "./ruta" ni "docker://". Valida: owner/repo[/ruta]@<40 hex> # v...
while IFS= read -r f; do
  en_alcance "$f" || continue
  while IFS= read -r linea; do
    echo "USES SIN SHA (resuelvelo con scripts/resolver-sha.sh): $f:$linea"
    fail=1
  done < <(grep -nE '^[[:space:]-]*uses:[[:space:]]*[^[:space:]]' "$f" \
           | grep -vE 'uses:[[:space:]]*["'\'']?(\./|docker://)' \
           | grep -vE 'uses:[[:space:]]*[^@[:space:]]+@[0-9a-f]{40}[[:space:]]+#[[:space:]]*v?[0-9]' \
           | grep -v antipatron)
done < <(find . \( -path ./.git -o -path '*/node_modules' \) -prune -o \
           \( -name "*.yaml" -o -name "*.yml" -o -name "*.md" \) -print)

echo "== 11. runs-on: ubuntu-latest =="
while IFS= read -r f; do
  en_alcance "$f" || continue
  while IFS= read -r linea; do
    echo "UBUNTU-LATEST (usa ubuntu-24.04): $f:$linea"
    fail=1
  done < <(grep -nE 'ubuntu-latest' "$f" | grep -v antipatron)
done < <(find . \( -path ./.git -o -path '*/node_modules' \) -prune -o \
           \( -name "*.yaml" -o -name "*.yml" -o -name "*.md" \) -print)

echo "== 12. Reglas de lenguaje y stack =="
declare -A reglas=(
  ["VOSEO (usa tuteo)"]='\b(tenés|podés|querés|sabés|hacé|mirá|fijate|probá|usá|vos)\b'
  ["PIP (usa uv)"]='\bpip3? install\b|requirements\.txt|python3? -m venv'
  ["NPM (usa pnpm)"]='\bnpm (i|install|ci|run)\b|\bnpx\b|package-lock\.json'
  ["MYSQL (usa PostgreSQL)"]='\b(mysql|mariadb)\b'
  ["COMPOSE V1 (usa docker compose)"]='docker-compose'
)
while IFS= read -r f; do
  en_alcance "$f" || continue
  for nombre in "${!reglas[@]}"; do
    while IFS= read -r linea; do
      echo "$nombre: $f:$linea"
      fail=1
    done < <(grep -niE "${reglas[$nombre]}" "$f" | grep -v antipatron | grep -v 'package-ecosystem')
  done
done < <(archivos_de_texto)

echo "== 13. Los workflows de los starters pasan actionlint =="
if command -v actionlint >/dev/null 2>&1; then
  while IFS= read -r wf; do
    esta_publicada "$wf" || continue
    if ! salida=$(actionlint -no-color "$wf" 2>&1); then
      echo "ACTIONLINT FALLA: $wf"
      printf '%s\n' "$salida" | sed 's/^/    /'
      fail=1
    fi
  done < <(find bootcamp -path "*/3-proyecto/starter/*" \( -name "*.yml" -o -name "*.yaml" \) \
             -path "*/.github/workflows/*" 2>/dev/null)
else
  echo "AVISO: actionlint no esta instalado, no se validan los starters"
fi

if [ "$fail" -eq 0 ]; then
  echo "OK: sin problemas detectados."
fi
exit "$fail"
