# Práctica 04 — Retención y limpieza

> Lo que un pipeline produce también ocupa sitio: artefactos, logs y cachés. En esta práctica
> bajas la retención del repo a lo que `tablero` necesita y dejas un workflow diario que borra
> las cachés sin dueño, empezando por las del experimento de la práctica 02.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- La retención de artefactos y logs del repo en 14 días, con el valor anterior respaldado
- `scripts/prune-caches.sh` completo (`TODO 7` a `TODO 9`), probado sin GitHub y en `dry-run`
- `cleanup.yml` completo (`TODO 10` a `TODO 12`), en `main` por la cola
- Una limpieza lanzada a mano en `dry-run` y después de verdad, con las cachés del experimento
  borradas
- Los límites de caché del repo leídos y los artefactos y logs de un run borrados por API

## 📋 Antes de empezar

Terminaste las prácticas [02](02-cache-y-paralelismo-medidos.md) y [03](03-metricas-del-ci.md).
Leíste la [teoría 07](../1-teoria/07-retencion-y-limpieza.md).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
S=~/code/bc-github-actions/bootcamp/week-19-rendimiento_coste_y_observabilidad/3-proyecto/starter
exp=$(cat ~/code/perf-19/exp-pr)
gh cache list --ref "refs/pull/$exp/merge" --json id --jq length
# 3
```

Si sale 0, las cachés del experimento ya caducaron (7 días sin acceso): la práctica funciona
igual, pero el `dry-run` del paso 4 tendrá menos que enseñarte.

---

## Paso 1: Retención a 14 días

**Por qué**: un repo público guarda artefactos y logs 90 días por defecto. Nada de `tablero`
necesita un artefacto de hace tres meses: lo que debe durar (una release, un SBOM, una imagen)
ya vive en la release de GitHub o en GHCR desde la Semana 14. Catorce días cubren una iteración:
el artefacto de un fallo de esta semana sigue ahí. Y el valor del repo es un techo: un
`retention-days: 30` en `upload-artifact` se queda en 14.

> ⚠️ **Cambias un ajuste del repo.** Afecta a los artefactos y logs que se creen a partir de
> ahora. Guardas antes el valor actual; para volver atrás:
> `gh api -X PUT "repos/{owner}/{repo}/actions/permissions/artifact-and-log-retention" -F days="$(jq .days ~/code/org-policy-backup/retention-s19.json)"`.

**Comando**:

```bash
mkdir -p ~/code/org-policy-backup
gh api "repos/{owner}/{repo}/actions/permissions/artifact-and-log-retention" \
  | tee ~/code/org-policy-backup/retention-s19.json
# {"days":90,"maximum_allowed_days":90}
gh api -X PUT "repos/{owner}/{repo}/actions/permissions/artifact-and-log-retention" -F days=14
```

`-F` envía `14` como número; con `-f` iría como cadena. El `PUT` no imprime nada si va bien.

**Verifica**: la orden de `artifact-retention`:

```bash
gh api "repos/{owner}/{repo}/actions/permissions/artifact-and-log-retention" --jq .days
# 14
```

---

## Paso 2: `prune-caches.sh`

**Por qué**: una caché es huérfana cuando ninguna ref que la pueda leer va a volver a correr: el
PR está cerrado o la rama ya no existe, como las `gh-readonly-queue/...` que la cola borra al
terminar cada grupo. Las de `main` nunca, y los tags tampoco: no son ramas de trabajo. El script
pide **una vez** las ramas y los PR abiertos, y decide con esas dos listas para cada caché. Como
habla con `gh`, lo pruebas con un `gh` de mentira que responde lo que tú quieras y apunta lo que
se borraría.

**Comando**:

```bash
git switch -c ci/cleanup
cp "$S/scripts/prune-caches.sh" scripts/
cp "$S/.github/workflows/cleanup.yml" .github/workflows/
```

En el **TODO 7**, la rama de `refs/pull/*/merge` saca el número del PR y sigue si está abierto:

```bash
    refs/pull/*/merge)
      n=${ref#refs/pull/}
      if grep -qxF "${n%/merge}" <<<"$open_prs"; then continue; fi ;;
```

`-x` compara la línea entera: sin él, el PR 1 coincidiría con el 12. `-F` toma el texto tal
cual, porque un nombre de rama puede llevar puntos. En el **TODO 8**, lo mismo con `branches` y
`${ref#refs/heads/}`, y quitas el `continue` que deja el starter. En el **TODO 9**, un
`if [[ "$dry_run" == true ]]` que solo imprime `se borraría <id> (<ref>)` y, en el `else`, el
`gh cache delete` y el `echo` que ya están.

Ahora el `gh` de mentira, el mismo que usa `check-week.sh`:

```bash
t=$(mktemp -d)
cat > "$t/gh" <<'EOF'
#!/usr/bin/env bash
# gh de mentira: ramas main y feat/x, PR 7 abierto y seis cachés.
case "$1 $2" in
  "api repos/{owner}/{repo}/branches?per_page=100") printf 'main\nfeat/x\n' ;;
  "pr list") echo 7 ;;
  "cache list") printf '%s\n' '1 refs/heads/main' '2 refs/pull/7/merge' '3 refs/pull/8/merge' \
    '4 refs/heads/gh-readonly-queue/main/pr-8-abc' '5 refs/heads/feat/x' '6 refs/tags/v1.0.0' ;;
  "cache delete") echo "$3" >> "${0%/gh}/deleted" ;;
esac
EOF
chmod +x "$t/gh"
```

**Verifica**: en `dry-run` no borra nada; de verdad, solo la 3 (PR 8, cerrado) y la 4 (rama de
la cola que ya no existe):

```bash
PATH="$t:$PATH" DRY_RUN=true scripts/prune-caches.sh
# se borraría 3 (refs/pull/8/merge)
# se borraría 4 (refs/heads/gh-readonly-queue/main/pr-8-abc)
# cachés sin dueño: 2
cat "$t/deleted" 2>/dev/null | wc -l
# 0
PATH="$t:$PATH" scripts/prune-caches.sh > /dev/null; paste -sd, - < "$t/deleted"
# 3,4
rm -rf "$t"
DRY_RUN=true scripts/prune-caches.sh
# se borraría <id> (refs/pull/<exp>/merge)
# ...
# cachés sin dueño: <n>
```

La última orden habla con tu repo de verdad, en `dry-run`: solo lee. Entre las líneas tienen que
estar las tres cachés de `refs/pull/<exp>/merge` y ninguna de `refs/heads/main`.

---

## Paso 3: `cleanup.yml`

**Por qué**: la limpieza no puede depender de que alguien se acuerde. El cron diario borra de
verdad; a mano, lo seguro es listar. Las dos cosas salen de un solo input: en `workflow_dispatch`,
`dry-run` vale `true` salvo que pidas lo contrario; en `schedule` no hay inputs, llega vacío, y el
script solo deja de borrar si vale `true`. El job escribe en Actions (borrar cachés) y solo lee lo
demás: `contents` para el checkout y las ramas, `pull-requests` para los PR abiertos
([teoría 07](../1-teoria/07-retencion-y-limpieza.md#el-workflow-seguro-por-defecto-según-quién-lo-lance)).

**Comando**: en el **TODO 10**, `default: true`. En el **TODO 11**, los permisos del job:

```yaml
    permissions:
      # Borrar cachés es escribir en Actions; leer ramas y PR, lectura.
      actions: write
      contents: read
      pull-requests: read
```

En el **TODO 12**, bajo `env:` del step, el input pasa al script:

```yaml
          DRY_RUN: ${{ inputs.dry-run }}
```

Un input de `workflow_dispatch` no es dato de un tercero, pero la regla 4 se aplica igual: entra
por `env:` y el script lo compara, nunca se interpola en `run:`.

```bash
actionlint && GH_TOKEN=$(gh auth token) zizmor -q .github/ && echo limpio
# limpio
```

**Verifica**: la orden de `cleanup-workflow`:

```bash
yq '(.on | keys | sort | join(",")) + " dry=" + (.on.workflow_dispatch.inputs."dry-run".default | tostring) + " root=" + (.permissions | length | tostring) + " jobs=" + ([.jobs[] | (.permissions.actions // "none") + ":" + (has("timeout-minutes") | tostring)] | join(",")) + " env=" + ([.jobs[].steps[] | select(.run // "" | test("prune-caches\.sh")) | .env.DRY_RUN] | join(""))' .github/workflows/cleanup.yml
# schedule,workflow_dispatch dry=true root=0 jobs=write:true env=${{ inputs.dry-run }}
```

---

## Paso 4: PR, cola y la primera limpieza

**Por qué**: `workflow_dispatch` solo ofrece workflows que están en la rama que eliges, así que
`cleanup` se lanza sobre `main` después de fusionar. Lo primero es un `dry-run`: lees qué
borraría y, si la lista tiene sentido, lo lanzas de verdad. Como este merge mueve `main`, la
tendencia de `ci-metrics` se vuelve a lanzar al final: su comprobación mira el último commit.

**Comando**:

```bash
git add scripts/prune-caches.sh .github/workflows/cleanup.yml
git commit -m "ci: add daily cleanup of orphan caches"
git push -u origin ci/cleanup
gh pr create --title "ci: add daily cleanup of orphan caches" --body "Capa 19, práctica 04."
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch --required > /dev/null && gh pr merge "$pr"
until [ "$(gh pr view "$pr" --json state --jq .state)" = MERGED ]; do sleep 15; done
git switch main && git pull --ff-only
gh workflow run cleanup.yml --ref main
sleep 10
c=$(gh run list --workflow cleanup.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$c" --exit-status > /dev/null
gh run view "$c" --log | grep -oE '(se borraría|borrada|cachés sin dueño).*'
# se borraría <id> (refs/pull/<exp>/merge)
# se borraría <id> (refs/pull/<exp>/merge)
# se borraría <id> (refs/pull/<exp>/merge)
# se borraría <id> (refs/heads/gh-readonly-queue/main/pr-<n>-<sha>)
# cachés sin dueño: <n>
```

Lee la lista. Ninguna línea puede ser de `refs/heads/main` ni de un PR que siga abierto.

> ⚠️ **El siguiente comando borra cachés de verdad.** Una caché borrada no se recupera, pero
> tampoco se pierde nada que no se pueda regenerar: el siguiente run que la necesite la vuelve a
> crear y tarda lo que tarde la instalación. Si la lista del `dry-run` incluye algo que no
> esperabas, para aquí y revisa el paso 2.

```bash
gh workflow run cleanup.yml --ref main -f dry-run=false
sleep 10
c=$(gh run list --workflow cleanup.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$c" --exit-status > /dev/null && echo limpieza-ok
# limpieza-ok
gh workflow run ci-metrics.yml --ref main
```

**Verifica**: las cachés del experimento ya no están, las de `main` sí, y la orden de
`cleanup-ran`:

```bash
gh cache list --ref "refs/pull/$exp/merge" --json id --jq length
# 0
gh cache list --ref refs/heads/main --json id --jq length
# <n mayor que 0>
git fetch -q origin main
gh run list --workflow cleanup.yml --commit "$(git rev-parse origin/main)" --json conclusion --jq '[.[].conclusion] | first'
# success
```

Compara el uso con el inventario de la práctica 02:
`gh api "repos/{owner}/{repo}/actions/cache/usage" --jq .active_caches_count`.

---

## Paso 5: Límites de caché y borrar lo de un run

**Por qué**: además de la limpieza, el repo tiene dos límites de caché que se leen y se cambian
por API: cuántos días vive una entrada sin acceso y cuántos GB caben. En `tablero` no hace falta
tocarlos: la limpieza diaria quita lo que sobra sin acortar la vida de la caché de `main`. Si
quisieras acortarla, sería un `PUT` con `-F max_cache_retention_days=<n>`, que afecta a todas
las cachés del repo, `main` incluida. Lo que sí necesitas saber hacer es borrar los artefactos y
el log de un run concreto: es la respuesta si un log muestra algo que no debía, junto con
**rotar** la credencial, porque quien lo leyó ya la tiene.

**Comando**: los límites, solo lectura:

```bash
gh api "repos/{owner}/{repo}/actions/cache/retention-limit"
# {"max_cache_retention_days":7}
gh api "repos/{owner}/{repo}/actions/cache/storage-limit"
# {"max_cache_size_gb":10}
```

Para practicar el borrado usa el run de `ci` del PR del experimento: está cerrado y nadie lo va
a necesitar.

```bash
r=$(gh run list --workflow ci.yml --branch exp/shard-web --limit 1 --json databaseId --jq '.[0].databaseId'); echo "$r"
# <id-del-run>
gh api "repos/{owner}/{repo}/actions/runs/$r/artifacts" --jq '.artifacts[] | "\(.id) \(.name)"'
# <artifact-id> web-dist
# ...
```

> ⚠️ **Destructivo y sin vuelta atrás.** Borrar los artefactos o el log de un run no se puede
> deshacer. Antes, descarga lo que quieras conservar. `gh run download` falla si el run ya no
> tiene artefactos (caducan): en ese caso no hay nada que respaldar.

```bash
mkdir -p ~/code/run-backup/"$r"
gh run download "$r" -D ~/code/run-backup/"$r" || echo "sin artefactos que descargar"
gh run view "$r" --log > ~/code/run-backup/"$r"/run.log
for a in $(gh api "repos/{owner}/{repo}/actions/runs/$r/artifacts" --jq '.artifacts[].id'); do
  gh api -X DELETE "repos/{owner}/{repo}/actions/artifacts/$a"
done
gh api -X DELETE "repos/{owner}/{repo}/actions/runs/$r/logs"
```

**Verifica**: el run sigue existiendo, sin artefactos ni log, y el respaldo está en disco:

```bash
gh api "repos/{owner}/{repo}/actions/runs/$r/artifacts" --jq .total_count
# 0
gh api "repos/{owner}/{repo}/actions/runs/$r/logs" > /dev/null 2>&1 || echo sin-logs
# sin-logs
test -s ~/code/run-backup/"$r"/run.log && echo respaldo-ok
# respaldo-ok
```

---

## ✅ Resultado

- [ ] Retención de artefactos y logs en 14 días, con el valor anterior en `~/code/org-policy-backup/`
- [ ] `scripts/prune-caches.sh` respeta `main`, tags, PR abiertos y ramas vivas, y en `dry-run` no borra
- [ ] `cleanup.yml` en `main`: cron diario, `dry-run` por defecto a mano y `actions: write` solo en su job
- [ ] Una limpieza en `dry-run` leída y otra de verdad, con las cachés del experimento borradas
- [ ] Los artefactos y el log de un run borrados por API, con respaldo previo

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 19
# ...
# 15/15 comprobaciones superadas.
```

Se suman `artifact-retention`, `prune-caches-script`, `cleanup-workflow` y `cleanup-ran`: las
quince en verde. Si `ci-metrics-ran-after-ci` sale en rojo, el `ci` del último merge aún no
había terminado: espera a que corra `ci-metrics` y repite. Si es `ci-metrics-trend-ran`, la
tendencia que lanzaste en el paso 4 aún estaba en curso.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `HTTP 422` en el `PUT` de retención | `days` fuera de rango o enviado como cadena | `-F days=14`, entre 1 y `maximum_allowed_days` |
| `cleanup` falla con `HTTP 403: Resource not accessible by integration` | Falta `actions: write` en el job (`TODO 11`) | Paso 3 |
| `cleanup` falla al listar PR | Falta `pull-requests: read` | Paso 3 |
| El `dry-run` lista una caché de un PR abierto | El `TODO 7` no compara con `open_prs`, o le falta `-x` | Paso 2 |
| El `dry-run` borró de verdad | El `TODO 9` no comprueba `dry_run`, o `DRY_RUN` no llega (`TODO 12`) | Pasos 2 y 3; las cachés se regeneran solas |
| `gh workflow run cleanup.yml` responde `HTTP 404` | El archivo aún no está en `main` | Fusiona el PR antes del dispatch |
| `cleanup` sale en verde aunque el script falló | Quitaste `shell: bash` de `defaults` y el fallo se pierde tras `tee` | Restáuralo: activa `pipefail` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Práctica 03 — Métricas del CI](03-metricas-del-ci.md) | [Proyecto: capa 19 de tablero](../3-proyecto/README.md) |
