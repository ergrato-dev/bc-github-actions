# Práctica 01 — Filtros de ramas y rutas

> Hoy cualquier cambio en `tablero`, aunque sea una coma del `README.md`, despierta a los cinco
> workflows. En esta práctica pones `paths` en los cuatro que comprueban una carpeta, demuestras
> que un cambio de documentación solo despierta a `ci` y pruebas un filtro de ramas y tags con
> negación en un workflow de laboratorio.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Una rama de trabajo con un PR abierto, que reutilizarás en la práctica 02
- `paths` idénticos en `push` y `pull_request` de `ci-api`, `ci-web`, `smoke` e `images`, cada
  uno con su propio YAML en la lista
- Un PR que solo toca `README.md` y despierta únicamente a `ci`
- Un workflow de laboratorio con `branches`, `tags` y una negación `!`, comprobado con pushes reales

## 📋 Antes de empezar

`check-week.sh 06` está en 17/17 y `main` no tiene cambios pendientes. Ningún workflow tiene
todavía filtros de rutas:

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
for f in ci ci-api ci-web smoke images; do yq '.on.pull_request.paths // "sin paths"' ".github/workflows/$f.yml"; done | sort -u
# sin paths
```

---

## Paso 1: Rama de trabajo y PR

**Por qué**: los filtros de `pull_request` se ven en un PR, y la concurrencia de la práctica 02
también. Abres uno ahora y lo fusionas al final de la práctica 02. El primer commit va vacío a
propósito: sin filtros, hasta un PR que no cambia ningún archivo despierta a los cinco
workflows. Esa es la línea base que vas a recortar.

**Comando**:

```bash
git switch -c ci/trigger-filters
git commit --allow-empty -m "ci: start trigger filters work"
git push -u origin ci/trigger-filters
gh pr create --title "ci: trigger filters, concurrency and timeouts" \
  --body "Filtros de rutas, concurrency y timeout-minutes en el CI de tablero (Semana 07)."
sleep 15
```

**Verifica**: los runs del commit, por nombre de workflow.

```bash
gh run list --commit "$(git rev-parse HEAD)" --json workflowName --jq '[.[].workflowName] | sort | join(",")'
# ci,ci-api,ci-web,images,smoke
```

`--commit` filtra por el SHA de la punta del PR: la usarás toda la semana.

---

## Paso 2: `paths` en `ci-api`

**Por qué**: `ci-api` solo comprueba la carpeta `api/`, así que solo tiene que correr cuando algo
de ella cambia ([teoría 02](../1-teoria/02-filtros-de-rutas.md#paths-y-paths-ignore)). La segunda
ruta es el propio workflow: sin ella, un cambio en `ci-api.yml` no lo ejecutaría y descubrirías el
error en `main`, no en el PR. Los dos eventos llevan **la misma lista**: si difieren, hay cambios
que pasan el PR sin CI y llegan a `main` con CI, o al revés. `workflow_dispatch` se queda sin
filtros: no tiene `paths` y corre siempre que se lanza, que es lo que necesitará el `nightly` del
proyecto.

**Comando**: sustituye el bloque `on:` de `.github/workflows/ci-api.yml`. Las comillas importan:
en YAML, un valor que empieza por `*` es un alias.

```yaml
on:
  push:
    branches: [main]
    paths:
      - "api/**"
      - ".github/workflows/ci-api.yml"
  pull_request:
    paths:
      - "api/**"
      - ".github/workflows/ci-api.yml"
  workflow_dispatch:
```

**Verifica**: es la orden del check `ci-api-paths`.

```bash
actionlint .github/workflows/ci-api.yml; echo "exit $?"
# exit 0
yq '[.on.push.paths // [] | sort | join(","), .on.pull_request.paths // [] | sort | join(",")] | join(" | ")' .github/workflows/ci-api.yml
# .github/workflows/ci-api.yml,api/** | .github/workflows/ci-api.yml,api/**
```

---

## Paso 3: Comprobar por qué está el propio YAML

**Por qué**: en un `pull_request` GitHub no mira el último commit, sino el diff de tres puntos
entre la base y la punta del PR ([teoría 02](../1-teoria/02-filtros-de-rutas.md#con-qué-se-compara-dos-puntos-y-tres-puntos)).
Ahora mismo ese diff es un único archivo, `.github/workflows/ci-api.yml`, y no está en `api/`:
`ci-api` corre solo porque su propio YAML está en la lista.

**Comando**:

```bash
git add .github/workflows/ci-api.yml
git commit -m "ci(api): run only when api or its workflow changes"
git push
sleep 15
gh pr diff --name-only
# .github/workflows/ci-api.yml
```

**Verifica**:

```bash
gh run list --commit "$(git rev-parse HEAD)" --workflow ci-api.yml --json event --jq '.[0].event'
# pull_request
```

---

## Paso 4: `paths` en `ci-web`

**Por qué**: el mismo razonamiento para la otra mitad del monorepo. `ci-web` instala con `pnpm`,
pasa eslint, vitest en dos versiones de Node y construye: unos minutos que no hacen falta cuando
solo cambia la API.

**Comando**: sustituye el bloque `on:` de `.github/workflows/ci-web.yml`.

```yaml
on:
  push:
    branches: [main]
    paths:
      - "web/**"
      - ".github/workflows/ci-web.yml"
  pull_request:
    paths:
      - "web/**"
      - ".github/workflows/ci-web.yml"
  workflow_dispatch:
```

**Verifica**: es la orden del check `ci-web-paths`.

```bash
actionlint .github/workflows/ci-web.yml; echo "exit $?"
# exit 0
yq '[.on.push.paths // [] | sort | join(","), .on.pull_request.paths // [] | sort | join(",")] | join(" | ")' .github/workflows/ci-web.yml
# .github/workflows/ci-web.yml,web/** | .github/workflows/ci-web.yml,web/**
```

---

## Paso 5: `paths` en `smoke` e `images`

**Por qué**: estos dos dependen de más de una carpeta. El smoke test levanta la API, la web y nginx
con `compose.yaml` y los sondea con `scripts/smoke-test.sh`: un cambio en cualquiera de esas cinco
rutas puede romperlo. `images` construye `api/` y `web/` con sus `Dockerfile`, que viven dentro de
cada carpeta: no necesita `compose.yaml`.

**Comando**: sustituye el bloque `on:` de `.github/workflows/smoke.yml`…

```yaml
on:
  push:
    branches: [main]
    paths:
      - "api/**"
      - "web/**"
      - "compose.yaml"
      - "scripts/smoke-test.sh"
      - ".github/workflows/smoke.yml"
  pull_request:
    paths:
      - "api/**"
      - "web/**"
      - "compose.yaml"
      - "scripts/smoke-test.sh"
      - ".github/workflows/smoke.yml"
  workflow_dispatch:
```

…y el de `.github/workflows/images.yml`:

```yaml
on:
  push:
    branches: [main]
    paths:
      - "api/**"
      - "web/**"
      - ".github/workflows/images.yml"
  pull_request:
    paths:
      - "api/**"
      - "web/**"
      - ".github/workflows/images.yml"
  workflow_dispatch:
```

`ci.yml` **no lleva `paths`**, y es deliberado. Es el único workflow que corre en todo PR, así que
es el único check que siempre existe. Si un día marcas `ci-api` como check obligatorio, un PR que
no toca `api/` se queda esperando un check que nunca llega
([teoría 02](../1-teoria/02-filtros-de-rutas.md#el-check-obligatorio-que-se-queda-esperando)); la
Semana 18 convierte `ci` en la puerta `ci-gate` que resuelve ese problema.

**Verifica**: las órdenes de `smoke-paths` e `images-paths`, y que `ci` sigue sin filtros.

```bash
actionlint; echo "exit $?"
# exit 0
yq '.on.pull_request.paths // [] | sort | join(",")' .github/workflows/smoke.yml
# .github/workflows/smoke.yml,api/**,compose.yaml,scripts/smoke-test.sh,web/**
yq '.on.pull_request.paths // [] | sort | join(",")' .github/workflows/images.yml
# .github/workflows/images.yml,api/**,web/**
yq '.on.pull_request.paths // "sin paths"' .github/workflows/ci.yml
# sin paths
git add .github/workflows/
git commit -m "ci: run web, smoke and images only when their inputs change"
git push
```

---

## Paso 6: Un cambio de documentación solo despierta a `ci`

**Por qué**: es la promesa de la capa, y en el PR de trabajo no se puede ver. Su diff de tres
puntos ya incluye los cuatro YAML que acabas de cambiar, así que cualquier push nuevo a ese PR
despierta a los cuatro por su propia ruta. La salida es un PR apilado: una rama que sale de
`ci/trigger-filters` y apunta a ella como base. Su diff es solo lo que tú añades, y el YAML que
evalúa GitHub es el de tu rama de trabajo, ya con los filtros.

**Comando**: el `echo` añade una línea vacía al final de `README.md`.

```bash
git switch -c test/docs-only
echo "" >> README.md
git commit -am "docs: touch readme to test path filters"
git push -u origin test/docs-only
gh pr create --base ci/trigger-filters --title "test: docs-only change" \
  --body "Solo toca README.md: solo debe correr ci."
sleep 15
gh pr diff --name-only
# README.md
```

**Verifica**:

```bash
gh run list --commit "$(git rev-parse HEAD)" --json workflowName --jq '[.[].workflowName] | sort | join(",")'
# ci
```

> ⚠️ El cierre siguiente **borra la rama `test/docs-only`** en local y en GitHub. Solo lleva la
> línea vacía de este paso.

```bash
git switch ci/trigger-filters
gh pr close test/docs-only --delete-branch
git branch --list test/docs-only | wc -l
# 0
```

---

## Paso 7: Ramas y tags con negación, en un laboratorio

**Por qué**: `branches` y `tags` filtran refs, y su negación `!` solo funciona **después** del
patrón que recorta: gana el último que casa
([teoría 01](../1-teoria/01-filtros-de-ramas-y-tags.md#el-último-que-coincide-gana)). Lo pruebas
en refs `lab` desechables, fuera de tu PR; los workflows de `tablero`, con solo
`branches: [main]`, no despiertan con ninguno.

**Comando**: crea una rama local de laboratorio con `git switch -c lab/base` y en ella
`.github/workflows/filters-lab.yml`. `github.ref` llega por `env:`: el nombre de una rama lo elige
quien la crea (regla 4).

```yaml
name: filters-lab

on:
  push:
    branches:
      - "lab/**"
      - "!lab/**-skip"
    tags:
      - "lab-v*"

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  show:
    name: Qué ref me ha despertado
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - name: Evento y ref
        env:
          EVENT: ${{ github.event_name }}
          REF: ${{ github.ref }}
        run: echo "Evento $EVENT sobre $REF"
```

```bash
actionlint .github/workflows/filters-lab.yml; echo "exit $?"
# exit 0
git add .github/workflows/filters-lab.yml
git commit -m "test: add branch and tag filter lab"
git tag lab-v1 && git tag lab-beta
git push origin HEAD:refs/heads/lab/one HEAD:refs/heads/lab/two-skip lab-v1 lab-beta
sleep 20
```

**Verifica**:

```bash
gh run list --limit 20 --json workflowName,event,headBranch \
  --jq '[.[] | select(.workflowName == "filters-lab") | .headBranch] | sort | join(",")'
# lab-v1,lab/one
```

`lab/two-skip` casa con `lab/**`, pero el último patrón que casa es `!lab/**-skip`. `lab-beta` no
casa con `lab-v*`. Ninguno aparece: no hay run saltado, simplemente no hay run.

> ⚠️ Recoger el laboratorio **borra dos ramas y dos tags remotos** y la rama local `lab/base`. Solo
> contienen el commit de `filters-lab.yml`, que nunca entró en tu PR. Si quieres conservarlo,
> cópialo antes fuera del repo.

```bash
git push origin --delete lab/one lab/two-skip refs/tags/lab-v1 refs/tags/lab-beta
git tag -d lab-v1 lab-beta
git switch ci/trigger-filters && git branch -D lab/base
git ls-remote origin 'refs/heads/lab/*' 'refs/tags/lab-*' | wc -l
# 0
```

---

## ✅ Resultado

- [ ] Tienes un PR abierto desde `ci/trigger-filters`, que sigue en la práctica 02
- [ ] `ci-api`, `ci-web`, `smoke` e `images` tienen sus `paths`, idénticos en `push` y `pull_request`
- [ ] `ci.yml` sigue sin `paths`, y sabes por qué
- [ ] Un PR que solo tocaba `README.md` despertó únicamente a `ci`
- [ ] Has visto que `!lab/**-skip` recorta `lab/**` y que un filtro que no casa no deja run

Los checks de rutas ya pasan; el resto llega con las prácticas siguientes y el proyecto:

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 07
# ✅ ci-api.yml solo corre en push y en PR si cambia api/ o el propio workflow
# ...
# ✅ images.yml corre si cambia api/, web/ o el propio workflow
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `ci-api` no corre en el paso 3 | Falta `.github/workflows/ci-api.yml` en `paths` del `pull_request` | Paso 2: la misma lista en los dos eventos |
| En el paso 6 corren los cinco workflows | El PR apilado apunta a `main`, no a `ci/trigger-filters` | `gh pr edit test/docs-only --base ci/trigger-filters` |
| En el paso 6 no corre nada, ni `ci` | Pusiste `paths` también en `ci.yml` | Quítalos: `ci` corre siempre (paso 5) |
| `filters-lab` corre también para `lab/two-skip` | La negación va antes de `lab/**` | El `!` va después del patrón que recorta (paso 7) |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [github-script](../1-teoria/08-github-script.md) | [Concurrencia y timeouts](02-concurrencia-y-timeouts.md) |
