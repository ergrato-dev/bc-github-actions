# 📖 Glosario — Semana 16

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **ARC** (*Actions Runner Controller*): operador de Kubernetes de GitHub que crea un runner
  efímero en un pod por cada job y lo borra al terminar. Se instala con dos charts de Helm: el
  del controller y el del scale set.
- **`allowPrivilegeEscalation`**: campo del `securityContext` del contenedor. Con `false` activa
  `no_new_privs`, el equivalente de `--security-opt no-new-privileges`: `sudo` deja de servir.
- **`automountServiceAccountToken`**: campo del pod. Con `false`, Kubernetes no monta el token de
  la service account en `/var/run/secrets/kubernetes.io`, y el job no puede autenticarse ante la
  API.
- **`AutoscalingListener`**: CRD de ARC detrás del pod listener de cada scale set, en
  `arc-systems`.
- **`AutoscalingRunnerSet`**: CRD de ARC que representa tu scale set. Lo crea el chart
  `gha-runner-scale-set` a partir de tus values.

## C

- **Capacidades** (*capabilities*): trozos de los privilegios de root. `capabilities.drop: [ALL]`
  se los quita todos al contenedor del runner.
- **Chart**: paquete de Helm con plantillas de objetos de Kubernetes y sus values por defecto.
  ARC publica los suyos en GHCR como artefactos OCI.
- **Clave privada** (*private key*): archivo `.pem` que generas para la GitHub App y descargas
  una sola vez. Con ella ARC firma sus JWT; es la joya de la corona de la semana y nunca entra en
  el repo.
- **Client ID**: identificador público de la GitHub App. Va en la clave `github_app_id` del
  secret, que acepta el client ID o el app ID.
- **Contexto** (*kubectl context*): entrada de kubeconfig que dice a qué clúster y con qué usuario
  habla `kubectl`. El del laboratorio es `kind-gha`.
- **Controller**: programa que vigila objetos de Kubernetes y actúa para que la realidad coincida
  con lo declarado. El de ARC es el deployment `arc-gha-rs-controller`, en `arc-systems`.
- **CRD** (*Custom Resource Definition*): definición de un tipo de objeto nuevo en Kubernetes.
  ARC añade cuatro en `actions.github.com`. Helm los instala, pero no los actualiza ni los borra.

## D

- **`dind`** (*Docker-in-Docker*): modo de contenedor de ARC que añade un `dockerd` como root en un
  contenedor privilegiado junto al runner. `tablero` no lo usa.

## E

- **`EphemeralRunner`**: CRD de ARC con un runner concreto: su configuración JIT y su pod.
- **`EphemeralRunnerSet`**: CRD de ARC con cuántos runners quiere el scale set ahora mismo. El
  listener lo parchea cuando llega un job.

## G

- **GitHub App**: identidad de la organización con permisos uno a uno y solo en los repos donde
  está instalada. La de ARC tiene Administration (lectura y escritura) y Metadata (lectura) y vive
  instalada solo en `tablero`.
- **`githubConfigSecret`**: value del scale set con el nombre del secret de Kubernetes que guarda
  la credencial. En `tablero`, `tablero-arc-app`.
- **`githubConfigUrl`**: value del scale set que decide dónde se registra: repositorio,
  organización o enterprise.

## H

- **Helm**: gestor de paquetes de Kubernetes. Instala un chart con unos values y lleva la cuenta
  de lo instalado como una release.
- **Hooks de contenedor** (*runner container hooks*): programa que, en el modo `kubernetes`, crea
  un pod por cada `container:`, servicio o action Docker del job.

## I

- **inotify**: mecanismo del kernel para vigilar archivos. Con varios clústeres kind se agotan sus
  instancias (`fs.inotify.max_user_instances`) y un nodo no llega a `Ready`.
- **Installation ID**: identificador de la instalación de la App en `tablero`. Sale en la URL de la
  instalación y va en la clave `github_app_installation_id`.

## J

- **JWT** (*JSON Web Token*): token que ARC firma con la clave privada para probar que habla en
  nombre de la App. Dura diez minutos como mucho y solo sirve para pedir un token de instalación.

## K

- **kind** (*Kubernetes in Docker*): herramienta que crea un clúster de Kubernetes con contenedores
  de Docker como nodos. El laboratorio se llama `gha`.
- **kubectl**: cliente de línea de comandos de la API de Kubernetes.
- **kubelet**: agente de cada nodo que arranca los contenedores de los pods y aplica su
  `securityContext`.

## L

- **Límites** (*limits*): techo de CPU y memoria de un contenedor. Por encima de la memoria, el
  kernel lo mata (`OOMKilled`); por encima de la CPU, lo frena.
- **Listener**: pod de ARC, uno por scale set, que mantiene un *long poll* con el servicio de
  Actions y pide runners cuando llegan jobs.
- **Long poll**: petición HTTPS que el servidor deja abierta hasta que tiene algo que decir. Así
  ARC recibe jobs sin abrir ningún puerto de entrada.

## M

- **`maxRunners`** · **`minRunners`**: techo y suelo de runners del scale set. ARC crea
  `minRunners` más los jobs asignados, sin pasar de `maxRunners`. En `tablero`, 0 y 2.
- **Modo de contenedor** (*container mode*): valor `containerMode.type` del scale set: `dind`,
  `kubernetes` o `kubernetes-novolume`. Sin él, el pod solo tiene el contenedor del runner.

## N

- **Namespace**: partición de un clúster para nombres y permisos. ARC usa `arc-systems` para el
  controller y el listener y `arc-runners` para los runners.
- **Nodo** (*node*): máquina del clúster donde corren los pods. En kind, un contenedor de tu
  Docker.

## O

- **OCI** (*Open Container Initiative*): formato de los registros de imágenes. Helm instala charts
  desde un registro OCI con `oci://`, sin `helm repo add`.

## P

- **Peticiones** (*requests*): CPU y memoria que el planificador reserva para un pod al elegir
  nodo.
- **Pod**: la unidad mínima que ejecuta Kubernetes, uno o varios contenedores que comparten red y
  volúmenes. Cada job de `tablero` corre en uno.
- **Pod Security Standards**: los tres perfiles de seguridad de Kubernetes: *privileged*,
  *baseline* y *restricted*.
- **Privilegiado** (*privileged*): contenedor con todas las capacidades y acceso a los dispositivos
  del nodo. Lo exige `dind`.

## R

- **Release**: una instalación concreta de un chart con un nombre. En `kind-gha`, `arc` y
  `tablero-runners`.
- **`runAsNonRoot`**: campo del `securityContext` que impide arrancar el contenedor como root.
  Con una imagen de usuario no numérico necesita `runAsUser`.
- **`runnerScaleSetName`**: value con el nombre del scale set, el que pone `runs-on`. Si falta,
  vale el nombre de la release.

## S

- **Scale set** (*runner scale set*): grupo de runners homogéneos que ARC escala según los jobs
  asignados. El de `tablero` se llama `tablero-runners`.
- **`scaleSetLabels`**: value del chart con etiquetas extra del scale set (desde ARC 0.14.0). La
  plantilla las copia al campo `runnerScaleSetLabels`. `tablero` no las usa.
- **Seccomp**: filtro del kernel sobre las llamadas al sistema. `seccompProfile: RuntimeDefault`
  aplica el perfil por defecto del runtime.
- **Secret**: objeto de Kubernetes para datos sensibles. Va en base64, que no es cifrado: lo
  protege quién puede leerlo.
- **`securityContext`**: bloque de seguridad del pod (usuario, grupo, seccomp) y de cada
  contenedor (escalada, capacidades).
- **Service account**: identidad con la que un pod habla con la API de Kubernetes.

## T

- **Token de instalación** (*installation access token*): token de una hora que ARC obtiene con
  el JWT. Solo tiene los permisos de la App en los repos donde está instalada.

## V

- **Values**: parámetros de un chart. Los de `tablero` viven en `ops/arc/values.yaml`, versionados
  en el repo.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Índice del bootcamp](../../README.md) |
