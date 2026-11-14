# Práctica 03 — El scale set de tablero

> El controller está listo, pero no sabe nada de `tablero`. Hoy declaras el scale set
> `tablero-runners` en un `values.yaml`, lo instalas junto al secret de la App y mueves `lab.yml`
> a él. Al lanzarlo, ves nacer un pod para el job y desaparecer cuando termina.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `ops/arc/values.yaml` con el scale set `tablero-runners`, registrado en el repo y escalando de
  0 a 2 runners
- `ops/arc/install.sh` completo: controller, namespace, secret de la App y scale set, con la misma
  versión de ARC
- El listener de `tablero-runners` conectado a GitHub
- `lab.yml` en `runs-on: tablero-runners`, con actionlint y zizmor sin hallazgos
- Un run de `lab.yml` en verde en un pod de ARC que ya no existe

## 📋 Antes de empezar

Terminaste la [práctica 02](02-arc-con-helm.md) y leíste la
[teoría 05](../1-teoria/05-scale-sets-y-runs-on.md). Necesitas los datos de la App en el entorno:

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
source ~/.config/tablero-arc/app.env
helm list -A --kube-context kind-gha -o json | jq -r '.[] | .namespace + "/" + .name + " " + .status'
# arc-systems/arc deployed
```

---

## Paso 1: El scale set, en un `values.yaml`

**Por qué**: el chart `gha-runner-scale-set` se configura con un archivo de values, y ese
archivo es todo lo que decides sobre tus runners. Versionado en `tablero`, cualquier cambio
pasa por un PR. Tres valores definen **qué** es el scale set:

- **`githubConfigUrl`** decide dónde se registra. Acabado en `/tablero`, es un scale set de
  repositorio: solo `tablero` puede mandarle jobs, igual que el runner de la Semana 15. Acabado
  en `/<tu-org>`, quedaría al alcance de todos los repos de la org, porque una org Free no puede
  limitar su runner group por defecto.
- **`githubConfigSecret`** es un **nombre**, no un objeto con credenciales. El chart admite poner
  la clave aquí mismo, pero entonces acabaría en el repo y en los values guardados de la release.
- **`runnerScaleSetName`** es lo que escribes en `runs-on`. `tablero` no usa etiquetas
  adicionales: el nombre basta.

Falta un cuarto valor que no se ve: si no defines `template`, el chart usa
`ghcr.io/actions/actions-runner:latest`. Lo fijas desde ya a la versión de la Semana 15; la
práctica 04 le añade el digest y el resto del pod.

**Comando**: crea `ops/arc/values.yaml`:

```yaml
# Values del chart gha-runner-scale-set para el scale set tablero-runners. Los aplica
# ops/arc/install.sh; la versión del chart está fijada allí.

# Runner de repositorio: solo tablero lo ve, igual que el de la Semana 15. La GitHub App
# necesita entonces Administration (read and write) sobre tablero y nada en la org.
githubConfigUrl: https://github.com/<tu-org>/tablero

# Nombre del secret de Kubernetes que crea install.sh: la clave privada nunca pasa por aquí.
githubConfigSecret: tablero-arc-app

# El nombre es lo que pone runs-on.
runnerScaleSetName: tablero-runners

template:
  spec:
    containers:
      - name: runner
        # Sin template, el chart usaría actions-runner:latest.
        image: ghcr.io/actions/actions-runner:2.338.2
        command: ["/home/runner/run.sh"]
```

**Verifica** (con tu org en lugar de `<tu-org>`): las órdenes de `arc-scope-repo`, `arc-secret-by-name` y `scale-set-name`:

```bash
yq '.githubConfigUrl' ops/arc/values.yaml | sed "s#^https://github.com/$GH_REPO\$#repo-ok#"
# repo-ok
yq '.githubConfigSecret | type + " " + (. | tostring)' ops/arc/values.yaml
# !!str tablero-arc-app
yq '.runnerScaleSetName' ops/arc/values.yaml
# tablero-runners
```

`!!str` confirma que `githubConfigSecret` es un texto, no un mapa con credenciales dentro.

---

## Paso 2: De 0 a 2 runners

**Por qué**: `minRunners` y `maxRunners` deciden cuántos pods puede haber a la vez.

- **`minRunners: 0`**: sin jobs no hay ningún pod esperando. Un runner en reposo es un proceso
  registrado en GitHub y un pod gastando memoria en tu máquina sin hacer nada. Con 0, cada job
  crea el suyo y lo pagas con unos segundos de arranque.
- **`maxRunners: 2`**: es tu techo de seguridad. Si alguien lanza veinte jobs, nunca habrá más de
  dos pods en tu kind; el resto espera en cola. En la práctica 04 cada pod puede llegar a 4 GiB:
  dos caben en un portátil, diez no.

**Comando**: añade los dos valores en `ops/arc/values.yaml`, justo debajo de `runnerScaleSetName`:

```yaml
# El nombre es lo que pone runs-on. Con 0 no hay ningún pod esperando: cada job crea el suyo.
runnerScaleSetName: tablero-runners
minRunners: 0
maxRunners: 2
```

**Verifica**: la orden de `scale-set-bounds`:

```bash
yq '"min=" + (.minRunners | tostring) + " max=" + (.maxRunners | tostring)' ops/arc/values.yaml
# min=0 max=2
```

---

## Paso 3: `install.sh` completo y el listener

**Por qué**: con el scale set definido, el script pasa a reconstruir ARC entero en un clúster
vacío. El orden importa:

1. **Controller** primero: el chart del scale set lo busca para darle permisos.
2. **Namespace y secret** después: el scale set no arranca sin su credencial. Son las órdenes que
   lanzaste a mano en la práctica 01, ahora en el script, con `--dry-run=client -o yaml | apply`
   para que repetirlas actualice en lugar de fallar.
3. **Scale set** al final, con el **mismo** `--version "$ARC_VERSION"` que el controller.

Las variables de la App se validan al principio con `${VAR:?}`: si falta una, el script se para
antes de tocar el clúster, en vez de crear un secret vacío.

Cuando el scale set existe, el controller usa la App para registrarlo en `tablero` y arranca un
**listener**: un pod en `arc-systems` que mantiene abierta una conexión saliente con GitHub y
avisa cuando hay un job para `tablero-runners` ([teoría 03](../1-teoria/03-arquitectura-de-arc.md)).
Si el listener aparece, la App funciona.

**Comando**: sustituye `ops/arc/install.sh` entero por esta versión:

```bash
#!/usr/bin/env bash
#
# install.sh — instala ARC en el clúster kind del laboratorio (contexto kind-gha):
#   controller en arc-systems y el scale set tablero-runners en arc-runners.
#
# Necesita las variables de la GitHub App de tablero:
#   APP_CLIENT_ID, APP_INSTALLATION_ID y APP_PRIVATE_KEY_FILE (ruta al .pem, fuera del repo).
# Idempotente: repetirlo actualiza el secret y las dos releases.

set -euo pipefail
: "${APP_CLIENT_ID:?falta APP_CLIENT_ID}"
: "${APP_INSTALLATION_ID:?falta APP_INSTALLATION_ID}"
: "${APP_PRIVATE_KEY_FILE:?falta APP_PRIVATE_KEY_FILE}"

# Controller y scale set salen de la misma release de ARC: versiones distintas no se garantizan.
ARC_VERSION=0.15.1
CHARTS=oci://ghcr.io/actions/actions-runner-controller-charts
KUBE=(--kube-context kind-gha)

helm upgrade --install arc "${KUBE[@]}" --namespace arc-systems --create-namespace \
  --version "$ARC_VERSION" "$CHARTS/gha-runner-scale-set-controller" --wait

kubectl --context kind-gha create namespace arc-runners --dry-run=client -o yaml \
  | kubectl --context kind-gha apply -f -
# github_app_id acepta el client ID de la App. El secret se genera y se aplica sin tocar disco.
kubectl --context kind-gha create secret generic tablero-arc-app --namespace arc-runners \
  --from-literal=github_app_id="$APP_CLIENT_ID" \
  --from-literal=github_app_installation_id="$APP_INSTALLATION_ID" \
  --from-file=github_app_private_key="$APP_PRIVATE_KEY_FILE" \
  --dry-run=client -o yaml | kubectl --context kind-gha apply -f -

helm upgrade --install tablero-runners "${KUBE[@]}" --namespace arc-runners \
  --version "$ARC_VERSION" "$CHARTS/gha-runner-scale-set" \
  -f "$(dirname "$0")/values.yaml" --wait
```

```bash
ops/arc/install.sh
```

**Verifica**: las órdenes de `arc-charts-pinned` y `arc-installed-in-kind`:

```bash
f=ops/arc/install.sh
printf 'version=%s pinned=%s charts=%s\n' "$(grep -oE '^ARC_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' $f)" \
  "$(grep -c -- '--version "\$ARC_VERSION"' $f)" "$(grep -c 'oci://ghcr.io/actions/actions-runner-controller-charts' $f)"
# version=ARC_VERSION=0.15.1 pinned=2 charts=1
v=$(sed -n 's/^ARC_VERSION=//p' ops/arc/install.sh)
helm list -A --kube-context kind-gha -o json | jq -r --arg v "$v" \
  '[.[] | select(.status == "deployed" and (.chart | endswith("-" + $v))) | .namespace + "/" + .name] | sort | join(",")'
# arc-runners/tablero-runners,arc-systems/arc
```

Y lo que el controller hizo con el scale set:

```bash
kubectl --context kind-gha get autoscalingrunnerset tablero-runners -n arc-runners \
  -o jsonpath='{.spec.runnerScaleSetName} {.spec.minRunners} {.spec.maxRunners}{"\n"}'
# tablero-runners 0 2
kubectl --context kind-gha get pods -n arc-systems -o name | grep -c listener
# 1
kubectl --context kind-gha get pods -n arc-runners -o name | wc -l
# 0
```

Un listener en `arc-systems` y ningún runner en `arc-runners`: `minRunners: 0` en acción. Si el
listener no aparece en un minuto, el motivo está en el log del controller:

```bash
kubectl --context kind-gha logs -n arc-systems deploy/arc-gha-rs-controller | grep -i error
```

Con una clave mal copiada verás `failed to parse RSA private key from PEM`; con la App sin los
permisos o sin instalar en `tablero`, un error al crear el scale set en GitHub.

```bash
git add ops/arc
git commit -m "ci(arc): add tablero-runners scale set"
```

---

## Paso 4: `lab.yml` en `tablero-runners`

**Por qué**: el scale set existe, pero ningún job lo pide. `runs-on: tablero-runners` lo hace:
con ARC, el nombre del scale set es la etiqueta que GitHub usa para asignarle el job. Es el
**único** cambio que necesita `lab.yml`: sigue sin `pull_request`, así que solo se lanza a mano
y nunca ejecuta código de un fork en tu clúster.

actionlint no conoce las etiquetas de tus runners y avisaría de una etiqueta desconocida. Se la
enseñas en `.github/actionlint.yaml`, junto a `tablero-lab`, que ya estaba de la Semana 15.

**Comando**: deja `.github/workflows/lab.yml` así (cambian el comentario de cabecera, el `name`
del job y `runs-on`):

```yaml
# Tests unitarios de la API en un runner efímero de ARC en tu kind. Solo se lanza a mano y, como lo
# hace alguien con permiso de escritura, nunca ejecuta código de un PR ajeno en tu máquina.
name: lab
on:
  workflow_dispatch:
concurrency:
  group: ${{ github.workflow }}
  cancel-in-progress: false
permissions: {}
jobs:
  unit:
    name: Tests unitarios en un runner de ARC
    runs-on: tablero-runners
    timeout-minutes: 15
    permissions:
      contents: read
    defaults:
      run:
        working-directory: api
    steps:
      - name: Quién ejecuta este job
        run: echo "runner=$RUNNER_NAME work=$RUNNER_WORKSPACE os=$ImageOS"
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
      - run: uv sync --locked
      - run: uv run --no-sync pytest tests/unit
```

Y `.github/actionlint.yaml`:

```yaml
# Etiquetas propias que actionlint debe aceptar en runs-on: las del runner propio de tablero.
self-hosted-runner:
  labels:
    - tablero-lab
    - tablero-runners
```

**Verifica**: las órdenes de `lab-runs-on-arc`, `own-runners-only-in-lab` y `workflows-lint`:

```bash
printf 'runs-on=%s actionlint=%s\n' "$(yq '.jobs[]."runs-on"' .github/workflows/lab.yml)" \
  "$(yq '."self-hosted-runner".labels | contains(["tablero-runners"])' .github/actionlint.yaml)"
# runs-on=tablero-runners actionlint=true
yq -N '.jobs | to_entries | .[] | select(.value."runs-on" | tostring | test("self-hosted|tablero-lab|tablero-runners")) | (filename | sub(".*/"; "")) + ":" + .key' .github/workflows/*.yml
# lab.yml:unit
actionlint && GH_TOKEN=$(gh auth token) zizmor -q .github/ && echo lint-ok
# No findings to report. Good job! (...)
# lint-ok
```

```bash
git add .github
git commit -m "ci(lab): run lab workflow on arc scale set"
git push
```

---

## Paso 5: Un pod por job

**Por qué**: es la prueba de que todo encaja. GitHub pone el job en cola para `tablero-runners`,
el listener lo ve, el controller crea un `EphemeralRunner` y su pod, el runner ejecuta ese único
job y ARC borra los dos. El job queda en la API con el nombre de un runner que ya no existe.

**Comando**: en una segunda terminal, deja mirando los runners de ARC:

```bash
kubectl --context kind-gha get pods -n arc-runners -w
```

En la primera, lanza `lab.yml` y espera a que termine:

```bash
gh workflow run lab.yml --ref main
sleep 5
gh run watch "$(gh run list --workflow lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
```

En la segunda terminal aparece un pod `tablero-runners-<x>-runner-<y>`: pasa por `Pending`
mientras baja la imagen la primera vez, luego a `Running` y, cuando el job termina, desaparece.
Para la vigilancia con Ctrl-C.

**Verifica**: la orden de `lab-green-on-arc`, que solo cuenta el run del último commit de `main`:

```bash
git fetch -q origin main
id=$(gh run list --workflow lab.yml --commit "$(git rev-parse origin/main)" --json databaseId --jq '.[0].databaseId')
gh api "repos/{owner}/{repo}/actions/runs/$id/jobs" \
  --jq '.jobs[0] | "conclusion=\(.conclusion) runner=\(.runner_name) labels=\(.labels | join(","))"'
# conclusion=success runner=tablero-runners-<x>-runner-<y> labels=tablero-runners
kubectl --context kind-gha get pods,ephemeralrunners -n arc-runners -o name | wc -l
# 0
```

En el clúster no queda nada del runner. El bucle de la Semana 15 hacía lo mismo, pero en tu
terminal y de uno en uno; ahora es un servicio del clúster.

---

## ✅ Resultado

- [ ] `values.yaml` registra `tablero-runners` en `<tu-org>/tablero` y nombra el secret de la App
- [ ] El scale set escala de 0 a 2 runners
- [ ] `install.sh` instala controller, secret y scale set con la misma `ARC_VERSION`
- [ ] El listener de `tablero-runners` está en `arc-systems`
- [ ] `lab.yml` pide `tablero-runners`, y actionlint y zizmor pasan sin hallazgos
- [ ] `lab.yml` en verde en el último commit de `main`, en un pod que ya no existe

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 16
# ...
# ✅ kind-gha tiene desplegadas las releases arc y tablero-runners con la versión de ARC de install.sh
# ...
# ✅ lab.yml terminó en success sobre el último commit de main en un runner de tablero-runners
```

Las comprobaciones del pod del runner siguen en rojo: las cierra la práctica 04.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `APP_CLIENT_ID: falta APP_CLIENT_ID` al lanzar `install.sh` | La terminal no tiene los datos de la App | `source ~/.config/tablero-arc/app.env` |
| `repo-ok` no sale en el paso 1 | `<tu-org>` sin cambiar, o `GH_REPO` sin exportar | Pon tu org en `githubConfigUrl` y `export GH_REPO=<tu-org>/tablero` |
| No aparece el listener y el log dice `failed to parse RSA private key from PEM` | El secret no lleva el `.pem` de la App | Revisa `APP_PRIVATE_KEY_FILE` y relanza `install.sh` |
| No aparece el listener y el error habla del scale set en GitHub | La App no tiene Administration o no está instalada en `tablero` | Práctica 01, pasos 1 y 2 |
| `lab.yml` se queda en cola | `runs-on` no coincide con `runnerScaleSetName`, o no hay listener | `helm get values tablero-runners -n arc-runners --kube-context kind-gha` y el log del controller |
| actionlint: `label "tablero-runners" is unknown` | Falta la etiqueta en `.github/actionlint.yaml` | Paso 4 |
| `lab-green-on-arc` en rojo tras un run verde | El run es de un commit anterior a `origin/main` | Lanza `lab.yml` otra vez tras tu último push |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [ARC con Helm](02-arc-con-helm.md) | [El pod del runner endurecido](04-pod-del-runner-endurecido.md) |
