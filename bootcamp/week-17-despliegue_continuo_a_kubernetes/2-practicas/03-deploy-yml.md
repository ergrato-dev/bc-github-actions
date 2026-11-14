# Práctica 03 — deploy.yml

> Lo que hiciste a mano en la práctica 02, ahora con un workflow, la identidad del job y tu aprobación.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `deploy.yml`, solo con `workflow_dispatch`, con un job `verify` que entrega los digests firmados
- Jobs `staging` y `production` en `tablero-runners`, con environment, cola y un kubeconfig sin
  credenciales; Helm con checksum, `--rollback-on-failure`, smoke test y `helm rollback`
- El primer despliegue de `tablero` desde un workflow, aprobado por ti en production

## 📋 Antes de empezar

Terminaste la [práctica 02](02-chart-y-rollback-con-helm.md) y leíste las teorías
[01](../1-teoria/01-despliegue-continuo-y-promocion.md) y [06](../1-teoria/06-credenciales-de-corta-vida-en-el-runner.md).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
v=$(gh release view --json tagName --jq '.tagName | ltrimstr("v")')
```

---

## Paso 1: `deploy-gate.yml` se va, llega `deploy.yml`

**Por qué**: `deploy-gate.yml` ensayaba la puerta sin desplegar nada; la Semana 13 prometió que
aquí desplegaría de verdad. `deploy.yml` solo se lanza con `workflow_dispatch` porque corre en tus
runners propios, que la regla 11 admite solo en eventos de confianza: un `pull_request` pondría el
código de cualquiera en un pod de tu clúster. El input `version` sirve para el despliegue
automático (práctica 04), para redesplegar y para volver atrás.

**Comando**:

```bash
git rm -q .github/workflows/deploy-gate.yml
```

Crea `.github/workflows/deploy.yml` con la cabecera:

```yaml
# Despliegue de tablero en kind: verifica las attestations de la versión, la despliega por
# digest en staging y, tras la aprobación, en production. Lo lanza release.yml tras publicar
# las imágenes; a mano sirve para redesplegar o volver a una versión anterior.
name: deploy
# La versión en el título: en la lista de runs ves qué se desplegó sin abrir ninguno.
run-name: deploy ${{ inputs.version }}
on:
  workflow_dispatch:
    inputs:
      version:
        description: Versión de tablero (X.Y.Z, sin la v)
        required: true
        type: string
permissions: {}
jobs:
```

**Verifica**:

```bash
yq '(.on | keys | join(",")) + " " + ."run-name"' .github/workflows/deploy.yml
# workflow_dispatch deploy ${{ inputs.version }}
```

Los `gate-*` de la Semana 13 y `own-runners-only-in-lab` de la 16 quedan en rojo: los
[superan capas posteriores](../../../docs/autograding.md#comprobaciones-superadas-por-capas-posteriores).

---

## Paso 2: El job `verify`

**Por qué**: se despliega solo lo que firmó `release.yml` de `tablero` en un runner de GitHub
([teoría 07](../1-teoria/07-desplegar-solo-lo-verificado.md)); `--deny-self-hosted-runners`
importa porque ahora `tablero` tiene runners propios. La salida es **el digest que cubre la
attestation**, no el tag: si alguien lo mueve después, Helm despliega lo verificado. La versión
se valida aunque llegue por `env:`: acaba en una referencia de imagen.

**Comando**: añade bajo `jobs:`:

```yaml
  verify:
    name: Verificar imágenes
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    permissions:
      attestations: read
    outputs:
      api: ${{ steps.verify.outputs.api }}
      web: ${{ steps.verify.outputs.web }}
    steps:
      - name: Attestations de procedencia firmadas por release.yml
        id: verify
        env:
          GH_TOKEN: ${{ github.token }}
          OWNER: ${{ github.repository_owner }}
          VERSION: ${{ inputs.version }}
        run: |
          [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "::error::Versión no válida: $VERSION"; exit 1; }
          for c in api web; do
            image="ghcr.io/${OWNER,,}/tablero-$c"
            # Se despliega el digest que cubre la attestation, no lo que diga el tag después.
            digest=$(gh attestation verify "oci://$image:$VERSION" --repo "$GITHUB_REPOSITORY" \
              --signer-workflow "$GITHUB_REPOSITORY/.github/workflows/release.yml" \
              --deny-self-hosted-runners \
              --format json --jq '.[0].verificationResult.statement.subject[0].digest.sha256')
            echo "$c=$image@sha256:$digest" >> "$GITHUB_OUTPUT"
            echo "- \`$image@sha256:$digest\`" >> "$GITHUB_STEP_SUMMARY"
          done
```

**Verifica**: lo esencial de la orden de `deploy-verifies-attestations`:

```bash
f=.github/workflows/deploy.yml
printf 'runs-on=%s perms=%s\n' "$(yq '.jobs.verify."runs-on"' $f)" \
  "$(yq '.jobs.verify.permissions | to_entries | map(.key + "=" + .value) | join(",")' $f)"
# runs-on=ubuntu-24.04 perms=attestations=read
```

---

## Paso 3: Staging y production, con la identidad del job

**Por qué**: cuatro decisiones, cada una en su línea ([teoría 06](../1-teoria/06-credenciales-de-corta-vida-en-el-runner.md)):

- **`runs-on: tablero-runners`**: el apiserver de kind no sale de tu máquina (regla 12).
- **`environment`**: la aprobación, el `DATABASE_PASSWORD` de cada uno y el claim que el
  apiserver convierte en `github:staging` o `github:production`.
- **`concurrency` sin cancelar**: cortar un `helm upgrade` a medias bloquea la release.
- **`id-token: write` y un kubeconfig sin credenciales**: Helm llama a `github-token.sh` cuando
  necesita token. Vive 5 minutos; el script declara 4 y client-go pide otro. Nunca toca disco.

**Comando**: crea `ops/deploy/kubeconfig.yaml`:

```yaml
# kubeconfig de deploy.yml: sin ninguna credencial dentro. Helm lo lee por KUBECONFIG desde el
# pod del runner de ARC; la identidad la pone github-token.sh en cada petición que la necesita.
apiVersion: v1
kind: Config
clusters:
  - name: kind-gha
    cluster:
      server: https://kubernetes.default.svc
      # El CA del clúster, montado en el pod del runner (ops/arc/values.yaml).
      certificate-authority: /etc/kube-ca/ca.crt
users:
  - name: github-oidc
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1
        # Ruta relativa a este archivo.
        command: ./github-token.sh
        interactiveMode: Never
contexts:
  - name: deploy
    context:
      cluster: kind-gha
      user: github-oidc
current-context: deploy
```

Y `ops/deploy/github-token.sh`, ejecutable (`chmod +x ops/deploy/github-token.sh`):

```bash
#!/usr/bin/env bash
#
# github-token.sh — plugin exec de kubeconfig.yaml: entrega a Helm un token OIDC de GitHub con
# audiencia kind-gha. El token vale minutos; con la caducidad declarada, Helm vuelve a llamar al
# script cuando hace falta otro, aunque el despliegue tarde.
set -euo pipefail

token=$(curl -sSf -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=kind-gha" | jq -r .value)

# Un poco antes de que caduque de verdad, para no estrenar uno ya muerto.
jq -n --arg token "$token" --arg exp "$(date -u -d '+4 min' +%Y-%m-%dT%H:%M:%SZ)" '{
  apiVersion: "client.authentication.k8s.io/v1",
  kind: "ExecCredential",
  status: {token: $token, expirationTimestamp: $exp}
}'
```

Añade a `deploy.yml` los dos jobs, de momento sin steps (llegan en el paso 4). Staging:

```yaml
  staging:
    name: Staging
    needs: verify
    # Dentro de kind: el apiserver no está expuesto fuera de tu máquina.
    runs-on: tablero-runners
    timeout-minutes: 15
    environment: staging
    # Dos despliegues al mismo namespace se pisan: el segundo espera.
    concurrency:
      group: deploy-staging
      cancel-in-progress: false
    permissions:
      contents: read
      id-token: write
    env:
      NAMESPACE: tablero-staging
      HELM_VERSION: v4.3.2
      # Sin credenciales: Helm pide el token OIDC del job con ops/deploy/github-token.sh.
      KUBECONFIG: ops/deploy/kubeconfig.yaml
```

Production es igual salvo `name`, `needs`, environment, grupo y namespace:

```yaml
  production:
    name: Production
    needs: [verify, staging]
    runs-on: tablero-runners
    timeout-minutes: 15
    environment: production
    concurrency:
      group: deploy-production
      cancel-in-progress: false
    permissions:
      contents: read
      id-token: write
    env:
      NAMESPACE: tablero-production
      HELM_VERSION: v4.3.2
      KUBECONFIG: ops/deploy/kubeconfig.yaml
```

**Verifica**: la orden de `deploy-environments`, lo esencial de `deploy-kubeconfig-oidc`, la de
`own-runners-dispatch-only` y que el plugin no funciona fuera de un job:

```bash
yq -N '.jobs | to_entries | .[] | select(.value.environment) | .key + ":env=" + (.value.environment | .name // .) + ",runs-on=" + .value."runs-on" + ",needs=" + ([.value.needs] | flatten | join("+")) + ",queue=" + ((.value.concurrency.group // "") != "" and .value.concurrency."cancel-in-progress" == false | tostring)' .github/workflows/deploy.yml | paste -sd" "
# staging:env=staging,runs-on=tablero-runners,needs=verify,queue=true production:env=production,runs-on=tablero-runners,needs=verify+staging,queue=true
k=ops/deploy/kubeconfig.yaml
printf 'exec=%s aud=%s creds=%s\n' "$(yq '.users[0].user.exec.command' $k)" "$(grep -c 'audience=kind-gha' ops/deploy/github-token.sh)" \
  "$(yq '[.. | select(tag == "!!map") | keys[] | select(test("^(token|tokenFile|client-key|client-key-data|password)$"))] | length' $k)"
# exec=./github-token.sh aud=1 creds=0
yq -N 'select([.jobs[]."runs-on" | tostring | test("self-hosted|tablero-lab|tablero-runners")] | any) | (filename | sub(".*/"; "")) + ":" + (.on | keys | join(","))' .github/workflows/*.yml | sort | paste -sd" "
# deploy.yml:workflow_dispatch lab.yml:workflow_dispatch
ops/deploy/github-token.sh
# ops/deploy/github-token.sh: line 9: ACTIONS_ID_TOKEN_REQUEST_TOKEN: unbound variable
```

Fuera de un job con `id-token: write`, el kubeconfig no da acceso a nada.

---

## Paso 4: Helm, despliegue, smoke test y rollback

**Por qué**: el runner no trae Helm, y la regla 9 pide versión fijada y checksum. El despliegue
es el de la práctica 02 sin `--kube-as-user`: la identidad sale del token. Imágenes y contraseña
llegan por `env:`. El smoke test llega a la web por el DNS del Service. Si falla tras un
despliegue que Helm dio por bueno, el último step vuelve atrás; `steps.deploy.outcome == 'success'`
evita repetir el rollback cuando el que falló fue Helm.

**Comando**: añade estos steps al final de **los dos jobs, idénticos**:

```yaml
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: Instalar Helm con checksum
        run: |
          cd "$RUNNER_TEMP"
          file="helm-$HELM_VERSION-linux-amd64.tar.gz"
          curl -fsSLO "https://get.helm.sh/$file"
          curl -fsSL "https://get.helm.sh/$file.sha256sum" | sha256sum -c
          tar -xzf "$file" linux-amd64/helm
          echo "$RUNNER_TEMP/linux-amd64" >> "$GITHUB_PATH"
      - name: Desplegar por digest
        id: deploy
        env:
          API_IMAGE: ${{ needs.verify.outputs.api }}
          WEB_IMAGE: ${{ needs.verify.outputs.web }}
          DATABASE_PASSWORD: ${{ secrets.DATABASE_PASSWORD }}
          VERSION: ${{ inputs.version }}
        # Si los pods no llegan a Ready, Helm vuelve solo a la revisión anterior.
        run: |
          helm upgrade --install tablero deploy/k8s --namespace "$NAMESPACE" \
            --rollback-on-failure --timeout 3m --description "tablero $VERSION" \
            --set-string images.api="$API_IMAGE" --set-string images.web="$WEB_IMAGE" \
            --set-string database.password="$DATABASE_PASSWORD"
      - name: Smoke test a través de la web
        run: ./scripts/smoke-test.sh "http://web.$NAMESPACE.svc.cluster.local:8080"
      - name: Volver a la revisión anterior si el smoke test falla
        if: failure() && steps.deploy.outcome == 'success'
        run: helm rollback tablero --namespace "$NAMESPACE" --wait --timeout 3m
```

**Verifica**: lo esencial de la orden de `deploy-helm-rollback`:

```bash
f=.github/workflows/deploy.yml; for j in staging production; do printf "%s:helm=%s checksum=%s rollback=%s " $j \
  "$(yq ".jobs.$j.env.HELM_VERSION" $f)" "$(yq "[.jobs.$j.steps[].run // \"\" | select(test(\"sha256sum -c\"))] | length" $f)" \
  "$(yq "[.jobs.$j.steps[] | select((.run // \"\" | test(\"helm rollback\")) and (.if // \"\" | test(\"failure\")))] | length" $f)"; done; echo
# staging:helm=v4.3.2 checksum=1 rollback=1 production:helm=v4.3.2 checksum=1 rollback=1
```

---

## Paso 5: Lint, push y el primer despliegue

**Por qué**: actionlint y zizmor revisan expresiones, permisos e inyección. Después llega al
apiserver el primer token OIDC real: si una regla de la práctica 01 no casa, lo verás aquí.

**Comando**:

```bash
actionlint && GH_TOKEN=$(gh auth token) zizmor -q .github/ && echo limpio
# limpio
git add .github/workflows/deploy.yml ops/deploy
git commit -m "ci: deploy verified images to kind with helm"
git push
gh workflow run deploy.yml -f version="$v"
sleep 5
run=$(gh run list --workflow deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId')
kubectl --context kind-gha get pods -n tablero-staging -w
```

Con la versión de la práctica 02 los pods no cambian: Helm añade una revisión igual. Cuando
staging acabe, `Ctrl-C` y aprueba production con `pending_deployments` ([Semana 13, práctica 02, paso 5](../../week-13-secretos_entornos_y_oidc/2-practicas/02-environments-y-reglas-de-proteccion.md)):

```bash
pending="repos/{owner}/{repo}/actions/runs/$run/pending_deployments"
until [ "$(gh api "$pending" --jq length)" -gt 0 ]; do sleep 10; done
gh api -X POST "$pending" -F "environment_ids[]=$(gh api "$pending" --jq '.[0].environment.id')" \
  -f state=approved -f comment="Staging en verde con $v" > /dev/null
gh run watch "$run" --exit-status > /dev/null && echo deploy ok
# deploy ok
```

**Verifica**:

```bash
gh run view "$run" --json displayTitle,jobs --jq '.displayTitle, (.jobs[] | .name + " " + .conclusion)'
# deploy X.Y.Z
# Verificar imágenes success
# Staging success
# Production success
```

---

## ✅ Resultado

- [ ] `deploy-gate.yml` borrado; `deploy.yml` solo con `workflow_dispatch` y un `verify` mínimo
- [ ] Staging y production en `tablero-runners`, con environment, cola e identidad OIDC
- [ ] actionlint y zizmor limpios, y el primer run en verde con production aprobado por ti

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 17
# ...
# ❌ release.yml lanza deploy.yml con la versión publicada tras las imágenes, desde un job con actions: write como único permiso
# ...
```

Diecisiete en verde: las de las prácticas 01 y 02, las seis de `deploy.yml` y, con el run
aprobado, `production-runs-latest-release` y `deploy-green-for-release`. Solo queda
`release-dispatches-deploy`: la práctica 04 hace que cada release se despliegue sola.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `Error: kubernetes cluster unreachable: the server has asked for the client to provide credentials` | El apiserver rechazó el token: audiencia, id, rama, workflow o environment | Compara cada regla de `authentication-config.yaml` con los claims (práctica 01, paso 3) |
| `secrets is forbidden: User "github:staging" ... "tablero-production"` | `NAMESPACE` del job no coincide con su environment | Revisa el bloque `env` de cada job |
| El job de staging se queda en `Queued` | No hay listener de `tablero-runners` o ARC no está instalado | `helm list -A --kube-context kind-gha` y `ops/arc/install.sh` (práctica 01, paso 1) |
| El smoke test falla con `password authentication failed` | `DATABASE_PASSWORD` de staging no es la de la instalación a mano | Práctica 02, paso 3: la misma contraseña en los dos sitios |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Chart y rollback con Helm](02-chart-y-rollback-con-helm.md) | [Promoción, aprobación y rollback](04-promocion-aprobacion-y-rollback.md) |
