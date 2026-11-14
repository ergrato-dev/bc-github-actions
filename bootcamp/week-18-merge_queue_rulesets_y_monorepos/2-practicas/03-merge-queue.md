# Práctica 03 — Merge queue

> Dos PR en verde por separado pueden romper `main` juntos: cada uno se probó contra un `main`
> que ya no existe. En esta práctica `ci.yml` aprende a contestar a la merge queue, activas la
> cola en el ruleset y fusionas tres PR a través de ella, dos a la vez.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `ci.yml` disparándose también con `merge_group`, en `main` antes de activar la cola
- La regla `merge_queue` en `ops/github/ruleset-main.yaml` y en el ruleset activo, con un `PUT`
- Un PR que entra en `main` a través de la cola, con su run de `merge_group` en verde
- Dos PR en la cola a la vez, el segundo probado sobre el primero, y `ci` en verde en el push a `main`

## 📋 Antes de empezar

Terminaste la [práctica 02](02-ruleset-y-codeowners-en-main.md): `main` solo acepta PR con
`ci-gate` en verde. Leíste la [teoría 05](../1-teoria/05-merge-queue.md). Todo lo que cambies hoy
en `tablero` entra por PR.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
id=$(gh api 'repos/{owner}/{repo}/rulesets' --jq '.[] | select(.name == "main") | .id'); echo "$id"
# <id-del-ruleset>
```

Si `echo` imprime dos números, repetiste el `POST` en la práctica 02: borra el duplicado
(su tabla de errores lo explica) antes de seguir.

---

## Paso 1: `ci.yml` contesta a la cola

**Por qué**: la cola no lanza tus workflows por arte de magia: crea una rama temporal
`gh-readonly-queue/main/...` con el grupo y emite el evento `merge_group`. Un workflow que no lo
escucha no corre, `ci-gate` no llega y, pasado el `check_response_timeout_minutes`, la cola saca
el PR. Por eso `merge_group` entra en `ci.yml` **antes** de activar la cola, y entra por el camino
normal: un PR con `ci-gate` en verde. Si activaras la cola primero, este mismo PR se quedaría
atascado en ella. La sintaxis de `merge_group` admite `branches` y `branches-ignore`, no `paths`:
de qué áreas corren ya se encarga `changes`, con `merge_group.base_sha` como base
([teoría 05](../1-teoria/05-merge-queue.md#el-evento-merge_group)).

La concurrencia no cambia: cada grupo tiene su propia ref y `cancel-in-progress` solo vale
`true` en `pull_request`, así que un grupo nunca cancela a otro.

**Comando**: rellena el **TODO 4** de `ci.yml`:

```yaml
on:
  push:
    branches: [main]
  pull_request:
  # Sin este evento la merge queue espera un ci-gate que nunca llega.
  merge_group:
  workflow_dispatch:
```

```bash
git switch -c ci/merge-group
actionlint && echo limpio
# limpio
git commit -am "ci: run ci on merge_group"
git push -u origin ci/merge-group
gh pr create --title "ci: run ci on merge_group" --body "Capa 18, práctica 03."
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch --required > /dev/null && gh pr merge "$pr" --squash --delete-branch
git switch main && git pull --ff-only
```

**Verifica**: la orden de `ci-triggers`, ya sobre `main`:

```bash
yq '(.on | keys | sort | join(",")) + " push=" + (.on.push.branches | join(","))' .github/workflows/ci.yml
# merge_group,pull_request,push,workflow_dispatch push=main
git log -1 --format=%s
# ci: run ci on merge_group (#<n>)
```

---

## Paso 2: La regla `merge_queue`

**Por qué**: la cola es una regla más del ruleset, con siete parámetros obligatorios. Los
valores de `tablero` están razonados en la
[teoría 05](../1-teoria/05-merge-queue.md#los-parámetros-de-la-regla): `SQUASH` (en
**mayúsculas**, a diferencia de `allowed_merge_methods`), `ALLGREEN` para que cada grupo pase
por sí mismo, hasta cinco grupos en paralelo y 30 minutos de margen para un CI que tarda mucho
menos. `strict_required_status_checks_policy` se queda en `false`: la cola ya prueba cada PR
sobre el `main` real, así que exigir además que la rama del PR esté al día solo añadiría esperas.

El cambio de archivo va en una rama y el ruleset se actualiza desde ella con un `PUT`. El PR de
ese archivo será el primero que pase por la cola (paso 3): cuando entre en `main`, archivo y
ruleset vuelven a decir lo mismo.

> ⚠️ **Cambias el ruleset que protege `main`.** Antes guardas el actual con la forma que acepta
> el `PUT`; para volver atrás:
> `gh api -X PUT "repos/{owner}/{repo}/rulesets/$id" --input ~/code/org-policy-backup/ruleset-main-s18.json`.

**Comando**: el respaldo, y después el **TODO 14**:

```bash
mkdir -p ~/code/org-policy-backup
gh api "repos/{owner}/{repo}/rulesets/$id" \
  --jq '{name, target, enforcement, conditions, bypass_actors, rules}' \
  > ~/code/org-policy-backup/ruleset-main-s18.json
jq -r '[.rules[].type] | sort | join(",")' ~/code/org-policy-backup/ruleset-main-s18.json
# deletion,non_fast_forward,pull_request,required_status_checks
git switch -c ops/merge-queue
```

Al final de `rules:` en `ops/github/ruleset-main.yaml`, en lugar del comentario del TODO 14:

```yaml
  - type: merge_queue
    parameters:
      merge_method: SQUASH
      grouping_strategy: ALLGREEN
      max_entries_to_build: 5
      min_entries_to_merge: 1
      max_entries_to_merge: 5
      min_entries_to_merge_wait_minutes: 0
      check_response_timeout_minutes: 30
```

```bash
git commit -am "chore: enable merge queue in main ruleset"
yq -o=json ops/github/ruleset-main.yaml \
  | gh api -X PUT "repos/{owner}/{repo}/rulesets/$id" --input - --jq '[.rules[].type] | sort | join(",")'
# deletion,merge_queue,non_fast_forward,pull_request,required_status_checks
```

**Verifica**: la orden de `ruleset-active`, y los parámetros de la cola tal como los aplica GitHub:

```bash
gh api 'repos/{owner}/{repo}/rules/branches/main' --jq '"rules=\([.[].type] | unique | join(",")) checks=\([.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[] | "\(.context)@\(.integration_id)"] | join(","))"'
# rules=deletion,merge_queue,non_fast_forward,pull_request,required_status_checks checks=ci-gate@15368
gh api 'repos/{owner}/{repo}/rules/branches/main' \
  --jq '.[] | select(.type == "merge_queue") | .parameters | "\(.merge_method) \(.grouping_strategy) build=\(.max_entries_to_build) timeout=\(.check_response_timeout_minutes)"'
# SQUASH ALLGREEN build=5 timeout=30
```

En la página de cualquier PR abierto contra `main`, el botón de fusionar pasa a ofrecer meterlo
en la cola en lugar de fusionarlo.

---

## Paso 3: El primer PR a través de la cola

**Por qué**: con la cola activa, `gh pr merge` ya no fusiona: si los checks del PR pasaron, lo
mete en la cola; si no, intenta activar el auto-merge para que entre al pasar. Por eso esperas
antes a `ci-gate`. No hace falta `--squash`: el método lo fija la regla. Y `--admin`, que se
saltaría la cola, no te sirve: `bypass_actors` está vacío. Dentro de la cola, `changes` compara
contra `merge_group.base_sha`: este PR solo toca `ops/`, así que ninguna área corre y el grupo
pasa en un par de minutos.

**Comando**:

```bash
git push -u origin ops/merge-queue
gh pr create --title "chore: enable merge queue in main ruleset" --body "Capa 18, práctica 03."
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch --required > /dev/null
gh pr merge "$pr"
# <gh confirma que el PR entra en la merge queue de main>
sleep 20
gh run list --workflow ci.yml --event merge_group --limit 1 --json headBranch,status --jq '.[0] | "\(.headBranch) \(.status)"'
# gh-readonly-queue/main/pr-<n>-<sha> in_progress
run=$(gh run list --workflow ci.yml --event merge_group --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo cola-ok
# cola-ok
until [ "$(gh pr view "$pr" --json state --jq .state)" = MERGED ]; do sleep 15; done
git switch main && git pull --ff-only
```

**Verifica**: el grupo no corrió ninguna área, el PR está en `main` y el archivo vuelve a coincidir
con el ruleset:

```bash
gh run view "$run" --log | grep -oE '(api|web|tools|smoke|workflows)=(true|false)$' | sort -u | tr '\n' ' '; echo
# api=false smoke=false tools=false web=false workflows=false
git log -1 --format=%s
# chore: enable merge queue in main ruleset (#<n>)
yq -o=json ops/github/ruleset-main.yaml | jq -r '[.rules[].type] | sort | join(",")'
# deletion,merge_queue,non_fast_forward,pull_request,required_status_checks
```

---

## Paso 4: Dos PR en la cola a la vez

**Por qué**: es el caso para el que existe la cola. Con dos PR dentro, el primer grupo es
`main` + A y el segundo, `main` + A + B: B se prueba sobre A, no sobre el `main` de cuando abriste
su PR. Si A fallara, la cola lo sacaría y B tendría que probarse otra vez, ya sin A. Después, cada
commit que la cola deja en `main` dispara el `ci` de `push`, que es la última comprobación de
que `main` está verde ([teoría 05](../1-teoria/05-merge-queue.md#grupos-sobre-main)).

Los dos PR solo tocan documentación: corren los jobs base y `ci-gate`, y la cola va rápida. Con
`docs:` en el título, release-please no prepara una versión.

**Comando**: dos ramas desde `main`, cada una con su PR:

```bash
git switch -c docs/queue-a
printf '\n## Cómo contribuir\n\nTodo cambio entra en `main` por PR y a través de la merge queue.\n' >> README.md
git commit -am "docs: explain how changes reach main"
git push -u origin docs/queue-a
gh pr create --fill
a=$(gh pr view --json number --jq .number)
git switch main && git switch -c docs/queue-b
cat > CONTRIBUTING.md <<'EOF'
# Contribuir a tablero

1. Abre un PR contra `main`.
2. Espera a que `ci-gate` salga en verde: `gh pr checks <número> --watch --required`.
3. Mételo en la merge queue con `gh pr merge <número>`.
EOF
git add CONTRIBUTING.md
git commit -m "docs: add contributing guide"
git push -u origin docs/queue-b
gh pr create --fill
b=$(gh pr view --json number --jq .number)
gh pr checks "$a" --watch --required > /dev/null && gh pr checks "$b" --watch --required > /dev/null
gh pr merge "$a" && gh pr merge "$b"
sleep 30
gh run list --workflow ci.yml --event merge_group --limit 2 --json headBranch,status --jq '.[] | "\(.headBranch) \(.status)"'
# gh-readonly-queue/main/pr-<b>-<sha> in_progress
# gh-readonly-queue/main/pr-<a>-<sha> in_progress
```

Si el grupo de A ya terminó cuando miras, verás `completed` en su línea: la cola no espera a nadie.
Espera a que entren los dos y al `ci` del push del último:

```bash
until [ "$(gh pr view "$b" --json state --jq .state)" = MERGED ]; do sleep 15; done
git switch main && git pull --ff-only
sha=$(git rev-parse HEAD); sleep 10
run=$(gh run list --workflow ci.yml --event push --commit "$sha" --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo push-ok
# push-ok
```

**Verifica**: los dos commits en orden y la orden de `merged-through-queue`:

```bash
git log -2 --format=%s
# docs: add contributing guide (#<b>)
# docs: explain how changes reach main (#<a>)
n=$(gh api "repos/{owner}/{repo}/commits/$sha/pulls" --jq '.[0].number')
printf 'queue=%s push=%s\n' \
  "$(gh run list --workflow ci.yml --event merge_group --limit 50 --json headBranch,conclusion --jq "[.[] | select(.headBranch | test(\"/pr-$n-\"))][0].conclusion")" \
  "$(gh run list --workflow ci.yml --event push --commit "$sha" --json conclusion --jq '.[0].conclusion')"
# queue=success push=success
```

Limpia las ramas locales:

```bash
git branch -D ci/merge-group ops/merge-queue docs/queue-a docs/queue-b 2>/dev/null; git branch --show-current
# main
```

---

## ✅ Resultado

- [ ] `ci.yml` escucha `merge_group`, y entró en `main` antes de activar la cola
- [ ] `ops/github/ruleset-main.yaml` y el ruleset activo tienen la regla `merge_queue` con `SQUASH` y `ALLGREEN`
- [ ] El respaldo del ruleset anterior en `~/code/org-policy-backup/ruleset-main-s18.json`
- [ ] Un PR entró en `main` por la cola con su run de `merge_group` en verde
- [ ] Dos PR en la cola a la vez, el segundo probado sobre el primero, y `ci` verde en el push

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 18
# ...
#   ✅ El PR del último commit de main pasó ci-gate en la merge queue y ci volvió a pasar en el push a main
# ...
```

Se suman `ci-triggers`, `ruleset-file`, `ruleset-active` y `merged-through-queue`: catorce en
verde. Las cuatro que faltan son de la GitHub App de release, en la práctica 04.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El PR sale de la cola a los 30 minutos sin run de `merge_group` | `ci.yml` de `main` no escucha `merge_group` | Paso 1, por PR, con la cola desactivada si hace falta (restaura el respaldo) |
| `HTTP 422` en el `PUT` | `merge_method` en minúsculas o un valor fuera de rango | `SQUASH` en mayúsculas; rangos en la teoría 05 |
| `gh pr merge` habla de auto-merge o falla por ello | Los checks del PR aún no han pasado | Espera con `gh pr checks <n> --watch --required` y repite |
| El grupo de B falla aunque B estaba verde | B no funciona sobre A: es lo que la cola tenía que detectar | Arregla B sobre el `main` nuevo y vuelve a meterlo |
| `queue=null` en la verificación | El último commit de `main` no vino de la cola | Repite el paso 4 con otro par de PR |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Ruleset y CODEOWNERS en main](02-ruleset-y-codeowners-en-main.md) | [release-please con una GitHub App](04-release-please-con-una-github-app.md) |
