# Práctica 04 — El workflow del runner propio

> Tienes un runner que nace para un job y muere con él, en un contenedor cerrado. Falta lo que
> lo justifica: un workflow de verdad que corra en él. `lab.yml` ejecuta los tests unitarios de
> la API en tu runner, solo cuando tú lo lanzas, y es el único job de `tablero` que lo pide.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `lab.yml`, lanzable solo a mano, como único job `self-hosted` de `tablero`
- El job con `runs-on: [self-hosted, tablero-lab]`, permisos de lectura, timeout y sin secretos
- actionlint y zizmor sin hallazgos sobre todos los workflows
- `lab.yml` en verde en tu runner, con el `runner_name` y las etiquetas comprobados por la API
- La sonda retirada y ningún runner registrado al terminar

## 📋 Antes de empezar

Terminaste la [práctica 03](03-contenedor-endurecido-e-imagen-al-dia.md): el contenedor del
runner está endurecido y en `main`. Releíste
[el esqueleto seguro de `lab.yml`](../1-teoria/07-runner-propio-en-un-repo-publico.md) de la
teoría 07.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
grep -l 'self-hosted' .github/workflows/*.yml
# .github/workflows/runner-probe.yml
```

---

## Paso 1: Solo se lanza a mano

**Por qué**: un runner propio en un repo público tiene un enemigo concreto: el PR de un fork que
cambia un workflow para que pida `self-hosted` y ejecute lo que quiera en tu máquina
([teoría 07](../1-teoria/07-runner-propio-en-un-repo-publico.md)). La aprobación de forks de la
práctica 01 es una capa; esta es otra. `workflow_dispatch` solo lo puede lanzar alguien con
permiso de escritura, y ejecuta el workflow de la rama que elija esa persona, no el de un PR.
Ni `push` ni `pull_request`: nada dispara este job sin que tú lo decidas.

Lo mismo vale para el resto: **ningún** otro workflow de `tablero` pide `self-hosted`. La sonda
de la práctica 01 lo pide y la borras en el paso 5.

`concurrency` sin cancelar pone en cola un segundo lanzamiento en lugar de matar el primero: con
un único runner esperando, correrían igualmente uno detrás de otro.

**Comando**: crea `.github/workflows/lab.yml` con la cabecera y el job:

```yaml
# Tests unitarios de la API en el runner propio. Solo se lanza a mano y, como lo hace alguien con
# permiso de escritura, nunca ejecuta código de un PR ajeno en tu máquina.
name: lab
on:
  workflow_dispatch:
concurrency:
  group: ${{ github.workflow }}
  cancel-in-progress: false
permissions: {}
jobs:
  unit:
    name: Tests unitarios en el runner propio
    runs-on: [self-hosted, tablero-lab]
```

**Verifica**: las órdenes de `lab-dispatch-only` y `self-hosted-only-in-lab`:

```bash
yq '.on | keys | join(",")' .github/workflows/lab.yml
# workflow_dispatch
yq -N '.jobs | to_entries | .[] | select(.value."runs-on" | tostring | test("self-hosted")) | (filename | sub(".*/"; "")) + ":" + .key' .github/workflows/*.yml | tr '\n' ' '; echo
# lab.yml:unit runner-probe.yml:probe
```

La segunda queda en `lab.yml:unit` a secas en el paso 5, cuando borres la sonda.

---

## Paso 2: Límites del job

**Por qué**: el job corre en tu máquina, así que cada límite protege algo tuyo:

- `permissions: {}` en la raíz y `contents: read` en el job: el `GITHUB_TOKEN` que llega a tu
  runner solo puede leer el código. Si alguien lo roba del contenedor, no escribe nada.
- `timeout-minutes: 15`: un job colgado libera el runner. Sin él, el valor por defecto es 360
  minutos.
- Ningún `secrets.`: el contenedor es desechable, pero lo que pasa por él lo ve el job.
- `persist-credentials: false`: el token no se queda en `.git/config` del contenedor.

`runs-on` es una lista que **casa con todas** sus etiquetas: `self-hosted` descarta los runners
de GitHub y `tablero-lab` elige el tuyo ([teoría 03](../1-teoria/03-etiquetas-y-runs-on.md)).

**Comando**: completa el job `unit`:

```yaml
  unit:
    name: Tests unitarios en el runner propio
    runs-on: [self-hosted, tablero-lab]
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

`setup-uv` descarga `uv` en el `_work/_tool` del contenedor y `uv` trae el Python que pide
`api/`: nada de eso necesita `sudo`, que desde la práctica 03 ya no existe.

**Verifica**: las órdenes de `lab-runs-on` y `lab-job-limits`:

```bash
printf 'runs-on=%s actionlint=%s\n' "$(yq '.jobs[]."runs-on" | join(",")' .github/workflows/lab.yml)" \
  "$(yq '."self-hosted-runner".labels | join(",")' .github/actionlint.yaml)"
# runs-on=self-hosted,tablero-lab actionlint=tablero-lab
printf '%s secrets=%s\n' "$(yq '.jobs[] | "perms=" + (.permissions | to_entries | map(.key + "=" + .value) | join(",")) + " timeout=" + (."timeout-minutes" | tostring)' .github/workflows/lab.yml)" \
  "$(grep -c 'secrets\.' .github/workflows/lab.yml)"
# perms=contents=read timeout=15 secrets=0
```

---

## Paso 3: actionlint y zizmor

**Por qué**: actionlint comprueba la sintaxis y que `tablero-lab` es una etiqueta conocida (la
declaraste en la práctica 01); zizmor busca los fallos de seguridad de la Semana 12. Con
`GH_TOKEN` en el entorno, zizmor consulta además la API para comprobar que los SHA de los `uses:`
son commits reales de esas actions. Lo pasas en local antes del push: el job `lint-workflows`
lo repetirá en GitHub, pero tarde.

**Comando**:

```bash
actionlint
GH_TOKEN=$(gh auth token) zizmor -q .github/
# No findings to report. Good job! (N suppressed)
```

El número de *suppressed* depende de cuántos `# zizmor: ignore[...]` justificados tengas.

```bash
git add .github/workflows/lab.yml
git commit -m "ci(runner): run api unit tests on self-hosted runner"
git push
```

**Verifica**: la orden de `workflows-lint`:

```bash
actionlint && GH_TOKEN=$(gh auth token) zizmor -q .github/ > /dev/null && echo lint-ok
# lint-ok
```

---

## Paso 4: `lab.yml` en tu runner

**Por qué**: hasta ahora el runner solo ejecutó la sonda, que no hace checkout ni instala nada.
`lab.yml` es un job real dentro del contenedor endurecido de la práctica 03: si algo de ese
endurecimiento rompe el job, lo ves aquí. La comprobación de la semana mira el run del último
commit de `main`: un verde de otro commit no cuenta.

**Comando**: en una segunda terminal, arranca el bucle:

```bash
cd ~/code/tablero
export GH_REPO=<tu-org>/tablero
ops/runner/jit-runner.sh
# Esperando un job como tablero-lab-1763041200
# ...
```

En la primera, lanza `lab.yml` y espera a que termine:

```bash
gh workflow run lab.yml > /dev/null
sleep 5
id=$(gh run list --workflow lab.yml --commit "$(git rev-parse origin/main)" --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null && echo verde
# verde
```

**Verifica**: la orden de `lab-green-on-own-runner`:

```bash
gh api "repos/{owner}/{repo}/actions/runs/$id/jobs" \
  --jq '.jobs[0] | "conclusion=\(.conclusion) runner=\(.runner_name) labels=\(.labels | join(","))"'
# conclusion=success runner=tablero-lab-1763041200 labels=self-hosted,tablero-lab
```

`labels` son las que pidió `runs-on`, no las del runner; `runner_name` es el que puso tu script.

---

## Paso 5: Retirar la sonda y dejar el repo sin runners

> ⚠️ **Advertencia**: vas a borrar `runner-probe.yml` de `main` y runners registrados de
> `tablero`. La sonda queda en el historial de git (`git show HEAD~1:.github/workflows/runner-probe.yml`
> la recupera tras el commit). Antes de borrar runners, lista y lee: solo deben salir
> `tablero-lab-<número>` en `offline`.

**Por qué**: la sonda cumplió su papel y es un segundo job `self-hosted`, justo lo que el paso 1
prohíbe. Borrarla crea un commit nuevo en `main`, así que lanzas `lab.yml` otra vez para que el
último commit tenga su verde. Después paras el bucle: un runner propio que nadie vigila no debe
quedarse esperando jobs.

**Comando**: con el bucle todavía en marcha:

```bash
git rm .github/workflows/runner-probe.yml
git commit -m "chore(runner): remove runner probe"
git push
gh workflow run lab.yml > /dev/null
sleep 5
id=$(gh run list --workflow lab.yml --commit "$(git rev-parse origin/main)" --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null && echo verde
# verde
```

Pulsa Ctrl-C en la segunda terminal y barre el runner que esperaba:

```bash
gh api "repos/$GH_REPO/actions/runners" --jq '.runners[] | "\(.id) \(.name) \(.status)"'
# 31 tablero-lab-1763041530 offline
gh api "repos/$GH_REPO/actions/runners" --jq '.runners[] | select(.status == "offline") | .id' |
  xargs -r -I{} gh api -X DELETE "repos/$GH_REPO/actions/runners/{}"
```

**Verifica**: las órdenes de `self-hosted-only-in-lab` y `runners-ephemeral`:

```bash
yq -N '.jobs | to_entries | .[] | select(.value."runs-on" | tostring | test("self-hosted")) | (filename | sub(".*/"; "")) + ":" + .key' .github/workflows/*.yml | tr '\n' ' '; echo
# lab.yml:unit
r=$(gh api "repos/{owner}/{repo}/actions/runs/$id/jobs" --jq '.jobs[0].runner_name')
gh api 'repos/{owner}/{repo}/actions/runners' \
  --jq "\"persistent=\([.runners[] | select(.ephemeral | not)] | length) last=\([.runners[] | select(.name == \"$r\")] | length)\""
# persistent=0 last=0
```

---

## ✅ Resultado

- [ ] `lab.yml` solo tiene `workflow_dispatch` y es el único workflow con `self-hosted`
- [ ] Su job pide `[self-hosted, tablero-lab]`, `contents: read`, `timeout-minutes: 15` y ningún secreto
- [ ] actionlint y zizmor pasan sin hallazgos
- [ ] `lab.yml` en verde en el último commit de `main`, ejecutado por un runner `tablero-lab-…`
- [ ] Sin sonda, sin runners registrados y sin contenedores del runner

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 15
# Semana 15 — Runners propios  [repo: <tu-org>/tablero]
# ...
# 16/16 comprobaciones superadas.
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `lab.yml` no aparece en `gh workflow run` | El archivo no está en la rama por defecto | `git push` y espera unos segundos |
| El run se queda en *Queued* | El bucle no está en marcha o el runner no tiene las dos etiquetas | Segunda terminal; práctica 02, paso 2 |
| `uv sync --locked` falla al crear el entorno | `--memory` o `--pids-limit` demasiado bajos para tu caso | Mira el log del step; no quites `--cap-drop` ni `no-new-privileges` para arreglarlo |
| Un step falla con `sudo: The "no new privileges" flag is set` | Ese step necesita root | Muévelo a la imagen (`ops/runner/Dockerfile`) o fuera del runner propio |
| `lab-green-on-own-runner` falla con un verde en GitHub | Ese verde es de otro commit | Relanza `lab.yml` tras el último push, como en el paso 5 |
| `self-hosted-only-in-lab` lista `runner-probe.yml` | No borraste la sonda o no la subiste | Paso 5 |
| `persistent=1` | Sigue registrado el runner de la práctica 01 | Práctica 01, paso 6 |
| `last=1` | El runner del último job no terminó de darse de baja | Bórralo con `DELETE` como en el paso 5 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Contenedor endurecido e imagen al día](03-contenedor-endurecido-e-imagen-al-dia.md) | [Proyecto: capa 15 de tablero](../3-proyecto/README.md) |
