# 🌐 Webgrafía — Semana 16

Documentación oficial primero: GitHub para ARC y las Apps, luego kind, Helm y Kubernetes para lo
que la semana enseña "lo justo". La documentación de GitHub cambia de ruta a menudo: si un enlace
falla, busca el título en docs.github.com.

### GitHub: Actions Runner Controller

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Actions Runner Controller](https://docs.github.com/en/actions/concepts/runners/actions-runner-controller) | Las piezas y los once pasos del viaje de un job que la teoría 03 agrupa en tres fases | 2026-11-14 |
| [Get started with Actions Runner Controller](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller/quickstart) | La instalación mínima con Helm y los charts OCI: compárala con `install.sh` y fíjate en lo que `tablero` añade | 2026-11-14 |
| [Authenticating ARC to the GitHub API](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller/authenticate-to-the-api) | Los permisos de la App según el alcance, el secret predefinido y la excepción del PAT en enterprise (teoría 04) | 2026-11-14 |
| [Deploying runner scale sets with Actions Runner Controller](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller/deploy-runner-scale-sets) | Cada valor del chart del scale set: `minRunners`, `maxRunners`, `runnerGroup`, los modos de contenedor y cómo actualizar los CRD | 2026-11-14 |
| [Using Actions Runner Controller runners in a workflow](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller/use-arc-in-a-workflow) | Qué pone `runs-on` para llegar a un scale set y por qué el nombre debe ser único en su runner group (teoría 05) | 2026-11-14 |
| [Troubleshooting Actions Runner Controller errors](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller/troubleshoot) | Dónde mirar los logs del controller y del listener cuando un job se queda en cola | 2026-11-14 |
| [Support for Actions Runner Controller](https://docs.github.com/en/actions/concepts/runners/support-for-arc) | Qué soporta GitHub de ARC y qué queda de tu lado: el clúster, el runtime y tu configuración | 2026-11-14 |

### GitHub Apps

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Registering a GitHub App](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app) | Cada campo del formulario de la práctica 01, incluido el webhook que desmarcas | 2026-11-14 |
| [Installing your own GitHub App](https://docs.github.com/en/apps/using-github-apps/installing-your-own-github-app) | Cómo instalarla en repos seleccionados, que es lo que limita Administration a `tablero` | 2026-11-14 |
| [Managing private keys for GitHub Apps](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/managing-private-keys-for-github-apps) | Generar, guardar y borrar claves: el procedimiento de rotación de la teoría 04 | 2026-11-14 |
| [Generating a JSON Web Token (JWT) for a GitHub App](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app) | El JWT de diez minutos como mucho que ARC firma con la clave privada | 2026-11-14 |
| [Generating an installation access token for a GitHub App](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app) | El token de una hora con el que ARC registra el scale set y pide cada configuración JIT | 2026-11-14 |
| [Deciding when to build a GitHub App](https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/deciding-when-to-build-a-github-app) | La comparación oficial entre App y token personal, el porqué de la prohibición del PAT | 2026-11-14 |

### El código de ARC

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [actions/actions-runner-controller](https://github.com/actions/actions-runner-controller) | El repo de los dos charts y del controller: aquí comprobarás cualquier valor antes de fiarte de un tutorial | 2026-11-14 |
| [Releases de ARC](https://github.com/actions/actions-runner-controller/releases) | Cada versión de los charts: de aquí sale `ARC_VERSION` y aquí lees si cambian los CRD antes de subirla | 2026-11-14 |
| [values.yaml del chart gha-runner-scale-set](https://github.com/actions/actions-runner-controller/blob/master/charts/gha-runner-scale-set/values.yaml) | La fuente de verdad de los values: `scaleSetLabels`, `github_app_id` con el client ID y lo que inyecta `dind` | 2026-11-14 |
| [actions/runner-container-hooks](https://github.com/actions/runner-container-hooks) | Los hooks que usa el modo `kubernetes` para crear un pod por contenedor del job (teoría 06) | 2026-11-14 |
| [actions/scaleset](https://github.com/actions/scaleset) | La librería en Go de la API de scale sets que usa ARC desde 0.14.0, por si quieres ver el protocolo por dentro | 2026-11-14 |

### kind y Helm

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [kind: Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/) | Crear, listar y borrar clústeres, y cómo nombra kind el contexto (`kind-gha`) | 2026-11-14 |
| [kind: Configuration](https://kind.sigs.k8s.io/docs/user/configuration/) | Cada campo de `lab/kind-config.yaml`: nodos, imagen del nodo y puertos en `127.0.0.1` | 2026-11-14 |
| [kind: Known Issues](https://kind.sigs.k8s.io/docs/user/known-issues/) | El límite de inotify que deja a `gha-worker` sin llegar a `Ready` (práctica 02) y otros tropiezos frecuentes | 2026-11-14 |
| [Releases de kind](https://github.com/kubernetes-sigs/kind/releases) | La versión de kind y el digest de cada imagen `kindest/node` | 2026-11-14 |
| [Installing Helm](https://helm.sh/docs/intro/install/) | Las formas de instalar Helm; `tablero` usa el binario de la release con su checksum | 2026-11-14 |
| [Using Helm](https://helm.sh/docs/intro/using_helm/) | Chart, release y values en la práctica: el vocabulario de la teoría 02 | 2026-11-14 |
| [Use OCI-based registries](https://helm.sh/docs/topics/registries/) | Por qué los charts de ARC se instalan con `oci://ghcr.io/...` sin `helm repo add` | 2026-11-14 |
| [helm upgrade](https://helm.sh/docs/helm/helm_upgrade/) | La referencia de `--install`, `--version`, `--wait` y `--create-namespace` | 2026-11-14 |
| [Custom Resource Definitions (best practices)](https://helm.sh/docs/chart_best_practices/custom_resource_definitions/) | Por qué Helm instala los CRD de `crds/` pero nunca los actualiza ni los borra | 2026-11-14 |
| [Releases de Helm](https://github.com/helm/helm/releases) | Cada versión de Helm y dónde están el binario y su `.sha256sum` | 2026-11-14 |

### Kubernetes

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) | `runAsNonRoot`, `runAsUser`, `allowPrivilegeEscalation`, `capabilities` y `seccompProfile`, en los dos niveles (teoría 07) | 2026-11-14 |
| [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) | Los perfiles *privileged*, *baseline* y *restricted*: tu pod cumple las líneas de *restricted*; uno con `dind` no pasa ni *baseline* | 2026-11-14 |
| [Service Accounts](https://kubernetes.io/docs/concepts/security/service-accounts/) | Qué es la identidad de un pod y por qué todo pod tiene una aunque no la pidas | 2026-11-14 |
| [Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) | Cómo no montar el token con `automountServiceAccountToken: false` | 2026-11-14 |
| [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) | Base64 no es cifrado y los secrets se guardan sin cifrar por defecto: el aviso de la teoría 01 | 2026-11-14 |
| [Good practices for Kubernetes Secrets](https://kubernetes.io/docs/concepts/security/secrets-good-practices/) | Mínimo privilegio sobre quién lee un secret, el motivo de separar `arc-systems` y `arc-runners` | 2026-11-14 |
| [Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) | La diferencia entre `requests` y `limits`, y qué pasa al superar el límite de memoria (`OOMKilled`) | 2026-11-14 |
| [Restrict a Container's Syscalls with seccomp](https://kubernetes.io/docs/tutorials/security/seccomp/) | Qué filtra `RuntimeDefault` y qué significa correr `Unconfined` | 2026-11-14 |
| [Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) | Qué es un CRD, la mitad del patrón CRD + controller en que se basa ARC | 2026-11-14 |
| [Controllers](https://kubernetes.io/docs/concepts/architecture/controller/) | La otra mitad: el bucle que compara lo declarado con lo real y lo corrige | 2026-11-14 |
| [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) | Roles y role bindings: para leer qué deja hacer el chart al listener y, en modo `kubernetes`, al runner | 2026-11-14 |
| [kubectl Quick Reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/) | Los comandos de la semana a mano: `get -w`, `logs`, `exec`, `-o jsonpath` | 2026-11-14 |

### Docker dentro de Kubernetes

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Imagen oficial docker](https://hub.docker.com/_/docker) | La página de `docker:dind`: dice que necesita `--privileged`, que es justo lo que `tablero` rechaza (teoría 06) | 2026-11-14 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
