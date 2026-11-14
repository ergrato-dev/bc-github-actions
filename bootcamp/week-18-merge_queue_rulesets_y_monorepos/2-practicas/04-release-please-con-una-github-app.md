# Práctica 04 — release-please con una GitHub App

> Con el ruleset de `main`, el PR de release también necesita `ci-gate` en verde. Abierto con
> `GITHUB_TOKEN`, su CI se queda esperando a que alguien lo apruebe. En esta práctica lo abre una
> GitHub App con dos permisos, instalada solo en `tablero`, y `GITHUB_TOKEN` pierde para siempre
> la capacidad de crear o aprobar PR.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- La GitHub App `tablero-release` de tu org: sin webhook, con Contents y Pull requests de
  lectura y escritura, instalada solo en `tablero`
- El environment `release`, limitado a `main`, con la clave privada como secreto y el client ID
  como variable
- `release.yml` pidiendo un token de la App, con `GITHUB_TOKEN` sin permisos en ese job
- `can_approve_pull_request_reviews=false` en la org y en el repo, con respaldo
- Una release completa: un `feat` por la cola, el PR de release abierto por la App, la cola otra
  vez y el despliegue de la Semana 17

## 📋 Antes de empezar

Terminaste la [práctica 03](03-merge-queue.md) y leíste la
[teoría 07](../1-teoria/07-bots-que-abren-pr-y-el-token-de-una-app.md). Para el despliegue del
final necesitas el laboratorio de la Semana 17 arriba (`kind-gha` y ARC), y ser propietario de la org.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
gh auth status 2>&1 | grep -q admin:org || gh auth refresh -h github.com -s admin:org
gh pr list --label "autorelease: pending" --json number,author --jq '.[] | "\(.number) \(.author.login)"'
# (sin salida)
```

Si sale un PR de `app/github-actions`, es un PR de release abierto con `GITHUB_TOKEN`: ciérralo
con `gh pr close <número> --delete-branch` y release-please abrirá otro, ya con la App. Trae
también las dos funciones de la
[práctica 04 de la Semana 17](../../week-17-despliegue_continuo_a_kubernetes/2-practicas/04-promocion-aprobacion-y-rollback.md#-antes-de-empezar):

```bash
approve() {
  local pending="repos/{owner}/{repo}/actions/runs/$1/pending_deployments"
  until [ "$(gh api "$pending" --jq length)" -gt 0 ]; do sleep 10; done
  gh api -X POST "$pending" -F "environment_ids[]=$(gh api "$pending" --jq '.[0].environment.id')" \
    -f state=approved -f comment="$2" > /dev/null
  gh run watch "$1" --exit-status > /dev/null && echo "deploy ok"
}
last_deploy() { gh run list --workflow deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId'; }
```

---

## Paso 1: La App `tablero-release`

**Por qué**: la App es una identidad propia de la org, no tuya, con un token que dura una hora
como mucho, vale solo donde está instalada y lleva solo los permisos que se piden. Es otra App
distinta de la de ARC de la Semana 16: una App, un trabajo. release-please necesita escribir en
el repo (rama, tag, release) y en los PR (abrirlos, etiquetarlos): **Contents** y **Pull
requests**, nada más. No escucha eventos, así que sin webhook
([teoría 07](../1-teoria/07-bots-que-abren-pr-y-el-token-de-una-app.md#la-app-mínima)).

**Comando**: en GitHub, **Settings de la org** → **Developer settings** → **GitHub Apps** →
**New GitHub App**:

| Campo | Valor | Por qué |
|---|---|---|
| GitHub App name | `tablero-release` | Es único en todo GitHub: si ya existe, `<tu-org>-tablero-release` |
| Homepage URL | `https://github.com/<tu-org>/tablero` | Obligatorio; no se usa para nada más |
| Webhook → Active | **Desmarcado** | La App solo emite tokens |
| Repository permissions → Contents | Read and write | Rama del PR, tag y release |
| Repository permissions → Pull requests | Read and write | Abrir, actualizar y etiquetar el PR de release |
| Repository permissions → Metadata | Read-only | GitHub lo exige junto a cualquier permiso de repo |
| Organization permissions | Todos en *No access* | La App no toca la org |
| Where can this GitHub App be installed? | Only on this account | Nadie de fuera de tu org puede instalarla |

Créala. En su página, **Install App** → tu org → **Only select repositories** → `tablero`. Después,
en la sección de claves privadas, genera una clave y muévela fuera de cualquier repo (en WSL2 tus
descargas están en `/mnt/c/Users/<tu-usuario>/Downloads`):

```bash
mkdir -p ~/.config/tablero-release && chmod 700 ~/.config/tablero-release
mv ~/Downloads/<slug-de-tu-app>.*.private-key.pem ~/.config/tablero-release/app.pem
chmod 600 ~/.config/tablero-release/app.pem
```

> ⚠️ **La clave privada solo se descarga una vez.** No hagas `cat` de ella. Si la pierdes o
> sospechas que se filtró, genera otra, actualiza el secreto del paso 2 y **después** borra la
> vieja en la página de la App: al revés, `release.yml` se quedaría sin clave válida.

**Verifica**: la App, su instalación y la clave:

```bash
APP_SLUG=<slug-de-tu-app>
gh api "apps/$APP_SLUG" --jq '"\(.owner.login) \(.permissions | to_entries | map("\(.key)=\(.value)") | join(",")) events=\(.events | length)"'
# <tu-org> contents=write,metadata=read,pull_requests=write events=0
gh api 'orgs/{owner}/installations' --jq ".installations[] | select(.app_slug == \"$APP_SLUG\") | .repository_selection"
# selected
openssl pkey -in ~/.config/tablero-release/app.pem -noout && echo pem-ok
# pem-ok
```

`selected`: no está en todos los repos. Que el único sea `tablero` lo revisa la rúbrica a mano.

---

## Paso 2: El environment `release`

**Por qué**: un secreto del repo lo puede leer cualquier workflow de cualquier rama. Un secreto
de un environment limitado a `main` solo lo ve un job que declara ese environment y corre desde
`main`: una rama con un workflow modificado no llega a la clave. El client ID no es secreto
(sale en la API pública de la App): va como variable del mismo environment. Las órdenes del
environment son las de la
[Semana 13](../../week-13-secretos_entornos_y_oidc/2-practicas/02-environments-y-reglas-de-proteccion.md);
la clave entra por la entrada estándar, sin pasar por la línea de órdenes.

**Comando**:

```bash
gh api -X PUT 'repos/{owner}/{repo}/environments/release' --input - > /dev/null \
  <<< '{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}'
gh api -X POST 'repos/{owner}/{repo}/environments/release/deployment-branch-policies' \
  -f name=main -f type=branch > /dev/null
gh secret set RELEASE_APP_PRIVATE_KEY --env release < ~/.config/tablero-release/app.pem
gh variable set RELEASE_APP_CLIENT_ID --env release --body "$(gh api "apps/$APP_SLUG" --jq .client_id)"
```

**Verifica**: la orden de `release-environment`:

```bash
printf 'branches=%s secrets=%s vars=%s\n' \
  "$(gh api 'repos/{owner}/{repo}/environments/release/deployment-branch-policies' --jq '[.branch_policies[] | .type + "/" + .name] | join(",")')" \
  "$(gh api 'repos/{owner}/{repo}/environments/release/secrets' --jq '[.secrets[].name] | join(",")')" \
  "$(gh api 'repos/{owner}/{repo}/environments/release/variables' --jq '[.variables[].name] | join(",")')"
# branches=branch/main secrets=RELEASE_APP_PRIVATE_KEY vars=RELEASE_APP_CLIENT_ID
```

---

## Paso 3: `release.yml` con el token de la App

**Por qué**: `actions/create-github-app-token` firma un JWT con la clave y lo cambia por un token
de instalación para este repo, que su paso `post` revoca al acabar el job. `permission-*` pide
menos de lo que la App tiene: si un día la App gana permisos, este token no los hereda. Con ese
token, release-please no usa `GITHUB_TOKEN`, que se queda en `permissions: {}`. Es una action de
`actions/*`: la política de la org de la Semana 11 ya la admite sin tocar la lista de actions
seleccionadas.

**Comando**: comprueba la política y crea la rama:

```bash
gh api 'orgs/{owner}/actions/permissions' --jq .allowed_actions
# selected
gh api 'orgs/{owner}/actions/permissions/selected-actions' --jq .github_owned_allowed
# true
git switch -c ci/release-app
```

En `.github/workflows/release.yml`, el job `release-please` queda así (el resto no cambia salvo
el comentario del `if:` de `images`, que pasa a `# Las imágenes salen en este mismo run, en
cuanto existe la release.`):

```yaml
  release-please:
    name: Release PR o release
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    # Todo lo escribe el token de la App: GITHUB_TOKEN no necesita nada.
    permissions: {}
    # La clave privada de la App solo existe en este environment, limitado a main.
    environment: release
    outputs:
      created: ${{ steps.release.outputs.release_created }}
      version: ${{ steps.release.outputs.version }}
      tag: ${{ steps.release.outputs.tag_name }}
    steps:
      # Un PR abierto con GITHUB_TOKEN no dispara workflows: ci-gate no llegaría nunca y el
      # ruleset no dejaría fusionarlo. Con el token de la App, el PR pasa por el CI normal.
      - name: Token de la GitHub App tablero-release
        id: app-token
        uses: actions/create-github-app-token@64ab729a6294000f5aa4a4bc0b73d1f32bc45510 # v3.3.0
        with:
          client-id: ${{ vars.RELEASE_APP_CLIENT_ID }}
          private-key: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
          permission-contents: write
          # release-please etiqueta su PR con "autorelease: pending/tagged".
          permission-pull-requests: write
      - name: Preparar PR de release o publicar la release
        id: release
        uses: googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0
        with:
          token: ${{ steps.app-token.outputs.token }}
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json
```

```bash
actionlint && GH_TOKEN=$(gh auth token) zizmor -q .github/ && echo limpio
# limpio
git commit -am "ci(release): open release PRs with the tablero-release app"
git push -u origin ci/release-app
gh pr create --fill
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch --required > /dev/null && gh pr merge "$pr"
until [ "$(gh pr view "$pr" --json state --jq .state)" = MERGED ]; do sleep 15; done
git switch main && git pull --ff-only && sleep 10
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
# release ok
```

Ese run no publica nada (un `ci:` no es una versión), pero ya pidió el token: si la clave o el
client ID estuvieran mal, el step `Token de la GitHub App tablero-release` habría fallado.

**Verifica**: lo que mira `release-app-token`, en dos órdenes:

```bash
yq -o=json '.jobs."release-please"' .github/workflows/release.yml | jq -r '"perms=\(.permissions | tojson) env=\(.environment) token=\(.steps[] | select(.uses // "" | startswith("googleapis/")) | .with.token)"'
# perms={} env=release token=${{ steps.app-token.outputs.token }}
yq '.jobs."release-please".steps[0].with | to_entries | .[] | .key + "=" + .value' .github/workflows/release.yml
# client-id=${{ vars.RELEASE_APP_CLIENT_ID }}
# private-key=${{ secrets.RELEASE_APP_PRIVATE_KEY }}
# permission-contents=write
# permission-pull-requests=write
```

---

## Paso 4: `GITHUB_TOKEN` ya no crea ni aprueba PR

**Por qué**: en la Semana 14 abriste `can_approve_pull_request_reviews` para que release-please
creara su PR con `GITHUB_TOKEN`. El mismo ajuste le deja **aprobar** PR, y la API lo describe
como un riesgo. Ya no lo necesitas: lo cierras en la org y en el repo. Con eso,
`org-default-token-read` de la Semana 11 vuelve a verde.

> ⚠️ **Cambias una política de toda la organización.** Primero guardas la actual de la org y la
> del repo; para volver atrás, el `PUT` con los valores de esos archivos.

**Comando**:

```bash
mkdir -p ~/code/org-policy-backup
gh api 'orgs/{owner}/actions/permissions/workflow' > ~/code/org-policy-backup/workflow-s18.json
gh api 'repos/{owner}/{repo}/actions/permissions/workflow' > ~/code/org-policy-backup/repo-workflow-s18.json
jq -r '"\(.default_workflow_permissions) approve_prs=\(.can_approve_pull_request_reviews)"' ~/code/org-policy-backup/workflow-s18.json
# read approve_prs=true
gh api -X PUT 'orgs/{owner}/actions/permissions/workflow' \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
gh api -X PUT 'repos/{owner}/{repo}/actions/permissions/workflow' \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
```

**Verifica**: la orden de `actions-cannot-approve` y la comprobación de la Semana 11:

```bash
printf 'org=%s repo=%s\n' \
  "$(gh api 'orgs/{owner}/actions/permissions/workflow' --jq .can_approve_pull_request_reviews)" \
  "$(gh api 'repos/{owner}/{repo}/actions/permissions/workflow' --jq .can_approve_pull_request_reviews)"
# org=false repo=false
(cd ~/code/bc-github-actions && ./scripts/check-week.sh 11 | grep 'no puede aprobar')
#   ✅ El GITHUB_TOKEN de la organización es de solo lectura por defecto y no puede aprobar pull requests
```

---

## Paso 5: Una release de punta a punta

**Por qué**: es la prueba de que todo encaja. Un `feat` entra por la cola; en el push a `main`,
`release.yml` abre el PR de release **con la App**; su `ci` corre solo, sin aprobar nada a mano;
`ci-gate` pasa; el PR entra por la cola; el push crea la release, las imágenes y lanza
`deploy.yml`, que despliega en staging y espera tu aprobación para production como en la
Semana 17.

**Comando**: en una rama nueva (`git switch -c feat/version-endpoint`), un endpoint pequeño con
su test. En `api/src/tablero/main.py`, debajo de `health`:

```python
@app.get("/api/version")
def version() -> dict[str, str]:
    return {"version": app_version()}
```

Y en `api/tests/unit/test_api.py`:

```python
def test_version_endpoint(client, monkeypatch):
    monkeypatch.setenv("APP_VERSION", "9.9.9")
    response = client.get("/api/version")
    assert response.status_code == 200
    assert response.json() == {"version": "9.9.9"}
```

```bash
(cd api && uv run --locked pytest tests/unit -q -k version_endpoint | tail -1)
# 1 passed, <n> deselected in <t>s
git commit -am "feat(api): add version endpoint"
git push -u origin feat/version-endpoint
gh pr create --fill
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch --required > /dev/null && gh pr merge "$pr"
until [ "$(gh pr view "$pr" --json state --jq .state)" = MERGED ]; do sleep 15; done
git switch main && git pull --ff-only && sleep 10
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
# release ok
rp=$(gh pr list --label "autorelease: pending" --json number --jq '.[0].number')
gh pr view "$rp" --json author --jq .author.login
# app/<slug-de-tu-app>
gh pr checks "$rp" --watch --required > /dev/null; gh pr checks "$rp" --required
# ci-gate	pass	<duración>	https://github.com/<tu-org>/tablero/actions/runs/<run-id>/job/<job-id>
```

El PR es de la App y `ci-gate` llegó solo. Mételo en la cola y sigue la release hasta production:

```bash
gh pr merge "$rp"
until [ "$(gh pr view "$rp" --json state --jq .state)" = MERGED ]; do sleep 15; done
git pull --ff-only && sleep 10
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
# release ok
gh run view "$run" --json jobs --jq '.jobs[] | .name + " " + .conclusion' | sort
# Imagen tablero-api success
# Imagen tablero-web success
# Lanzar el despliegue success
# Release PR o release success
sleep 5; approve "$(last_deploy)" "Release de la capa 18"
# deploy ok
```

**Verifica**: la orden de `release-pr-by-app` y quién publicó la release:

```bash
gh pr list --state merged --label 'autorelease: tagged' --limit 1 --json author --jq '.[0].author.login'
# app/<slug-de-tu-app>
sha=$(gh pr list --state merged --label 'autorelease: tagged' --limit 1 --json headRefOid --jq '.[0].headRefOid')
gh api "repos/{owner}/{repo}/commits/$sha/check-runs?check_name=ci-gate" --jq '[.check_runs[].conclusion] | first'
# success
gh release view --json tagName,author --jq '"\(.tagName) \(.author.login)"'
# v<X.Y.Z> <slug-de-tu-app>[bot]
```

---

## ✅ Resultado

- [ ] La App `tablero-release`: sin webhook, Contents y Pull requests en escritura, instalada solo en `tablero`
- [ ] La clave privada en `~/.config/tablero-release/app.pem` (`600`) y en el environment `release`, limitado a `main`
- [ ] `release.yml` con el token de la App y `permissions: {}` en el job `release-please`
- [ ] `can_approve_pull_request_reviews=false` en la org y en el repo, con el respaldo guardado
- [ ] Una release cuyo PR abrió la App, que pasó `ci-gate` y la cola, desplegada en production

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 18
# ...
#   ✅ El último PR de release lo abrió la GitHub App, no GITHUB_TOKEN, y ci-gate corrió en verde sobre él
#
# 18/18 comprobaciones superadas.
```

Si `merged-through-queue` sale en rojo, el `ci` del push de la release aún no ha terminado.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El step del token falla al pedir la instalación | La App no está instalada en `tablero` | Paso 1: **Install App** con `tablero` seleccionado |
| El step del token falla con la clave | El secreto no es el `.pem` completo o es de otra App | Repite el `gh secret set` del paso 2 con el archivo |
| `client-id` o `private-key` llegan vacíos | Secreto o variable en el repo y no en `release`, o falta `environment: release` | Paso 2 y el job del paso 3 |
| El job no arranca: action no permitida | La política de la org no admite `actions/*` | `github_owned_allowed` tiene que valer `true` (Semana 11) |
| El PR de release sigue siendo de `app/github-actions` | Quedó abierto el PR antiguo y release-please lo actualiza | Ciérralo con `--delete-branch`; el próximo push lo reabre la App |
| `gh run list --status action_required` muestra el PR de release | release-please sigue con `GITHUB_TOKEN` | Falta `token: ${{ steps.app-token.outputs.token }}` |
| `HTTP 403` en el `PUT` de la org | El token de `gh` no tiene `admin:org` | `gh auth refresh -h github.com -s admin:org` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Merge queue](03-merge-queue.md) | [Capa 18 de tablero](../3-proyecto/README.md) |
