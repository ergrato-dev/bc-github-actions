#!/usr/bin/env bash
#
# check-repo.sh — integridad del repositorio y reglas de CLAUDE.md:
#   1. Nombres de carpeta week-NN-slug.
#   2. Enlaces relativos de markdown que resuelven.
#   3. Tabla de navegación ← Anterior | Siguiente → al pie de docs/ y de cada
#      archivo de semana publicada.
#   4. Ningún SVG sin enlazar.
#   5. checks.json válido.
#   6. Scripts .sh con "#!/usr/bin/env bash", "set -euo pipefail" y bit de ejecución.
#   7. Teoría de 200-300 líneas.
#   8. Ninguna carpeta solution/.
#   9. Imágenes con tag (ni sin tag ni :latest).
#  10. Toda "uses:" remota fijada por SHA de 40 caracteres con "# vX" detrás.
#  11. Ningún "runs-on: ubuntu-latest" (citarlo en prosa para explicarlo sí vale).
#  12. Lenguaje y stack: tuteo, uv, pnpm, PostgreSQL, docker compose.
#  13. Los workflows de los starters pasan actionlint.
#
# Alcance: en bootcamp/ solo las semanas marcadas ✅ en bootcamp/README.md (una
# semana a medio escribir fallaría por diseño); fuera de bootcamp/, todo.
# Una línea con la marca "antipatron" queda exenta de 9-12: es un ejemplo de
# lo que no se hace.
#
# Uso: ./scripts/check-repo.sh   (exit 1 si hay al menos un problema)

set -u
cd "$(dirname "$0")/.." || exit 1

fail=0

published=$(grep -oE '^\| \[[0-9]{2}\]\(([a-z0-9_-]+)/README\.md\).*\| ✅ \|$' bootcamp/README.md \
            | sed -E 's/^\| \[[0-9]{2}\]\(([a-z0-9_-]+)\/README\.md\).*/\1/')

is_published() {
  local path="$1" slug
  for slug in $published; do
    case "$path" in *"$slug"*) return 0 ;; esac
  done
  return 1
}

# CLAUDE.md, .claude/ y este script citan los patrones prohibidos para definirlos.
in_scope() {
  case "$1" in
    ./bootcamp/*) is_published "$1" ;;
    ./CLAUDE.md|./.claude/*|./scripts/check-repo.sh) return 1 ;;
    *) return 0 ;;
  esac
}

find_files() {
  find . \( -path ./.git -o -path '*/node_modules' -o -path '*/.venv' -o -path '*/dist' \) -prune \
    -o -type f \( "$@" \) -print
}

if [ -z "$published" ]; then
  echo "AVISO: ninguna semana marcada como ✅ en bootcamp/README.md."
  echo "       Se omiten las comprobaciones de contenido de las semanas."
fi

echo "== 1. Nombres de carpeta =="
while IFS= read -r dir; do
  if ! [[ "$(basename "$dir")" =~ ^week-[0-9]{2}-[a-z0-9_]+$ ]]; then
    echo "NOMBRE INVALIDO (week): $dir"; fail=1
  fi
done < <(find bootcamp -mindepth 1 -maxdepth 1 -type d -iname "week-*")

echo "== 2. Enlaces relativos en markdown =="
# CLAUDE.md queda fuera: sus rutas de plantilla (../0-assets/NN-nombre.svg) no resuelven a propósito.
while IFS= read -r file; do
  content=$(awk '/^[[:space:]]*```/{c=!c; next} !c' "$file")
  while IFS= read -r link; do
    target="${link%%#*}"
    [ -z "$target" ] && continue
    case "$target" in http*|\<http*|ws*|mailto:*|/*) continue ;; esac
    if [ ! -e "$(realpath -m "$(dirname "$file")/$target")" ]; then
      echo "ENLACE ROTO: $file -> $link"; fail=1
    fi
  done < <(printf '%s\n' "$content" | grep -oE '\]\([^)]+\)' | sed -E 's/^\]\(//;s/\)$//')
done < <(find_files -iname '*.md' | grep -v '^./CLAUDE.md$')

echo "== 3. Navegacion =="
# La tabla tiene que ser lo último del archivo: cabecera, alineación y una fila con dos enlaces.
nav_ok() {
  tail -n 3 "$1" | tr -d '\r' | {
    read -r header; read -r align; read -r row
    [[ "$header" == "| ← Anterior | Siguiente → |" && "$align" == "|:---|---:|" \
       && "$row" =~ ^\|\ \[.+\]\(.+\)\ \|\ \[.+\]\(.+\)\ \|$ ]]
  }
}
while IFS= read -r readme; do
  is_published "$readme" || continue
  grep -q "## 🔗 Navegación" "$readme" || { echo "SIN SECCION DE NAVEGACION: $readme"; fail=1; }
done < <(find bootcamp -mindepth 2 -maxdepth 2 -iname "README.md")
while IFS= read -r file; do
  case "$file" in bootcamp/*) is_published "$file" || continue ;; esac
  nav_ok "$file" || { echo "SIN TABLA DE NAVEGACION AL PIE: $file"; fail=1; }
done < <(find bootcamp -mindepth 2 \( -path "*/1-teoria/*.md" -o -path "*/2-practicas/*.md" \
            -o -path "*/3-proyecto/README.md" -o -name "rubrica-evaluacion.md" \
            -o -path "*/4-recursos/*/README.md" -o -path "*/5-glosario/README.md" \
            -o -path "*/week-*/README.md" \) ; find docs -name "*.md")

echo "== 4. SVG sin enlazar =="
while IFS= read -r svg; do
  grep -rqF "$(basename "$svg")" --include="*.md" . || { echo "SVG HUERFANO: $svg"; fail=1; }
done < <(find bootcamp assets -iname "*.svg" 2>/dev/null)

echo "== 5. checks.json valido =="
if command -v jq >/dev/null 2>&1; then
  while IFS= read -r checks; do
    jq -e . "$checks" >/dev/null 2>&1 || { echo "JSON INVALIDO: $checks"; fail=1; }
  done < <(find bootcamp -name "checks.json")
else
  echo "AVISO: jq no esta instalado, no se validan los checks.json"
fi

echo "== 6. Cabecera de los scripts bash =="
while IFS= read -r script; do
  case "$script" in bootcamp/*) is_published "$script" || continue ;; esac
  [ "$(head -1 "$script")" = "#!/usr/bin/env bash" ] || { echo "SHEBANG INCORRECTO: $script"; fail=1; }
  grep -q 'set -euo pipefail' "$script" || { echo "SIN 'set -euo pipefail': $script"; fail=1; }
  [ -x "$script" ] || { echo "SIN BIT DE EJECUCION (chmod +x): $script"; fail=1; }
done < <(find bootcamp scripts app lab -name "*.sh" -not -path "*/node_modules/*" 2>/dev/null)

echo "== 7. Teoria de 200-300 lineas =="
while IFS= read -r theory; do
  is_published "$theory" || continue
  lines=$(wc -l < "$theory")
  if [ "$lines" -lt 200 ] || [ "$lines" -gt 300 ]; then
    echo "TEORIA FUERA DE RANGO ($lines lineas): $theory"; fail=1
  fi
done < <(find bootcamp -path "*/1-teoria/*" -name "*.md" 2>/dev/null)

echo "== 8. Carpetas solution/ =="
while IFS= read -r dir; do
  echo "SOLUCION COMITEABLE (este bootcamp no tiene solution/): $dir"; fail=1
done < <(find . -type d -name solution -not -path "./.git/*")

echo "== 9. Imagenes con tag =="
while IFS= read -r file; do
  in_scope "$file" || continue
  while IFS= read -r line; do
    ref=$(sed -E 's/^[[:space:]-]*image:[[:space:]]*//; s/[[:space:]]+#.*$//; s/["'\'']//g' <<<"$line")
    case "$ref" in *'<'*|*'$'*|*'{{'*|'['*) continue ;; esac   # placeholders, expresiones y listas de matriz
    case "$ref" in Dockerfile|*/Dockerfile) continue ;; esac   # action Docker: se construye del Dockerfile
    last="${ref##*/}"
    if { [[ "$last" != *:* ]] && [[ "$ref" != *@sha256:* ]]; } || [[ "$last" == *:latest ]]; then
      echo "IMAGEN SIN VERSION: $file: $line"; fail=1
    fi
  done < <(grep -E '^[[:space:]-]*image:[[:space:]]*[^[:space:]]' "$file" | grep -v antipatron)
done < <(find_files -name '*.yaml' -o -name '*.yml' -o -name '*.md')

echo "== 10. uses: fijado por SHA con el tag en comentario =="
# Exentas: acciones locales (./ruta) e imágenes (docker://).
while IFS= read -r file; do
  in_scope "$file" || continue
  while IFS= read -r line; do
    echo "USES SIN SHA (resuelvelo con scripts/resolve-sha.sh): $file:$line"; fail=1
  done < <(grep -nE '^[[:space:]-]*uses:[[:space:]]*[^[:space:]]' "$file" \
           | grep -vE 'uses:[[:space:]]*["'\'']?(\./|docker://)' \
           | grep -vE 'uses:[[:space:]]*[^@[:space:]]+@[0-9a-f]{40}[[:space:]]+#[[:space:]]*v?[0-9]' \
           | grep -v antipatron)
done < <(find_files -name '*.yaml' -o -name '*.yml' -o -name '*.md')

echo "== 11. runs-on: ubuntu-latest =="
while IFS= read -r file; do
  in_scope "$file" || continue
  while IFS= read -r line; do
    echo "UBUNTU-LATEST (usa ubuntu-24.04): $file:$line"; fail=1
  done < <(grep -nE 'runs-on:[[:space:]]*["'\'']?ubuntu-latest' "$file" | grep -v antipatron)
done < <(find_files -name '*.yaml' -o -name '*.yml' -o -name '*.md')

echo "== 12. Lenguaje y stack =="
# package-ecosystem queda exento: "npm" es el nombre que Dependabot da al ecosistema de pnpm.
declare -A rules=(
  ["VOSEO (usa tuteo)"]='\b(tenés|podés|querés|sabés|hacé|mirá|fijate|probá|usá|vos)\b'
  ["PIP (usa uv)"]='\bpip3? install\b|requirements\.txt|python3? -m venv'
  ["NPM (usa pnpm)"]='\bnpm (i|install|ci|run)\b|\bnpx\b|package-lock\.json'
  ["MYSQL (usa PostgreSQL)"]='\b(mysql|mariadb)\b'
  ["COMPOSE V1 (usa docker compose)"]='docker-compose'
)
while IFS= read -r file; do
  in_scope "$file" || continue
  for rule in "${!rules[@]}"; do
    while IFS= read -r line; do
      echo "$rule: $file:$line"; fail=1
    done < <(grep -niE "${rules[$rule]}" "$file" | grep -v antipatron | grep -v 'package-ecosystem')
  done
done < <(find_files -name '*.md' -o -name '*.yml' -o -name '*.yaml' -o -name '*.json' \
                    -o -name '*.toml' -o -name '*.sh' -o -name 'Dockerfile' -o -name '*.py')

echo "== 13. Workflows de los starters con actionlint =="
if command -v actionlint >/dev/null 2>&1; then
  # actionlint resuelve "uses: ./.github/workflows/x.yml" desde la raiz del repo git: cada
  # starter se valida en una copia con su propio git, o las llamadas locales no se encuentran.
  while IFS= read -r starter; do
    is_published "$starter" || continue
    [ -d "$starter/.github/workflows" ] || continue
    tmp=$(mktemp -d)
    cp -r "$starter/." "$tmp/"
    git -C "$tmp" init -q
    if ! output=$(cd "$tmp" && actionlint -no-color 2>&1); then
      echo "ACTIONLINT FALLA: $starter"
      printf '%s\n' "$output" | sed 's/^/    /'
      fail=1
    fi
    rm -rf "$tmp"
  done < <(find bootcamp -type d -path "*/3-proyecto/starter" 2>/dev/null)
else
  echo "AVISO: actionlint no esta instalado, no se validan los starters"
fi

[ "$fail" -eq 0 ] && echo "OK: sin problemas detectados."
exit "$fail"
