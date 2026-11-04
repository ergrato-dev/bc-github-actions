# Práctica 03 — Políticas de la organización

> En la Semana 01 ajustaste los permisos de Actions de **un repo**. Un repo nuevo de tu
> organización no hereda esos ajustes: nace con lo que diga la org. En esta práctica fijas,
> para toda la org, qué actions se ejecutan, que vayan por SHA y con qué token por defecto.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- La org en `allowed_actions=selected` con `sha_pinning_required=true`
- Una lista explícita de patrones con las seis actions de terceros que usa `tablero`
- El `GITHUB_TOKEN` por defecto de solo lectura y sin poder aprobar pull requests
- El CI de `tablero` y de `actions-tablero` en verde con las políticas activas, y un run que
  la política corta a propósito

## 📋 Antes de empezar

Terminaste la [práctica 02](02-consumir-el-repo-central.md): `tablero` consume
`actions-tablero` y todo su `main` está en verde. Eres propietario (owner) de la organización.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
gh api orgs/{owner} --jq .login
# <tu-org>
```

Con `GH_REPO` exportado, `gh` sustituye `{owner}` también en las rutas de organización
([teoría 06](../1-teoria/06-politicas-de-actions-de-la-organizacion.md)).

---

## Paso 1: Permiso para leer las políticas y foto del estado actual

**Por qué**: los endpoints de políticas de Actions de la org piden el scope `admin:org` en el
token de `gh`. Sin él responden HTTP 403 con "You must be an org admin or have the actions
policies fine-grained permission.". Antes de cambiar nada guardas lo que hay: es lo que
restaurarías si algo sale mal.

**Comando**:

```bash
gh auth refresh -h github.com -s admin:org
mkdir -p ~/code/org-policy-backup
gh api orgs/{owner}/actions/permissions > ~/code/org-policy-backup/permissions.json
gh api orgs/{owner}/actions/permissions/workflow > ~/code/org-policy-backup/workflow.json
```

**Verifica**: lees las dos políticas sin 403. En una org nueva verás algo como esto:

```bash
jq -r '"\(.enabled_repositories) \(.allowed_actions) sha_pinning_required=\(.sha_pinning_required)"' \
  ~/code/org-policy-backup/permissions.json
# all all sha_pinning_required=false
jq -r '"\(.default_workflow_permissions) approve_prs=\(.can_approve_pull_request_reviews)"' \
  ~/code/org-policy-backup/workflow.json
# read approve_prs=false
```

Si tus valores son otros, apúntalos: son los que usarías para volver atrás.

---

## Paso 2: Solo actions seleccionadas, y por SHA

**Por qué**: con `all`, cualquier repo de la org puede ejecutar cualquier action de cualquiera.
Con `selected` entran las de la propia org (`actions-tablero`, y también `./` y `$/`) y, de
fuera, solo lo que pongas en la lista del paso 3. `local_only` sería más estricto pero deja
fuera hasta `actions/checkout`. Con `sha_pinning_required`, una action por tag no se ejecuta
en ningún repo, aunque ese repo lo permitiera: un repo nunca es más permisivo que su org.

> ⚠️ **Cambias una política de toda la organización.** Entre este paso y el siguiente, la lista
> de actions de fuera está vacía: no hagas push ni lances workflows hasta terminar el paso 3.
> Para volver atrás, el `PUT` inverso con los valores de tu foto del paso 1:
> `gh api -X PUT orgs/{owner}/actions/permissions -f enabled_repositories=all -f allowed_actions=all -F sha_pinning_required=false`

**Comando**: el `PUT` exige `enabled_repositories` aunque no lo cambies; `-F` manda `true` como
booleano JSON y `-f`, como texto:

```bash
gh api -X PUT orgs/{owner}/actions/permissions \
  -f enabled_repositories=all -f allowed_actions=selected -F sha_pinning_required=true
```

Responde `204` sin cuerpo: no verás salida.

**Verifica**: la orden de `org-allowed-actions`:

```bash
gh api orgs/{owner}/actions/permissions --jq '"\(.allowed_actions) sha_pinning_required=\(.sha_pinning_required)"'
# selected sha_pinning_required=true
```

---

## Paso 3: La lista de patrones

**Por qué**: la lista solo existe con `allowed_actions=selected` (por eso va después del paso 2),
y cada `PUT` la **sustituye entera**. `github_owned_allowed` abre las de GitHub (`actions/*`);
`verified_allowed` abriría todo el Marketplace verificado, y "verificado" dice quién publica, no
qué hace cada versión: queda en `false`. El resto son las seis actions de terceros que usan
`tablero` y `actions-tablero`, una a una. `docker/*` sería más corto, pero dejaría entrar
cualquier action nueva de `docker` sin que nadie la revise.

**Comando**: localiza primero qué usas de fuera, en los dos repos:

```bash
cat .github/workflows/*.yml ~/code/actions-tablero/*/action.yml ~/code/actions-tablero/.github/workflows/*.yml \
  | grep -oE 'uses: [a-z0-9-]+/[a-z0-9-]+' | sed 's/uses: //' | grep -vE '^(actions|<tu-org>)/' | sort -u
# astral-sh/setup-uv
# docker/build-push-action
# docker/login-action
# docker/metadata-action
# docker/setup-buildx-action
# pnpm/action-setup
```

Cambia `<tu-org>` en el `grep` por el nombre de tu org. Después, la lista:

```bash
gh api -X PUT orgs/{owner}/actions/permissions/selected-actions \
  -F github_owned_allowed=true -F verified_allowed=false \
  -f 'patterns_allowed[]=astral-sh/setup-uv@*' \
  -f 'patterns_allowed[]=pnpm/action-setup@*' \
  -f 'patterns_allowed[]=docker/metadata-action@*' \
  -f 'patterns_allowed[]=docker/setup-buildx-action@*' \
  -f 'patterns_allowed[]=docker/login-action@*' \
  -f 'patterns_allowed[]=docker/build-push-action@*'
```

`@*` admite cualquier versión del repo nombrado; que la versión vaya por SHA ya lo exige el
paso 2.

**Verifica**: la orden de `org-selected-actions`, y la lista tal como la guardó GitHub:

```bash
gh api orgs/{owner}/actions/permissions/selected-actions \
  --jq '"github=\(.github_owned_allowed) verified=\(.verified_allowed) patterns=\(.patterns_allowed | length)"'
# github=true verified=false patterns=6
gh api orgs/{owner}/actions/permissions/selected-actions --jq '.patterns_allowed | sort | .[]'
# astral-sh/setup-uv@*
# docker/build-push-action@*
# docker/login-action@*
# docker/metadata-action@*
# docker/setup-buildx-action@*
# pnpm/action-setup@*
```

---

## Paso 4: Token de solo lectura y sin aprobar pull requests

**Por qué**: un workflow sin bloque `permissions:` recibe el token por defecto de la org.
Con `read`, ese descuido no da escritura; tus workflows ya declaran `permissions:` en la raíz,
pero la política protege a los que escriba otro. `can_approve_pull_request_reviews=false`
impide que un workflow cree o apruebe un PR y se salte así la revisión humana. Una org nueva ya
viene así: lo fijas para que conste y para que lo sepas restaurar. Con qué permisos corre cada
job y por qué lo verás a fondo en la Semana 12.

> ⚠️ **Política de toda la organización.** Para volver atrás, el `PUT` con los valores de
> `~/code/org-policy-backup/workflow.json`; por ejemplo
> `gh api -X PUT orgs/{owner}/actions/permissions/workflow -f default_workflow_permissions=write -F can_approve_pull_request_reviews=true`
> si así estaba.

**Comando**:

```bash
gh api -X PUT orgs/{owner}/actions/permissions/workflow \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
```

**Verifica**: la orden de `org-default-token-read`:

```bash
gh api orgs/{owner}/actions/permissions/workflow \
  --jq '"\(.default_workflow_permissions) approve_prs=\(.can_approve_pull_request_reviews)"'
# read approve_prs=false
```

---

## Paso 5: El CI sigue en verde, y la política corta lo que debe

**Por qué**: una política que nadie ha visto actuar es una suposición. Primero compruebas que
todo lo legítimo sigue pasando: los dos repos, sobre su último commit, con las políticas ya
activas. Después rompes una regla a propósito en una rama de prueba, para ver el fallo una vez
en un sitio sin consecuencias y reconocerlo cuando aparezca de verdad.

**Comando**: relanza los workflows de `main` con `workflow_dispatch` (todos lo tienen):

```bash
for w in ci ci-api ci-web; do gh workflow run "$w.yml" --ref main; done
gh workflow run ci.yml --ref main -R <tu-org>/actions-tablero
```

Espera a que terminen y comprueba la conclusión del último run de cada uno:

```bash
for w in ci ci-api ci-web; do
  id=$(gh run list --workflow "$w.yml" --branch main --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')
  gh run watch "$id" --exit-status > /dev/null && echo "$w ok"
done
# ci ok
# ci-api ok
# ci-web ok
```

Si `gh run list` no devuelve nada aún, espera unos segundos: el run tarda en aparecer.

Ahora el fallo provocado. En una rama, cambia el primer checkout de `ci.yml` a una referencia
por tag, que `sha_pinning_required` no admite:

```bash
git switch -c test/org-policy
sed -i -E '0,/actions\/checkout@[0-9a-f]{40} # (v[0-9.]+)/s//actions\/checkout@\1/' .github/workflows/ci.yml
grep -c 'actions/checkout@v' .github/workflows/ci.yml
# 1
git commit -am "test: unpinned checkout to see the org policy" && git push -u origin test/org-policy
gh workflow run ci.yml --ref test/org-policy
```

**Verifica**: los cuatro de `main` en verde (lo hiciste arriba, más `actions-tablero`), y el de
la rama de prueba sin terminar en `success`:

```bash
gh run list --workflow ci.yml -R <tu-org>/actions-tablero --event workflow_dispatch --limit 1 --json conclusion --jq '.[0].conclusion'
# success
id=$(gh run list --workflow ci.yml --branch test/org-policy --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" > /dev/null
gh run view "$id" --json conclusion --jq '.conclusion != "success"'
# true
```

Abre el run (`gh run view "$id" --web`) y lee el motivo: dice qué referencia no está fijada. El
texto exacto lo pone GitHub y puede cambiar; lo importante es que el job no llegó a ejecutar la
action.

> ⚠️ **Borra la rama de prueba**: es lo único que queda roto a propósito. No toca `main`; si la
> quisieras recuperar, el commit sigue en tu reflog local (`git reflog`).

```bash
git switch main
git push origin --delete test/org-policy && git branch -D test/org-policy
git branch -a --list '*org-policy*' | wc -l
# 0
```

---

## ✅ Resultado

- [ ] Tienes la foto de las políticas anteriores en `~/code/org-policy-backup/`
- [ ] La org solo admite actions seleccionadas, por SHA completo
- [ ] La lista tiene las actions de GitHub y seis patrones, sin creadores verificados
- [ ] El token por defecto es de lectura y no aprueba pull requests
- [ ] `tablero` y `actions-tablero` siguen en verde; viste cómo la política corta un `@v7`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 11
# ✅ La organización solo permite actions seleccionadas y exige fijarlas por SHA completo
# ✅ La lista de la organización admite las actions de GitHub y una lista de patrones explícita, sin abrir la puerta a todo creador verificado
# ✅ El GITHUB_TOKEN de la organización es de solo lectura por defecto y no puede aprobar pull requests
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| HTTP 403 "You must be an org admin or have the actions policies fine-grained permission." | El token de `gh` no tiene `admin:org`, o no eres owner de la org | Paso 1: `gh auth refresh -h github.com -s admin:org` |
| El `PUT` de `permissions` falla | Falta `enabled_repositories` | Es obligatorio en ese `PUT`: `-f enabled_repositories=all` |
| El `PUT` de `selected-actions` falla | `allowed_actions` no es `selected`: la lista solo existe con esa política | Repite el paso 2 y después el 3 |
| El `PUT` de un booleano falla o no lo cambia | Usaste `-f`, que lo manda como texto | `-F` para `true`/`false` |
| `ci-api` o `ci-web` fallan antes del primer step: action no permitida | Falta su patrón, o lo escribiste sin `@*` | Añádelo y repite el `PUT` completo: sustituye la lista entera |
| `actions-tablero` falla en `zizmor` antes de empezar | `astral-sh/setup-uv@*` no está en la lista | Paso 3 |
| El run de `test/org-policy` termina en `success` | `sha_pinning_required` sigue en `false` | Paso 2 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Consumir el repo central](02-consumir-el-repo-central.md) | [Workflow templates](04-workflow-templates.md) |
