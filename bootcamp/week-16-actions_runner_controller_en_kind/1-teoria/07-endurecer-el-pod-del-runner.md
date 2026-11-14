# Endurecer el pod del runner

> El pod del runner es el único sitio del clúster donde corre código ajeno. Las capas que en la
> Semana 15 eran flags de `docker run` aquí son campos de la plantilla del pod, y la plantilla
> por defecto del chart no trae ninguna.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Traducir cada capa del contenedor de la Semana 15 a un campo de la plantilla del pod
- Explicar por qué `runAsNonRoot` exige un uid numérico con la imagen oficial del runner
- Quitar al pod el token de la API de Kubernetes y explicar qué evita
- Poner peticiones y límites de CPU y memoria, y saber qué pasa al superarlos
- Fijar la imagen del runner por digest y mantenerla igual que la de `ops/runner/Dockerfile`
- Comprobar desde dentro de un pod qué puede hacer un job y qué no

## 1. Qué problema resuelve

La plantilla del pod que trae el chart del scale set es mínima: un contenedor `runner` con la
imagen `ghcr.io/actions/actions-runner:latest` y el comando `run.sh`. Con eso funciona, pero:

| Lo que trae por defecto | Qué significa para un job malicioso |
|---|---|
| Imagen `:latest` | No sabes qué versión ejecuta ni cuándo cambia |
| El usuario `runner` puede hacer `sudo` sin contraseña | Root dentro del contenedor con un comando |
| Capacidades por defecto del runtime | Más alcance sobre el kernel del nodo del que necesita |
| Token de la service account montado | Credencial para hablar con la API del clúster |
| Sin límites | Puede dejar sin memoria el nodo, que en kind es tu máquina |

Un runner de un repo público ejecuta lo que llegue a `main` o lo que alguien con permiso
lance a mano. Si un día se cuela algo, estas capas deciden hasta dónde llega.

## 2. Cómo funciona

### De `docker run` a la plantilla del pod

| Semana 15 (`docker run`) | Semana 16 (plantilla del pod) | Nivel |
|---|---|---|
| `--rm` | ARC borra el pod al terminar el job | Lo hace ARC |
| `--cap-drop ALL` | `securityContext.capabilities.drop: [ALL]` | Contenedor |
| `--security-opt no-new-privileges` | `securityContext.allowPrivilegeEscalation: false` | Contenedor |
| `--memory 4g` · `--cpus 2` | `resources.limits.memory: 4Gi` · `resources.limits.cpu: "2"` | Contenedor |
| `--pids-limit 512` | Sin campo en la spec del pod: lo configura el kubelet del nodo | Nodo |
| Sin `-v /var/run/docker.sock` | Sin `containerMode` ni volúmenes del nodo (archivo 06) | Pod |
| Sin `-p` | Ningún servicio apuntando al pod | Clúster |
| (no existía) | `automountServiceAccountToken: false` | Pod |
| (no existía) | `runAsNonRoot: true` con `runAsUser: 1001` | Pod |
| (no existía) | `seccompProfile.type: RuntimeDefault` | Pod |

El `securityContext` existe en dos niveles. El del **pod** vale para todos sus contenedores:
usuario, grupo y perfil de seccomp. El del **contenedor** afina uno solo: escalada y capacidades.

### `runAsNonRoot` y el uid numérico

`runAsNonRoot: true` le pide al kubelet que se niegue a arrancar el contenedor si fuera a correr
como root. Para comprobarlo necesita saber el uid, y la imagen oficial declara su usuario por
nombre (`USER runner`), no por número. Con solo `runAsNonRoot`, el pod no arranca y queda en
`CreateContainerConfigError` con este mensaje:

```text
container has runAsNonRoot and image has non-numeric user (runner), cannot verify user is non-root
```

La solución es decírselo: `runAsUser: 1001` y `runAsGroup: 1001`, el uid y el gid de `runner`
en la imagen. Con eso, dentro del pod:

```bash
id
# uid=1001(runner) gid=1001(runner) groups=1001(runner),27(sudo),100(users),123(docker)
```

Sigue en el grupo `sudo`, porque lo dice la imagen. Pero `sudo` ya no sirve.

### Sin escalada: `allowPrivilegeEscalation: false`

Este campo activa en el proceso el mismo indicador `no_new_privs` que la Semana 15 ponía con
`--security-opt no-new-privileges`: ningún binario setuid, `sudo` incluido, puede dar más
privilegios de los que ya hay. El mensaje es idéntico:

```bash
sudo -n true
# sudo: The "no new privileges" flag is set, which prevents sudo from running as root.
```

Junto con `capabilities.drop: [ALL]`, el proceso no tiene ninguna capacidad del kernel. El
runner no las necesita: descarga, escribe en `_work` y habla HTTPS con GitHub.

### `seccompProfile: RuntimeDefault`

Seccomp filtra las llamadas al sistema que un proceso puede hacer. `RuntimeDefault` aplica el
perfil por defecto del runtime de contenedores, que bloquea llamadas que un proceso normal no
usa. Sin este campo, según la configuración del clúster, el pod puede correr sin filtro
(`Unconfined`). Es la línea que el estándar *restricted* de Kubernetes exige.

### Sin token de la API

Con `automountServiceAccountToken: false`, Kubernetes no monta nada en
`/var/run/secrets/kubernetes.io`. El chart ya da al runner una service account sin permisos,
pero sin token ni siquiera puede autenticarse ante la API: no puede preguntar qué hay en el
clúster ni probar si algún permiso se le escapó. Ninguna pieza del runner usa ese token.

### Peticiones y límites

| Campo | Qué hace | En `tablero` |
|---|---|---|
| `requests.cpu` · `requests.memory` | Lo que el planificador reserva para el pod al elegir nodo | `500m` · `1Gi` |
| `limits.cpu` | El techo de CPU: por encima, el proceso se frena | `"2"` |
| `limits.memory` | El techo de memoria: por encima, el kernel mata el contenedor (`OOMKilled`) | `4Gi` |

Con `maxRunners: 2`, el peor caso son 8 GiB de memoria para runners. Ajusta las cifras a tu
máquina, pero que existan: sin límite, un job con una fuga de memoria se lleva el nodo.

### La imagen: la misma que vigila Dependabot

El contenedor `runner` usa exactamente la imagen de `ops/runner/Dockerfile`:

```text
ghcr.io/actions/actions-runner:2.338.2@sha256:6d0b2d80d80f143f77dcb676e50920100bbb547e39e883454d57f45ab8c31300
```

Dependabot vigila ese Dockerfile desde la Semana 15. La documentación de Dependabot dice que el
ecosistema `docker` también actualiza imágenes en manifiestos de Kubernetes y Helm, pero no
concreta qué archivos reconoce, así que `tablero` no depende de eso. La comprobación
`arc-runner-image-matches` exige que `values.yaml` y el Dockerfile digan lo mismo: cuando
Dependabot sube el Dockerfile, el check se pone rojo hasta que copias el digest nuevo a
`values.yaml`. Una sola fuente de verdad, y un aviso cuando se separan.

La imagen no trae `ENTRYPOINT` y su `CMD` es `/bin/bash`: por eso la plantilla dice
`command: ["/home/runner/run.sh"]`.

_Verificado con ARC 0.15.1, actions/runner v2.338.2 y kind v0.33.0, noviembre de 2026._

## 3. Cómo se usa

### La plantilla completa de `tablero`

```yaml
template:
  spec:
    automountServiceAccountToken: false
    securityContext:
      runAsNonRoot: true
      runAsUser: 1001
      runAsGroup: 1001
      seccompProfile:
        type: RuntimeDefault
    containers:
      - name: runner
        image: ghcr.io/actions/actions-runner:2.338.2@sha256:6d0b2d80d80f143f77dcb676e50920100bbb547e39e883454d57f45ab8c31300
        command: ["/home/runner/run.sh"]
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: [ALL]
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: "2"
            memory: 4Gi
```

El contenedor tiene que llamarse `runner`: ARC reconoce el contenedor del runner por ese nombre
(la constante `EphemeralRunnerContainerName` de su código).

### Lo que ve un job

Un pod de runner solo vive lo que dura un job, así que la práctica 04 arranca un pod de prueba
con la misma plantilla y mira desde dentro:

| Prueba | Resultado |
|---|---|
| `id` | uid 1001, no root |
| `sudo -n true` | Falla: `no new privileges` |
| `ls /var/run/secrets/kubernetes.io` | No existe: sin token |
| Escribir en `_work` | Funciona: el runner tiene lo que necesita |

Lo que estas capas **no** cierran: el pod sigue teniendo red. Sin una `NetworkPolicy`, un pod de
Kubernetes puede hablar con cualquier otro pod del clúster y salir a tu red local. En un
laboratorio con un solo scale set y nada más en el clúster eso es aceptable, pero tenlo presente
en cuanto el clúster aloje algo más que runners.

### Comprobar la plantilla aplicada

```bash
kubectl --context kind-gha get autoscalingrunnerset tablero-runners -n arc-runners \
  -o jsonpath='{.spec.template.spec.automountServiceAccountToken} {.spec.template.spec.securityContext.runAsUser}'
# false 1001
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `image: ghcr.io/actions/actions-runner:latest` | Cambia sin aviso y no coincide con el Dockerfile que vigila Dependabot | Tag y digest, los mismos del Dockerfile | <!-- antipatron -->
| `runAsNonRoot: true` sin `runAsUser` | El pod no arranca: la imagen tiene un usuario no numérico | `runAsUser: 1001` y `runAsGroup: 1001` |
| Confiar en que `runner` no es root | Puede hacer `sudo` sin contraseña | `allowPrivilegeEscalation: false` |
| Dejar el token montado "porque no tiene permisos" | Cualquier permiso que se añada mañana le llega al job | `automountServiceAccountToken: false` |
| Sin `limits` | Un job se come la memoria del nodo, que en kind es tu máquina | Límites de CPU y memoria |
| `hostPath` o `hostNetwork: true` en la plantilla | El job llega al disco o a la red del nodo | Nada del nodo dentro del pod |
| Endurecer en `kubectl edit` | El siguiente `install.sh` lo deshace | Todo en `values.yaml` |

## 5. Trucos

- **Por qué murió un runner**: `kubectl describe pod <pod> -n arc-runners` enseña
  `Last State: Terminated` con `Reason: OOMKilled` si el job pasó del límite de memoria.
- **La referencia de cada campo**: `kubectl explain pod.spec.containers.securityContext` lista
  todos los campos del `securityContext` de contenedor con su descripción.
- **El usuario de la imagen sin arrancarla**: `docker run --rm --entrypoint id <imagen>`, el
  truco de la Semana 15, te da el uid y el gid que pones en `runAsUser` y `runAsGroup`.

## 📚 Recursos Adicionales

- [Kubernetes: Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Kubernetes: Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Kubernetes: Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Kubernetes: Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [GitHub Docs: Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)

## ✅ Checklist de Verificación

- [ ] Sé a qué campo del pod corresponde cada flag del `docker run` de la Semana 15
- [ ] Sé por qué `runAsNonRoot` necesita `runAsUser` con la imagen oficial
- [ ] Sé qué hace `allowPrivilegeEscalation: false` con `sudo`
- [ ] Sé qué evita `automountServiceAccountToken: false`
- [ ] Sé qué pasa cuando un job supera el límite de CPU y el de memoria
- [ ] Sé por qué la imagen de `values.yaml` tiene que ser la del Dockerfile
- [ ] Sé qué no cierran estas capas

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Modos de contenedor](06-modos-de-contenedor.md) | [Una GitHub App para ARC](../2-practicas/01-github-app-para-arc.md) |
