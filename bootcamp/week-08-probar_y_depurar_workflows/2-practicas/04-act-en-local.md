# Práctica 04 — act en local

> Los linters leen el YAML; el runner real lo ejecuta, pero cada intento cuesta un push y unos
> minutos. act está en medio: ejecuta tus jobs en tu Docker en un minuto. En esta práctica lo
> instalas con checksum, lo envuelves en `scripts/ci-local.sh`, ves un fallo en local antes del
> push y compruebas dónde deja de parecerse al runner.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- act 0.2.94 en `~/.local/bin`, comprobado contra el `digest` de su release
- La imagen `catthehacker/ubuntu:act-24.04-20260815` en tu Docker
- `scripts/ci-local.sh`: un comando corto para ejecutar cualquier workflow o job de `tablero`
- `ci-api lint` y `lint-workflows` en verde en tu máquina, y un error de ruff cazado antes del push
- Variables y secretos de prueba que git ignora, y lo que act no imita, comprobado

## 📋 Antes de empezar

Terminaste la [práctica 03](03-zizmor-primer-contacto.md): `lint-workflows.yml` tiene sus dos jobs
en `main`. Docker funciona (Semana 05).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
docker info --format '{{.OSType}}/{{.Architecture}}'
# linux/x86_64
```

---

## Paso 1: act con checksum

**Por qué**: la misma regla 9 que con actionlint: versión fijada y checksum, nunca un script de
instalación por `curl | bash` ([teoría 06](../1-teoria/06-act.md#4-antipatrones)). act va a
montar tu repo en contenedores y a hablar con tu Docker: es la última herramienta que querrías
instalar sin saber qué binario es.

**Comando**: el hash, desde la API de la release; la descarga, con `gh` en una carpeta temporal.

```bash
gh api repos/nektos/act/releases/tags/v0.2.94 \
  --jq '.assets[] | select(.name == "act_Linux_x86_64.tar.gz") | .digest'
# sha256:33e6748e3c07affb6855f19fb7a28bc6c344c1d0888fae0564e6d34d4a71915a
tmp=$(mktemp -d) && cd "$tmp"
gh release download v0.2.94 -R nektos/act -p act_Linux_x86_64.tar.gz
echo "33e6748e3c07affb6855f19fb7a28bc6c344c1d0888fae0564e6d34d4a71915a  act_Linux_x86_64.tar.gz" | sha256sum -c
# act_Linux_x86_64.tar.gz: OK
tar -xzf act_Linux_x86_64.tar.gz act
mkdir -p ~/.local/bin
install -m 0755 act ~/.local/bin/act
cd ~/code/tablero && rm -rf "$tmp"
```

En un Mac con Apple Silicon el archivo es `act_Darwin_arm64.tar.gz`, con su propio `digest`:
cambia el nombre en las dos órdenes y usa `shasum -a 256 -c` en lugar de `sha256sum -c`.

**Verifica**:

```bash
command -v act
# /home/<tu-usuario>/.local/bin/act
act --version
# act version 0.2.94
```

Si act avisa de una versión nueva, ignóralo: la fijada es la del resto del bootcamp.

---

## Paso 2: El plan y la imagen del runner

**Por qué**: `act -l` lee todos los workflows y enseña qué jobs hay, en qué etapa (el orden que
sale de `needs:`) y con qué eventos, sin crear ni un contenedor. Luego necesitas la imagen que
hará de `ubuntu-24.04`. Con tag **con fecha**: `act-24.04` a secas se reapunta en cada
publicación y tu prueba cambiaría sin que cambies nada
([teoría 06](../1-teoria/06-act.md#la-imagen-del-runner)).

**Comando**:

```bash
act -l
# Stage  Job ID       Job name                               Workflow name   Workflow file       Events
# 0      lint         Lint y formato (ruff)                  ci-api          ci-api.yml          push,pull_request,workflow_dispatch
# ...
# 0      versions     Versiones declaradas                   debug-lab       debug-lab.yml       workflow_dispatch
# 0      actionlint   actionlint                             lint-workflows  lint-workflows.yml  push,pull_request,workflow_dispatch
# 0      zizmor       zizmor                                 lint-workflows  lint-workflows.yml  workflow_dispatch,push,pull_request
# ...
# 1      integration  Tests de integración (PostgreSQL 17)   ci-api          ci-api.yml          push,pull_request,workflow_dispatch
#
# Detected multiple jobs with the same job name, use `-W` to specify the path to the specific workflow.
```

El aviso final importa: `lint` existe en `ci-api` y en `ci-web`, y `act -j lint` sin `-W`
ejecutaría los dos. El script del paso 3 siempre pasa `-W`.

> ⚠️ La imagen descarga unos **570 MB** y ocupa más de 2 GB en disco. Hazlo con una conexión que
> lo aguante; solo se descarga una vez.

```bash
docker pull catthehacker/ubuntu:act-24.04-20260815
```

**Verifica**:

```bash
docker image ls catthehacker/ubuntu --format '{{.Repository}}:{{.Tag}}'
# catthehacker/ubuntu:act-24.04-20260815
```

---

## Paso 3: `scripts/ci-local.sh`

**Por qué**: la orden completa de act lleva evento, `-W`, `-j`, `-P` con la imagen fechada y la
arquitectura. Nadie la escribe igual dos veces. Un script la fija para todos: la misma imagen, el
evento `pull_request` por defecto (el de un PR, que es lo que estás a punto de abrir) y
`linux/amd64` para que en un Mac ARM no busque una imagen que no existe. Y falla con un mensaje
claro si falta act o el workflow no existe.

**Comando**: crea `scripts/ci-local.sh`.

```bash
#!/usr/bin/env bash
# ci-local.sh — ejecuta un workflow (o un job) de tablero en tu máquina con act, en Docker.
# Uso: scripts/ci-local.sh --list
#      scripts/ci-local.sh <workflow> [job] [argumentos extra de act]
# Ejemplo: scripts/ci-local.sh ci-api lint
set -euo pipefail

ACT_VERSION="0.2.94"
# La imagen que act usa como runner ubuntu-24.04. Tag con fecha: la etiqueta act-24.04 se mueve.
RUNNER_IMAGE="catthehacker/ubuntu:act-24.04-20260815"
EVENT="${EVENT:-pull_request}"

if ! command -v act >/dev/null; then
  echo "act no está instalado: Semana 08, práctica 04, paso 1" >&2
  exit 1
fi
if [[ "$(act --version)" != "act version ${ACT_VERSION}" ]]; then
  echo "Aviso: se espera act ${ACT_VERSION}, tienes '$(act --version)'" >&2
fi

if [[ "${1:-}" == "--list" ]]; then
  exec act --list
fi

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 --list | <workflow> [job] [argumentos de act]" >&2
  exit 2
fi

workflow=".github/workflows/$1.yml"
shift
[[ -f "$workflow" ]] || { echo "No existe $workflow" >&2; exit 2; }

args=("$EVENT" -W "$workflow" -P "ubuntu-24.04=${RUNNER_IMAGE}")
# Sin esto, en un Mac con Apple Silicon act intentaría una imagen arm64 que no existe.
args+=(--container-architecture linux/amd64)
if [[ $# -gt 0 && "$1" != -* ]]; then
  args+=(-j "$1")
  shift
fi

exec act "${args[@]}" "$@"
```

`exec` cambia el script por act: un job rojo deja `$?` distinto de 0. Lo que va detrás del job
pasa tal cual a act. Dale permiso de ejecución con `chmod +x scripts/ci-local.sh`.

**Verifica**: las órdenes de `ci-local-script`, `ci-local-image` y `ci-local-list`, y un error
claro.

```bash
chmod +x scripts/ci-local.sh
test -x scripts/ci-local.sh && head -1 scripts/ci-local.sh && grep -x 'set -euo pipefail' scripts/ci-local.sh
# #!/usr/bin/env bash
# set -euo pipefail
grep -oE 'catthehacker/ubuntu:act-24\.04[^" ]*' scripts/ci-local.sh
# catthehacker/ubuntu:act-24.04-20260815
./scripts/ci-local.sh --list 2>/dev/null | grep -c 'lint-workflows\.yml'
# 2
./scripts/ci-local.sh no-existe; echo "exit $?"
# No existe .github/workflows/no-existe.yml
# exit 2
```

---

## Paso 4: Dos workflows en tu Docker

**Por qué**: `ci-api lint` tiene lógica de verdad (uv, el lockfile, ruff) y es el job que más
tocarás. `lint-workflows` es tu puerta: ejecutada en local antes de un PR, el rojo te llega en la
terminal y no en el PR. La primera vez act clona cada action en `~/.cache/act`; luego, segundos.

**Comando**:

```bash
./scripts/ci-local.sh ci-api lint
# [ci-api/Lint y formato (ruff)] 🚀  Start image=catthehacker/ubuntu:act-24.04-20260815
# ...
# [ci-api/Lint y formato (ruff)]   ✅  Success - Main ruff format
# ...
# [ci-api/Lint y formato (ruff)] 🏁  Job succeeded
./scripts/ci-local.sh lint-workflows 2>&1 | grep -E 'tar.gz: OK|add-matcher|🏁'
# [lint-workflows/actionlint]   | actionlint_1.7.12_linux_amd64.tar.gz: OK
# [lint-workflows/actionlint]   ❓ add-matcher .github/actionlint-matcher.json
# [lint-workflows/actionlint] 🏁  Job succeeded
# [lint-workflows/zizmor    ]   ❓ add-matcher /run/act/actions/astral-sh-setup-uv@.../.github/python.json
# [lint-workflows/zizmor    ] 🏁  Job succeeded
```

Los dos jobs de `lint-workflows` corren a la vez, como en el runner, porque ninguno tiene
`needs:`; por eso sus líneas pueden salir mezcladas. Los `❓ add-matcher` son act diciéndote que
vio el comando y no hace nada con él: el segundo es el matcher que registra la propia `setup-uv`.

**Verifica**: el código de salida de los dos.

```bash
./scripts/ci-local.sh ci-api lint > /dev/null 2>&1; echo "exit $?"
# exit 0
./scripts/ci-local.sh lint-workflows > /dev/null 2>&1; echo "exit $?"
# exit 0
```

---

## Paso 5: Romperlo en local, antes del push

**Por qué**: es para lo que existe act. Ejecuta lo que hay en tu carpeta de trabajo, comiteado o
no: el fallo aparece sin un commit de "fix ci" en el historial y sin gastar un minuto de runner.

**Comando**: un import sin usar en la API, el job de lint, y vuelta atrás.

```bash
sed -i '/^from typing import Annotated/i import os' api/src/tablero/main.py
./scripts/ci-local.sh ci-api lint 2>&1 | grep -E 'F401|🏁'
# [ci-api/Lint y formato (ruff)]   ❗  ::error title=ruff (F401),file=.../api/src/tablero/main.py,line=3,...::src/tablero/main.py:3:8: F401 `os` imported but unused...
# [ci-api/Lint y formato (ruff)] 🏁  Job failed
git restore api/src/tablero/main.py
```

(En macOS, `sed -i ''`.) El `❗ ::error` es la anotación que `ruff --output-format=github` deja en
el PR; aquí, solo texto.

**Verifica**: el árbol limpio, sin rastro del experimento.

```bash
git status --short
# (sin salida)
```

---

## Paso 6: Variables y secretos de prueba

**Por qué**: un job que lee `vars.*` o `secrets.*` necesita que se los des. act los toma de
archivos en formato `.env` con `--var-file` y `--secret-file`. Esos archivos se ignoran en git
**antes** de crearlos: un `git add .` distraído los publicaría. Y nunca llevan un valor real: act
imprime mucho y tu terminal guarda historial. Las credenciales de usar y tirar del bootcamp valen
`cambiame` ([teoría 06](../1-teoria/06-act.md#secretos-variables-y-eventos)).

**Comando**: `debug-lab` lee `vars.LAB_OWNER` desde la práctica 01 y solo escucha
`workflow_dispatch`; `EVENT` cambia el evento por defecto del script.

```bash
printf '.secrets\n.vars\n' >> .gitignore
printf 'LAB_OWNER=act-local\n' > .vars
printf 'DATABASE_PASSWORD=cambiame\n' > .secrets
EVENT=workflow_dispatch ./scripts/ci-local.sh debug-lab versions --var-file .vars --secret-file .secrets \
  2>&1 | grep -E 'Responsable|🏁'
# [debug-lab/Versiones declaradas]   ❓  ::notice title=Responsable::act-local
# [debug-lab/Versiones declaradas] 🏁  Job succeeded
```

`DATABASE_PASSWORD` no lo usa este job; queda para el día que pruebes uno que sí. En GitHub, sin
la variable, el step dice `sin definir`.

**Verifica**: git ignora los dos archivos y solo `.gitignore` aparece como cambio.

```bash
git check-ignore .secrets .vars
# .secrets
# .vars
git status --short
#  M .gitignore
```

---

## Paso 7: Lo que act no imita

**Por qué**: un verde de act no es un verde del runner. act ejecuta tus scripts, pero ignora todo
lo que depende de GitHub como plataforma ([teoría 06](../1-teoria/06-act.md#lo-que-act-no-imita)).
Lo compruebas con el mismo `debug-lab` del paso 5 de la práctica 01, que en GitHub dejó un
`::error` anotado en `api/.python-version`.

**Comando**:

```bash
EVENT=workflow_dispatch ./scripts/ci-local.sh debug-lab versions --input expected_python=3.14 \
  2>&1 | grep -E '::error|Summary|🏁'
# [debug-lab/Versiones declaradas]   ❗  ::error file=api/.python-version,line=1,title=Versión de Python::fijada 3.15, esperada 3.14
# [debug-lab/Versiones declaradas]   ⚙  Summary - ## Versiones de tablero
# [debug-lab/Versiones declaradas] 🏁  Job failed
```

| En el runner real | En act |
|---|---|
| `::error` con archivo y línea se convierte en anotación | Sale como texto con `❗` |
| El resumen es una página del run | act 0.2.94 lo vuelca al log con `⚙ Summary`; no hay página |
| `timeout-minutes: 5` corta el job | Se ignora |
| `permissions: contents: read` limita el `GITHUB_TOKEN` | Se ignora, y no hay `GITHUB_TOKEN` automático |
| `concurrency` cancela runs obsoletos | Se ignora |
| Los `services:` de `ci-api integration` arrancan PostgreSQL | No cuentes con ello: pruébalo en una rama |

El circuito: linters, act para la lógica y una rama con PR para esta tabla ([teoría 07](../1-teoria/07-estrategia-de-pruebas-de-workflows.md#el-circuito-de-un-cambio-en-un-workflow)).

**Verifica**: el código de salida de act refleja el job rojo, aunque no haya anotaciones.

```bash
EVENT=workflow_dispatch ./scripts/ci-local.sh debug-lab versions --input expected_python=3.14 > /dev/null 2>&1; echo "exit $?"
# exit 1
```

Ahora sube el script y el `.gitignore`. Este commit no toca `.github/workflows/`, así que el
filtro salta `lint-workflows`: lánzalo a mano para que el último commit de `main` tenga su verde.

```bash
git add scripts/ci-local.sh .gitignore
git commit -m "ci: run workflows locally with act"
git push
gh workflow run lint-workflows.yml --ref main
sleep 10
id=$(gh run list --workflow lint-workflows.yml --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
```

---

## ✅ Resultado

- [ ] act 0.2.94 está en `~/.local/bin`, instalado tras `sha256sum -c`
- [ ] La imagen `act-24.04-20260815` está en tu Docker
- [ ] `scripts/ci-local.sh` es ejecutable, fija la imagen con fecha y lista los jobs con `--list`
- [ ] `ci-api lint` y `lint-workflows` terminan en verde en tu máquina
- [ ] Viste un error de ruff en local y lo deshiciste sin commit
- [ ] `.secrets` y `.vars` existen, con valores de prueba, y git los ignora
- [ ] Sabes qué partes de un run solo comprueba el runner real

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 08
# ✅ scripts/ci-local.sh es ejecutable, empieza por #!/usr/bin/env bash y usa set -euo pipefail
# ✅ ci-local.sh fija la imagen del runner de act con un tag con fecha, nunca act-24.04 a secas
# ✅ ci-local.sh --list enseña los jobs de tus workflows, lint-workflows incluido
# ...
# 15/15 comprobaciones superadas.
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `act_Linux_x86_64.tar.gz: FAILED` | El hash no es el del archivo descargado | Paso 1: sácalo de `gh api`, sin el prefijo `sha256:` |
| `act: command not found` | `~/.local/bin` no está en tu `PATH` | Añádelo en tu `~/.zshrc` o `~/.bashrc` y abre otra terminal |
| `Cannot connect to the Docker daemon` | Docker no está arrancado | Arráncalo y comprueba con `docker info` |
| act ejecuta `lint` de `ci-api` y de `ci-web` | Usaste `act -j lint` sin `-W` | Usa el script: siempre pasa `-W` |
| `debug-lab` falla en act con `esperada ` vacío | Con `-j`, act ejecuta el job aunque el evento por defecto (`pull_request`) no sea el suyo, y sin inputs | `EVENT=workflow_dispatch ./scripts/ci-local.sh debug-lab versions` |
| La primera ejecución tarda minutos | act descarga la imagen y clona cada action | Normal; la segunda vez ya están en tu máquina |
| `Aviso: se espera act 0.2.94` | Tienes otra versión de act antes en el `PATH` | `command -v act` y reinstala con el paso 1 |
| `.secrets` aparece en `git status` | Lo creaste antes de ignorarlo, o sin el punto | `git check-ignore -v .secrets` y corrige `.gitignore` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [zizmor: primer contacto](03-zizmor-primer-contacto.md) | [Proyecto: capa 08 de tablero](../3-proyecto/README.md) |
