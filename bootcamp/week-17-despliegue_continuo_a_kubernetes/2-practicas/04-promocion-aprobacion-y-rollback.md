# Práctica 04 — Promoción, aprobación y rollback

> Hasta ahora lanzabas `deploy.yml` tú. Hoy cierras la cadena: un `fix` real se convierte en
> release, la release se despliega sola en staging y espera tu aprobación para production. Después
> vuelves a la versión anterior, regresas a la última y lanzas dos despliegues a la vez para ver
> que no se pisan.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Un job `deploy` en `release.yml` que lanza `deploy.yml` con la versión recién publicada
- Una release nueva de `tablero` desplegada sin escribir un comando de despliegue
- La aprobación de production y su rastro en la API de deployments de GitHub
- Un rollback de production por la puerta principal y la vuelta a la última release
- Dos despliegues simultáneos que esperan su turno en lugar de cancelarse

## 📋 Antes de empezar

Terminaste la [práctica 03](03-deploy-yml.md), con su primer run de `deploy.yml` en verde, y
leíste la [teoría 01](../1-teoria/01-despliegue-continuo-y-promocion.md). Prepara la terminal con
una función que aprueba production en un run y espera a que acabe; la usarás cuatro veces:

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
# Aprueba production en el run $1 con el comentario $2 y espera a que el run termine.
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

## Paso 1: La release lanza el despliegue

**Por qué**: la release la crea `GITHUB_TOKEN`, y los eventos que provoca `GITHUB_TOKEN` no
disparan otros workflows: un `on: release` en `deploy.yml` no se enteraría nunca. Las dos
excepciones son `workflow_dispatch` y `repository_dispatch`. El job nuevo pide `actions: write`,
el permiso de lanzar workflows, y nada más; el despliegue en sí sigue en `deploy.yml`, con su
aprobación y su identidad OIDC. Depende de `images`, así que solo corre cuando hubo release y
sus dos imágenes están firmadas: en un push normal, `images` se salta y `deploy` también.
`--ref main` hace que el token del despliegue lleve `ref: refs/heads/main`, la rama que exige el
apiserver.

**Comando**: añade al final de `.github/workflows/release.yml`:

```yaml
  deploy:
    name: Lanzar el despliegue
    # Solo tras una release con sus dos imágenes publicadas y firmadas.
    needs: [release-please, images]
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    permissions:
      # Lanzar un workflow por workflow_dispatch pide actions: write.
      actions: write
    steps:
      - name: Lanzar deploy.yml con la versión publicada
        env:
          GH_TOKEN: ${{ github.token }}
          VERSION: ${{ needs.release-please.outputs.version }}
        run: gh workflow run deploy.yml --repo "$GITHUB_REPOSITORY" --ref main -f version="$VERSION"
```

```bash
actionlint && GH_TOKEN=$(gh auth token) zizmor -q .github/ && echo limpio
# limpio
git commit -am "ci(release): dispatch deploy after publishing images"
```

Ahora un arreglo de verdad para que haya release. La API acepta como título `"   "`:
`min_length=1` cuenta los espacios y después `strip()` guarda un título vacío. En
`api/src/tablero/main.py`, cambia el import de pydantic y el campo `title` de `TaskIn`:

```python
from pydantic import BaseModel, StringConstraints
```

```python
class TaskIn(BaseModel):
    title: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
```

```bash
cd api
uv run --locked python -c 'from tablero.main import TaskIn; print(repr(TaskIn(title="  hola  ").title))'
# 'hola'
uv run --locked python -c 'from tablero.main import TaskIn; TaskIn(title="   ")' 2>&1 | grep -q string_too_short && echo rechazado
# rechazado
cd ..
git commit -am "fix(api): reject blank task titles"
git push
sleep 5
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
# release ok
gh run view "$run" --json jobs --jq '.jobs[] | select(.name == "Lanzar el despliegue") | .conclusion'
# skipped
```

`skipped`: ese push abrió el PR de release, no una release. Mézclalo:

```bash
pr=$(gh pr list --label "autorelease: pending" --json number --jq '.[0].number')
gh pr merge "$pr" --squash --delete-branch
git pull --ff-only && sleep 5
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
# release ok
```

**Verifica**: el job `deploy`, la orden de `release-dispatches-deploy` y el run que lanzó:

```bash
gh run view "$run" --json jobs --jq '.jobs[] | .name + " " + .conclusion' | sort
# Imagen tablero-api success
# Imagen tablero-web success
# Lanzar el despliegue success
# Release PR o release success
f=.github/workflows/release.yml
printf 'needs=%s perms=%s\n' "$(yq '.jobs.deploy.needs | join(",")' $f)" \
  "$(yq '.jobs.deploy.permissions | to_entries | map(.key + "=" + .value) | join(",")' $f)"
# needs=release-please,images perms=actions=write
v=$(gh release view --json tagName --jq '.tagName | ltrimstr("v")')
gh run list --workflow deploy.yml --limit 1 --json displayTitle,event --jq '.[0] | .displayTitle + " " + .event'
# deploy X.Y.Z workflow_dispatch
```

El título del run es la versión nueva: nadie la escribió a mano.

---

## Paso 2: Aprobar production y leer el rastro

**Por qué**: staging se despliega solo; production espera a una persona
(la regla de protección de la Semana 13). La aprobación queda en el run con su comentario, y cada
job con `environment` crea un **deployment** en GitHub con estados: la respuesta a "qué versión
corre en production y quién la dejó pasar" sin entrar al clúster. El clúster, por su parte,
tiene que estar corriendo el **digest** que cubre la attestation de esa versión, no solo algo con
ese tag.

**Comando**:

```bash
approve "$(last_deploy)" "Staging en verde con $v"
# deploy ok
```

**Verifica**: el deployment de production, la orden de `deploy-green-for-release` y la de
`production-runs-latest-release`:

```bash
dep=$(gh api 'repos/{owner}/{repo}/deployments?environment=production' --jq '.[0].id')
gh api "repos/{owner}/{repo}/deployments/$dep/statuses" --jq '.[0].state'
# success
read -r sha concl < <(gh run list --workflow deploy.yml --json displayTitle,headSha,conclusion \
  --jq "[.[] | select(.displayTitle == \"deploy $v\")][0] | \"\(.headSha) \(.conclusion)\"")
dep=$(gh api "repos/{owner}/{repo}/deployments?environment=production&sha=$sha" --jq '.[0].id')
echo "deploy=$concl production=$(gh api "repos/{owner}/{repo}/deployments/$dep/statuses" --jq '.[0].state')"
# deploy=success production=success
owner=$(gh repo view "$GH_REPO" --json owner --jq '.owner.login | ascii_downcase')
check_production() {
  for c in api web; do
    want="ghcr.io/$owner/tablero-$c@sha256:$(gh attestation verify "oci://ghcr.io/$owner/tablero-$c:$v" \
      --repo "$GH_REPO" --format json --jq '.[0].verificationResult.statement.subject[0].digest.sha256')"
    have=$(kubectl --context kind-gha -n tablero-production get deploy $c -o jsonpath='{.spec.template.spec.containers[0].image}')
    printf '%s=%s ' $c "$([[ "$have" == "$want" ]] && echo "v$v" || echo "$have")"
  done; echo
}
check_production
# api=vX.Y.Z web=vX.Y.Z
```

---

## Paso 3: Volver a la versión anterior, y regresar

**Por qué**: el rollback de producción no se hace con `helm rollback` desde tu portátil: en un
equipo real nadie tiene credenciales de administrador del clúster, y saltarse `deploy.yml` deja
fuera la verificación, la aprobación y el registro de deployments. Se hace por la puerta
principal: `deploy.yml` con la versión anterior. Ojo con una cosa: volver a una imagen anterior
no deshace migraciones de base de datos. Este `fix` no toca el esquema, así que es seguro; con
una migración, la versión vieja tendría que tolerar el esquema nuevo.

> ⚠️ **Advertencia**: durante este paso production corre la versión anterior, sin el arreglo de
> títulos vacíos. No hay nada que respaldar: el volumen de PostgreSQL no se toca y la segunda
> mitad del paso vuelve a la última release.

**Comando**:

```bash
prev=$(gh release list --limit 2 --json tagName --jq '.[1].tagName | ltrimstr("v")')
gh workflow run deploy.yml -f version="$prev"
sleep 5
approve "$(last_deploy)" "Simulacro: vuelta a $prev"
# deploy ok
check_production
# api=ghcr.io/<owner>/tablero-api@sha256:<digest-de-la-anterior> web=ghcr.io/<owner>/tablero-web@sha256:<digest-de-la-anterior>
```

`production-runs-latest-release` estaría ahora en rojo: production no corre la última release.
Vuelve a ella:

```bash
gh workflow run deploy.yml -f version="$v"
sleep 5
approve "$(last_deploy)" "Fin del simulacro: vuelta a $v"
# deploy ok
```

**Verifica**:

```bash
check_production
# api=vX.Y.Z web=vX.Y.Z
helm history tablero --kube-context kind-gha -n tablero-production -o json |
  jq -r '.[-3:][] | "\(.status) \(.description)"'
# superseded tablero X.Y.Z
# superseded tablero <anterior>
# deployed tablero X.Y.Z
```

Dos revisiones nuevas, ninguna fallida, cada una con la versión en la descripción gracias a
`--description "tablero $VERSION"`.

---

## Paso 4: Dos despliegues a la vez

**Por qué**: `concurrency` con `cancel-in-progress: false` hace que el segundo despliegue al
mismo namespace **espere** a que acabe el primero. Si cancelara, podría cortar un `helm upgrade`
a medias y dejar la release de Helm bloqueada en una operación pendiente, de modo que el
siguiente despliegue fallaría hasta arreglarla a mano. Un límite que conviene conocer: GitHub
guarda **un solo** run pendiente por grupo; un tercero sustituye al segundo. Es lo que resolvería
`concurrency.queue: max`, que actionlint aún no acepta
([teoría 07](../1-teoria/07-desplegar-solo-lo-verificado.md)).

**Comando**: lanza dos y mira el segundo mientras el primero ocupa staging:

```bash
gh workflow run deploy.yml -f version="$v"
gh workflow run deploy.yml -f version="$v"
sleep 10
read -r second first < <(gh run list --workflow deploy.yml --limit 2 --json databaseId --jq '[.[].databaseId] | join(" ")')
gh run view "$second" --json jobs --jq '.jobs[] | .name + " " + .status'
# Verificar imágenes completed
# Staging <en espera>
```

Mientras el primer run despliega staging, el job `Staging` del segundo no arranca: en la UI
aparece esperando por el grupo `deploy-staging`. Aprueba los dos en orden, para que el último run
de `deploy X.Y.Z` termine en verde:

```bash
approve "$first" "Concurrencia: primero"
# deploy ok
approve "$second" "Concurrencia: segundo"
# deploy ok
```

**Verifica**: los dos en verde y ningún despliegue fallido en staging:

```bash
gh run view "$first" --json conclusion --jq .conclusion; gh run view "$second" --json conclusion --jq .conclusion
# success
# success
helm history tablero --kube-context kind-gha -n tablero-staging -o json |
  jq -r '.[-2:][] | "\(.status) \(.description)"'
# superseded tablero X.Y.Z
# deployed tablero X.Y.Z
```

Uno detrás de otro, ninguno pisó al otro.

---

## ✅ Resultado

- [ ] `release.yml` lanza `deploy.yml` con la versión publicada, con `actions: write` como único permiso
- [ ] Un `fix` real llegó a staging sin intervención y a production con tu aprobación
- [ ] La API de deployments dice `success` en production para el run de la última release
- [ ] Production volvió a la versión anterior por `deploy.yml` y regresó a la última
- [ ] Dos despliegues simultáneos terminaron en verde, uno detrás de otro

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 17
# ...
# 18/18 comprobaciones superadas.
```

Las 18 en verde: `release-dispatches-deploy` era la última. Si `production-runs-latest-release`
sigue en rojo, te quedaste en la versión anterior del paso 3.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `Lanzar el despliegue` en `skipped` tras mezclar el PR de release | El commit no era `fix:` o `feat:` y no hubo release, o `images` falló | Mira el job `Release PR o release` y los de `images` |
| `HTTP 403: Resource not accessible by integration` en `Lanzar el despliegue` | Falta `actions: write` en el job | Añádelo al job, no a la raíz |
| El run de `deploy.yml` no aparece | `gh workflow run` falló o lanzó otra rama | Mira el log del job `deploy` de `release.yml`; tiene que llevar `--ref main` |
| `approve` no termina | Production no tiene revisor, o el run falló en staging | `gh run view "$(last_deploy)"` y mira qué job falló |
| `check_production` imprime un digest, no la versión | Production corre otra versión | Lanza `deploy.yml` con la última y apruébalo (paso 3) |
| `Error: verifying with issuer "sigstore.dev"` al volver a `$prev` | La versión anterior se publicó antes de las attestations de la Semana 14 | Elige una versión con attestation; `verify` hace bien en negarse |
| El tercer run pendiente sustituyó al segundo | Un solo pendiente por grupo de concurrencia | Es lo esperado: vuelve a lanzarlo cuando acabe el primero |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [deploy.yml](03-deploy-yml.md) | [Proyecto: capa 17 de tablero](../3-proyecto/README.md) |
