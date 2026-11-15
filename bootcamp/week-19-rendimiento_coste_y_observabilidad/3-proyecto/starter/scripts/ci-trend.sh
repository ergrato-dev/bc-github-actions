#!/usr/bin/env bash
# Copia en <tu-org>/tablero como scripts/ci-trend.sh (con bit de ejecución).
# Tendencia de un workflow: runs, tasa de éxito y duración p50/p95, en markdown.
# Lee de stdin los runs tal como los da la API, uno tras otro:
#   gh api "repos/{owner}/{repo}/actions/workflows/ci.yml/runs?branch=main&status=completed&per_page=100" --jq '.workflow_runs[]'
# Con BUDGET (segundos), avisa con ::warning si el p95 se pasa del presupuesto.
set -euo pipefail

budget="${BUDGET:-}"

read -r runs ok p50 p95 < <(jq -rs '
  [.[] | (.updated_at | fromdateiso8601) - (.run_started_at | fromdateiso8601)] as $d
  | ($d | sort) as $s
  | def pct(p): if ($s | length) == 0 then 0 else $s[(p * ($s | length) | ceil) - 1] end;
  # TODO 3: el cuarto valor es el p95 con pct, no la duración máxima.
  "\(length) \([.[] | select(.conclusion == "success")] | length) \(pct(0.5)) \($s | max // 0)"
')

rate=0
if (( runs > 0 )); then rate=$(( ok * 100 / runs )); fi

echo "| Runs | Éxito | p50 (s) | p95 (s) |"
echo "|--:|--:|--:|--:|"
echo "| $runs | $rate % | $p50 | $p95 |"

# TODO 4: si budget no está vacío y p95 lo supera, escribe en stderr
# "::warning title=CI lento::p95 de <p95> s, por encima del presupuesto de <budget> s".
: "$budget"
