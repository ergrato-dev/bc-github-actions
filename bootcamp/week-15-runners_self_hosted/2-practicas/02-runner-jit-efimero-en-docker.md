# Práctica 02 — Runner JIT efímero en Docker

> En la práctica 01 el segundo job encontró lo que dejó el primero. Ahora cada job tiene su
> propio runner: tu máquina pide a GitHub una configuración JIT, la entrega a un contenedor
> nuevo, el contenedor ejecuta un único job y desaparece. El siguiente job empieza de cero.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `ops/runner/Dockerfile`, la imagen del runner de `tablero`
- `ops/runner/jit-runner.sh`, un bucle que crea un runner por job
- La configuración JIT entregada por el entorno, sin token de registro ni `config.sh`
- La sonda en verde dos veces seguidas, las dos `state=clean` y cada una en un runner distinto
- Ningún runner huérfano al parar el bucle

## 📋 Antes de empezar

Terminaste la [práctica 01](01-primer-runner-propio.md): la org solo deja runners propios en
`tablero`, la sonda está en `main` y no queda ningún runner registrado. Leíste la
[teoría 04](../1-teoria/04-runners-efimeros-y-jit.md) y la
[teoría 05](../1-teoria/05-runner-en-contenedor.md).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
gh api "repos/$GH_REPO/actions/runners" --jq .total_count
# 0
```

---

## Paso 1: El Dockerfile y el esqueleto del script

**Por qué**: el script vive en el repo, junto a su imagen, para que el runner de `tablero` sea
código revisable como cualquier otro. El Dockerfile de momento solo nombra la imagen oficial
por tag; en la práctica 03 lo fijas por digest y Dependabot pasa a vigilarlo. El script
construye la imagen al arrancar: si el Dockerfile cambia, el siguiente bucle ya usa la nueva.

**Comando**: crea `ops/runner/Dockerfile`:

```dockerfile
# Imagen del runner propio de tablero: la oficial de actions/runner, sin capas propias.
FROM ghcr.io/actions/actions-runner:2.338.2
```

Y `ops/runner/jit-runner.sh`:

```bash
#!/usr/bin/env bash
# Runner propio de tablero: cada vuelta registra un runner JIT, lo arranca en un contenedor
# desechable, ejecuta un único job y lo borra con todo lo que ese job dejó. Ctrl-C para parar.
# Uso: GH_REPO=<tu-org>/tablero ops/runner/jit-runner.sh
set -euo pipefail

: "${GH_REPO:?exporta GH_REPO=<tu-org>/tablero}"
LABEL=tablero-lab
IMAGE=tablero-runner:local

docker build -q -t "$IMAGE" "$(dirname "$0")" >/dev/null
```

```bash
chmod +x ops/runner/jit-runner.sh
ops/runner/jit-runner.sh
```

`set -euo pipefail` corta el script en el primer fallo: si `gh` no puede pedir la configuración,
el bucle no arranca un contenedor sin ella.

**Verifica**: el script se ejecuta, construye la imagen y el bit de ejecución queda en git:

```bash
docker image inspect tablero-runner:local --format '{{.Config.User}} {{.Config.WorkingDir}}'
# runner /home/runner
git add ops/runner && git ls-files -s ops/runner/jit-runner.sh | cut -c1-6
# 100755
```

---

## Paso 2: Pedir una configuración JIT

**Por qué**: el token de registro de la práctica 01 se canjea por credenciales permanentes y el
runner se queda. La API `generate-jitconfig` registra el runner **ya** como efímero y devuelve
una configuración que sirve para un único job ([teoría 04](../1-teoria/04-runners-efimeros-y-jit.md)).
No hay `config.sh` ni credenciales que sobrevivan al contenedor.

Tres detalles que el check comprueba:

- `runner_group_id=1` es el grupo por defecto, el único que tiene un runner de repositorio en una
  org Free. Va con `-F` para que llegue como número.
- Las etiquetas JIT son **exactamente** las que pasas: sin `labels[]=self-hosted`, un
  `runs-on: [self-hosted, tablero-lab]` no casa nunca.
- El nombre lleva la hora en segundos: cada runner es único y lo reconoces en `runner_name`.

**Comando**: añade el bucle al final de `jit-runner.sh`:

```bash
while true; do
  name="$LABEL-$(date +%s)"
  # El grupo 1 es el grupo por defecto, el único que tiene un runner de repositorio.
  # La config JIT es una credencial: va por el entorno, nunca a disco, al log ni a la línea
  # de órdenes, y el runner la borra de su entorno antes de ejecutar el job.
  ACTIONS_RUNNER_INPUT_JITCONFIG=$(gh api -X POST "repos/$GH_REPO/actions/runners/generate-jitconfig" \
    -f name="$name" -F runner_group_id=1 -f 'labels[]=self-hosted' -f "labels[]=$LABEL" \
    --jq .encoded_jit_config)
  export ACTIONS_RUNNER_INPUT_JITCONFIG
  echo "Esperando un job como $name"
done
```

> ⚠️ **No lo ejecutes todavía.** Sin el `docker run` del paso 3, el bucle registraría un runner
> nuevo en cada vuelta, sin pausa, hasta que lo pares.

**Verifica**: las órdenes de `jit-not-registration-token` y `jit-runner-labels`:

```bash
f=ops/runner/jit-runner.sh
bash -n "$f" && echo sintaxis-ok
# sintaxis-ok
printf 'jit=%s reg=%s\n' "$(grep -c 'repos/[^ ]*/actions/runners/generate-jitconfig' $f)" \
  "$(grep -cE 'registration-token|config\.sh' $f)"
# jit=1 reg=0
printf 'group=%s self-hosted=%s lab=%s\n' "$(grep -cE 'runner_group_id=1( |$)' $f)" \
  "$(grep -c 'labels\[\]=self-hosted' $f)" "$(grep -cE 'labels\[\]=(tablero-lab|\$LABEL|\$\{LABEL\})' $f)"
# group=1 self-hosted=1 lab=1
```

---

## Paso 3: Entregar la configuración al contenedor

**Por qué**: `run.sh` acepta `--jitconfig <cfg>`, pero un argumento lo ve cualquier usuario de tu
máquina con `ps`, mientras dure el proceso. El runner lee también cualquier argumento de una
variable `ACTIONS_RUNNER_INPUT_<ARG>`: la toma, la **quita de su entorno** y enmascara su valor
en los logs como un secreto. `-e ACTIONS_RUNNER_INPUT_JITCONFIG`, sin `=valor`, copia la
variable exportada de tu shell al contenedor sin escribirla en la línea de órdenes.

No es invisible del todo: `docker inspect` enseña las variables de un contenedor. Quien puede
usar Docker en tu máquina ya es root en ella ([práctica 03](03-contenedor-endurecido-e-imagen-al-dia.md),
paso 4), así que no le das nada nuevo.

`--rm` borra el contenedor cuando `run.sh` sale tras su único job: el `$HOME` donde la sonda
deja su marcador se va con él. `--name "$name"` pone al contenedor el mismo nombre que al runner.

**Comando**: dentro del bucle, sustituye el `echo` final por estas líneas:

```bash
  echo "Esperando un job como $name"
  docker run --rm --name "$name" \
    -e ACTIONS_RUNNER_INPUT_JITCONFIG \
    "$IMAGE" ./run.sh
```

```bash
git add ops/runner
git commit -m "ci(runner): add ephemeral jit runner loop"
```

La práctica 03 endurece este `docker run`. Hoy el job aún puede usar `sudo` dentro del
contenedor.

**Verifica**: la orden de `jitconfig-by-env`:

```bash
f=ops/runner/jit-runner.sh
printf 'env=%s arg=%s\n' "$(grep -c -- '-e ACTIONS_RUNNER_INPUT_JITCONFIG' $f)" "$(grep -c -- '--jitconfig' $f)"
# env=1 arg=0
```

---

## Paso 4: El bucle en marcha

**Por qué**: es la prueba de que el problema de la práctica 01 desapareció. Si cada job tiene
contenedor y runner propios, la sonda no puede encontrar nunca un marcador: las dos vueltas
tienen que dar `state=clean`, y cada una con un `runner_name` distinto.

**Comando**: en una segunda terminal, arranca el bucle y déjalo corriendo:

```bash
cd ~/code/tablero
export GH_REPO=<tu-org>/tablero
ops/runner/jit-runner.sh
# Esperando un job como tablero-lab-1763040071
# √ Connected to GitHub
# ...
# 2026-11-13 10:00:00Z: Listening for Jobs
```

En la primera terminal, vuelve a definir la función `probe` del
[paso 5 de la práctica 01](01-primer-runner-propio.md#paso-5-el-segundo-job-hereda-lo-del-primero)
si la cerraste, y lanza la sonda dos veces:

```bash
probe
# state=clean
probe
# state=clean
```

En la segunda terminal verás cómo cada job termina, el contenedor sale y el bucle pide la
siguiente configuración con otro nombre.

**Verifica**: dos runs en verde, cada uno en su runner:

```bash
gh run list --workflow runner-probe.yml --limit 2 --json databaseId --jq '.[].databaseId' |
  while read -r id; do
    gh api "repos/$GH_REPO/actions/runs/$id/jobs" --jq '.jobs[0] | "\(.conclusion) \(.runner_name)"'
  done
# success tablero-lab-1763040123
# success tablero-lab-1763040071
gh api "repos/$GH_REPO/actions/runners" --jq '.runners[] | "\(.name) \(.status) ephemeral=\(.ephemeral)"'
# tablero-lab-1763040160 online ephemeral=true
```

Solo queda uno registrado: el que espera el siguiente job. Los dos que ejecutaron la sonda ya no
existen ni en GitHub ni en tu máquina.

---

## Paso 5: Parar sin dejar huérfanos

> ⚠️ **Advertencia**: vas a borrar runners de `tablero` con la API. Lista antes y lee la lista:
> solo deben salir runners `tablero-lab-<número>` en `offline`. Un runner JIT sin job no guarda
> nada que respaldar; su configuración solo vivía en el contenedor que acabas de parar.

**Por qué**: si paras el bucle mientras un runner espera, su contenedor desaparece (`--rm`) pero
el registro en GitHub queda *offline*. No ejecutará nada, porque su configuración ya no existe,
pero ensucia la lista y GitHub tarda un día en borrarlo solo.

**Comando**: en la segunda terminal pulsa Ctrl-C (otra vez si el contenedor no sale). En la
primera:

```bash
docker ps -a --filter name=tablero-lab --format '{{.Names}}'
# (sin salida)
gh api "repos/$GH_REPO/actions/runners" --jq '.runners[] | "\(.id) \(.name) \(.status)"'
# 23 tablero-lab-1763040160 offline
gh api "repos/$GH_REPO/actions/runners" --jq '.runners[] | select(.status == "offline") | .id' |
  xargs -r -I{} gh api -X DELETE "repos/$GH_REPO/actions/runners/{}"
git push
```

**Verifica**:

```bash
gh api "repos/$GH_REPO/actions/runners" --jq .total_count
# 0
git status --short ops/runner
# (sin salida)
```

---

## ✅ Resultado

- [ ] `ops/runner/Dockerfile` construye `tablero-runner:local` a partir de la imagen oficial
- [ ] `jit-runner.sh` es ejecutable, pide una config JIT por vuelta y no usa token de registro
- [ ] La config llega por `ACTIONS_RUNNER_INPUT_JITCONFIG`, nunca como `--jitconfig`
- [ ] La sonda dio `state=clean` dos veces, con dos `runner_name` distintos
- [ ] Tras parar el bucle no queda ningún runner ni contenedor

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 15
# ...
# ✅ jit-runner.sh registra cada runner con la API generate-jitconfig del repositorio, sin token de registro ni config.sh
# ✅ El runner JIT se registra en el grupo por defecto con las etiquetas self-hosted y tablero-lab
# ✅ La config JIT llega al contenedor por la variable ACTIONS_RUNNER_INPUT_JITCONFIG, nunca como argumento --jitconfig
# ...
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `GH_REPO: exporta GH_REPO=<tu-org>/tablero` | La segunda terminal no tiene la variable | `export GH_REPO=<tu-org>/tablero` antes de lanzar el script |
| `HTTP 422` en `generate-jitconfig` | `runner_group_id` llegó como texto o faltan etiquetas | `-F runner_group_id=1` y los dos `labels[]=` del paso 2 |
| `Runner listener exit with terminated error, stop the service, no retry needed.` | El contenedor no recibió una config JIT válida | Comprueba el `export` y el `-e` sin `=valor` del paso 3 |
| La sonda se queda en *Queued* | El runner no tiene `self-hosted` entre sus etiquetas | `gh api repos/$GH_REPO/actions/runners --jq '.runners[].labels[].name'` y el paso 2 |
| La sonda da `state=inherited` | Sigue registrado el runner persistente de la práctica 01 | Práctica 01, paso 6 |
| `permission denied` al lanzar el script | Falta el bit de ejecución | `chmod +x ops/runner/jit-runner.sh` y `git add` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Primer runner propio](01-primer-runner-propio.md) | [Contenedor endurecido e imagen al día](03-contenedor-endurecido-e-imagen-al-dia.md) |
