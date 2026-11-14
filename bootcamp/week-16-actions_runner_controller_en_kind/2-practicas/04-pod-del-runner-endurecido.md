# Práctica 04 — El pod del runner endurecido

> `lab.yml` ya corre en ARC, pero en un pod con lo que el chart trae por defecto: la imagen sin
> digest, el token de la API de Kubernetes montado y ningún límite. Hoy le das al pod lo mismo
> que diste al contenedor de la Semana 15, en el idioma de Kubernetes, y compruebas desde dentro
> qué puede hacer un job con malas intenciones.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- El contenedor `runner` con la misma imagen y el mismo digest que `ops/runner/Dockerfile`
- El pod como uid 1001, sin root, sin escalada, sin capacidades y con seccomp `RuntimeDefault`
- El pod sin token de la API de Kubernetes y sin `containerMode`
- Límites de CPU y memoria que el kernel aplica de verdad
- `lab.yml` otra vez en verde, ahora en el pod endurecido

## 📋 Antes de empezar

Terminaste la [práctica 03](03-scale-set-de-tablero.md) y leíste la
[teoría 06](../1-teoria/06-modos-de-contenedor.md) y la
[teoría 07](../1-teoria/07-endurecer-el-pod-del-runner.md).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
source ~/.config/tablero-arc/app.env
```

Los runners de verdad solo existen mientras dura un job. Para mirar dentro del pod con calma,
creas uno **de prueba** a partir de la plantilla que el scale set tiene aplicada en el clúster,
cambiando solo su orden por `sleep 600`: mismo usuario, misma imagen, mismos límites, pero sin
arrancar `run.sh`, así que no se registra en GitHub. Define estas dos funciones en tu terminal:

```bash
# Recrea el pod runner-probe con la plantilla actual de tablero-runners.
probe() {
  kubectl --context kind-gha delete pod runner-probe -n arc-runners --ignore-not-found >/dev/null
  kubectl --context kind-gha get autoscalingrunnerset tablero-runners -n arc-runners -o json |
    jq '{apiVersion: "v1", kind: "Pod", metadata: {name: "runner-probe"},
         spec: (.spec.template.spec | .containers[0].command = ["sleep", "600"])}' |
    kubectl --context kind-gha apply -n arc-runners -f - >/dev/null
  kubectl --context kind-gha wait pod/runner-probe -n arc-runners --for=condition=Ready --timeout=180s
}
# Ejecuta una orden dentro del pod de prueba.
pexec() { kubectl --context kind-gha exec -n arc-runners runner-probe -- "$@"; }
```

`probe` borra antes el pod `runner-probe` si existe: es tuyo y no guarda nada. Nunca la cambies
para borrar un pod `tablero-runners-…-runner-…`: ese pod es un job en marcha.

---

## Paso 1: La imagen de la Semana 15, por digest

**Por qué**: un tag se puede mover; un digest no. Con `actions-runner:2.338.2`, el día que alguien
vuelva a publicar ese tag tus jobs correrán en otra imagen sin que cambie una línea de tu repo.
Con el digest, Kubernetes baja exactamente la imagen que revisaste.

La imagen ya está fijada en `ops/runner/Dockerfile` desde la Semana 15, y Dependabot vigila ese
archivo: cuando sale una versión del runner, abre un PR. Dependabot no garantiza vigilar también
`values.yaml`, así que no dependes de eso: el check `arc-runner-image-matches` exige que las dos
líneas sean **idénticas**. Si Dependabot actualiza el Dockerfile, el check se pone rojo hasta que
copies el nuevo `FROM` a `values.yaml`. Una fuente que se vigila y un check que impide que la
otra se quede atrás.

**Comando**: copia la imagen del Dockerfile:

```bash
sed -n 's/^FROM //p' ops/runner/Dockerfile
# ghcr.io/actions/actions-runner:2.338.2@sha256:6d0b2d80d80f143f77dcb676e50920100bbb547e39e883454d57f45ab8c31300
```

Y pégala en el contenedor `runner` de `ops/arc/values.yaml`:

```yaml
    containers:
      - name: runner
        # La misma imagen y el mismo digest que ops/runner/Dockerfile, que vigila Dependabot.
        image: ghcr.io/actions/actions-runner:2.338.2@sha256:6d0b2d80d80f143f77dcb676e50920100bbb547e39e883454d57f45ab8c31300
        command: ["/home/runner/run.sh"]
```

Si tu Dockerfile tiene un digest más nuevo, usa el tuyo: lo que cuenta es que coincidan.

```bash
ops/arc/install.sh >/dev/null
```

**Verifica**: la orden de `arc-runner-image-matches` y la plantilla aplicada en el clúster:

```bash
a=$(yq '.template.spec.containers[] | select(.name == "runner") | .image' ops/arc/values.yaml)
b=$(sed -n 's/^FROM //p' ops/runner/Dockerfile)
[ -n "$a" ] && [ "$a" = "$b" ] && echo "$a"
# ghcr.io/actions/actions-runner:2.338.2@sha256:6d0b2d80d80f143f77dcb676e50920100bbb547e39e883454d57f45ab8c31300
kubectl --context kind-gha get autoscalingrunnerset tablero-runners -n arc-runners \
  -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -c '@sha256:'
# 1
```

---

## Paso 2: Sin root, sin escalada, sin capacidades, sin token

**Por qué**: es el endurecimiento de la Semana 15 traducido a un pod
([teoría 07](../1-teoria/07-endurecer-el-pod-del-runner.md)):

| Semana 15 (`docker run`) | Semana 16 (`values.yaml`) |
|---|---|
| `--user 1001:1001` | `securityContext.runAsUser` y `runAsGroup` del pod |
| `--security-opt no-new-privileges` | `allowPrivilegeEscalation: false` del contenedor |
| `--cap-drop ALL` | `capabilities.drop: [ALL]` del contenedor |
| seccomp por defecto de Docker | `seccompProfile.type: RuntimeDefault` |
| (no había API que proteger) | `automountServiceAccountToken: false` |

Dos detalles que no son obvios:

- **`runAsNonRoot` sin `runAsUser` no arranca.** La imagen declara `USER runner`, un **nombre**.
  Kubernetes no puede comprobar que un nombre no es root, así que se niega a crear el contenedor.
  Con `runAsUser: 1001` le das el número.
- **El token de la API.** Kubernetes monta en cada pod, por defecto, un token de su service
  account. Un job no lo necesita para nada; un job malicioso lo usaría para hablar con la API del
  clúster. Sin montarlo, no hay nada que robar.

Y lo que **no** hay: `containerMode`. Ni `dind`, que añade un contenedor privilegiado, ni
`kubernetes`, que necesita volúmenes y permisos sobre la API. Los jobs de `tablero` no necesitan
Docker dentro del runner ([teoría 06](../1-teoria/06-modos-de-contenedor.md)).

**Comando**: deja el bloque `template` de `ops/arc/values.yaml` así:

```yaml
# Sin containerMode: ni dind (privilegiado) ni kubernetes. Los jobs de tablero no necesitan
# Docker dentro del runner.
template:
  spec:
    # El runner no habla con la API de Kubernetes: sin token montado, un job no puede usarla.
    automountServiceAccountToken: false
    securityContext:
      # La imagen declara USER runner (nombre): runAsNonRoot exige un uid numérico.
      runAsNonRoot: true
      runAsUser: 1001
      runAsGroup: 1001
      seccompProfile:
        type: RuntimeDefault
    containers:
      - name: runner
        # La misma imagen y el mismo digest que ops/runner/Dockerfile, que vigila Dependabot.
        image: ghcr.io/actions/actions-runner:2.338.2@sha256:6d0b2d80d80f143f77dcb676e50920100bbb547e39e883454d57f45ab8c31300
        command: ["/home/runner/run.sh"]
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: [ALL]
```

```bash
ops/arc/install.sh >/dev/null
probe
# pod/runner-probe condition met
```

**Verifica**: las órdenes de `runner-pod-nonroot`, `runner-pod-no-k8s-token` y `arc-no-dind`:

```bash
yq '.template.spec as $p | ($p.containers[] | select(.name == "runner")) as $c | "nonroot=" + ($p.securityContext.runAsNonRoot | tostring) + " uid=" + ($p.securityContext.runAsUser | tostring) + " escalation=" + ($c.securityContext.allowPrivilegeEscalation | tostring) + " drop=" + ($c.securityContext.capabilities.drop | join(","))' ops/arc/values.yaml
# nonroot=true uid=1001 escalation=false drop=ALL
yq '.template.spec.automountServiceAccountToken' ops/arc/values.yaml
# false
printf 'mode=%s privileged=%s\n' "$(yq '.containerMode.type // "none"' ops/arc/values.yaml)" \
  "$(grep -c 'privileged: *true' ops/arc/values.yaml)"
# mode=none privileged=0
```

Y desde dentro del pod:

```bash
pexec id
# uid=1001(runner) gid=1001(runner) groups=1001(runner),27(sudo),100(users),123(docker)
pexec sh -c 'test -e /var/run/secrets/kubernetes.io && echo token || echo sin-token'
# sin-token
```

El usuario sigue en el grupo `sudo`: la imagen es la oficial y no la cambias. Lo que lo deja sin
efecto lo ves en el paso 4.

Para ver con tus ojos por qué hace falta `runAsUser`, crea un segundo pod igual pero sin él:

```bash
kubectl --context kind-gha get autoscalingrunnerset tablero-runners -n arc-runners -o json |
  jq '{apiVersion: "v1", kind: "Pod", metadata: {name: "runner-probe-nouid"},
       spec: (.spec.template.spec | .containers[0].command = ["sleep", "600"]
              | del(.securityContext.runAsUser, .securityContext.runAsGroup))}' |
  kubectl --context kind-gha apply -n arc-runners -f -
sleep 10
kubectl --context kind-gha get pod runner-probe-nouid -n arc-runners \
  -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}{"\n"}'
# CreateContainerConfigError
```

El motivo completo está en `kubectl describe pod`: `container has runAsNonRoot and image has
non-numeric user (runner), cannot verify user is non-root`.

> ⚠️ **Advertencia**: vas a borrar un pod. Comprueba el nombre: tiene que ser
> `runner-probe-nouid`, el que acabas de crear. No contiene nada.

```bash
kubectl --context kind-gha delete pod runner-probe-nouid -n arc-runners
# pod "runner-probe-nouid" deleted from arc-runners namespace
```

---

## Paso 3: Límites que el kernel aplica

**Por qué**: sin límites, un job que se desboca (un test que reserva memoria sin parar, un bucle
que no termina) se come el nodo de kind, y con él tu máquina. Kubernetes reparte dos cosas:

- **`requests`**: lo que el pod tiene garantizado; el planificador solo lo coloca en un nodo con
  ese hueco libre.
- **`limits`**: el techo. Por encima del límite de memoria el kernel mata el proceso; por encima
  del de CPU, lo frena.

Con `maxRunners: 2`, el peor caso son dos pods de 4 GiB y 2 CPU. Si tu máquina va justa, baja
los límites: el check solo exige que existan.

**Comando**: añade `resources` al contenedor `runner`, debajo de su `securityContext`:

```yaml
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: "2"
            memory: 4Gi
```

`cpu: "2"` va entre comillas para que YAML lo lea como texto, igual que lo escribe Kubernetes.

```bash
ops/arc/install.sh >/dev/null
probe
# pod/runner-probe condition met
```

**Verifica**: la orden de `runner-pod-limits` y lo que ve el kernel dentro del pod:

```bash
yq '.template.spec.containers[] | select(.name == "runner") | .resources.limits | "cpu=" + (.cpu // "" | tostring) + " memory=" + (.memory // "" | tostring)' ops/arc/values.yaml
# cpu=2 memory=4Gi
pexec cat /sys/fs/cgroup/memory.max /sys/fs/cgroup/cpu.max
# 4294967296
# 200000 100000
```

`4294967296` bytes son 4 GiB. `200000 100000` significa 200 ms de CPU por cada 100 ms de
reloj: dos CPU. Los límites no son una etiqueta: están en el cgroup del contenedor.

---

## Paso 4: Lo que ve un job con malas intenciones

**Por qué**: el endurecimiento se demuestra desde dentro. Un paso malicioso de un job (una
dependencia comprometida, un script inyectado) intentaría, por orden: hacerse root, robar el
token de Kubernetes y hablar con la API del clúster para leer secrets, como el de la App.

**Comando**: intenta los dos primeros, en el pod de prueba:

```bash
pexec sudo -n id
# sudo: The "no new privileges" flag is set, which prevents sudo from running as root.
# ...
pexec cat /var/run/secrets/kubernetes.io/serviceaccount/token
# cat: /var/run/secrets/kubernetes.io/serviceaccount/token: No such file or directory
# ...
```

**Verifica**:

```bash
pexec sudo -n true 2>&1 | head -1
# sudo: The "no new privileges" flag is set, which prevents sudo from running as root.
pexec grep -E '^(CapEff|NoNewPrivs):' /proc/self/status
# CapEff:	0000000000000000
# NoNewPrivs:	1
pexec sh -c 'curl -sk -m5 -o /dev/null -w "%{http_code}\n" "https://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/arc-runners/secrets"'
# 403
```

`sudo` no puede subir a root, el proceso no tiene ninguna capacidad y la API contesta `403`: sin
token, el job es un anónimo y no puede leer nada.

Con `containerMode: dind` todo esto daría igual. El chart añade al pod un contenedor
`docker:dind` **privilegiado**: todas las capacidades, todos los dispositivos, sin seccomp. Un
job que habla con ese Docker arranca un contenedor que monta `/` del nodo y es root en él. El
`values.yaml` del chart lo deja escrito:

```bash
helm show values oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --version 0.15.1 | grep -c 'privileged: true'
# 1
```

> ⚠️ **Advertencia**: borras el pod de prueba. Comprueba que es `runner-probe`; los pods
> `tablero-runners-…-runner-…` son jobs reales y no se tocan.

```bash
kubectl --context kind-gha delete pod runner-probe -n arc-runners
# pod "runner-probe" deleted from arc-runners namespace
git add ops/arc/values.yaml
git commit -m "ci(arc): harden runner pod"
git push
gh workflow run lab.yml --ref main
sleep 5
gh run watch "$(gh run list --workflow lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
```

El último commit de `main` cambió, así que `lab.yml` tiene que volver a pasar, ahora en el pod
endurecido: `uv`, `pytest` y `actions/checkout` no necesitan root, capacidades ni la API.

**Verifica**: el run, en un pod de ARC, y nada sobrante en el namespace:

```bash
git fetch -q origin main
id=$(gh run list --workflow lab.yml --commit "$(git rev-parse origin/main)" --json databaseId --jq '.[0].databaseId')
gh api "repos/{owner}/{repo}/actions/runs/$id/jobs" \
  --jq '.jobs[0] | "conclusion=\(.conclusion) runner=\(.runner_name) labels=\(.labels | join(","))"'
# conclusion=success runner=tablero-runners-<x>-runner-<y> labels=tablero-runners
kubectl --context kind-gha get pods -n arc-runners -o name | wc -l
# 0
```

---

## ✅ Resultado

- [ ] El contenedor `runner` usa exactamente la imagen de `ops/runner/Dockerfile`
- [ ] El pod corre como uid 1001, sin root, sin escalada, sin capacidades y con seccomp
- [ ] El pod no monta el token de Kubernetes y no hay `containerMode`
- [ ] Los límites de CPU y memoria se ven en el cgroup del contenedor
- [ ] `sudo`, las capacidades y la API fallan desde dentro del pod
- [ ] `lab.yml` en verde en el último commit de `main`, sin pods de prueba en `arc-runners`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 16
# ...
# 17/17 comprobaciones superadas.
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `arc-runner-image-matches` en rojo | La imagen de `values.yaml` no es idéntica al `FROM` del Dockerfile | Cópiala con el `sed` del paso 1, sin retocarla |
| `probe` se queda esperando y acaba en `timed out` | El pod no arranca: imagen que no baja o `securityContext` que no cuadra | `kubectl --context kind-gha describe pod runner-probe -n arc-runners` y mira los eventos |
| `CreateContainerConfigError`: `image has non-numeric user (runner)` | `runAsNonRoot` sin `runAsUser` | Paso 2: `runAsUser: 1001` |
| El pod queda en `Pending` con `Insufficient memory` | Los `requests` no caben en el nodo | Baja `requests.memory` en el paso 3 |
| `runner-pod-limits` en rojo con `cpu=` vacío | Los límites están en el pod o en otro contenedor | Van en `resources.limits` del contenedor `runner` |
| `lab.yml` falla con `OOMKilled` | El límite de memoria es menor que lo que usan los tests | Sube `limits.memory` y relanza `install.sh` |
| `lab-green-on-arc` en rojo tras tu último commit | El run verde es de un commit anterior | Lanza `lab.yml` otra vez (paso 4) |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [El scale set de tablero](03-scale-set-de-tablero.md) | [Proyecto: capa 16 de tablero](../3-proyecto/README.md) |
