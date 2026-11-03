#!/usr/bin/env bash
#
# lab-down.sh — borra el clúster kind "gha" y todo lo que corre dentro
# (ARC, runners, despliegues de tablero). Los manifiestos y los values de
# Helm de tu repo no se tocan: con ./scripts/lab-up.sh y reaplicandolos
# vuelves al mismo estado.

set -euo pipefail

kind delete cluster --name gha
