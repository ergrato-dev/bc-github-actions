#!/usr/bin/env bash
# Copia en <tu-org>/tablero como scripts/job-timings.sh (con bit de ejecución).
# Tiempos de los jobs de un run en una tabla markdown, para $GITHUB_STEP_SUMMARY.
# Lee de stdin los jobs tal como los da la API, uno tras otro:
#   gh api "repos/{owner}/{repo}/actions/runs/$RUN_ID/jobs" --paginate --jq '.jobs[]'
set -euo pipefail

jq -rs '
  def secs: if . == null then null else fromdateiso8601 end;
  map(
    (.created_at | secs) as $c | (.started_at | secs) as $s | (.completed_at | secs) as $e
    | {name, created: $c, ended: $e,
       queue: (if $s then $s - $c else 0 end),
       run: (if $s and $e then $e - $s else 0 end)}
    # TODO 1: GitHub factura cada job redondeado al minuto siguiente: 61 s son 2 minutos
    # y un job saltado (0 s) no factura nada.
    | .billable = (.run / 60 | floor)
  )
  | sort_by(.run) | reverse
  # TODO 2: antes de la tabla, la línea "Reloj del run: <s> s · minutos facturables: <n>",
  # con el reloj desde el primer job creado hasta el último terminado; y al final la fila
  # "| **Total** | <cola> | <duración> | <minutos> |".
  | "| Job | Cola (s) | Duración (s) | Minutos facturables |",
    "|---|--:|--:|--:|",
    (.[] | "| \(.name) | \(.queue) | \(.run) | \(.billable) |")
'
