# Práctica 04 — Dependabot y zizmor online

> Fijar cada action por SHA te protege de un tag que se mueve, pero el SHA envejece: sin nadie
> que lo actualice, acabas con versiones con fallos conocidos. En esta práctica Dependabot
> propone las versiones nuevas con una semana de espera, y zizmor consulta la API de GitHub
> para comprobar que cada SHA es lo que dice ser.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Alertas de Dependabot y security updates activadas en `tablero`
- `dependabot.yml` con `github-actions` en la raíz, `uv` en `/api` y pnpm en `/web`
- 7 días de cooldown en cada ecosistema y las actions agrupadas en un solo PR
- Saber leer un PR de Dependabot que cambia un SHA
- El job `zizmor` de `lint-workflows` con las auditorías online
- `actionlint` y zizmor online limpios en local, y `main` en verde con los cinco workflows

## 📋 Antes de empezar

Terminaste la [práctica 03](03-pull-request-target-y-workflow-run.md) y leíste la
[teoría 06](../1-teoria/06-dependencias-de-actions.md) (SHA, commits impostores, cooldown) y la
[teoría 07](../1-teoria/07-analisis-estatico-zizmor-y-codeql.md) (auditorías online).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
zizmor --version
# zizmor 1.31.1
```

---

## Paso 1: Alertas y security updates

**Por qué**: Dependabot tiene dos funciones que se activan por separado. Las **alertas**
cruzan tus dependencias con la base de avisos de GitHub y te avisan cuando una tiene una
vulnerabilidad publicada. Las **security updates** abren el PR que la corrige. Las dos se
activan en el repo, no en `dependabot.yml`, y el cooldown del paso 3 no las frena: un arreglo
de seguridad no espera.

**Comando**: los dos `PUT` responden `204` sin cuerpo:

```bash
gh api -X PUT 'repos/{owner}/{repo}/vulnerability-alerts'
gh api -X PUT 'repos/{owner}/{repo}/automated-security-fixes'
```

**Verifica**: el primer endpoint responde `204` si las alertas están activas y `404` si no;
`--silent` deja solo el código de salida:

```bash
gh api 'repos/{owner}/{repo}/vulnerability-alerts' --silent && echo alertas activas
# alertas activas
gh api 'repos/{owner}/{repo}/automated-security-fixes' --jq .enabled
# true
```

---

## Paso 2: Los tres ecosistemas

**Por qué**: las **version updates** se configuran en `.github/dependabot.yml`, un bloque por
ecosistema y directorio. `github-actions` en `/` vigila los `uses:` de `.github/workflows/`:
actualiza el SHA y reescribe el comentario del tag a la vez. `uv` en `/api` lee `uv.lock`. Para
`web` el ecosistema se llama `npm` aunque uses pnpm: es el **nombre** que Dependabot da a todo
el ecosistema de paquetes de Node, y lee `pnpm-lock.yaml`. No es el CLI `npm`, que en este
bootcamp no se usa.

**Comando**: escribe a mano `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
  - package-ecosystem: uv
    directory: /api
    schedule:
      interval: weekly
  # "npm" es el nombre del ecosistema; Dependabot lo usa también para pnpm-lock.yaml.
  - package-ecosystem: npm
    directory: /web
    schedule:
      interval: weekly
```

**Verifica**: la orden de `dependabot-ecosystems`:

```bash
yq '[.updates[] | .package-ecosystem + ":" + (.directory // .directories[0])] | sort | join(" ")' .github/dependabot.yml
# github-actions:/ npm:/web uv:/api
```

Todavía no hagas commit: a este archivo le falta lo del paso 3.

---

## Paso 3: Cooldown de 7 días y las actions agrupadas

**Por qué**: una release comprometida suele detectarse en días. Sin `cooldown`, Dependabot
aplica una espera implícita corta y puedes recibir un PR con la versión maliciosa antes de que
nadie avise. Con `default-days: 7` la versión nueva tiene que llevar una semana publicada
antes de que la propongan. `groups` con `patterns: ["*"]` junta todas las actions en un solo PR
semanal en lugar de uno por action: menos ruido y un único run de CI que lo prueba todo junto.
zizmor revisa también `dependabot.yml`, y su auditoría `dependabot-cooldown` lo marca.

**Comando**: primero mira el aviso con el archivo del paso 2:

```bash
zizmor --offline .github/dependabot.yml 2>&1 | grep -E '^warning\[' | sort | uniq -c
#       3 warning[dependabot-cooldown]: insufficient cooldown in Dependabot updates
```

Uno por ecosistema; el detalle completo dice `insufficient implicit default-days (less than
7)`. Después deja el archivo así:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    cooldown:
      default-days: 7
    groups:
      actions:
        patterns: ["*"]
  - package-ecosystem: uv
    directory: /api
    schedule:
      interval: weekly
    cooldown:
      default-days: 7
  # "npm" es el nombre del ecosistema; Dependabot lo usa también para pnpm-lock.yaml.
  - package-ecosystem: npm
    directory: /web
    schedule:
      interval: weekly
    cooldown:
      default-days: 7
```

```bash
git add .github/dependabot.yml
git commit -m "ci: add dependabot with a 7-day cooldown"
git push
```

**Verifica**: la orden de `dependabot-cooldown` y zizmor sin avisos:

```bash
yq '[.updates[] | select((.cooldown.default-days // 0) < 7)] | length' .github/dependabot.yml
# 0
zizmor --offline -q .github/dependabot.yml
# No findings to report. Good job!
```

---

## Paso 4: Leer un PR de Dependabot

**Por qué**: Dependabot propone; tú decides. Un PR de `github-actions` cambia dos cosas en cada
`uses:`: el SHA y el comentario del tag. El comentario lo lee una persona y el SHA lo ejecuta
el runner, así que lo que compruebas es que el SHA nuevo es de verdad el del tag que dice el
comentario, en el repo oficial de la action. `scripts/resolve-sha.sh` hace esa resolución por
ti. Con el cooldown, puede que esta semana no haya ningún PR todavía: eso también es el
cooldown funcionando.

**Comando**: `--app` filtra por la GitHub App; `--author` no sirve para una app:

```bash
gh pr list --app dependabot --state all --json number,title --jq '.[] | "\(.number) \(.title)"'
```

Si sale algún PR de `github-actions`, mira sus `uses:`:

```bash
n=<número del PR>
gh pr diff "$n" | grep -E '^[-+] .*uses: '
# -      - uses: <action>@<sha antiguo> # <tag antiguo>
# +      - uses: <action>@<sha nuevo> # <tag nuevo>
```

**Verifica**: el SHA nuevo coincide con el que resuelve el script para ese tag. Cambia
`<owner>/<repo>` y `<tag nuevo>` por los del diff; para `github/codeql-action/init` el repo es
`github/codeql-action`:

```bash
sha=$(~/code/bc-github-actions/scripts/resolve-sha.sh <owner>/<repo> <tag nuevo> | grep -oE '[0-9a-f]{40}')
gh pr diff "$n" | grep -E '^\+' | grep -c "$sha"
# 1
```

El número es el de líneas `uses:` con esa action que cambia el PR: puede ser más de 1.

Un `0` significa que el SHA del PR no es el del tag: no lo fusiones y averigua por qué. Si no
hay ningún PR, la orden de la sección de comandos no imprime nada; vuelve a este paso la
semana que viene. Cuando lo apruebes, fusiónalo con `gh pr merge "$n" --squash`.

---

## Paso 5: zizmor online en `lint-workflows`

**Por qué**: hasta ahora el job `zizmor` corría con `--offline`. Sin ese flag y con un
token, zizmor añade las auditorías que consultan la API de GitHub: `impostor-commit` (el SHA no
pertenece al repo de la action, sino a un fork), `known-vulnerable-actions` (la versión tiene
un aviso publicado), `ref-version-mismatch` (el comentario del tag no coincide con el SHA) y
otras. El `GITHUB_TOKEN` del job basta: solo lee, y el job ya tiene `contents: read`. Cambiar
`.github/workflows/` por `.github/` mete también `dependabot.yml` en la revisión.

**Comando**: en `.github/workflows/lint-workflows.yml`, cambia el step `zizmor` del job
`zizmor`. Antes:

```yaml
      - name: zizmor
        # --format=github emite ::error y ::warning: cada hallazgo es una anotación.
        # --offline: las auditorías que consultan la API llegan en la Semana 12.
        run: zizmor --offline --format=github .github/workflows/
```

Después:

```yaml
      - name: zizmor
        # Sin --offline: impostor-commit, known-vulnerable-actions y ref-version-mismatch
        # consultan la API de GitHub con este token de solo lectura.
        env:
          GH_TOKEN: ${{ github.token }}
        run: zizmor --format=github .github/
```

El token llega por `env:`, nunca dentro del `run:`: es la regla de la práctica 02 aplicada a
un secreto.

**Verifica**: la orden de `zizmor-online`:

```bash
yq '.jobs[].steps[] | select(.run // "" | test("^zizmor ")) | "offline=" + (.run | test("--offline|--no-online-audits") | tostring) + " token=" + ((.env.GH_TOKEN // "") != "" | tostring)' \
  .github/workflows/lint-workflows.yml
# offline=false token=true
```

---

## Paso 6: actionlint y zizmor online en local

**Por qué**: antes de hacer push compruebas en tu máquina lo mismo que hará el CI, con tu
propio token. En local zizmor online es más lento que offline porque consulta la API por cada
`uses:`, y es justo la comprobación que el CI va a hacer. Si tu `actions-tablero` no es
público o el token no puede leerlo, zizmor falla con `couldn't list tags for
<tu-org>/actions-tablero`.

**Comando**:

```bash
actionlint && GH_TOKEN=$(gh auth token) zizmor -q .github/ && echo limpio
```

**Verifica**: el mismo comando que `workflows-lint`; termina en `limpio`:

```bash
actionlint && GH_TOKEN=$(gh auth token) zizmor -q .github/ && echo limpio
# No findings to report. Good job! (N suppressed)
# limpio
```

`N` depende de cuántos hallazgos esconde la persona `regular`; no importa su valor.

---

## Paso 7: Push y los cinco workflows en verde

**Por qué**: es el cierre de la semana. `check-week.sh` exige `success` en `ci`, `ci-api`,
`ci-web`, `lint-workflows` y `codeql` sobre el **último** commit de `main`. Este commit solo
toca `lint-workflows.yml`: `ci` y `codeql` corren siempre en `push`, pero `ci-api` y `ci-web`
tienen filtros de ruta y no se disparan. Los lanzas a mano sobre `main`; un `workflow_dispatch`
corre sobre el mismo commit y cuenta igual.

**Comando**:

```bash
git commit -am "ci: run zizmor online audits"
git push
for w in ci-api ci-web; do gh workflow run "$w.yml" --ref main; done
sha=$(git rev-parse HEAD)
for w in ci ci-api ci-web lint-workflows codeql; do
  id=$(gh run list --workflow "$w.yml" --commit "$sha" --limit 1 --json databaseId --jq '.[0].databaseId')
  gh run watch "$id" --exit-status > /dev/null && echo "$w ok"
done
# ci ok
# ci-api ok
# ci-web ok
# lint-workflows ok
# codeql ok
```

Si `gh run list` no devuelve nada aún, espera unos segundos: el run tarda en aparecer.

**Verifica**: la orden de `green-on-main`:

```bash
git fetch -q origin main && sha=$(git rev-parse origin/main)
for w in ci ci-api ci-web lint-workflows codeql; do
  printf '%s=%s ' "$w" "$(gh run list --workflow $w.yml --commit "$sha" --json conclusion --jq '.[0].conclusion')"
done; echo
# ci=success ci-api=success ci-web=success lint-workflows=success codeql=success
```

---

## ✅ Resultado

- [ ] Alertas de Dependabot y security updates activas
- [ ] `dependabot.yml` con `github-actions`, `uv` y `npm` (pnpm), cada uno en su directorio
- [ ] 7 días de cooldown en los tres y las actions agrupadas
- [ ] Sabes comprobar que el SHA de un PR de Dependabot es el del tag que anuncia
- [ ] El job `zizmor` corre online con el `GITHUB_TOKEN` sobre todo `.github/`
- [ ] `actionlint` y zizmor online limpios en local
- [ ] Los cinco workflows en `success` sobre el último commit de `main`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 12
# Semana 12 — Modelo de amenazas y endurecimiento  [repo: <tu-org>/tablero]
#
#   ✅ Todos los workflows de tablero declaran permissions: {} en la raíz
#   ...
# 17/17 comprobaciones superadas.
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `warning[dependabot-cooldown]` en zizmor | Un ecosistema sin `cooldown` o con menos de 7 días | Paso 3: `cooldown: {default-days: 7}` en cada uno |
| Dependabot no abre ningún PR | No hay versiones nuevas con más de 7 días, o el archivo no está en `main` | Es normal la primera semana; comprueba `git ls-tree origin/main .github/dependabot.yml` |
| `couldn't list tags for <tu-org>/actions-tablero` | El token no puede leer el repo central | Comprueba que `actions-tablero` es público y que `gh auth status` es tu cuenta |
| zizmor marca `impostor-commit` en un `uses:` | El SHA no está en el repo de la action, sino en un fork | Vuelve a resolverlo con `scripts/resolve-sha.sh` |
| zizmor online en local falla con un error de autenticación | `GH_TOKEN` vacío | `gh auth status`; el comando lleva `GH_TOKEN=$(gh auth token)` delante |
| `green-on-main` con `ci-api=` vacío | No lanzaste `ci-api` y `ci-web` sobre el último commit | Paso 7: `gh workflow run` con `--ref main` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [pull_request_target y workflow_run](03-pull-request-target-y-workflow-run.md) | [Proyecto: capa 12 de tablero](../3-proyecto/README.md) |
