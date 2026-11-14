# Kubernetes, lo justo

> ARC no es un programa que arrancas: es un conjunto de objetos de Kubernetes que se vigilan
> unos a otros. Para operarlo te basta con siete piezas de Kubernetes y un puñado de comandos.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué hace kind y por qué el laboratorio usa un clúster `gha` con dos nodos
- Usar `kubectl` siempre contra el contexto correcto, `kind-gha`
- Distinguir pod, namespace, secret y service account, y decir para qué los usa ARC
- Explicar por qué un secret de Kubernetes no está cifrado y qué lo protege de verdad
- Describir el patrón CRD + controller con el que ARC convierte un YAML en pods

## 1. Qué problema resuelve

El bucle de la Semana 15 funciona, pero tiene tres límites que se notan en cuanto hay más de un
job:

| Límite del bucle | Qué hace falta |
|---|---|
| Un runner cada vez: el segundo job espera a que acabe el primero | Varios contenedores a la vez, con un máximo |
| Si el script muere, nadie lo vuelve a arrancar | Algo que vigile y reconcilie el estado |
| La credencial vive en tu shell mientras corre el bucle | Un sitio para credenciales que lean los procesos, no las personas |

Kubernetes resuelve esas tres cosas de forma genérica: arranca contenedores en máquinas, los
vigila y guarda configuración y credenciales. ARC es la pieza que le enseña a hacerlo con
runners de GitHub. Tú no vas a administrar un clúster de producción: vas a usar uno de juguete,
local y desechable, que crea **kind**.

## 2. Cómo funciona

### kind: un clúster dentro de Docker

kind (Kubernetes IN Docker) crea cada **nodo** del clúster como un contenedor de Docker en tu
máquina. Dentro de ese contenedor corre todo lo que un nodo real necesita. El laboratorio,
definido en `lab/kind-config.yaml`, crea el clúster `gha` con dos nodos:

| Nodo | Rol |
|---|---|
| `gha-control-plane` | La API de Kubernetes y quien decide dónde corre cada cosa |
| `gha-worker` | Donde corren los pods: el controller de ARC y los runners |

La imagen de los nodos va fijada por tag y digest, como cualquier otra imagen del bootcamp. Y
como los nodos son contenedores, borrar el clúster es borrar dos contenedores: nada queda en tu
máquina.

### kubectl y los contextos

`kubectl` es el cliente de la API de Kubernetes. Lee en `~/.kube/config` una lista de
**contextos**: cada uno es un clúster más un usuario. kind añade el suyo con el prefijo `kind-`,
así que tu clúster es `kind-gha`. Si tienes otros clústeres (de trabajo, de otro curso), un
`kubectl` sin contexto explícito va contra el que esté marcado como actual. Por eso los scripts
de `tablero` pasan siempre `--context kind-gha`, y Helm, `--kube-context kind-gha`.

### Objetos declarativos

Todo en Kubernetes es un **objeto** con dos mitades: `spec`, lo que pides, y `status`, lo que hay.
Un **controller** es un proceso que compara las dos sin parar y actúa para que coincidan. Tú no
dices "arranca un contenedor": dices "quiero que exista este pod" y el sistema converge.

### Las siete piezas que usa ARC

| Objeto | Qué es | Para qué lo usa ARC |
|---|---|---|
| **Pod** | Uno o varios contenedores que nacen, viven y mueren juntos | Cada runner es un pod; el controller y el listener, también |
| **Namespace** | Una carpeta de objetos con nombre propio | `arc-systems` para el controller, `arc-runners` para los runners |
| **Secret** | Un objeto con pares clave-valor para credenciales | Guarda la GitHub App: id, installation id y clave privada |
| **ServiceAccount** | La identidad con la que un pod habla con la API | El controller y el listener la necesitan; el runner, no |
| **Role / RoleBinding** | Qué puede hacer una identidad dentro de un namespace | El listener puede cambiar cuántos runners quiere |
| **CRD** | Un tipo de objeto nuevo que alguien añade a la API | `AutoscalingRunnerSet`, `EphemeralRunner` y compañía |
| **Deployment** | Un pod que Kubernetes mantiene siempre vivo | El controller de ARC |

### Un secret no es un cofre

Los valores de un secret se guardan codificados en base64, que **no** es cifrado: cualquiera que
pueda leer el objeto lo decodifica con un comando. La documentación de Kubernetes avisa de que,
por defecto, los secrets se guardan sin cifrar en la base de datos del clúster. Lo que protege a
un secret es **quién puede leerlo**: los permisos sobre el namespace. Por eso los runners van en
un namespace y el controller en otro, y por eso un pod que no necesita la API no debe tener
credenciales para usarla.

### El token que Kubernetes monta sin que lo pidas

Por defecto, todo pod recibe montado en
`/var/run/secrets/kubernetes.io/serviceaccount/` un token de su service account. Con ese token,
cualquier proceso del pod habla con la API del clúster con los permisos de esa identidad. Para el
controller es imprescindible; para un runner que ejecuta código de un workflow, es una puerta
que nadie necesita abierta. El archivo 07 la cierra con `automountServiceAccountToken: false`.

### El patrón CRD + controller

ARC extiende la API con cuatro tipos propios del grupo `actions.github.com`:

| CRD | Qué representa |
|---|---|
| `AutoscalingRunnerSet` | Tu scale set: a qué repo se registra, nombre, mínimo, máximo, plantilla del pod |
| `AutoscalingListener` | El pod que escucha a GitHub en nombre de un scale set |
| `EphemeralRunnerSet` | Cuántos runners quiere ese scale set ahora mismo |
| `EphemeralRunner` | Un runner concreto, con su pod y su configuración JIT |

Tú solo declaras el primero. El controller de ARC crea los demás y, a partir de ellos, los pods.
Es el mismo patrón que `Deployment` → pods, aplicado a runners. El archivo 03 cuenta el viaje
completo.

_Verificado con ARC 0.15.1 y kind v0.33.0, noviembre de 2026._

## 3. Cómo se usa

### Levantar y comprobar el laboratorio

```bash
./scripts/lab-up.sh
kubectl --context kind-gha get nodes
# NAME                STATUS   ROLES           AGE   VERSION
# gha-control-plane   Ready    control-plane   1m    v1.37.0
# gha-worker          Ready    <none>          1m    v1.37.0
```

Si usas WSL2 y ya tienes otro clúster kind corriendo, el nodo nuevo puede no arrancar nunca. En
los logs del nodo aparece `inotify_init: too many open files`: es un problema conocido de kind,
porque el límite de instancias de inotify por defecto es 128. Se arregla subiéndolo:

```bash
sudo sysctl -w fs.inotify.max_user_instances=512
```

Ese valor se pierde al reiniciar; si quieres que dure, va en un archivo de `/etc/sysctl.d/`. La
práctica 02 lo comprueba paso a paso.

### Los comandos que vas a usar esta semana

| Comando | Qué te dice |
|---|---|
| `kubectl get pods -n arc-runners` | Los pods de un namespace y su estado |
| `kubectl get pods -n arc-runners -w` | Lo mismo, en vivo: cada cambio es una línea nueva |
| `kubectl describe pod <pod> -n arc-runners` | La spec aplicada y los eventos: por qué no arranca |
| `kubectl logs -n arc-systems deploy/arc-gha-rs-controller` | El log del controller de ARC |
| `kubectl get crd` | Los tipos de objeto que hay en el clúster, incluidos los de ARC |
| `kubectl explain pod.spec.securityContext` | La referencia de un campo sin salir de la terminal |

Los objetos de ARC se consultan igual que los nativos, por su nombre en plural:

```bash
kubectl --context kind-gha get crd | grep actions.github.com
# autoscalinglisteners.actions.github.com    <fecha>
# autoscalingrunnersets.actions.github.com   <fecha>
# ephemeralrunners.actions.github.com        <fecha>
# ephemeralrunnersets.actions.github.com     <fecha>
```

### Mirar un secret sin enseñar su contenido

```bash
kubectl --context kind-gha get secret tablero-arc-app -n arc-runners -o json | jq '.data | keys'
# [
#   "github_app_id",
#   "github_app_installation_id",
#   "github_app_private_key"
# ]
```

Las claves te dicen si está bien construido; los valores no tienen por qué pasar por tu pantalla.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `kubectl` sin `--context` en un script | Instala o borra en el clúster que esté activo, que puede no ser el tuyo | `--context kind-gha` en cada llamada |
| Todo en el namespace `default` | Runners y controller comparten permisos y secrets | Un namespace para el controller y otro para los runners |
| Tratar un secret como cifrado | base64 se decodifica con un comando | Limitar quién lee el namespace |
| `kubectl get secret ... -o yaml` "para revisar" | Imprime la clave privada en base64 en tu terminal y en tu historial | `jq '.data \| keys'` |
| Un YAML de secret en el repo | La credencial queda en el historial de git para siempre | Crear el secret desde la variable o el archivo, sin tocar el repo |
| Puertos de kind abiertos en `0.0.0.0` | El clúster queda a la vista de tu red | `127.0.0.1` en `extraPortMappings`, si alguna vez los necesitas |

## 5. Trucos

- **Qué contexto está activo**: `kubectl config current-context`. Si no dice `kind-gha`, no lances
  nada sin `--context`.
- **Los eventos cuentan lo que el estado calla**:
  `kubectl get events -n arc-runners --sort-by=.lastTimestamp` ordena por tiempo los motivos de
  cada fallo: imagen que no baja, contenedor que no arranca, límite que no cabe.
- **Entrar en un nodo de kind**: `docker exec -it gha-worker crictl ps` lista los contenedores
  que corren de verdad en el nodo, por debajo de Kubernetes.
- **Un campo que no recuerdas**: `kubectl explain pod.spec.automountServiceAccountToken` da la
  descripción oficial de la versión de tu clúster.

## 📚 Recursos Adicionales

- [kind: Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [kind: Known Issues](https://kind.sigs.k8s.io/docs/user/known-issues/)
- [Kubernetes: Pods](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Kubernetes: Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Kubernetes: Service Accounts](https://kubernetes.io/docs/concepts/security/service-accounts/)
- [Kubernetes: Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)

## ✅ Checklist de Verificación

- [ ] Sé qué es un nodo de kind y qué nodos tiene el clúster `gha`
- [ ] Sé por qué todo comando lleva `--context kind-gha`
- [ ] Sé distinguir pod, namespace, secret, service account, role y deployment
- [ ] Sé por qué un secret no está cifrado y qué lo protege de verdad
- [ ] Sé qué token monta Kubernetes en cada pod y por qué un runner no lo necesita
- [ ] Sé nombrar los cuatro CRD de ARC y cuál de ellos declaro yo
- [ ] Sé arreglar el fallo de inotify de kind en WSL2

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Semana 16 — Actions Runner Controller en kind](../README.md) | [Helm, lo justo](02-helm-lo-justo.md) |
