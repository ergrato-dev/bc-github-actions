# Práctica 02 — Concurrencia y timeouts

> Tu PR de la práctica 01 sigue abierto. En esta práctica le pones a los cinco workflows un grupo
> de concurrencia que cancela los runs obsoletos solo en los PR, das a cada job un techo de tiempo
> calibrado, ves con tus ojos un job que muere por timeout y fusionas el PR.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- La duración real de cada workflow, medida antes de elegir ningún número
- `concurrency` con grupo `${{ github.workflow }}-${{ github.ref }}` en `ci`, `ci-api`, `ci-web`,
  `smoke` e `images`, con `cancel-in-progress` solo en `pull_request`
- Tres pushes seguidos al PR y los runs obsoletos en `cancelled`
- `timeout-minutes` en los trece jobs, unas tres veces su duración normal
- Un job de laboratorio que vence su `timeout-minutes: 1`, con un step `if: always()` que sí corre
- El PR fusionado y los cinco workflows en verde sobre `main`

## 📋 Antes de empezar

Terminaste la [práctica 01](01-filtros-de-ramas-y-rutas.md): estás en `ci/trigger-filters`, con
el PR abierto y los filtros de rutas subidos.

```bash
cd ~/code/tablero
git switch ci/trigger-filters && git pull --ff-only
gh pr view --json state,headRefName --jq '"\(.state) \(.headRefName)"'
# OPEN ci/trigger-filters
yq '.concurrency // "sin concurrency"' .github/workflows/ci-api.yml
# sin concurrency
```

---

## Paso 1: Cuánto dura cada workflow

**Por qué**: un `timeout-minutes` sin medir es una apuesta. Demasiado bajo da rojos falsos el día
que te toca un runner lento; 360, el valor por defecto, deja un job colgado seis horas
([teoría 07](../1-teoria/07-timeouts-y-cancelacion.md#cómo-elegir-el-valor)). La medida también
dice cuánto ahorra cancelar un run obsoleto: lo que dura el más largo.

**Comando**: la duración del run más lento entre los últimos verdes de cada workflow, en minutos
redondeados hacia arriba.

```bash
for w in ci ci-api ci-web smoke images; do
  m=$(gh run list --workflow "$w.yml" --status success --limit 10 --json startedAt,updatedAt \
    --jq 'map((.updatedAt | fromdate) - (.startedAt | fromdate)) | max / 60 | ceil')
  echo "$w $m"
done | tee /tmp/tablero-durations.txt
# ci 1
# ci-api 3
# ci-web 3
# smoke 4
# images 5
```

**Verifica**: cinco líneas, una por workflow, con un número cada una. Una línea sin número es un
workflow sin ningún run verde: arréglalo antes de seguir.

```bash
awk '$2 ~ /^[0-9]+$/' /tmp/tablero-durations.txt | wc -l
# 5
```

Tus cifras serán otras. Apúntalas: las usas en el paso 4. Son minutos de **run**, que suma jobs
en serie; el techo va por **job**, y un job nunca dura más que su run.

---

## Paso 2: Un grupo de concurrencia por workflow y ref

**Por qué**: sin `concurrency`, tres pushes seguidos a un PR dejan tres runs del mismo workflow
compitiendo por runners, y solo el último importa. El grupo `${{ github.workflow }}-${{ github.ref }}`
junta los runs de **un** workflow en **una** ref: cada PR tiene el suyo (`refs/pull/<n>/merge`) y
`ci-api` nunca cancela a `ci-web`
([teoría 06](../1-teoria/06-concurrencia.md#el-nombre-del-grupo)). `cancel-in-progress` recibe una
expresión: verdadera en `pull_request`, falsa en `push` a `main`, donde cada commit tiene que
terminar su run para que la historia de `main` tenga un resultado por commit
([teoría 06](../1-teoria/06-concurrencia.md#cancelar-solo-en-los-pr)).

**Comando**: añade este bloque a los cinco workflows (`ci`, `ci-api`, `ci-web`, `smoke` e
`images`), entre `on:` y `permissions:`.

```yaml
# Un run por workflow y ref: en un PR, el push nuevo cancela el run anterior;
# en main cada commit termina su run.
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

Va a nivel de workflow, no de job: lo que se cancela es el run entero. Y es idéntico en los cinco
porque `github.workflow` ya trae el `name:` de cada uno.

**Verifica**: las órdenes de `ci-concurrency-group` y `ci-cancel-only-pr`. Las dos imprimen solo
los workflows que **no** cumplen.

```bash
actionlint; echo "exit $?"
# exit 0
for f in ci ci-api ci-web smoke images; do yq '.concurrency.group // "sin grupo"' .github/workflows/$f.yml | grep -vE 'github\.workflow.*github\.ref' | sed "s/^/$f: /"; done
# (sin salida)
for f in ci ci-api ci-web smoke images; do yq '.concurrency.cancel-in-progress // "ausente"' .github/workflows/$f.yml | grep -vE "event_name *== *'pull_request'" | sed "s/^/$f: /"; done
# (sin salida)
git add .github/workflows/
git commit -m "ci: cancel superseded pull request runs with concurrency groups"
git push
```

---

## Paso 3: Tres pushes seguidos al PR

**Por qué**: es la situación para la que existe el grupo. Cada push dispara los cinco workflows;
con `cancel-in-progress` verdadero en el PR, el push siguiente cancela el run en curso del mismo
workflow y ocupa su sitio. Los commits van vacíos: el diff de tres puntos del PR ya contiene los
cuatro YAML, así que todos corren.

**Comando**: tres commits vacíos, con 20 segundos entre uno y otro para que cada run llegue a
arrancar. Los SHA se guardan para comprobarlos uno a uno.

```bash
shas=()
for i in 1 2 3; do
  git commit --allow-empty -m "test: concurrency push $i"
  git push -q
  shas+=("$(git rev-parse HEAD)")
  sleep 20
done
gh pr checks --watch > /dev/null
```

**Verifica**: los runs del primer y segundo push, sin `ci`, acabaron cancelados; los del tercero,
en verde.

```bash
for s in "${shas[@]}"; do
  gh run list --commit "$s" --json workflowName,conclusion \
    --jq '[.[] | select(.workflowName != "ci") | .conclusion] | unique | join(",")'
done
# cancelled
# cancelled
# success
```

`ci` se excluye porque sus cuatro jobs cortos pueden terminar en menos de 20 segundos, antes de
que llegue el push siguiente: no hay nada que cancelar. La rama entera, de un vistazo:

```bash
gh run list --branch ci/trigger-filters --event pull_request --limit 15 \
  --json conclusion,workflowName --jq '.[] | "\(.conclusion)\t\(.workflowName)"' | sort | uniq -c
```

Abre uno de los cancelados con `gh run view <id> --web`: su anotación dice *Canceling since a
higher priority waiting request for 'ci-api-refs/pull/<n>/merge' exists*. Ese es el nombre del
grupo calculado.

---

## Paso 4: Un techo de tiempo en cada job

**Por qué**: la concurrencia corta runs obsoletos; un job colgado en `main` no lo es, y sin techo
se queda 360 minutos ocupando su sitio en el grupo, con el run siguiente esperando detrás. Con las
cifras del paso 1, el techo es unas tres veces lo normal, redondeado a un número fácil de leer
([teoría 07](../1-teoria/07-timeouts-y-cancelacion.md#cómo-elegir-el-valor)).

**Comando**: añade `timeout-minutes` a cada job, justo debajo de su `runs-on:`. Estos son los
valores de referencia; si tus medidas son muy distintas, ajústalos con la misma regla.

| Workflow | Job | `timeout-minutes` |
|---|---|:--:|
| `ci` | `runner-info`, `structure`, `version`, `summary` | 5 |
| `ci-api` | `lint`, `test` | 10 |
| `ci-api` | `integration` | 15 |
| `ci-web` | `lint`, `test`, `build` | 10 |
| `ci-web` | `dist-report` | 5 |
| `smoke` | `compose` | 20 |
| `images` | `build` | 30 |

Así queda, por ejemplo, el job `integration` de `ci-api.yml`:

```yaml
  integration:
    name: Tests de integración (PostgreSQL 17)
    needs: test
    runs-on: ubuntu-24.04
    timeout-minutes: 15
```

`integration` lleva más que `test` porque espera a que PostgreSQL esté sano. `images` lleva el
techo más alto porque un build con la caché fría reconstruye `uv sync` y `pnpm install`. En el job
con matriz de `ci-web`, el techo vale para cada entrada por separado.

**Verifica**: la orden de `jobs-timeout` sobre tus cinco workflows. Imprime los jobs sin techo.

```bash
actionlint; echo "exit $?"
# exit 0
for f in ci ci-api ci-web smoke images; do yq '.jobs // {} | to_entries | .[] | select(.value | has("timeout-minutes") | not) | .key' .github/workflows/$f.yml | sed "s/^/$f: /"; done
# (sin salida)
```

Los labs de semanas anteriores (`hello.yml`, `service-lab.yml`, `build-lab.yml`...) siguen en tu
repo y la regla vale para ellos también: ponles `timeout-minutes: 5` a cada job, o bórralos si ya
no los usas. Esta orden lista los jobs sin techo de **todos** tus workflows:

```bash
for f in .github/workflows/*.yml; do yq '.jobs // {} | to_entries | .[] | select(.value | has("timeout-minutes") | not) | .key' "$f" | sed "s|^|$f: |"; done
# (sin salida)
git add .github/workflows/
git commit -m "ci: cap every job with a calibrated timeout"
git push
```

---

## Paso 5: Un job que vence su techo

**Por qué**: vencer `timeout-minutes` se parece a una cancelación: el step en curso recibe la
señal de parada, los `if:` de los steps que faltan se reevalúan y solo corren los que la
sobreviven, como `always()` ([teoría 07](../1-teoria/07-timeouts-y-cancelacion.md#qué-pasa-al-cancelar)).
Lo pruebas en una rama `lab/` desechable, fuera de tu PR, para no dejar un rojo en él.

**Comando**: una rama local de laboratorio y en ella `.github/workflows/timeout-lab.yml`.

```bash
git switch -c lab/timeout
```

```yaml
name: timeout-lab

on:
  push:
    branches: ["lab/**"]

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  hang:
    name: Job que se cuelga
    runs-on: ubuntu-24.04
    # Un minuto de techo para un trabajo que dura dos: el timeout es seguro.
    timeout-minutes: 1
    steps:
      - name: Dormir dos minutos
        run: sleep 120

      - name: Paso normal
        run: echo "No llego a correr"

      - name: Limpieza con always
        if: ${{ always() }}
        run: echo "Limpieza tras el timeout"
```

```bash
actionlint .github/workflows/timeout-lab.yml; echo "exit $?"
# exit 0
git add .github/workflows/timeout-lab.yml
git commit -m "test: add job timeout lab"
git push -u origin lab/timeout
sleep 10
id=$(gh run list --branch lab/timeout --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" > /dev/null
```

**Verifica**: el run no termina en verde, el paso normal se salta y la limpieza corre.

```bash
gh run view "$id" --json conclusion --jq '.conclusion != "success"'
# true
gh run view "$id" --json jobs \
  --jq '.jobs[0].steps[] | select(.name | test("^(Paso normal|Limpieza)")) | "\(.conclusion)\t\(.name)"'
# skipped	Paso normal
# success	Limpieza con always
```

La anotación del job, en `gh run view "$id" --web`, dice que superó su tiempo máximo de
ejecución. Ese mismo mensaje es el que verás el día que un job real se cuelgue.

> ⚠️ Lo siguiente **borra la rama `lab/timeout`** en local y en GitHub. Solo lleva el commit de
> `timeout-lab.yml`; si quieres conservarlo, cópialo antes fuera del repo.

```bash
git switch ci/trigger-filters
git push origin --delete lab/timeout
git branch -D lab/timeout
git ls-remote origin refs/heads/lab/timeout | wc -l
# 0
```

---

## Paso 6: Fusionar el PR

**Por qué**: los filtros, la concurrencia y los techos ya están probados en el PR. Al fusionarlo
con squash, el commit nuevo de `main` toca los cinco YAML, así que los cinco corren por la ruta de
su propio workflow. En `main`, `cancel-in-progress` vale `false`: si fusionas otro PR mientras
tanto, su run espera en lugar de cancelar este.

**Comando**: `--delete-branch` borra `ci/trigger-filters` en local y en GitHub tras fusionar; todo
lo que contiene queda en `main`.

```bash
gh pr checks --watch > /dev/null
gh pr merge --squash --delete-branch
git switch main && git pull --ff-only
sleep 15
gh run list --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[].databaseId' \
  | xargs -n1 gh run watch --exit-status > /dev/null; echo "exit $?"
# exit 0
```

**Verifica**:

```bash
gh run list --commit "$(git rev-parse HEAD)" --json workflowName,conclusion \
  --jq '.[] | "\(.workflowName) \(.conclusion)"' | sort
# ci success
# ci-api success
# ci-web success
# images success
# smoke success
```

---

## ✅ Resultado

- [ ] Mediste la duración de cada workflow antes de elegir los techos
- [ ] Los cinco workflows tienen `concurrency` con grupo por workflow y ref
- [ ] `cancel-in-progress` es verdadero solo en `pull_request`
- [ ] Tres pushes seguidos dejaron los dos primeros runs en `cancelled`
- [ ] Los trece jobs tienen `timeout-minutes` calibrado
- [ ] Viste un job vencer su techo y un step `always()` correr igualmente
- [ ] El PR está fusionado y los cinco workflows están en verde sobre `main`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 07
# ✅ ci, ci-api, ci-web, smoke e images declaran concurrency con un grupo por workflow y ref
# ✅ cancel-in-progress cancela runs obsoletos solo en los pull requests, nunca en main
```

`jobs-timeout` sigue en rojo hasta que exista `nightly.yml` con su techo: llega en el proyecto.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| En el paso 3 ningún run sale `cancelled` | El push siguiente llegó cuando el run ya había terminado | Baja el `sleep` a 10 segundos y repite |
| `ci-api` cancela a `ci-web` | El grupo es `${{ github.ref }}` a secas | Paso 2: `github.workflow` y `github.ref` juntos |
| Los runs de `main` también se cancelan | `cancel-in-progress: true` a secas | `${{ github.event_name == 'pull_request' }}` |
| Un job falla por timeout en un día normal | El techo es menor que su duración real | Repite el paso 1 con más runs y sube el valor |
| `timeout-lab` termina en verde | El `sleep` dura menos que el techo | `sleep 120` con `timeout-minutes: 1` |
| `gh pr merge` falla con `not mergeable` | Hay checks pendientes o un conflicto con `main` | `gh pr checks --watch`; si hay conflicto, `git pull origin main` en la rama |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Filtros de ramas y rutas](01-filtros-de-ramas-y-rutas.md) | [Cron y dispatch con inputs](03-cron-y-dispatch-con-inputs.md) |
