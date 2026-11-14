# Práctica 01 — El clúster confía en GitHub

> Antes de que `deploy.yml` exista, el clúster tiene que saber a quién dejar entrar. Hoy recreas
> `kind-gha` con la configuración OIDC montada en el apiserver, das al runner el CA del clúster y
> conviertes cada environment de GitHub en un usuario de Kubernetes con su propio namespace.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `kind-gha` recreado con `--authentication-config` en el apiserver, y ARC reinstalado
- El pod del runner con el CA del clúster en `/etc/kube-ca` y todavía sin token de Kubernetes
- `ops/cluster/authentication-config.yaml` cargado en el apiserver, comprobado por su hash
- `tablero-staging` y `tablero-production` con Pod Security `restricted`, y un Role por environment

## 📋 Antes de empezar

Terminaste la [Semana 16](../../week-16-actions_runner_controller_en_kind/README.md) con
`check-week.sh 16` en 17/17 y leíste la [teoría 04](../1-teoria/04-el-apiserver-verifica-el-token-oidc.md),
la [teoría 05](../1-teoria/05-rbac-y-pod-security-por-environment.md) y la
[teoría 06](../1-teoria/06-credenciales-de-corta-vida-en-el-runner.md). Trae la versión nueva del
laboratorio y deja preparada la terminal:

```bash
git -C ~/code/bc-github-actions pull --ff-only
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
source ~/.config/tablero-arc/app.env
ls ~/code/bc-github-actions/lab
# authentication-config.yaml
# kind-config.yaml
```

---

## Paso 1: Un clúster con la configuración OIDC montada

**Por qué**: el apiserver solo lee `--authentication-config` al arrancar y desde un archivo de su
propio sistema de archivos. En kind, ese sistema es el contenedor `gha-control-plane`, así que el
archivo tiene que llegar por un montaje que se declara **al crear el clúster**: no se puede
añadir a uno que ya existe. El `lab-up.sh` nuevo monta `~/.config/tablero-kind/` en
`/etc/kubernetes/auth` del control plane y pasa el flag al apiserver por `kubeadmConfigPatches`.
Si en esa carpeta no hay ninguna configuración, copia `lab/authentication-config.yaml`, que confía
en el emisor de GitHub pero **rechaza todos los tokens** (su única regla es `"false"`): el
clúster nace cerrado.

Con el clúster de la Semana 16 en marcha, el script se niega a seguir:

```bash
~/code/bc-github-actions/scripts/lab-up.sh
# El clúster gha es anterior a la Semana 17 (sin configuración OIDC).
# Recréalo: ./scripts/lab-down.sh && ./scripts/lab-up.sh
```

> ⚠️ **Advertencia — recrear el clúster**: `lab-down.sh` borra el clúster `gha` y **todo lo que
> corre dentro**: el controller de ARC, el scale set `tablero-runners`, el secret
> `tablero-arc-app` y cualquier pod. No hay nada que respaldar: la clave de la App sigue en
> `~/.config/tablero-arc/` y `ops/arc/install.sh` lo reconstruye todo. Desinstala antes ARC con
> Helm, en orden inverso, para que el controller borre el registro del scale set en GitHub
> ([teoría 02 de la Semana 16](../../week-16-actions_runner_controller_en_kind/1-teoria/02-helm-lo-justo.md)).

**Comando**:

```bash
helm uninstall tablero-runners --kube-context kind-gha -n arc-runners --wait
helm uninstall arc --kube-context kind-gha -n arc-systems --wait
~/code/bc-github-actions/scripts/lab-down.sh
~/code/bc-github-actions/scripts/lab-up.sh
ops/arc/install.sh
```

**Verifica**: el flag en el manifiesto del apiserver, el archivo montado y ARC de vuelta:

```bash
docker exec gha-control-plane grep -o -- '--authentication-config=.*' /etc/kubernetes/manifests/kube-apiserver.yaml
# --authentication-config=/etc/kubernetes/auth/authentication-config.yaml
cmp ~/code/bc-github-actions/lab/authentication-config.yaml ~/.config/tablero-kind/authentication-config.yaml && echo cerrado
# cerrado
kubectl --context kind-gha logs -n kube-system -l component=kube-apiserver --tail=-1 |
  grep -q 'OIDC: No x509 certificates provided' && echo oidc-cargado
# oidc-cargado
helm list -A --kube-context kind-gha -o json | jq -r '[.[] | .namespace + "/" + .name + " " + .status] | sort | .[]'
# arc-runners/tablero-runners deployed
# arc-systems/arc deployed
```

El log dice que el apiserver aceptó la configuración y que comprobará el TLS del emisor con los CA
del sistema: `token.actions.githubusercontent.com` tiene un certificado público.

---

## Paso 2: El CA del clúster en el pod del runner

**Por qué**: Helm, desde el runner, hablará con `https://kubernetes.default.svc`. Para no
aceptar a cualquiera que conteste en esa dirección necesita el CA del clúster. El pod no monta
nada de Kubernetes (`automountServiceAccountToken: false` desde la Semana 16), y así debe
seguir: el token de una ServiceAccount sería una identidad del pod, válida para cualquier job.
Kubernetes publica el CA, que **no es una credencial**, en el ConfigMap `kube-root-ca.crt` de
cada namespace. Montas solo eso.

**Comando**: en `ops/arc/values.yaml`, dentro de `template.spec`, añade al contenedor `runner` el
montaje y al pod el volumen:

```yaml
    containers:
      - name: runner
        # (image, command, securityContext y resources se quedan como estaban)
        # Semana 17: el CA del clúster, para que Helm compruebe el apiserver al que habla.
        volumeMounts:
          - name: kube-ca
            mountPath: /etc/kube-ca
            readOnly: true
    # Kubernetes publica el CA en un ConfigMap de cada namespace. No es una credencial: la
    # identidad del job es su token OIDC (deploy.yml).
    volumes:
      - name: kube-ca
        configMap:
          name: kube-root-ca.crt
```

```bash
ops/arc/install.sh >/dev/null
```

**Verifica**: la orden de `runner-mounts-kube-ca`:

```bash
yq '"automount=" + (.template.spec.automountServiceAccountToken | tostring) + " ca=" + ([.template.spec.volumes[] | select(.configMap.name == "kube-root-ca.crt") | .name] | join(",")) + " mount=" + ([.template.spec.containers[0].volumeMounts[] | .mountPath] | join(","))' ops/arc/values.yaml
# automount=false ca=kube-ca mount=/etc/kube-ca
```

Y desde dentro, con las funciones `probe` y `pexec` de la
[práctica 04 de la Semana 16](../../week-16-actions_runner_controller_en_kind/2-practicas/04-pod-del-runner-endurecido.md):

```bash
probe
# pod/runner-probe condition met
pexec curl -sS --cacert /etc/kube-ca/ca.crt https://kubernetes.default.svc/version | jq -r .gitVersion
# v1.37.0
pexec sh -c 'test -e /var/run/secrets/kubernetes.io && echo token || echo sin-token'
# sin-token
kubectl --context kind-gha delete pod runner-probe -n arc-runners
git add ops/arc/values.yaml
git commit -m "ci(arc): mount cluster ca in runner pods"
```

TLS verificado contra el CA real y ninguna identidad en el pod: la credencial llegará del job.

---

## Paso 3: El apiserver acepta solo los tokens de `deploy.yml`

**Por qué**: confiar en el emisor de GitHub, sin más, es confiar en **todos** los repos de
GitHub. Cada regla cierra una puerta ([teoría 04](../1-teoria/04-el-apiserver-verifica-el-token-oidc.md)):
la audiencia `kind-gha`, el **id** de `tablero` (un nombre se puede volver a ocupar; el id no),
la rama `main`, el workflow `deploy.yml` y un environment conocido. El usuario resultante es el
environment, y eso es lo que RBAC limitará en el paso 4.

El apiserver relee el archivo cuando cambia. Si lo escribes en sitio (`>`, un heredoc, el editor
guardando sobre él), puede leerlo a medias: en el laboratorio dio
`"failed to load authentication config" err="empty config data"`. Por eso se copia a un temporal
**en la misma carpeta** y se renombra con `mv`, que cambia el archivo de una vez.

**Comando**: crea `ops/cluster/authentication-config.yaml`:

```yaml
# Configuración OIDC del apiserver de kind-gha: el clúster es quien verifica el token del job,
# como haría la nube. Se copia a ~/.config/tablero-kind/, que lab-up.sh monta en el control
# plane; el apiserver la recarga solo al cambiar. Los claims son de GitHub y van como texto.
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt:
  - issuer:
      url: https://token.actions.githubusercontent.com
      # deploy.yml pide el token con esta audiencia: un token para otro destino no sirve aquí.
      audiences: [kind-gha]
    claimValidationRules:
      # El id no cambia si alguien renombra el repo o crea otro con el mismo nombre.
      - expression: "claims.repository_id == '<id-de-tablero>'"
        message: el token no es de tablero
      - expression: "claims.ref == 'refs/heads/main'"
        message: solo se despliega desde main
      - expression: "claims.job_workflow_ref == '<tu-org>/tablero/.github/workflows/deploy.yml@refs/heads/main'"
        message: solo deploy.yml despliega
      - expression: "has(claims.environment) && claims.environment in ['staging', 'production']"
        message: solo los environments staging y production
    claimMappings:
      # El usuario de Kubernetes es el environment: RBAC (ops/cluster/access.yaml) da a cada uno
      # solo su namespace.
      username:
        expression: "'github:' + claims.environment"
```

Pon el id real y tu organización (el id va entre comillas: en el token es texto):

```bash
id=$(gh api repos/{owner}/{repo} --jq .id)
sed -i "s/<id-de-tablero>/$id/; s|<tu-org>/tablero|$GH_REPO|" ops/cluster/authentication-config.yaml
grep -c '<' ops/cluster/authentication-config.yaml
# 0
```

Instálalo en la carpeta montada con copia y renombrado, y espera a que el apiserver lo recargue
(entre 10 s y 1 min):

```bash
dir=~/.config/tablero-kind
cp ops/cluster/authentication-config.yaml "$dir/.authentication-config.yaml.tmp"
mv "$dir/.authentication-config.yaml.tmp" "$dir/authentication-config.yaml"
h=$(sha256sum ops/cluster/authentication-config.yaml | cut -d' ' -f1)
until kubectl --context kind-gha get --raw /metrics | grep -q "hash=\"sha256:$h\""; do sleep 10; done
```

**Verifica**: las órdenes de `oidc-authn-config` y `apiserver-oidc-config-loaded`, y el log:

```bash
f=ops/cluster/authentication-config.yaml
printf 'issuer=%s aud=%s repo=%s workflow=%s\n' "$(yq '.jwt[0].issuer.url' $f)" \
  "$(yq '.jwt[0].issuer.audiences | join(",")' $f)" "$(grep -cF "claims.repository_id == '$id'" $f)" \
  "$(grep -cF "claims.job_workflow_ref == '$GH_REPO/.github/workflows/deploy.yml@refs/heads/main'" $f)"
# issuer=https://token.actions.githubusercontent.com aud=kind-gha repo=1 workflow=1
kubectl --context kind-gha get --raw /metrics | grep -c "^apiserver_authentication_config_controller_last_config_info{.*hash=\"sha256:$h\"}"
# 1
kubectl --context kind-gha logs -n kube-system -l component=kube-apiserver --tail=-1 |
  grep -q 'reloaded authentication config' && echo recargado
# recargado
```

El hash de la métrica es el `sha256sum` del archivo que tienes en el repo: el apiserver tiene
cargado exactamente ese, no uno parecido. Por último, un token que no es de GitHub:

```bash
server=$(kubectl config view --minify --context kind-gha -o jsonpath='{.clusters[0].cluster.server}')
ca=$(mktemp)
kubectl config view --raw --minify --context kind-gha \
  -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > "$ca"
curl -sS --cacert "$ca" -H 'Authorization: Bearer no-es-un-token' "$server/api" | jq -r '"\(.code) \(.message)"'
# 401 Unauthorized
```

El apiserver contesta, pero no reconoce a nadie: es lo que verá todo token que no pase las reglas.

```bash
git add ops/cluster/authentication-config.yaml
git commit -m "ci(cluster): trust github oidc tokens from deploy.yml"
```

---

## Paso 4: Un namespace y un Role por environment

**Por qué**: el paso 3 dice **quién** es el job (`github:staging` o `github:production`); RBAC
dice **qué** puede hacer. Cada usuario recibe un Role en su namespace con lo que crea el chart
(Secrets, Services, PVC y Deployments) y lectura de pods, eventos y ReplicaSets para esperar el
rollout. Nada de clúster, nada de comodines: un token robado de staging no toca production
([teoría 05](../1-teoria/05-rbac-y-pod-security-por-environment.md)). Y la etiqueta
`pod-security.kubernetes.io/enforce: restricted` hace que el namespace rechace cualquier pod con
root, escalada, capacidades o sin seccomp, venga del chart o de quien sea.

**Comando**: crea `ops/cluster/access.yaml` con la mitad de staging:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tablero-staging
  labels:
    # Kubernetes rechaza cualquier pod con root, escalada, capacidades o sin seccomp.
    pod-security.kubernetes.io/enforce: restricted
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployer
  namespace: tablero-staging
rules:
  # Lo que crea el chart, más los secrets donde Helm guarda cada revisión.
  - apiGroups: [""]
    resources: [secrets, services, persistentvolumeclaims]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [apps]
    resources: [deployments]
    verbs: [get, list, watch, create, update, patch, delete]
  # Solo lectura: para esperar el rollout y entender por qué falla.
  - apiGroups: [""]
    resources: [pods, events]
    verbs: [get, list, watch]
  - apiGroups: [apps]
    resources: [replicasets]
    verbs: [get, list, watch]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployer
  namespace: tablero-staging
subjects:
  # El usuario que el apiserver saca del token OIDC (ops/cluster/authentication-config.yaml).
  - kind: User
    name: github:staging
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: deployer
  apiGroup: rbac.authorization.k8s.io
```

La mitad de production es idéntica cambiando `staging` por `production`. Que sean iguales es la
idea: añádela derivándola de la primera, y aplica el archivo como administrador:

```bash
prod=$(sed 's/staging/production/g' ops/cluster/access.yaml)
printf -- '---\n%s\n' "$prod" >> ops/cluster/access.yaml
kubectl --context kind-gha apply -f ops/cluster/access.yaml
```

**Verifica**: las órdenes de `namespaces-restricted`, `rbac-per-environment` y
`cluster-rbac-applied`:

```bash
yq -N 'select(.kind == "Namespace") | .metadata.name + "=" + .metadata.labels."pod-security.kubernetes.io/enforce"' ops/cluster/access.yaml | sort | paste -sd" "
# tablero-production=restricted tablero-staging=restricted
yq -N 'select(.kind == "RoleBinding") | .metadata.namespace + "=" + (.subjects | map(.kind + "/" + .name) | join(","))' ops/cluster/access.yaml | sort | paste -sd" "
# tablero-production=User/github:production tablero-staging=User/github:staging
for u in staging production; do for n in staging production; do
  printf '%s@%s=%s ' $u $n "$(kubectl --context kind-gha auth can-i create deployments -n tablero-$n --as github:$u)"
done; done; echo
# staging@staging=yes staging@production=no production@staging=no production@production=yes
kubectl --context kind-gha auth can-i get secrets -n tablero-staging --as github:staging
# yes
kubectl --context kind-gha auth can-i create namespaces --as github:production
# no
```

`--as` es impersonación: preguntas qué podría hacer ese usuario sin tener su token.

```bash
git add ops/cluster/access.yaml
git commit -m "ci(cluster): add restricted namespaces and per-environment rbac"
git push
```

---

## ✅ Resultado

- [ ] `kind-gha` recreado con `--authentication-config` y ARC reinstalado con `install.sh`
- [ ] El pod del runner comprueba el TLS del apiserver con `/etc/kube-ca/ca.crt` y sigue sin token
- [ ] El apiserver tiene cargado el hash de tu `authentication-config.yaml` y rechaza un token falso con 401
- [ ] `github:staging` y `github:production` solo pueden desplegar en su namespace

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 17
# ...
# ✅ El apiserver de kind-gha tiene cargada exactamente ops/cluster/authentication-config.yaml
# ...
```

En verde, las seis de esta práctica: `namespaces-restricted`, `rbac-per-environment`,
`oidc-authn-config`, `runner-mounts-kube-ca`, `apiserver-oidc-config-loaded` y
`cluster-rbac-applied`. Las del chart y de `deploy.yml` llegan en las prácticas 02 y 03.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `El clúster gha es anterior a la Semana 17 (sin configuración OIDC).` | El clúster se creó con el `lab-up.sh` de la Semana 16 | Paso 1: desinstala ARC, `lab-down.sh` y `lab-up.sh` |
| `install.sh` falla con `falta APP_CLIENT_ID` | No cargaste las variables de la App en esta terminal | `source ~/.config/tablero-arc/app.env` |
| El bucle del paso 3 no termina | El apiserver no pudo cargar el archivo | `kubectl --context kind-gha logs -n kube-system -l component=kube-apiserver --tail=-1 \| grep 'authentication config'` y corrige lo que diga |
| `"failed to load authentication config" err="empty config data"` | Escribiste el archivo en sitio y el apiserver lo leyó a medias | Copia a un temporal de la misma carpeta y renómbralo con `mv` |
| `repo=0` en la verificación del paso 3 | El id quedó sin comillas o con el nombre del repo | `claims.repository_id == '<número>'`, con comillas simples |
| `staging@production=yes` | La mitad de production conserva un `github:staging` | Revisa los `subjects` de los RoleBinding y vuelve a aplicar |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Desplegar solo lo verificado](../1-teoria/07-desplegar-solo-lo-verificado.md) | [Chart y rollback con Helm](02-chart-y-rollback-con-helm.md) |
