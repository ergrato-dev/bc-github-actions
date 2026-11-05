# Práctica 03 — El token OIDC y sus claims

> Un token OIDC es una frase firmada por GitHub sobre quién lo pide. Antes de confiar en él,
> léelo: en esta práctica sacas los claims de tus propios tokens sin imprimir nunca el token,
> cambias la frase para que diga también qué workflow lo pidió y guardas en cada environment la
> frase exacta que aceptará.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Un workflow temporal, `oidc-claims.yml`, que enseña los claims y nunca el token
- `id-token: write` en los dos jobs de `deploy-gate.yml`, y en ningún otro sitio
- El `sub` de `tablero` personalizado con `repo`, `context` y `job_workflow_ref`
- La variable `OIDC_SUB` de cada environment con el `sub` exacto que espera

## 📋 Antes de empezar

Terminaste la [práctica 02](02-environments-y-reglas-de-proteccion.md) y leíste la
[teoría 04](../1-teoria/04-de-credenciales-estaticas-a-oidc.md), la
[teoría 05](../1-teoria/05-el-token-oidc-y-sus-claims.md) y la
[teoría 06](../1-teoria/06-politica-de-confianza-y-sub-personalizado.md).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
git status --short | wc -l
# 0
```

Cada push a `main` lanza `deploy-gate`, y production se queda esperando tu aprobación. En esta
práctica no lo necesitas: después de cada push, cancela lo que espere.

```bash
gh run list --workflow deploy-gate.yml --status waiting --json databaseId --jq '.[].databaseId' |
  xargs -r -n1 gh run cancel
```

---

## Paso 1: Los claims de un job sin environment

**Por qué**: la teoría describe los claims; tu token los tiene de verdad, con los ids reales de
tu org y de tu repo. `oidc-claims.yml` pide un token en cada job y separa la parte central del
JWT, el payload, que no está cifrado: es JSON en base64url. La firma se queda en el pipe y no
llega al log. Solo se escriben claims, que no son secretos; el token sí lo es, porque mientras
no caduca vale como identidad.

`curl` lleva `-f` para fallar con un HTTP de error, y el shell explícito trae `pipefail`: si la
petición falla, el step falla en lugar de decodificar una cadena vacía.

**Comando**: escribe a mano `.github/workflows/oidc-claims.yml`:

```yaml
# Temporal: enseña los claims del token OIDC de un job sin enseñar nunca el token.
# Se borra en el paso 7.
name: oidc-claims
on:
  workflow_dispatch:
permissions: {}
defaults:
  run:
    shell: bash
jobs:
  no-environment:
    name: Sin environment
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    permissions:
      id-token: write
    steps:
      - name: Claims con la audiencia por defecto
        run: |
          # El token va de curl a cut por el pipe: solo sale el payload, sin firma.
          payload=$(curl -sSf -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
              "$ACTIONS_ID_TOKEN_REQUEST_URL" |
            jq -r .value | cut -d. -f2 | tr '_-' '/+')
          # base64url quita el relleno; base64 -d lo necesita.
          while (( ${#payload} % 4 )); do payload+="="; done
          claims=$(base64 -d <<<"$payload")
          jq -r '{sub, aud, environment, job_workflow_ref, repository_owner_id, repository_id}
            | to_entries[] | "\(.key)=\(.value)"' <<<"$claims"
          { echo '```json'; jq . <<<"$claims"; echo '```'; } >> "$GITHUB_STEP_SUMMARY"

  staging:
    name: Con environment staging
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    environment: staging
    permissions:
      id-token: write
    steps:
      - name: Claims con la audiencia tablero-verifier
        env:
          AUDIENCE: tablero-verifier
        run: |
          payload=$(curl -sSf -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
              "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=$AUDIENCE" |
            jq -r .value | cut -d. -f2 | tr '_-' '/+')
          while (( ${#payload} % 4 )); do payload+="="; done
          claims=$(base64 -d <<<"$payload")
          jq -r '{sub, aud, environment, job_workflow_ref, repository_owner_id, repository_id}
            | to_entries[] | "\(.key)=\(.value)"' <<<"$claims"
          { echo '```json'; jq . <<<"$claims"; echo '```'; } >> "$GITHUB_STEP_SUMMARY"
```

El resumen de cada job tiene el payload completo; `claims` lanza el workflow y filtra del log
los seis claims de cada job:

```bash
actionlint
git add .github/workflows/oidc-claims.yml
git commit -m "ci: add temporary oidc claims workflow"
git push
claims() {
  gh workflow run oidc-claims.yml --ref main && sleep 5
  local id
  id=$(gh run list --workflow oidc-claims.yml --limit 1 --json databaseId --jq '.[0].databaseId')
  gh run watch "$id" --exit-status > /dev/null
  gh run view "$id" --log | awk -F'\t' \
    'match($3, /(sub|aud|environment|job_workflow_ref|repository_owner_id|repository_id)=[^ $"]+$/) { print $1 ": " substr($3, RSTART) }'
}
before=$(claims)
grep '^Sin environment' <<<"$before"
```

Lo que esperas ver, con tus ids numéricos. Un repo creado después del 15 de julio de 2026 usa el
formato inmutable, con `@<id>` detrás de la org y del repo; uno anterior, el clásico
`repo:<tu-org>/tablero:...`, salvo que se activara el inmutable:

```bash
# Sin environment: sub=repo:<tu-org>@<id-org>/tablero@<id-repo>:ref:refs/heads/main
# Sin environment: aud=https://github.com/<tu-org>
# Sin environment: environment=null
# Sin environment: job_workflow_ref=<tu-org>/tablero/.github/workflows/oidc-claims.yml@refs/heads/main
# Sin environment: repository_owner_id=<id-org>
# Sin environment: repository_id=<id-repo>
```

**Verifica**: sin environment, el `sub` termina en la rama:

```bash
grep -cE '^Sin environment: sub=repo:.*:ref:refs/heads/main$' <<<"$before"
# 1
```

---

## Paso 2: `id-token: write` en los dos jobs de `deploy-gate`

**Por qué**: sin ese permiso el runner no define `ACTIONS_ID_TOKEN_REQUEST_URL` ni
`ACTIONS_ID_TOKEN_REQUEST_TOKEN`, y el job no puede pedir un token. El permiso solo deja
**pedirlo**: no da acceso a nada ni escribe en el repo. Aun así va por job y nunca en la raíz:
un job que no lo necesita no debe poder presentarse ante una nube con la identidad del repo.

**Comando**: en `.github/workflows/deploy-gate.yml`, los permisos de `staging` quedan así:

```yaml
    permissions:
      contents: read
      # Solo deja pedir el token OIDC; no da acceso a nada por sí mismo.
      id-token: write
```

Y los de `production`, igual pero sin repetir el comentario:

```yaml
    permissions:
      contents: read
      id-token: write
```

```bash
actionlint
git commit -am "ci: allow deploy gate jobs to request oidc tokens"
git push
```

**Verifica**: la orden de `id-token-scoped`. Hasta el paso 7 sale también `oidc-claims.yml`:

```bash
yq -N '(select(.permissions."id-token" == "write") | filename + ":raíz"), (.jobs | to_entries | .[] | select(.value.permissions."id-token" == "write") | filename + ":" + .key)' \
  .github/workflows/*.yml | sed 's#.*/##' | sort | tr '\n' ' '; echo
# deploy-gate.yml:production deploy-gate.yml:staging oidc-claims.yml:no-environment oidc-claims.yml:staging
```

---

## Paso 3: Con environment, y con tu audiencia

**Por qué**: el job `staging` de `oidc-claims` declara `environment: staging` y pide el token con
`audience=tablero-verifier`. Las dos cosas cambian el token. Con environment, el `sub` ya no
dice la rama sino el environment: la política de confianza puede atar una credencial a
production y no a "cualquier job de `main`". Y la audiencia por defecto es la URL de tu org, la
misma para cualquier consumidor: si dos servicios aceptan esa audiencia, un token pedido para
uno vale para el otro. Una audiencia propia por consumidor lo evita.

**Comando**: no hace falta otro run, el del paso 1 tenía los dos jobs:

```bash
grep '^Con environment staging' <<<"$before"
```

Lo que esperas ver:

```bash
# Con environment staging: sub=repo:<tu-org>@<id-org>/tablero@<id-repo>:environment:staging
# Con environment staging: aud=tablero-verifier
# Con environment staging: environment=staging
# Con environment staging: job_workflow_ref=<tu-org>/tablero/.github/workflows/oidc-claims.yml@refs/heads/main
# ...
```

**Verifica**: el `sub` termina en el environment y la audiencia es la pedida:

```bash
grep -cE '^Con environment staging: (sub=repo:.*:environment:staging|aud=tablero-verifier)$' <<<"$before"
# 2
```

---

## Paso 4: Por qué un PR nunca llega a este token

**Por qué**: un `pull_request` sin environment produce un `sub` que termina en `:pull_request`,
sin rama ni environment. Una política que acepte `repo:<tu-org>/tablero:*` le daría la
credencial a cualquier PR, incluido uno de un fork si alguien relaja los permisos. No hace falta
ejecutarlo: `deploy-gate` ni siquiera escucha `pull_request`, y ese es el primer cierre. El
segundo es que el verificador exige el `sub` exacto, sin comodines (práctica 04).

**Comando**: los eventos que escucha `deploy-gate`:

```bash
yq -o json '.on' .github/workflows/deploy-gate.yml
```

**Verifica**: ni `pull_request` ni `pull_request_target`, y el push solo desde `main`:

```bash
yq '.on | keys | join(",")' .github/workflows/deploy-gate.yml
# push,workflow_dispatch
yq '.on.push.branches | join(",")' .github/workflows/deploy-gate.yml
# main
```

---

## Paso 5: El `sub` dice también qué workflow lo pidió

**Por qué**: con el `sub` por defecto, `oidc-claims.yml` y `deploy-gate.yml` reciben en `staging`
exactamente el mismo `sub`. Cualquier workflow del repo que declare el environment se hace
pasar por el de despliegue. La plantilla `repo`, `context` y `job_workflow_ref` añade al `sub`
el workflow que pidió el token, con su ref: ahora son frases distintas. `context` es la parte
que ya conoces (`environment:staging`, `ref:refs/heads/main` o `pull_request`).

La plantilla vale para todos los tokens del repo desde el siguiente: una nube que confiara en el
`sub` antiguo dejaría de aceptarlo. Se cambia antes de crear las políticas.

**Comando**:

```bash
gh api -X PUT 'repos/{owner}/{repo}/actions/oidc/customization/sub' --input - > /dev/null \
  <<< '{"use_default":false,"include_claim_keys":["repo","context","job_workflow_ref"]}'
after=$(claims)
grep ': sub=' <<<"$after"
```

Lo que esperas ver. La documentación no publica el ejemplo inmutable con plantilla: lo que vale
es lo que firma GitHub para tu repo, y por eso lo copias del token en el paso 6:

```bash
# Sin environment: sub=repo:<tu-org>@<id-org>/tablero@<id-repo>:ref:refs/heads/main:job_workflow_ref:<tu-org>/tablero/.github/workflows/oidc-claims.yml@refs/heads/main
# Con environment staging: sub=repo:<tu-org>@<id-org>/tablero@<id-repo>:environment:staging:job_workflow_ref:<tu-org>/tablero/.github/workflows/oidc-claims.yml@refs/heads/main
```

**Verifica**: la orden de `oidc-sub-template`:

```bash
gh api 'repos/{owner}/{repo}/actions/oidc/customization/sub' \
  --jq '"default=" + (.use_default | tostring) + " keys=" + ((.include_claim_keys // []) | join(","))'
# default=false keys=repo,context,job_workflow_ref
```

---

## Paso 6: `OIDC_SUB`, el `sub` que acepta cada environment

**Por qué**: el verificador de la práctica 04 compara el `sub` del token con uno esperado, por
igualdad exacta. Ese valor no es secreto, así que va en una **variable** de environment: la lees,
la auditas y cada job recibe la de su environment con `vars.OIDC_SUB`. Lo sacas del token real
de `oidc-claims` y cambias solo lo que debe cambiar: el workflow, que será `deploy-gate.yml`, y
para production, el environment. Fíjate en que `oidc-claims.yml` nunca podrá presentar ese `sub`:
es justo lo que el paso 5 buscaba.

**Comando**:

```bash
sub=$(grep -oE 'Con environment staging: sub=.*' <<<"$after" | cut -d= -f2-)
staging_sub=${sub/oidc-claims.yml/deploy-gate.yml}
production_sub=${staging_sub/:environment:staging:/:environment:production:}
printf '%s\n%s\n' "$staging_sub" "$production_sub"
gh variable set OIDC_SUB --env staging --body "$staging_sub"
gh variable set OIDC_SUB --env production --body "$production_sub"
```

**Verifica**: la orden de `oidc-sub-vars`:

```bash
for e in staging production; do v=$(gh variable list --env "$e" --json name,value --jq '.[] | select(.name == "OIDC_SUB") | .value'); grep -qE "^repo:[^:]+/tablero[^:]*:environment:$e:job_workflow_ref:[^:]+/tablero/\.github/workflows/deploy-gate\.yml@refs/heads/main$" <<<"$v" && printf '%s=ok ' "$e" || printf '%s=mal ' "$e"; done; echo
# staging=ok production=ok
```

---

## Paso 7: Borrar `oidc-claims.yml`

**Por qué**: es un workflow con `id-token: write` que cualquiera con permiso de escritura puede
lanzar. Cumplió su papel, y mientras exista, `id-token-scoped` y `writes-only-where-needed`
siguen en rojo.

> ⚠️ **Vas a borrar `.github/workflows/oidc-claims.yml`.** Antes, comprueba que el paso 6 está en
> verde: después ya no tendrás de dónde sacar el `sub`. El archivo queda en el historial de Git.

**Comando**:

```bash
git rm .github/workflows/oidc-claims.yml
git commit -m "ci: remove temporary oidc claims workflow"
git push
```

**Verifica**: las órdenes de `id-token-scoped` y `writes-only-where-needed`:

```bash
yq -N '(select(.permissions."id-token" == "write") | filename + ":raíz"), (.jobs | to_entries | .[] | select(.value.permissions."id-token" == "write") | filename + ":" + .key)' \
  .github/workflows/*.yml | sed 's#.*/##' | sort | tr '\n' ' '; echo
# deploy-gate.yml:production deploy-gate.yml:staging
yq -N '.jobs | to_entries | .[] | .value.permissions // {} | to_entries | .[] | select(.value == "write") | (filename | sub(".*/"; "")) + ":" + .key' \
  .github/workflows/*.yml | sort -u | tr '\n' ' '; echo
# codeql.yml:security-events deploy-gate.yml:id-token images.yml:packages labeler.yml:pull-requests nightly.yml:actions pr-report.yml:pull-requests
```

---

## ✅ Resultado

- [ ] Leíste tus claims sin imprimir el token: `sub`, `aud`, `job_workflow_ref` e ids
- [ ] Sabes cómo cambian el `sub` y el `aud` con un environment y con una audiencia propia
- [ ] `id-token: write` solo en los jobs `staging` y `production` de `deploy-gate.yml`
- [ ] El `sub` de `tablero` lleva `repo`, `context` y `job_workflow_ref`
- [ ] `OIDC_SUB` en cada environment, sacado del token real
- [ ] `oidc-claims.yml` borrado

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 13
# ✅ Solo los jobs staging y production de deploy-gate.yml piden id-token: write
# ✅ Solo escriben codeql (security-events), deploy-gate (id-token), images (packages), labeler y pr-report (pull-requests) y nightly (actions); ningún write-all ni read-all
# ✅ El sub del token OIDC de tablero usa la plantilla repo, context y job_workflow_ref
# ✅ Cada environment guarda en la variable OIDC_SUB el sub exacto que acepta: su environment y deploy-gate.yml en main
# ...
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `curl: (6) Could not resolve host: &audience=tablero-verifier` | El job no tiene `id-token: write` | Permiso en el job, no en la raíz |
| `base64: invalid input` | Falta el relleno o el cambio de `_-` por `/+` | Copia el `while` y el `tr` del paso 1 |
| `claims` no imprime nada | El run falló o el patrón de `awk` está mal copiado | `gh run view <id> --log-failed` |
| El `sub` no cambia tras el paso 5 | Leíste un token anterior al `PUT` | `after=$(claims)` después del `PUT` |
| `oidc-sub-vars` dice `mal` | `$after` vacío al hacer el paso 6, o el `sub` no tiene `environment:staging` | `echo "$staging_sub"`; repite el paso 5 si hace falta |
| `deploy-gate` lleva rato en `Pending` | Un run anterior espera aprobación | El comando de "Antes de empezar" |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Environments y reglas de protección](02-environments-y-reglas-de-proteccion.md) | [Verificador OIDC y deploy-gate](04-verificador-oidc-y-deploy-gate.md) |
