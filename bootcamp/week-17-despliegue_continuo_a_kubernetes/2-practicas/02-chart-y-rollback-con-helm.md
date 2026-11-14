# Práctica 02 — Chart y rollback con Helm

> Antes de automatizar un despliegue, hazlo a mano y rómpelo a propósito. Hoy llevas el chart de
> `tablero` a tu repo, lo instalas en staging con la identidad exacta que tendrá `deploy.yml` y
> ves a Helm volver solo a la versión anterior cuando una imagen no arranca.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `deploy/k8s/` en `tablero`, un chart que se niega a renderizar imágenes por tag
- La prueba de que `tablero-staging` rechaza un pod con root y de que el chart no lo necesita
- `tablero` instalado en staging como `github:staging`, con las imágenes de la última release
  por digest y una contraseña que también conoce el environment
- Un despliegue roto, revertido por `--rollback-on-failure`, y un rollback a mano

## 📋 Antes de empezar

Terminaste la [práctica 01](01-el-cluster-confia-en-github.md) y leíste la
[teoría 02](../1-teoria/02-kubernetes-para-desplegar-una-app.md) y la
[teoría 03](../1-teoria/03-helm-releases-y-rollback.md). Prepara la terminal con el dueño en
minúsculas (GHCR solo admite minúsculas) y la última versión publicada:

```bash
cd ~/code/tablero
export GH_REPO=<tu-org>/tablero
owner=$(gh repo view "$GH_REPO" --json owner --jq '.owner.login | ascii_downcase')
v=$(gh release view --json tagName --jq '.tagName | ltrimstr("v")')
echo "$v"
# X.Y.Z
```

---

## Paso 1: El chart, solo por digest

**Por qué**: un tag es un puntero que se puede mover; un digest es el contenido. Lo que
`deploy.yml` verificará con `gh attestation verify` es un digest concreto, y si el chart aceptara
`tablero-api:X.Y.Z`, Kubernetes podría bajar otra imagen distinta de la verificada. El chart de
`app/deploy/k8s/` lo impide en la plantilla: si la imagen no acaba en `@sha256:` y 64
hexadecimales, `fail` corta el renderizado antes de tocar el clúster. La app trae cómo se
despliega; el pipeline decide qué versión y dónde.

**Comando**: copia el chart y prueba con un tag:

```bash
mkdir -p deploy && cp -r ~/code/bc-github-actions/app/deploy/k8s deploy/
helm template t deploy/k8s --set-string images.api="ghcr.io/$owner/tablero-api:$v" \
  --set-string images.web="ghcr.io/$owner/tablero-web:$v" --set-string database.password=x 2>&1 | head -1
# Error: execution error at (tablero/templates/api.yaml:3:4): images.api tiene que ir por digest (...@sha256:...), no ghcr.io/<owner>/tablero-api:X.Y.Z
```

Ahora con los digests que firmó `release.yml`. La función hace en local lo mismo que hará el job
`verify` de `deploy.yml`: no hay digest si la attestation no se verifica.

```bash
digest() {
  gh attestation verify "oci://ghcr.io/$owner/tablero-$1:$v" --repo "$GH_REPO" \
    --signer-workflow "$GH_REPO/.github/workflows/release.yml" --source-ref refs/heads/main \
    --deny-self-hosted-runners \
    --format json --jq '.[0].verificationResult.statement.subject[0].digest.sha256'
}
API_IMAGE="ghcr.io/$owner/tablero-api@sha256:$(digest api)"
WEB_IMAGE="ghcr.io/$owner/tablero-web@sha256:$(digest web)"
helm template t deploy/k8s --set-string images.api="$API_IMAGE" --set-string images.web="$WEB_IMAGE" \
  --set-string database.password=x | yq -N 'select(.kind == "Deployment") | .metadata.name + " " + .spec.template.spec.containers[0].image'
# api ghcr.io/<owner>/tablero-api@sha256:<digest>
# db postgres:17.11-alpine@sha256:e5d2edd28b1f8d40a0a6c0c9cdc545b19b56a0d5d88f94bc11a97d970d4700d0
# web ghcr.io/<owner>/tablero-web@sha256:<digest>
```

**Verifica**: la orden de `chart-digest-only`:

```bash
d=$(printf "a%.0s" $(seq 64)); t() { helm template t deploy/k8s --set-string images.api="$1" \
  --set-string images.web="$1" --set-string database.password=x >/dev/null 2>&1 && echo ok || echo rejected; }
echo "tag=$(t ghcr.io/x/y:1.0.0) digest=$(t ghcr.io/x/y@sha256:$d)"
# tag=rejected digest=ok
git add deploy/k8s
git commit -m "feat(deploy): add helm chart for kind"
```

---

## Paso 2: Lo que exige `restricted`

**Por qué**: la práctica 01 etiquetó los dos namespaces con Pod Security `restricted`. Antes de
instalar, comprueba que la etiqueta muerde y que el chart la cumple. Un pod sin `securityContext`
corre como el usuario de su imagen, a menudo root, con escalada permitida y las capacidades por
defecto: es lo que un atacante con permiso de crear pods querría. El chart pone en cada pod
`runAsNonRoot`, `seccompProfile: RuntimeDefault`, `allowPrivilegeEscalation: false`,
`drop: [ALL]`, límites de CPU y memoria y `automountServiceAccountToken: false`: ningún pod de
`tablero` habla con la API de Kubernetes, así que ninguno necesita token
([teoría 05](../1-teoria/05-rbac-y-pod-security-por-environment.md)).

**Comando**: intenta crear un pod sin nada de eso. La imagen da igual: la admisión lo rechaza
antes de descargarla.

```bash
kubectl --context kind-gha run root -n tablero-staging --restart=Never \
  --image=postgres:17.11-alpine@sha256:e5d2edd28b1f8d40a0a6c0c9cdc545b19b56a0d5d88f94bc11a97d970d4700d0 \
  --command -- sleep 60
# Error from server (Forbidden): pods "root" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "root" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (...), runAsNonRoot != true (...), seccompProfile (...)
```

Cuatro motivos, uno por cada campo que el chart sí declara.

**Verifica**: la orden de `chart-pods-restricted`:

```bash
d=$(printf "a%.0s" $(seq 64))
helm template t deploy/k8s --set-string images.api=ghcr.io/x/api@sha256:$d --set-string images.web=ghcr.io/x/web@sha256:$d --set-string database.password=x | yq -N 'select(.kind == "Deployment") | .metadata.name + ":" + ((.spec.template.spec.automountServiceAccountToken == false and .spec.template.spec.securityContext.runAsNonRoot == true and .spec.template.spec.securityContext.seccompProfile.type == "RuntimeDefault" and ([.spec.template.spec.containers[] | select(.securityContext.allowPrivilegeEscalation == false and (.securityContext.capabilities.drop | contains(["ALL"])) and .resources.limits.cpu != null and .resources.limits.memory != null)] | length) == (.spec.template.spec.containers | length)) | tostring)' | sort | paste -sd" "
# api:true db:true web:true
```

---

## Paso 3: Instalar a mano, como `github:staging`

**Por qué**: si el Role de la práctica 01 se queda corto, quieres saberlo aquí y no en un job a
medias. `--kube-as-user github:staging` hace que Helm actúe con el contexto de administrador
**suplantando** al usuario que tendrá el job: cada petición pasa por el RBAC de ese usuario.

La contraseña de PostgreSQL merece un momento. `deploy.yml` la tomará del secreto
`DATABASE_PASSWORD` del environment staging, que creaste en la Semana 13 sin ver su valor; un
secreto de GitHub no se puede leer. Y PostgreSQL guarda en su volumen la contraseña con la que se
**inicializó**: el PVC `db-data` sobrevive a los upgrades (`helm.sh/resource-policy: keep`), así
que si hoy instalas con otra, el primer despliegue de `deploy.yml` no podrá conectarse. La
salida es generar una nueva y darla a los dos sitios a la vez.

**Comando**:

```bash
pw=$(openssl rand -hex 16)
printf %s "$pw" | gh secret set DATABASE_PASSWORD --env staging
helm upgrade --install tablero deploy/k8s --kube-context kind-gha --kube-as-user github:staging \
  --namespace tablero-staging --wait --timeout 5m --description "tablero $v (a mano)" \
  --set-string images.api="$API_IMAGE" --set-string images.web="$WEB_IMAGE" \
  --set-string database.password="$pw"
unset pw
```

El valor va por stdin a `gh` y por variable a Helm: en tu historial queda `$pw`, no la
contraseña. La API puede reiniciar una o dos veces mientras PostgreSQL arranca (aplica las
migraciones al arrancar): la readiness no la da por lista hasta entonces.

**Verifica**: los tres Deployments listos y la app de punta a punta. El port-forward escucha solo
en `127.0.0.1` (regla 12 de seguridad):

```bash
kubectl --context kind-gha -n tablero-staging get deploy -o json |
  jq -r '.items[] | .metadata.name + " " + (.status.readyReplicas | tostring)'
# api 1
# db 1
# web 1
kubectl --context kind-gha -n tablero-staging port-forward --address 127.0.0.1 svc/web 8080:8080 >/dev/null &
sleep 2
curl -sS http://127.0.0.1:8080/api/tasks
# []
./scripts/smoke-test.sh | tail -1
# borrada. Smoke test OK
kill %1
```

`[]`: la petición cruzó nginx, llegó a la API y la API consultó PostgreSQL. Si el puerto 8080 está
ocupado (un `docker compose` de otra semana), páralo antes.

---

## Paso 4: Simulacro de rollback

**Por qué**: un despliegue que no arranca no debe quedarse a medias. Con
`--rollback-on-failure`, Helm 4 espera a que los recursos estén listos y, si no lo están al
acabar `--timeout`, vuelve a la última revisión buena (en Helm 3 era `--atomic`, que ya no
existe). Un digest de 64 ceros no existe en GHCR: el pod nuevo de la API se queda en
`ImagePullBackOff`. Mientras tanto el pod viejo sigue sirviendo, porque el Deployment no lo
retira hasta que el nuevo está listo: el rollback no tiene corte.

**Comando**:

> ⚠️ **Advertencia**: este paso rompe a propósito la API de `tablero-staging` durante un minuto.
> No hay nada que respaldar: Helm conserva la revisión buena y vuelve a ella solo.

```bash
zero=$(printf "0%.0s" $(seq 64))
helm upgrade tablero deploy/k8s --kube-context kind-gha --kube-as-user github:staging \
  --namespace tablero-staging --rollback-on-failure --timeout 1m --reuse-values \
  --description "simulacro: imagen inexistente" \
  --set-string images.api="ghcr.io/$owner/tablero-api@sha256:$zero"
# Error: UPGRADE FAILED: release tablero failed, and has been rolled back due to rollback-on-failure being set: resource Deployment/tablero-staging/api not ready. status: InProgress, message: ...
```

`--reuse-values` conserva las imágenes y la contraseña de la revisión anterior y cambia solo la
de la API.

**Verifica**: el historial y la orden de `rollback-drill`:

```bash
helm history tablero --kube-context kind-gha -n tablero-staging -o json |
  jq -r '.[] | "\(.revision) \(.status) \(.description)"'
# 1 superseded tablero X.Y.Z (a mano)
# 2 failed Upgrade "tablero" failed: ...
# 3 deployed Rollback to 1
helm history tablero --kube-context kind-gha -n tablero-staging -o json | jq -r '"failed=\(map(select(.status == "failed")) | length > 0) rollback=\(map(select(.description | startswith("Rollback to"))) | length > 0)"'
# failed=true rollback=true
kubectl --context kind-gha -n tablero-staging get deploy api -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
# ghcr.io/<owner>/tablero-api@sha256:<digest>
```

La revisión fallida no se borra: queda en el historial con su motivo, y el rollback es una
revisión nueva.

---

## Paso 5: Rollback a mano

**Por qué**: `--rollback-on-failure` solo ve lo que Kubernetes ve: pods listos. Una versión que
arranca pero responde mal pasa ese filtro. Para eso `deploy.yml` lanza un smoke test y, si
falla, `helm rollback`: el mismo comando que usarías tú a mano. Sin número de revisión vuelve a
la anterior; con número, a la que digas.

**Comando**: vuelve a la revisión 1 de forma explícita:

```bash
helm rollback tablero 1 --kube-context kind-gha --kube-as-user github:staging \
  --namespace tablero-staging --wait --timeout 3m
```

**Verifica**:

```bash
helm history tablero --kube-context kind-gha -n tablero-staging -o json |
  jq -r '.[-1] | "\(.revision) \(.status) \(.description)"'
# 4 deployed Rollback to 1
git push
```

Las revisiones 1, 3 y 4 tienen el mismo contenido: Kubernetes no reinicia ningún pod, pero el
historial cuenta todo lo que pasó.

---

## ✅ Resultado

- [ ] `deploy/k8s` rechaza una imagen por tag y renderiza con los digests firmados por `release.yml`
- [ ] `tablero-staging` rechaza un pod con root; el chart cumple `restricted`
- [ ] `tablero` corre en staging, instalado como `github:staging`, y el smoke test pasa
- [ ] `DATABASE_PASSWORD` de staging es la contraseña con la que se inicializó PostgreSQL
- [ ] El historial de Helm muestra el despliegue fallido, el rollback automático y el manual

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 17
# ...
# ✅ El historial de Helm de staging tiene una revisión fallida y un rollback automático
# ...
```

Ya en verde, nueve: las seis de la práctica 01 más `chart-digest-only`, `chart-pods-restricted` y
`rollback-drill`. Las de `deploy.yml` llegan en la práctica 03.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `Error: verifying with issuer "sigstore.dev"` en `digest` | La imagen no la firmó `release.yml` de `tablero`, o el owner va en mayúsculas | Revisa `owner` y `v`; no uses una imagen que no pasa |
| `images.api tiene que ir por digest` en el paso 3 | `API_IMAGE` está vacía porque `digest` falló | Vuelve a definir las dos variables del paso 1 en esta terminal |
| `secrets is forbidden: User "github:staging" cannot list resource "secrets"` | Falta la regla de secrets del Role o el namespace es otro | Revisa `access.yaml` (práctica 01, paso 4) y `--namespace` |
| `violates PodSecurity "restricted:latest"` al instalar | El chart de tu repo no es el de `app/deploy/k8s` | Vuelve a copiarlo desde el paso 1 |
| La API en `CrashLoopBackOff` con `password authentication failed` | El volumen `db-data` se inicializó con otra contraseña | Usa la primera o borra el PVC con `kubectl --context kind-gha -n tablero-staging delete pvc db-data` (pierdes los datos de staging) y reinstala |
| `curl` del paso 3 dice `Connection refused` | El port-forward aún no estaba listo o el 8080 está ocupado | Espera unos segundos más o libera el puerto |
| `Error: release tablero failed, and has been uninstalled due to rollback-on-failure being set` | Usaste `--rollback-on-failure` en la primera instalación | En el primer install no hay a dónde volver: repite el paso 3 sin ese flag |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [El clúster confía en GitHub](01-el-cluster-confia-en-github.md) | [deploy.yml](03-deploy-yml.md) |
