#!/usr/bin/env bash
#
# check-week.sh — autograding declarativo del bootcamp.
#
# Uso:
#   ./scripts/check-week.sh 05        comprueba la Semana 05
#   ./scripts/check-week.sh --doctor  comprueba tu entorno y tu repo
#
# Lee bootcamp/week-NN-*/checks.json y ejecuta cada comprobación dentro de tu
# copia local de <tu-org>/tablero (APP_DIR), con gh apuntando a ese repo.
# Este script no sabe nada de ninguna semana: la lógica de una semana va en su
# checks.json, nunca aquí. Contrato completo: docs/autograding.md.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${BC_GHA_CONFIG:-$HOME/.bc-github-actions}"

red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
gray()  { printf '\033[0;90m%s\033[0m\n' "$*"; }

# REPO y APP_DIR del entorno ganan al archivo: permite verificar otro clon
# sin tocar la configuración.
load_config() {
  local env_repo="${REPO:-}" env_app_dir="${APP_DIR:-}"
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
  fi
  REPO="${env_repo:-${REPO:-}}"
  APP_DIR="${env_app_dir:-${APP_DIR:-}}"
  APP_DIR="${APP_DIR/#\~/$HOME}"
}

tool_version() {
  case "$1" in
    gh)         gh --version | head -1 ;;
    git)        git --version ;;
    jq)         jq --version ;;
    yq)         yq --version ;;
    actionlint) actionlint -version | head -1 ;;
    zizmor)     zizmor --version ;;
    uv)         uv --version ;;
    pnpm)       echo "pnpm $(pnpm --version)" ;;
    docker)     echo "Docker $(docker version --format '{{.Server.Version}}' 2>/dev/null)" ;;
    act)        act --version ;;
    kind)       kind version ;;
    kubectl)    kubectl version --client -o json | jq -r .clientVersion.gitVersion ;;
    helm)       helm version --short ;;
  esac
}

# Para qué: separar "te falta una herramienta" de "el material está mal"
# antes de que el alumno pierda tiempo con una comprobación roja.
doctor() {
  local failures=0

  report() {
    local label="$1" result="$2" detail="${3:-}"
    case "$result" in
      ok)    printf '  \033[0;32m✅\033[0m %-16s %s\n' "$label" "$detail" ;;
      later) printf '  \033[0;90m⏳\033[0m %-16s %s\n' "$label" "$detail" ;;
      *)     printf '  \033[0;31m❌\033[0m %-16s %s\n' "$label" "$detail"
             failures=$(( failures + 1 )) ;;
    esac
  }

  echo "Herramientas (versiones en docs/stack-versions.md):"
  local tool
  for tool in gh git jq yq actionlint zizmor uv pnpm; do
    if command -v "$tool" >/dev/null 2>&1; then
      report "$tool" ok "$(tool_version "$tool" 2>/dev/null)"
    else
      report "$tool" missing "no instalado — ver docs/setup-entorno.md"
    fi
  done

  # El yq de Python tiene otra sintaxis: los checks.json fallarían sin motivo aparente.
  if command -v yq >/dev/null 2>&1 && ! yq --version 2>&1 | grep -q mikefarah; then
    report "yq (mikefarah)" missing "tienes otro yq; instala el de github.com/mikefarah/yq"
  fi

  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    report docker ok "$(tool_version docker)"
  else
    report docker missing "no disponible — lo necesitas desde la Semana 05"
  fi

  local entry
  for entry in act:08 kind:16 kubectl:16 helm:16; do
    tool="${entry%%:*}"
    if command -v "$tool" >/dev/null 2>&1; then
      report "$tool" ok "$(tool_version "$tool" 2>/dev/null)"
    else
      report "$tool" later "se instala en la Semana ${entry##*:}"
    fi
  done

  echo
  echo "GitHub:"
  if gh auth status >/dev/null 2>&1; then
    local scopes
    scopes=$(gh auth status 2>&1 | sed -n "s/.*Token scopes: //p" | tr -d "'")
    report "gh auth" ok "scopes: ${scopes:-desconocidos}"
    # Sin "workflow", GitHub rechaza cualquier push que toque .github/workflows/.
    if [[ -n "$scopes" && "$scopes" != *workflow* ]]; then
      report "scope workflow" missing "gh auth refresh -s workflow"
    fi
  else
    report "gh auth" missing "gh auth login --scopes workflow"
  fi

  load_config
  if [[ -z "$REPO" || -z "$APP_DIR" ]]; then
    report "config" missing "crea $CONFIG_FILE con REPO=<tu-org>/tablero y APP_DIR=<ruta> (Semana 01)"
  else
    if gh repo view "$REPO" --json name >/dev/null 2>&1; then
      report "REPO" ok "$REPO"
    else
      report "REPO" missing "$REPO no existe o no tienes acceso"
    fi
    if git -C "$APP_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      report "APP_DIR" ok "$APP_DIR"
    else
      report "APP_DIR" missing "$APP_DIR no es un repositorio git"
    fi
  fi

  echo
  if (( failures == 0 )); then
    green "Todo listo."
    return 0
  fi
  red "$failures comprobacion(es) del entorno fallaron."
  return 1
}

# Aserciones válidas: exit0, exit!=0, exit=N, stdout~RE, stdout!~RE (RE extendida).
evaluate() {
  local assertion="$1" code="$2" output="$3"

  case "$assertion" in
    exit0)       [[ "$code" -eq 0 ]] ;;
    "exit!=0")   [[ "$code" -ne 0 ]] ;;
    exit=*)      [[ "$code" -eq "${assertion#exit=}" ]] ;;
    "stdout!~"*) ! grep -qE "${assertion#stdout!~}" <<<"$output" ;;
    stdout~*)    grep -qE "${assertion#stdout~}" <<<"$output" ;;
    *)
      red "ASERCION DESCONOCIDA: '$assertion'"
      gray "Validas: exit0, exit!=0, exit=N, stdout~RE, stdout!~RE"
      return 2
      ;;
  esac
}

check_week() {
  local week="$1"

  if ! [[ "$week" =~ ^[0-9]{2}$ ]]; then
    red "La semana se indica con dos digitos: 01, 02 ... 20"
    exit 1
  fi

  local tool
  for tool in jq gh git; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      red "Falta $tool. ./scripts/check-week.sh --doctor"
      exit 1
    fi
  done

  local week_dir
  week_dir=$(find "$ROOT/bootcamp" -maxdepth 1 -type d -name "week-${week}-*" | head -1)
  if [[ -z "$week_dir" ]]; then
    red "No existe la carpeta de la Semana $week."
    exit 1
  fi

  local checks_file="$week_dir/checks.json"
  if [[ ! -f "$checks_file" ]]; then
    red "La Semana $week todavia no tiene checks.json."
    gray "Se escribe antes que el contenido: ver docs/autograding.md"
    exit 1
  fi
  if ! jq -e . "$checks_file" >/dev/null 2>&1; then
    red "checks.json invalido: $checks_file"
    exit 1
  fi

  load_config
  if [[ -z "$REPO" || -z "$APP_DIR" ]]; then
    red "Falta la configuracion de tu repo."
    gray "Crea $CONFIG_FILE con REPO=<tu-org>/tablero y APP_DIR=<ruta a tu clon> (Semana 01)."
    exit 1
  fi
  if ! git -C "$APP_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    red "APP_DIR=$APP_DIR no es un repositorio git."
    exit 1
  fi

  # GH_REPO es nativa de gh: todo "gh run" y "gh api repos/{owner}/{repo}/..."
  # del checks.json habla con el repo del alumno sin escribir su nombre.
  export GH_REPO="$REPO"

  # Semanas con clúster (S16+): un kubeconfig temporal con un único contexto
  # impide que un "kubectl" de checks.json toque otro clúster del alumno.
  local context
  context=$(jq -r '.context // empty' "$checks_file")
  if [[ -n "$context" ]]; then
    KUBECONFIG_WEEK=$(mktemp)
    trap 'rm -f "$KUBECONFIG_WEEK"' EXIT
    if ! kubectl config view --minify --flatten --context "$context" >"$KUBECONFIG_WEEK" 2>/dev/null \
       || ! KUBECONFIG="$KUBECONFIG_WEEK" kubectl get --raw /readyz >/dev/null 2>&1; then
      red "El clúster '$context' no responde."
      gray "./scripts/lab-up.sh y vuelve a intentarlo."
      exit 1
    fi
    export KUBECONFIG="$KUBECONFIG_WEEK"
  fi

  echo "Semana $week — $(jq -r '.title' "$checks_file")  [repo: $REPO${context:+ · contexto: $context}]"
  echo

  cd "$APP_DIR"

  local total=0 passed=0
  local description cmd assertion hint code output

  while IFS=$'\t' read -r _ description cmd assertion hint; do
    total=$(( total + 1 ))

    # El "if" permite capturar el código de salida con set -e activo;
    # </dev/null evita que un comando se coma el resto de checks.json.
    if output=$(bash -c "$cmd" </dev/null 2>/dev/null); then
      code=0
    else
      code=$?
    fi

    if evaluate "$assertion" "$code" "$output"; then
      printf '  \033[0;32m✅\033[0m %s\n' "$description"
      passed=$(( passed + 1 ))
    else
      printf '  \033[0;31m❌\033[0m %s\n' "$description"
      printf '     \033[0;90mpista: %s\033[0m\n' "$hint"
    fi
  # join() y no @tsv: @tsv duplica las barras invertidas y read -r no las
  # deshace, así que una regex con \. dejaría de casar sin avisar.
  done < <(jq -r '.checks[] | [.id, .description, .cmd, .assert, .hint] | join("\t")' "$checks_file")

  echo
  if (( passed == total )); then
    green "$passed/$total comprobaciones superadas."
    return 0
  fi
  red "$passed/$total comprobaciones superadas."
  gray "Cada pista dice en que practica y en que paso se arregla."
  return 1
}

case "${1:-}" in
  --doctor)      doctor ;;
  -h|--help|"")  sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's|^# \?||' ;;
  *)             check_week "$1" ;;
esac
