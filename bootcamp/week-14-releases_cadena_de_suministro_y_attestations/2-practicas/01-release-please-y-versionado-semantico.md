# Práctica 01 — release-please y versionado semántico

> Una versión que alguien sube a mano es una versión que un día no se sube, o se sube dos veces.
> En esta práctica dejas que la versión salga de los commits: release-please abre un PR con el
> número siguiente y el CHANGELOG, y al fusionarlo crea el tag y la release de `tablero`.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `GITHUB_TOKEN` autorizado a abrir PR en tu org y en `tablero`, sin subir sus permisos por defecto
- `release-please-config.json` y `.release-please-manifest.json` en la raíz de `tablero`
- `release.yml` con el job `release-please`, fijado por SHA y con permisos mínimos
- Tu primer PR de release, y la release `v0.2.0` publicada al fusionarlo

## 📋 Antes de empezar

Leíste la [teoría 01](../1-teoria/01-versionado-semantico-y-release-please.md) y
`check-week.sh 13` está en verde. `deploy-gate.yml` corre en cada push a `main` y espera
aprobación: los runs que se quedaron esperando de la semana pasada los cancelas ya, y los que
abran tus pushes de esta semana puedes dejarlos esperar o cancelarlos igual.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
gh run list --workflow deploy-gate.yml --status waiting --json databaseId --jq '.[].databaseId' |
  xargs -r -n1 gh run cancel
git status --short | wc -l
# 0
git tag --list 'v*' | wc -l
# 0
```

Si ese último comando no da `0`, ya tienes tags de versión de otra prueba: release-please
partiría de ellos. Bórralos antes de seguir o ajusta el manifest al último.

---

## Paso 1: Deja que `GITHUB_TOKEN` abra pull requests

**Por qué**: release-please trabaja abriendo y actualizando un PR, y por defecto `GITHUB_TOKEN`
no puede crear PR. En la Semana 11 dejaste la org con `can_approve_pull_request_reviews=false`;
ahora lo abres, porque el ajuste **Allow GitHub Actions to create and approve pull requests** es
uno solo para crear y para aprobar. Va primero en la org: si la org lo prohíbe, el repo no puede
activarlo. `default_workflow_permissions` se queda en `read`: abres la creación de PR, no subes
los permisos que recibe un workflow sin bloque `permissions:`. Que un workflow pueda aprobar PR
es el riesgo que compras; en la Semana 18 lo cierras con un ruleset que exige revisión humana.

> ⚠️ **Cambias una política de toda la organización.** Primero guardas la actual; para volver
> atrás, el `PUT` con los valores de ese archivo.

**Comando**:

```bash
gh auth status 2>&1 | grep -q admin:org || gh auth refresh -h github.com -s admin:org
mkdir -p ~/code/org-policy-backup
gh api orgs/{owner}/actions/permissions/workflow > ~/code/org-policy-backup/workflow-s14.json
gh api -X PUT orgs/{owner}/actions/permissions/workflow \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true
gh api -X PUT repos/{owner}/{repo}/actions/permissions/workflow \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true
```

**Verifica**: los dos niveles dicen lo mismo:

```bash
for p in orgs/{owner} repos/{owner}/{repo}; do
  gh api "$p/actions/permissions/workflow" \
    --jq '"\(.default_workflow_permissions) approve_prs=\(.can_approve_pull_request_reviews)"'
done
# read approve_prs=true
# read approve_prs=true
```

> A partir de aquí `check-week.sh 11` marca `org-default-token-read` en rojo: es lo esperado. La
> capa 14 sustituye esa política y la Semana 18 cierra el riesgo
> ([comprobaciones superadas por capas posteriores](../../../docs/autograding.md#comprobaciones-superadas-por-capas-posteriores)).

Falta otra política de la Semana 11: la org solo admite actions de GitHub y los patrones que
listaste, y `googleapis/release-please-action` no está entre ellos. Sin añadirla, el job
`release-please` ni arranca. El `PUT` **sustituye** la lista entera, así que partes de la
guardada y le sumas un patrón:

```bash
gh api orgs/{owner}/actions/permissions/selected-actions > ~/code/org-policy-backup/selected-actions-s14.json
jq '.patterns_allowed += ["googleapis/release-please-action@*"]' \
  ~/code/org-policy-backup/selected-actions-s14.json |
  gh api -X PUT orgs/{owner}/actions/permissions/selected-actions --input -
gh api orgs/{owner}/actions/permissions/selected-actions --jq '.patterns_allowed | sort | .[]'
# astral-sh/setup-uv@*
# docker/build-push-action@*
# docker/login-action@*
# docker/metadata-action@*
# docker/setup-buildx-action@*
# googleapis/release-please-action@*
# pnpm/action-setup@*
```

`actions/attest` y `actions/dependency-review-action` son de GitHub: ya entran por
`github_owned_allowed`.

---

## Paso 2: El config y el manifest

**Por qué**: en modo manifest, release-please lee dos archivos versionados en vez de inputs
sueltos. El **config** dice qué hay que versionar: un único paquete en la raíz (`"."`), de tipo
`simple`, que no toca ningún `pyproject.toml` ni `package.json` y escribe la versión en
`version.txt`. `include-component-in-tag: false` deja los tags como `v0.2.0` en vez de
`tablero-v0.2.0`: solo hay un paquete. `bump-minor-pre-major: true` hace que, mientras estés en
`0.x`, un cambio incompatible suba el `MINOR` y no te saque a `1.0.0` sin decidirlo. El
**manifest** guarda la última versión publicada: partes de `0.1.0`, y release-please lo
reescribe en cada release.

**Comando**: escribe a mano `release-please-config.json` en la raíz de `tablero`:

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "include-component-in-tag": false,
  "bump-minor-pre-major": true,
  "packages": {
    ".": {
      "release-type": "simple",
      "package-name": "tablero"
    }
  }
}
```

Y `.release-please-manifest.json`, también en la raíz:

```json
{ ".": "0.1.0" }
```

**Verifica**: la orden de `release-please-config`:

```bash
jq -r '"type=" + .packages["."]["release-type"] + " component=" + (.["include-component-in-tag"] | tostring) + " packages=" + (.packages | length | tostring)' release-please-config.json &&
  jq -e 'has(".")' .release-please-manifest.json
# type=simple component=false packages=1
# true
```

---

## Paso 3: El job `release-please`

**Por qué**: el workflow corre en cada push a `main` y release-please decide qué toca: abrir o
actualizar el PR de release, o crear la release si el commit que llega es la fusión de ese PR.
Los permisos son los que pide su README y ninguno más: `contents` para el tag, la release y la
rama del PR; `pull-requests` para el PR; `issues` para las etiquetas `autorelease: pending` y
`autorelease: tagged`. La raíz del workflow va con `permissions: {}`. La `concurrency` sin
cancelación hace que dos pushes seguidos no se pisen el PR ni el tag: el segundo espera.

Los outputs del job se declaran ya. En la práctica 02 el job de imágenes los lee, porque la
release la crea `GITHUB_TOKEN` y eso no dispara ningún otro workflow
([teoría 01](../1-teoria/01-versionado-semantico-y-release-please.md), apartado 2). Ojo: los
outputs de release-please no están en su `action.yml`, solo en su README; `actionlint` no los
puede comprobar.

**Comando**: escribe a mano `.github/workflows/release.yml`:

```yaml
# Release de tablero: release-please mantiene un PR de release con la próxima versión y el
# CHANGELOG; al fusionarlo crea el tag y la release, y en el mismo run se publican las imágenes
# versionadas, escaneadas, con SBOM y con attestations de procedencia.
name: release
on:
  push:
    branches: [main]
# Dos releases a la vez se pisarían el PR y el tag: el segundo run espera al primero.
concurrency:
  group: release
  cancel-in-progress: false
permissions: {}
jobs:
  release-please:
    name: Release PR o release
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    permissions:
      contents: write
      pull-requests: write
      # release-please marca su PR con etiquetas "autorelease: pending/tagged".
      issues: write
    outputs:
      created: ${{ steps.release.outputs.release_created }}
      version: ${{ steps.release.outputs.version }}
      tag: ${{ steps.release.outputs.tag_name }}
    steps:
      - name: Preparar PR de release o publicar la release
        id: release
        uses: googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0
        with:
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json
```

La cabecera ya describe el workflow completo: las imágenes llegan en la práctica 02 y las
attestations en la 03.

```bash
actionlint .github/workflows/release.yml && echo ok
# ok
```

**Verifica**: las órdenes de `release-please-job` y `release-please-permissions`:

```bash
yq '"push=" + (.on.push.branches | join(",")) + " " + (.jobs."release-please".steps[] | select(.uses // "" | test("^googleapis/release-please-action@[0-9a-f]{40}$")) | .with."config-file" + " " + .with."manifest-file")' .github/workflows/release.yml
# push=main release-please-config.json .release-please-manifest.json
yq '.jobs."release-please".permissions | to_entries | map(.key + "=" + .value) | sort | join(" ")' .github/workflows/release.yml
# contents=write issues=write pull-requests=write
```

---

## Paso 4: Un commit convencional y el PR de release

**Por qué**: release-please solo abre PR si algún commit desde la última release sube versión:
`feat` sube el `MINOR`, `fix` y `deps` el `PATCH`, y `ci:`, `docs:` o `chore:` no suben nada.
Que `tablero` publique releases versionadas es una capacidad nueva del proyecto, así que el
commit es un `feat`. Como no hay ninguna release anterior, release-please lee **todo** el
historial y parte de la versión del manifest: con al menos un `feat`, propone `0.2.0` (y un `!`
en `0.x`, con `bump-minor-pre-major`, también daría `0.2.0`). Por eso el primer CHANGELOG
recoge también los `fix` de semanas anteriores.

El PR lo abre `GITHUB_TOKEN`, y los eventos que causa ese token no disparan workflows (salvo
`workflow_dispatch` y `repository_dispatch`): **el PR de release no tiene checks**. No es un
fallo; su contenido son tres archivos de texto que genera la propia herramienta. Si algún día
un ruleset exige checks en todo PR (Semana 18), ese PR necesitará el token de una GitHub App.

**Comando**:

```bash
actionlint
git add release-please-config.json .release-please-manifest.json .github/workflows/release.yml
git commit -m "feat: publish versioned releases with release-please"
git push
sleep 5
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
# release ok
pr=$(gh pr list --label "autorelease: pending" --json number --jq '.[0].number'); echo "$pr"
# 12
```

Tu número será otro. Si `pr` sale vacío, el log del run dice por qué: `gh run view "$run" --log`.

**Verifica**: qué toca el PR, qué versión propone y que no corrió nada sobre él:

```bash
gh pr diff "$pr" --name-only | sort
# .release-please-manifest.json
# CHANGELOG.md
# version.txt
branch=$(gh pr view "$pr" --json headRefName --jq .headRefName)
git fetch -q origin "$branch" && git show "origin/$branch:version.txt"
# 0.2.0
gh pr view "$pr" --json labels,statusCheckRollup --jq '"\(.labels[].name) checks=\(.statusCheckRollup | length)"'
# autorelease: pending checks=0
```

Lee el CHANGELOG del PR (`gh pr diff "$pr"`). Si el historial de semanas anteriores lo llena de
ruido, puedes editarlo en la propia rama del PR antes de fusionar: release-please respeta lo que
fusionas. Es lo único que se toca a mano.

---

## Paso 5: Fusiona el PR y mira la release

**Por qué**: la release es un acto deliberado: no sale con cada push, sale cuando fusionas el PR.
Lo fusionas tú con `gh`, con tu token, y por eso ese push a `main` sí dispara `release.yml`. En
ese run release-please ve que el commit es la fusión de su PR y crea el tag `v0.2.0` sobre él,
la release con el trozo de CHANGELOG como notas, y cambia la etiqueta a `autorelease: tagged`.
El tag y la release los crea `GITHUB_TOKEN`: ningún workflow con `on: release` o `on: push` de
tags se dispararía, y por eso las imágenes de la práctica 02 salen en este mismo run.

**Comando**:

```bash
gh pr merge "$pr" --squash --delete-branch
git switch main && git pull --ff-only
sleep 5
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
# release ok
git fetch -q --tags && git describe --tags
# v0.2.0
cat version.txt
# 0.2.0
```

**Verifica**: la release es de release-please, la orden de `release-published` y que nada se
disparó por la release:

```bash
gh release view --json tagName,author --jq '.tagName + " " + .author.login'
# v0.2.0 github-actions[bot]
git fetch -q origin main && sha=$(git rev-parse origin/main) && printf 'tag=%s release=%s\n' "$(gh release view --json tagName --jq .tagName)" "$(gh run list --workflow release.yml --commit "$sha" --json conclusion --jq '.[0].conclusion')"
# tag=v0.2.0 release=success
gh run list --event release --json databaseId --jq length
# 0
gh pr view "$pr" --json labels --jq '.labels[].name'
# autorelease: tagged
```

`check-week.sh` mira el último commit de `main`: en cuanto hagas otro push, `release-published`
mirará el run de ese commit, que también tiene que acabar en verde.

---

## ✅ Resultado

- [ ] La org y `tablero` dejan a `GITHUB_TOKEN` crear PR, con permisos por defecto de lectura
- [ ] `release-please-config.json` y `.release-please-manifest.json` en la raíz
- [ ] `release.yml` con el job `release-please`, fijado por SHA y con tres permisos de escritura
- [ ] Viste que el PR de release no tiene checks y entendiste por qué
- [ ] La release `v0.2.0` existe, la creó `github-actions[bot]` y `release.yml` está en verde

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 14
# Semana 14 — Releases, cadena de suministro y attestations  [repo: <tu-org>/tablero]
# ...
# ✅ release-please-config.json declara un único paquete en la raíz de tipo simple, ...
# ✅ release.yml corre en push a main y su job release-please usa release-please-action ...
# ...
```

Las comprobaciones de imágenes, attestations y digests siguen en rojo: son las prácticas 02 a 04.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `GitHub Actions is not permitted to create or approve pull requests.` en el log | El ajuste no está activo en el repo o la org lo prohíbe | Paso 1, primero la org y luego el repo |
| El run falla al empezar con `The action googleapis/release-please-action@... is not allowed in <tu-org>` | La lista de actions permitidas de la Semana 11 no la incluye | Paso 1, añade el patrón partiendo de la lista guardada |
| `HTTP 403` en `gh api orgs/{owner}/actions/permissions/workflow` | La sesión de `gh` no tiene `admin:org` | `gh auth refresh -h github.com -s admin:org` |
| El run acaba en verde pero no hay PR | Ningún commit desde la última release sube versión | Comprueba los tipos con `git log --oneline`; el `feat` del paso 4 basta |
| El PR propone otra versión que `0.2.0` | Había tags `v*` o el manifest no dice `0.1.0` | "Antes de empezar" y paso 2 |
| El step de release-please falla al leer la configuración | Ruta o nombre del config o del manifest mal escrito (el manifest empieza por punto) | `ls -a` en la raíz y compara con `config-file` y `manifest-file` |
| El PR de release no tiene checks | Lo abrió `GITHUB_TOKEN`, que no dispara workflows | Es lo esperado (paso 4) |
| El run de la fusión no crea release | Fusionaste con un mensaje o un método que borra la referencia al PR, o quitaste la etiqueta `autorelease: pending` | Vuelve a poner la etiqueta y relanza: `gh run rerun "$run"` |
| Tras fusionar no ves `version.txt` en local | No hiciste `git pull` | `git switch main && git pull --ff-only` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Dependency graph y dependency review](../1-teoria/07-dependency-graph-y-dependency-review.md) | [Imágenes versionadas y escaneo](02-imagenes-versionadas-y-escaneo.md) |
