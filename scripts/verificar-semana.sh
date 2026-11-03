#!/usr/bin/env bash
#
# verificar-semana.sh — autograding declarativo del bootcamp.
#
# Uso:
#   ./scripts/verificar-semana.sh 05        comprueba la Semana 05
#   ./scripts/verificar-semana.sh --doctor  comprueba tu entorno y tu repo
#
# Este script no sabe nada de ninguna semana en concreto: lee las
# comprobaciones de bootcamp/week-NN-*/checks.json y las ejecuta en tu copia
# local de <tu-org>/tablero (APP_DIR), con GH_REPO apuntando a ese repo para
# que todo "gh run" y "gh api repos/{owner}/{repo}" hable con el tuyo.
# Si necesitas logica especifica de una semana, el sitio es el checks.json,
# nunca este archivo. Contrato completo: docs/autograding.md.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${BC_GHA_CONFIG:-$HOME/.bc-github-actions}"

rojo()  { printf '\033[0;31m%s\033[0m\n' "$*"; }
verde() { printf '\033[0;32m%s\033[0m\n' "$*"; }
gris()  { printf '\033[0;90m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
# Configuracion: REPO=<tu-org>/tablero y APP_DIR=/ruta/a/tu/clon.
# Las variables de entorno REPO y APP_DIR tienen prioridad sobre el archivo.
# ---------------------------------------------------------------------------
cargar_config() {
  local repo_env="${REPO:-}" app_env="${APP_DIR:-}"
  if [[ -f "$CONFIG" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG"
  fi
  REPO="${repo_env:-${REPO:-}}"
  APP_DIR="${app_env:-${APP_DIR:-}}"
  APP_DIR="${APP_DIR/#\~/$HOME}"
}

# ---------------------------------------------------------------------------
# --doctor: comprueba las dependencias antes de culpar al material
# ---------------------------------------------------------------------------
doctor() {
  local fallos=0

  comprobar() {
    local etiqueta="$1" resultado="$2" detalle="${3:-}"
    case "$resultado" in
      ok)    printf '  \033[0;32m✅\033[0m %-16s %s\n' "$etiqueta" "$detalle" ;;
      luego) printf '  \033[0;90m⏳\033[0m %-16s %s\n' "$etiqueta" "$detalle" ;;
      *)     printf '  \033[0;31m❌\033[0m %-16s %s\n' "$etiqueta" "$detalle"
             fallos=$(( fallos + 1 )) ;;
    esac
  }

  version_de() {
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

  echo "Herramientas (versiones en docs/stack-versions.md):"
  local h
  for h in gh git jq yq actionlint zizmor uv pnpm; do
    if command -v "$h" >/dev/null 2>&1; then
      comprobar "$h" ok "$(version_de "$h" 2>/dev/null)"
    else
      comprobar "$h" no "no instalado — ver docs/setup-entorno.md"
    fi
  done

  # yq de mikefarah (Go), no el yq de Python: la sintaxis es distinta.
  if command -v yq >/dev/null 2>&1 && ! yq --version 2>&1 | grep -q mikefarah; then
    comprobar "yq (mikefarah)" no "tienes otro yq; instala el de github.com/mikefarah/yq"
  fi

  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    comprobar docker ok "$(version_de docker)"
  else
    comprobar docker no "no disponible — lo necesitas desde la Semana 05"
  fi

  for h in act:08 kind:16 kubectl:16 helm:16; do
    if command -v "${h%%:*}" >/dev/null 2>&1; then
      comprobar "${h%%:*}" ok "$(version_de "${h%%:*}" 2>/dev/null)"
    else
      comprobar "${h%%:*}" luego "se instala en la Semana ${h##*:}"
    fi
  done

  echo
  echo "GitHub:"
  if gh auth status >/dev/null 2>&1; then
    local scopes
    scopes=$(gh auth status 2>&1 | sed -n "s/.*Token scopes: //p" | tr -d "'")
    comprobar "gh auth" ok "scopes: ${scopes:-desconocidos}"
    if [[ -n "$scopes" && "$scopes" != *workflow* ]]; then
      comprobar "scope workflow" no "gh auth refresh -s workflow (sin el no puedes subir .github/workflows/)"
    fi
  else
    comprobar "gh auth" no "gh auth login"
  fi

  cargar_config
  if [[ -z "$REPO" || -z "$APP_DIR" ]]; then
    comprobar "configuracion" no "crea $CONFIG con REPO=<tu-org>/tablero y APP_DIR=<ruta> (Semana 01)"
  else
    if gh repo view "$REPO" --json name >/dev/null 2>&1; then
      comprobar "REPO" ok "$REPO"
    else
      comprobar "REPO" no "$REPO no existe o no tienes acceso"
    fi
    if git -C "$APP_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      comprobar "APP_DIR" ok "$APP_DIR"
    else
      comprobar "APP_DIR" no "$APP_DIR no es un repositorio git"
    fi
  fi

  echo
  if (( fallos == 0 )); then
    verde "Todo listo."
    return 0
  fi
  rojo "$fallos comprobacion(es) del entorno fallaron."
  return 1
}

# ---------------------------------------------------------------------------
# Evaluacion de una asercion
#   exit0        el comando sale con 0
#   exit!=0      el comando sale distinto de 0
#   exit=N       el comando sale exactamente con N
#   stdout~RE    la salida casa con la expresion regular extendida RE
#   stdout!~RE   la salida NO casa con RE
# ---------------------------------------------------------------------------
evaluar() {
  local asercion="$1" codigo="$2" salida="$3"

  case "$asercion" in
    exit0)      [[ "$codigo" -eq 0 ]] ;;
    "exit!=0")  [[ "$codigo" -ne 0 ]] ;;
    exit=*)     [[ "$codigo" -eq "${asercion#exit=}" ]] ;;
    "stdout!~"*) ! grep -qE "${asercion#stdout!~}" <<<"$salida" ;;
    stdout~*)   grep -qE "${asercion#stdout~}" <<<"$salida" ;;
    *)
      rojo "ASERCION DESCONOCIDA: '$asercion'"
      gris "Validas: exit0, exit!=0, exit=N, stdout~RE, stdout!~RE"
      return 2
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Ejecucion de una semana
# ---------------------------------------------------------------------------
verificar_semana() {
  local semana="$1"

  if ! [[ "$semana" =~ ^[0-9]{2}$ ]]; then
    rojo "La semana se indica con dos digitos: 01, 02 ... 20"
    exit 1
  fi

  local h
  for h in jq gh git; do
    if ! command -v "$h" >/dev/null 2>&1; then
      rojo "Falta $h. ./scripts/verificar-semana.sh --doctor"
      exit 1
    fi
  done

  local dir
  dir=$(find "$RAIZ/bootcamp" -maxdepth 1 -type d -name "week-${semana}-*" | head -1)
  if [[ -z "$dir" ]]; then
    rojo "No existe la carpeta de la Semana $semana."
    exit 1
  fi

  local archivo="$dir/checks.json"
  if [[ ! -f "$archivo" ]]; then
    rojo "La Semana $semana todavia no tiene checks.json."
    gris "Se escribe antes que el contenido: ver docs/autograding.md"
    exit 1
  fi

  if ! jq -e . "$archivo" >/dev/null 2>&1; then
    rojo "checks.json invalido: $archivo"
    exit 1
  fi

  cargar_config
  if [[ -z "$REPO" || -z "$APP_DIR" ]]; then
    rojo "Falta la configuracion de tu repo."
    gris "Crea $CONFIG con REPO=<tu-org>/tablero y APP_DIR=<ruta a tu clon> (Semana 01, practica 01)."
    exit 1
  fi
  if ! git -C "$APP_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    rojo "APP_DIR=$APP_DIR no es un repositorio git."
    exit 1
  fi

  # GH_REPO es la variable nativa de gh: todo "gh run", "gh workflow" y
  # "gh api repos/{owner}/{repo}/..." del checks.json habla con tu repo.
  export GH_REPO="$REPO"

  # Semanas con clúster (S16+): kubeconfig temporal con solo ese contexto,
  # para que un "kubectl" a secas nunca toque otro clúster.
  local contexto
  contexto=$(jq -r '.contexto // empty' "$archivo")
  if [[ -n "$contexto" ]]; then
    KUBECONFIG_SEMANA=$(mktemp)
    trap 'rm -f "$KUBECONFIG_SEMANA"' EXIT
    if ! kubectl config view --minify --flatten --context "$contexto" >"$KUBECONFIG_SEMANA" 2>/dev/null \
       || ! KUBECONFIG="$KUBECONFIG_SEMANA" kubectl get --raw /readyz >/dev/null 2>&1; then
      rojo "El clúster '$contexto' no responde."
      gris "./scripts/lab-up.sh y vuelve a intentarlo."
      exit 1
    fi
    export KUBECONFIG="$KUBECONFIG_SEMANA"
  fi

  echo "Semana $semana — $(jq -r '.titulo' "$archivo")  [repo: $REPO${contexto:+ · contexto: $contexto}]"
  echo

  cd "$APP_DIR"

  local total=0 pasados=0
  local descripcion cmd asercion pista codigo salida

  # El primer campo (id) se descarta con "_": es el identificador estable
  # de checks.json, pero este script solo reporta por descripcion.
  while IFS=$'\t' read -r _ descripcion cmd asercion pista; do
    total=$(( total + 1 ))

    # `if` alrededor: con `set -e`, capturar el codigo de un comando que falla
    # a proposito requiere que la ejecucion este en un contexto condicional.
    # </dev/null: un comando no puede comerse el resto de checks.json.
    if salida=$(bash -c "$cmd" </dev/null 2>/dev/null); then
      codigo=0
    else
      codigo=$?
    fi

    if evaluar "$asercion" "$codigo" "$salida"; then
      printf '  \033[0;32m✅\033[0m %s\n' "$descripcion"
      pasados=$(( pasados + 1 ))
    else
      printf '  \033[0;31m❌\033[0m %s\n' "$descripcion"
      printf '     \033[0;90mpista: %s\033[0m\n' "$pista"
    fi
  # join(), no @tsv: @tsv duplica cada backslash literal y read -r nunca lo
  # deshace, asi que una regex con \. se rompe en silencio. join() es seguro
  # mientras ningun campo tenga un tab o salto de linea.
  done < <(jq -r '.checks[] | [.id, .descripcion, .cmd, .assert, .pista] | join("\t")' "$archivo")

  echo
  if (( pasados == total )); then
    verde "$pasados/$total comprobaciones superadas."
    return 0
  fi
  rojo "$pasados/$total comprobaciones superadas."
  gris "Cada pista dice en que practica y en que paso se arregla."
  return 1
}

# ---------------------------------------------------------------------------
case "${1:-}" in
  --doctor)      doctor ;;
  -h|--help|"")  sed -n '3,15p' "${BASH_SOURCE[0]}" | sed 's|^# \?||' ;;
  *)             verificar_semana "$1" ;;
esac
