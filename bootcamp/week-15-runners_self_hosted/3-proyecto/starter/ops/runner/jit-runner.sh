#!/usr/bin/env bash
# Runner propio de tablero: cada vuelta registra un runner JIT, lo arranca en un contenedor
# desechable, ejecuta un único job y lo borra. Se copia a ops/runner/jit-runner.sh de
# <tu-org>/tablero. Uso: GH_REPO=<tu-org>/tablero ops/runner/jit-runner.sh
set -euo pipefail

: "${GH_REPO:?exporta GH_REPO=<tu-org>/tablero}"
LABEL=tablero-lab
IMAGE=tablero-runner:local

docker build -q -t "$IMAGE" "$(dirname "$0")" >/dev/null

while true; do
  name="$LABEL-$(date +%s)"
  # TODO 2: pide a la API generate-jitconfig del repositorio una config JIT para "$name", en el
  # grupo 1, con las etiquetas self-hosted y $LABEL, y quédate solo con encoded_jit_config.
  ACTIONS_RUNNER_INPUT_JITCONFIG=""
  export ACTIONS_RUNNER_INPUT_JITCONFIG
  echo "Esperando un job como $name"
  # TODO 3: pasa la config JIT al contenedor por el entorno, nunca como argumento de run.sh.
  # TODO 4: que el contenedor se borre al salir y corra sin capacidades ni escalada de privilegios.
  # TODO 5: ponle techo de procesos, memoria y CPU.
  # TODO 6: quita el socket de Docker.
  docker run --name "$name" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "$IMAGE" ./run.sh
done
