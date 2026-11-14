# Práctica 02 — ARC con Helm

> ARC se reparte en dos charts de Helm: el controller, que vigila los recursos de ARC en todo el
> clúster, y el scale set, que declara los runners de `tablero`. Hoy instalas el primero con su
> versión fijada, desde un script que vive en el repo, y compruebas qué ha añadido a Kubernetes.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- El clúster `kind-gha` sano, con sus dos nodos en `Ready`
- Helm v4.3.2 instalado desde la release oficial y comprobado con su checksum
- `ops/arc/install.sh` instalando el controller de ARC desde su chart OCI con la versión fijada
- Las cuatro CRD de ARC en el clúster y el controller arrancado, leído en su propio log

## 📋 Antes de empezar

Terminaste la [práctica 01](01-github-app-para-arc.md) y leíste la
[teoría 02](../1-teoria/02-helm-lo-justo.md) y la [teoría 03](../1-teoria/03-arquitectura-de-arc.md).
Comprueba que el clúster sigue arriba y que sus dos nodos están listos:

```bash
cd ~/code/tablero
~/code/bc-github-actions/scripts/lab-up.sh >/dev/null
kubectl --context kind-gha get nodes --no-headers | awk '{print $1, $2}'
# gha-control-plane Ready
# gha-worker Ready
```

### Si `gha-worker` no llega a `Ready`: el límite de inotify

Cada nodo de kind es un contenedor que ejecuta su propio kubelet, y el kubelet y kube-proxy
vigilan archivos con **inotify**. El kernel limita las instancias de inotify por usuario, y en
WSL2 el límite por defecto es 128. Con otro clúster kind en marcha (o muchos contenedores), el
nodo nuevo se queda sin instancias: `lab-up.sh` espera y el worker no arranca. Los logs lo dicen
así:

```text
kubelet:    inotify_init: too many open files
kube-proxy: fsnotify watcher init: too many open files
```

Es un problema conocido de kind. Sube el límite:

```bash
sysctl fs.inotify.max_user_instances
# fs.inotify.max_user_instances = 128
sudo sysctl -w fs.inotify.max_user_instances=512
# fs.inotify.max_user_instances = 512
```

El cambio se pierde al reiniciar. Para que dure, déjalo en `/etc/sysctl.d/`:

```bash
echo 'fs.inotify.max_user_instances = 512' | sudo tee /etc/sysctl.d/99-kind.conf
```

> ⚠️ **Advertencia — recrear el clúster**: un nodo que arrancó sin inotify no se recupera solo:
> hay que borrar el clúster y volver a crearlo. `lab-down.sh` borra el clúster `gha` y **todo lo
> que corre dentro**, incluido el secret `tablero-arc-app` de la práctica 01. No hay nada que
> respaldar: la clave sigue en `~/.config/tablero-arc/` y el secret se rehace con el paso 4 de la
> práctica 01.

```bash
~/code/bc-github-actions/scripts/lab-down.sh
~/code/bc-github-actions/scripts/lab-up.sh
```

Con el límite en 512, los dos nodos llegan a `Ready` en torno a un minuto.

---

## Paso 1: Helm, verificado antes de usarlo

**Por qué**: Helm instala en tu clúster lo que diga un chart, con tus credenciales de
Kubernetes. Un binario manipulado podría instalar cualquier otra cosa. La regla 9 de seguridad
vale también para tus herramientas: versión fijada y checksum comprobado, nunca un
`curl | bash` ([reglas de seguridad](../../../docs/reglas-de-seguridad-de-workflows.md)).

Esta semana usas Helm **v4.3.2**, la versión de [`docs/stack-versions.md`](../../../docs/stack-versions.md).
La release publica, junto a cada archivo, otro `.sha256sum` con su hash en el formato que
`sha256sum -c` entiende.

**Comando**: descarga en un directorio temporal, verifica y solo entonces instala:

```bash
cd "$(mktemp -d)"
curl -fsSLO https://get.helm.sh/helm-v4.3.2-linux-amd64.tar.gz
curl -fsSLO https://get.helm.sh/helm-v4.3.2-linux-amd64.tar.gz.sha256sum
sha256sum -c helm-v4.3.2-linux-amd64.tar.gz.sha256sum
# helm-v4.3.2-linux-amd64.tar.gz: OK
tar -xzf helm-v4.3.2-linux-amd64.tar.gz linux-amd64/helm
install -m 0755 linux-amd64/helm ~/.local/bin/helm
cd ~/code/tablero
```

Si `sha256sum -c` no dice `OK`, para: no extraigas nada y vuelve a descargar los dos archivos.

**Verifica**:

```bash
helm version --template '{{.Version}}{{"\n"}}'
# v4.3.2
command -v helm
# /home/<tu-usuario>/.local/bin/helm
```

---

## Paso 2: El controller desde `install.sh`

**Por qué**: instalar ARC a mano funciona una vez. Con un script en el repo, reconstruir ARC en un
kind recién creado es una orden, y cada cambio de versión pasa por un PR que alguien revisa.

Tres decisiones del script:

- **`ARC_VERSION` en una sola línea**. El controller y el scale set salen de la misma release de
  ARC y deben ir siempre a la par: versiones distintas no se garantizan. Sin `--version`, Helm
  instala la última que encuentre, y tu clúster cambia sin que cambie tu repo.
- **Los charts OCI oficiales**, en `oci://ghcr.io/actions/actions-runner-controller-charts`: no
  hace falta `helm repo add`.
- **`upgrade --install` con `--wait`**: instala si no existe y actualiza si existe, y no termina
  hasta que el controller está en marcha. El scale set no puede ir antes: su chart busca el
  deployment del controller en el clúster para darle permisos, y sin él falla con
  `No gha-rs-controller deployment found`.

Todo lleva `--kube-context kind-gha`: el script nunca toca otro clúster aunque cambies el
contexto activo de `kubectl`.

**Comando**: crea `ops/arc/install.sh`:

```bash
#!/usr/bin/env bash
#
# install.sh — instala ARC en el clúster kind del laboratorio (contexto kind-gha):
#   controller en arc-systems.
#
# Idempotente: repetirlo actualiza la release.

set -euo pipefail

# Controller y scale set salen de la misma release de ARC: versiones distintas no se garantizan.
ARC_VERSION=0.15.1
CHARTS=oci://ghcr.io/actions/actions-runner-controller-charts
KUBE=(--kube-context kind-gha)

helm upgrade --install arc "${KUBE[@]}" --namespace arc-systems --create-namespace \
  --version "$ARC_VERSION" "$CHARTS/gha-runner-scale-set-controller" --wait
```

```bash
chmod +x ops/arc/install.sh
ops/arc/install.sh
```

La release se llama `arc`: de ahí sale el nombre del deployment, `arc-gha-rs-controller`, que
usarás en los logs.

**Verifica**: la orden de `arc-charts-pinned`:

```bash
f=ops/arc/install.sh
printf 'version=%s pinned=%s charts=%s\n' "$(grep -oE '^ARC_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' $f)" \
  "$(grep -c -- '--version "\$ARC_VERSION"' $f)" "$(grep -c 'oci://ghcr.io/actions/actions-runner-controller-charts' $f)"
# version=ARC_VERSION=0.15.1 pinned=1 charts=1
```

`pinned=1` es lo esperado hoy: el check pide `2` y el segundo `--version "$ARC_VERSION"` llega
con el scale set en la [práctica 03, paso 3](03-scale-set-de-tablero.md#paso-3-installsh-completo-y-el-listener).
Y en el clúster:

```bash
helm list -A --kube-context kind-gha -o json | jq -r '.[] | .namespace + "/" + .name + " " + .chart + " " + .status'
# arc-systems/arc gha-runner-scale-set-controller-0.15.1 deployed
kubectl --context kind-gha get deploy arc-gha-rs-controller -n arc-systems \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
# ghcr.io/actions/gha-runner-scale-set-controller:0.15.1
```

Lánzalo otra vez: no falla, y la release pasa a la revisión 2.

```bash
ops/arc/install.sh >/dev/null
helm list -n arc-systems --kube-context kind-gha -o json | jq -r '.[0].revision'
# 2
git add ops/arc/install.sh
git commit -m "ci(arc): install arc controller with pinned chart version"
```

---

## Paso 3: Lo que el controller añade a Kubernetes

**Por qué**: Kubernetes no sabe qué es un scale set ni un runner efímero. El chart del controller
le enseña cuatro tipos nuevos, las **CRD**, y arranca un proceso que los vigila: cuando aparezca
un `AutoscalingRunnerSet`, el controller creará el listener y, para cada job, un
`EphemeralRunner` con su pod ([teoría 01](../1-teoria/01-kubernetes-lo-justo.md)). Es el patrón
CRD + controller: tú declaras qué quieres, el controller lo hace realidad.

**Comando**:

```bash
kubectl --context kind-gha api-resources --api-group=actions.github.com -o name
kubectl --context kind-gha get autoscalingrunnersets,ephemeralrunners -A -o name
```

**Verifica**:

```bash
kubectl --context kind-gha api-resources --api-group=actions.github.com -o name
# autoscalinglisteners.actions.github.com
# autoscalingrunnersets.actions.github.com
# ephemeralrunners.actions.github.com
# ephemeralrunnersets.actions.github.com
kubectl --context kind-gha get autoscalingrunnersets,ephemeralrunners -A -o name | wc -l
# 0
```

Cuatro tipos y ningún objeto de ellos: el controller está listo, pero aún no le has pedido nada.
Eso llega en la práctica 03, con el scale set de `tablero`.

---

## Paso 4: Leer el log del controller

**Por qué**: cuando un job se queda en cola, la UI de Actions solo dice "Queued". El que sabe por
qué es el controller: si no puede autenticarse con la App, si no encuentra el secret o si no
consigue crear el listener, lo escribe en su log. Aprender a leerlo ahora, con el log limpio, te
ahorra buscar el fallo en GitHub cuando aparezca.

Al arrancar, el controller dice su versión y pone en marcha un bucle de trabajo por cada tipo de
recurso que vigila: uno por CRD.

**Comando**:

```bash
kubectl --context kind-gha logs -n arc-systems deploy/arc-gha-rs-controller | head -20
```

`deploy/arc-gha-rs-controller` elige el pod del deployment por ti: no tienes que copiar el sufijo
aleatorio de su nombre.

**Verifica**:

```bash
kubectl --context kind-gha logs -n arc-systems deploy/arc-gha-rs-controller | grep -c 'starting manager.*"0.15.1"'
# 1
kubectl --context kind-gha logs -n arc-systems deploy/arc-gha-rs-controller | grep -c 'Starting workers'
# 4
```

Cuatro bucles, uno por CRD del paso 3. Desde la práctica 03, la orden que más vas a usar es la de
los errores:

```bash
kubectl --context kind-gha logs -n arc-systems deploy/arc-gha-rs-controller | grep -i error
```

Hoy no imprime nada relevante: no hay scale set con el que equivocarse.

```bash
git push
git status --short ops/arc
# (sin salida)
```

---

## ✅ Resultado

- [ ] Los dos nodos de `kind-gha` están en `Ready`
- [ ] Helm v4.3.2 instalado tras `sha256sum -c` en `OK`
- [ ] `ops/arc/install.sh` ejecutable, con `ARC_VERSION` en una línea y el chart OCI oficial
- [ ] La release `arc` desplegada en `arc-systems` con el chart 0.15.1
- [ ] Las cuatro CRD de ARC en el clúster y el controller arrancado según su log

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 16
# ...
# ❌ install.sh instala el controller y el scale set desde los charts OCI oficiales de ARC con la misma versión fijada
# ...
```

Sigue en rojo a propósito: el scale set aún no está en el script. La práctica 03 lo añade.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `gha-worker` en `NotReady` y el kubelet dice `inotify_init: too many open files` | Límite de inotify del host | `sudo sysctl -w fs.inotify.max_user_instances=512` y recrea el clúster (antes de empezar) |
| El controller registra `dial tcp 10.96.0.1:443: i/o timeout` | El nodo arrancó sin inotify y kube-proxy no funciona | Lo mismo: sube el límite y recrea el clúster |
| `sha256sum -c` dice `FAILED` | Descarga corrupta o incompleta | Borra los dos archivos y descárgalos de nuevo; no instales nunca un binario que no pasa |
| `helm: command not found` | `~/.local/bin` no está en tu `PATH` | Añádelo en tu `~/.zshrc` o `~/.bashrc` y abre otra terminal |
| `Error: kubernetes cluster unreachable: context "kind-gha" does not exist` | El clúster no está levantado | `~/code/bc-github-actions/scripts/lab-up.sh` |
| `No gha-rs-controller deployment found` | Se intentó instalar el scale set antes que el controller | Instala primero el controller: `install.sh` respeta ese orden |
| `pinned=0` en la verificación del paso 2 | `--version $ARC_VERSION` sin comillas o con otro nombre de variable | Escríbelo exactamente `--version "$ARC_VERSION"` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Una GitHub App para ARC](01-github-app-para-arc.md) | [El scale set de tablero](03-scale-set-de-tablero.md) |
