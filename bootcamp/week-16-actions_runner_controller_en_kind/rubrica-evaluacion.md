# Rúbrica de evaluación — Semana 16

> Actions Runner Controller en kind. Se aprueba con un **mínimo del 70 % en cada evidencia**, no
> en el promedio.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de la capa 16 |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** Un compañero propone autenticar ARC con un PAT clásico con scope `repo` "porque son dos
minutos y la App son diez". Compara las dos credenciales en alcance, caducidad y qué se lleva
quien la robe. ¿Hay algún caso en que ARC solo admita un PAT?

<details>
<summary>Respuesta</summary>

Un PAT es de una persona y alcanza todo lo que ella puede tocar: un PAT clásico con `repo`, todos
sus repos, no solo `tablero`. Suele durar mucho o no caducar, y si la persona se va, la
credencial se va con ella o queda activa sin dueño. Quien lo roba tiene un token que funciona ya,
con todo ese alcance.

Una GitHub App es de la organización, tiene permisos uno a uno y solo alcanza los repos donde
está instalada. ARC no guarda ningún token largo: firma con la clave privada un JWT de diez
minutos como mucho, lo cambia por un token de instalación de una hora y con él pide la
configuración JIT de cada runner. Quien robe la clave privada tiene algo grave, pero acotado a
esa instalación y a los permisos que tú elegiste.

La excepción es un scale set de **enterprise**: ahí la documentación dice que solo vale un PAT.
No aplica a tu org. Teoría 04.

</details>

**2.** `tablero` registra su scale set en el repositorio y no en la organización, y eso obliga a
dar a la App **Administration: Read and write**, un permiso fuerte. ¿Por qué no registrarlo en la
org, donde bastaría *Self-hosted runners: Read and write*? ¿Cómo se paga el precio de
Administration sin que llegue a otros repos?

<details>
<summary>Respuesta</summary>

Un scale set de organización entra en un runner group, y en una org Free solo tienes el grupo
por defecto, que no puedes limitar a repos concretos: las políticas de acceso de los grupos son
de Team. El scale set quedaría al alcance de cualquier repo de la org. Con alcance de
repositorio (`githubConfigUrl` acabado en `/tablero`) solo `tablero` lo ve, igual que el runner
de la Semana 15, y la política de la org que limita los runners de repositorio a `tablero` sigue
valiendo.

La documentación dice que Administration solo hace falta para registrar a nivel de repositorio.
El precio se acota instalando la App **solo** en `tablero`: el permiso no existe en ningún otro
repo. Por eso su clave es la joya de la corona de la semana. Teorías 04 y 05, práctica 01.

</details>

**3.** Tu kind corre en tu portátil, detrás del NAT de tu casa, sin ingress ni puertos abiertos.
¿Cómo se entera ARC de que hay un job de `tablero`? Recorre el viaje desde que lanzas `lab.yml`
hasta que el pod desaparece, nombrando qué pieza actúa y con qué credencial.

<details>
<summary>Respuesta</summary>

Todo son conexiones salientes: GitHub nunca llama a tu clúster, así que no hace falta webhook,
ni ingress, ni ningún puerto, y la App se crea sin webhook.

1. El **listener** (en `arc-systems`), autenticado con las credenciales de la App, mantiene una
   conexión HTTPS de *long poll* con el servicio de Actions.
2. Lanzas `lab.yml`; Actions asigna el job al scale set cuyo nombre coincide con `runs-on` y el
   listener recibe *Job Available*.
3. Con una service account que solo puede eso, el listener parchea el `EphemeralRunnerSet` con
   las réplicas nuevas.
4. Se crea un `EphemeralRunner`: su controller pide una configuración JIT y crea el pod.
5. El runner del pod se registra con esa configuración de un uso, recibe el job y lo ejecuta.
6. Al terminar, el controller borra el runner, y con él el pod y lo que el job escribió.

El runner, la única pieza que ejecuta código ajeno, es la que menos credenciales tiene: solo su
configuración JIT. Teoría 03, práctica 03 paso 5.

</details>

**4.** Con `minRunners: 0` y `maxRunners: 2`, lanzas tres workflows distintos que piden
`tablero-runners` a la vez. ¿Cuántos pods ves y qué le pasa al tercer job? ¿Qué cambiaría con
`minRunners: 1`? ¿Y si no pusieras ninguno de los dos valores?

<details>
<summary>Respuesta</summary>

ARC crea la suma de `minRunners` y los jobs asignados, sin pasar de `maxRunners`: dos pods, uno
por job. El tercero no se pierde, espera en cola a que acabe uno (si nadie lo recoge en 24 horas,
falla). Sin jobs no hay ningún pod de runner.

Con `minRunners: 1` siempre hay un runner registrado esperando: arranca antes, pero ocupa memoria
en tu portátil todo el día sin hacer nada. Sin ninguno de los dos valores, ARC crea tantos
runners como jobs, sin techo: con límites de 4 GiB por pod, unos cuantos jobs a la vez se llevan
tu máquina. El 2 de `tablero` es el techo que aguanta tu kind. Teoría 05, práctica 03 paso 2.

</details>

**5.** Al migrar `lab.yml`, alguien escribe `runs-on: [self-hosted, tablero-runners]` "como en la
Semana 15" y otro añade `runnerScaleSetLabels: [gpu]` en `values.yaml`. ¿Qué pasa con cada
cambio? ¿Por qué `tablero` pide el scale set solo por su nombre?

<details>
<summary>Respuesta</summary>

ARC elige el scale set por su nombre (`runnerScaleSetName`, o el de la release si falta) o por
las etiquetas que le pongas; ni la documentación de ARC ni la de la librería del scale set dicen
que lleve `self-hosted`. Pedir una etiqueta que ningún runner tiene deja el job en cola hasta
caducar a las 24 horas. Por eso `runs-on: tablero-runners` es una cadena y nada más.

El segundo cae en la trampa de nombres: con Helm, el valor del chart que funciona es
`scaleSetLabels`, que la plantilla copia al campo `runnerScaleSetLabels` del
`AutoscalingRunnerSet`. La documentación de GitHub llama `runnerScaleSetLabels` al valor de
`values.yaml`, pero el `values.yaml` del chart 0.15.1 dice `scaleSetLabels`. `tablero` no
necesita etiquetas: tiene un único scale set, y su nombre, la release y `runs-on` coinciden a
propósito. Teoría 05.

</details>

**6.** Un job necesita `services:` con PostgreSQL y otro hace `docker build`. Sin `containerMode`
ninguno funciona. Compara `dind` y `kubernetes`: qué añaden al pod y qué precio de seguridad
tiene cada uno. ¿Por qué `tablero` no usa ninguno?

<details>
<summary>Respuesta</summary>

**`dind`** añade un contenedor `docker:dind` con `dockerd` como root y
`securityContext.privileged: true`, y apunta `DOCKER_HOST` del runner a su socket. Esos valores
no se pueden sobrescribir. Un contenedor privilegiado tiene todas las capacidades y los
dispositivos del nodo, y el job habla con ese demonio: puede pedirle un contenedor con `/`
montado y llegar al nodo. En kind, el nodo es a su vez un contenedor privilegiado de tu Docker:
el camino acaba en tu máquina. Es el socket de la Semana 15, un piso más abajo.

**`kubernetes`** usa los runner container hooks para crear un pod por cada `container:`,
servicio o action Docker. Necesita un volumen persistente por runner y una service account que
crea y borra pods, hace `pods/exec` y gestiona `jobs` y `secrets` del namespace: código del job
con permisos sobre la API. `kubernetes-novolume` quita el volumen, no los permisos.

Los jobs de `tablero` en ARC solo corren tests unitarios: no necesitan Docker, y el modo sin
contenedor no da ni privilegios ni API. Teoría 06, práctica 04 pasos 2 y 4.

</details>

**7.** Lanzas `install.sh` dos veces seguidas sin cambiar nada. ¿Por qué no falla? Después
decides subir ARC a una versión nueva cuyos CRD cambian: ¿basta con cambiar `ARC_VERSION` y
relanzarlo? ¿Y por qué `helm template` del scale set falla en un clúster recién creado?

<details>
<summary>Respuesta</summary>

`helm upgrade --install` instala la primera vez y actualiza las siguientes, y el secret se crea
con `--dry-run=client -o yaml | kubectl apply -f -`: las dos cosas son idempotentes, y el
clúster acaba igual que tu repo.

No basta: Helm instala los CRD de la carpeta `crds/` la primera vez, pero **no los actualiza ni
los borra** en un `upgrade`. La documentación de GitHub dice que, si cambian, hay que
desinstalar los scale sets, después el controller, borrar los CRD de `actions.github.com` y
volver a instalar. En el laboratorio eso es barato: un kind desechable y `install.sh`. Controller
y scale set van siempre con la misma `ARC_VERSION`, porque versiones distintas no se garantizan.

`helm template` del scale set busca el controller en el clúster para generar el role binding y
falla con `No gha-rs-controller deployment found`. Por eso el orden es fijo: controller primero.
Teoría 02, práctica 02.

</details>

**8.** Pones `runAsNonRoot: true` en el pod y nada más. El pod se queda en
`CreateContainerConfigError`. ¿Por qué? Lo arreglas, entras y `id` dice que estás en el grupo
`sudo`. ¿Por qué `sudo -n true` falla igualmente, y qué añade `seccompProfile: RuntimeDefault`?

<details>
<summary>Respuesta</summary>

`runAsNonRoot` pide al kubelet que no arranque el contenedor si fuera a correr como root, y para
comprobarlo necesita un uid. La imagen oficial declara `USER runner` por nombre, así que el
kubelet no puede verificarlo: `image has non-numeric user (runner), cannot verify user is
non-root`. Se arregla con `runAsUser: 1001` y `runAsGroup: 1001`.

El grupo `sudo` lo pone la imagen. `allowPrivilegeEscalation: false` activa `no_new_privs`, el
mismo indicador que `--security-opt no-new-privileges` en la Semana 15: ningún binario setuid
puede subir privilegios, y `sudo` responde `The "no new privileges" flag is set`. Con
`capabilities.drop: [ALL]`, el proceso no tiene ninguna capacidad.

`RuntimeDefault` aplica el perfil de seccomp del runtime, que bloquea llamadas al sistema que un
proceso normal no usa; sin él, según el clúster, el pod puede correr `Unconfined`. Es lo que
exige el estándar *restricted*. Teoría 07, práctica 04 paso 2.

</details>

**9.** La service account del runner no tiene ningún permiso, así que alguien dice que
`automountServiceAccountToken: false` sobra. ¿Por qué se equivoca? Y ya que hablamos de la API:
¿qué protege de verdad el secret `tablero-arc-app`, si sus valores están en base64?

<details>
<summary>Respuesta</summary>

Sin esa línea, Kubernetes monta en `/var/run/secrets/kubernetes.io/serviceaccount/` un token con
el que cualquier proceso del pod se autentica ante la API. Hoy no le sirve de mucho, pero puede
preguntar qué hay en el clúster y probar permisos, y cualquier permiso que alguien añada mañana a
esa identidad le llega al job. Ninguna pieza del runner usa el token: sin él, un job ni siquiera
puede autenticarse. Lo compruebas con `sin-token` en la práctica 04.

Base64 no es cifrado, y por defecto los secrets se guardan sin cifrar en la base de datos del
clúster. Lo que protege `tablero-arc-app` es **quién puede leerlo**: los permisos sobre su
namespace. Por eso el controller y los runners viven en namespaces distintos y el pod del runner
no tiene credenciales para la API. El secret se crea desde un pipe, sin tocar el disco ni el log,
y se comprueba mirando solo los nombres de sus claves. Teorías 01, 04 y 07.

</details>

**10.** Enumera quién puede hacer que un job corra en `tablero-runners`: (a) otro repo de tu org;
(b) un desconocido con un PR desde un fork; (c) una action de terceros que usa `lab.yml`;
(d) Dependabot cuando sube el digest de `ops/runner/Dockerfile`. Para cada uno, di qué capa lo
frena o qué pasa.

<details>
<summary>Respuesta</summary>

(a) Nadie fuera de `tablero`: el scale set es de repositorio y la App solo está instalada en
`tablero`.

(b) Ningún workflow con `pull_request` usa `tablero-runners` (check `own-runners-only-in-lab`),
y un workflow nuevo traído en el PR sigue sujeto a la aprobación de todos los contribuidores
externos de la Semana 15. El riesgo que queda eres tú aprobando sin leer `.github/`.

(c) Corre dentro del job, con todo su alcance. Lo acotan las actions por SHA y un pod sin root,
sin escalada, sin capacidades, sin token de Kubernetes, con límites y que se borra al terminar.
No lo acota lo que alcance por la red mientras dura.

(d) Dependabot no lanza nada en el runner: abre un PR. Al fusionarlo, `values.yaml` sigue con el
digest viejo y `arc-runner-image-matches` se pone rojo hasta que copias el `FROM` nuevo y
relanzas `install.sh`. Una sola fuente de verdad y un aviso cuando se separan. Teorías 05 y 07.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Una GitHub App para ARC | App de la org sin webhook, solo con Administration (lectura y escritura) y Metadata (lectura), instalada solo en `tablero`; client ID e installation ID anotados | 5 |
| 01 — Una GitHub App para ARC | Clave `.pem` fuera del repo con permisos `600` y secret `tablero-arc-app` con las tres claves de la App, creado sin tocar el disco (checks `no-private-key-in-repo`, `arc-secret-in-kind`) | 5 |
| 02 — ARC con Helm | Helm instalado con checksum verificado y controller desplegado desde el chart OCI oficial con `ARC_VERSION` fijada en `install.sh` (check `arc-charts-pinned`) | 5 |
| 02 — ARC con Helm | Enseña los CRD de `actions.github.com` y lee el log del controller; si `gha-worker` no llegaba a `Ready`, diagnosticó el límite de inotify | 5 |
| 03 — El scale set de tablero | `values.yaml` con alcance de repo, secret por nombre, `tablero-runners` de 0 a 2 runners, y las dos releases desplegadas en `kind-gha` (checks `arc-scope-repo`, `arc-secret-by-name`, `scale-set-name`, `scale-set-bounds`, `arc-installed-in-kind`) | 5 |
| 03 — El scale set de tablero | `lab.yml` en `tablero-runners`, actionlint con la etiqueta, linters limpios y un run en verde en el último commit de `main`; enseña con `kubectl get pods -w` cómo nace y muere el pod (checks `lab-runs-on-arc`, `own-runners-only-in-lab`, `workflows-lint`, `lab-green-on-arc`) | 5 |
| 04 — El pod del runner endurecido | Imagen de la Semana 15 por digest, uid 1001 sin root, sin escalada ni capacidades, sin token de Kubernetes, sin `containerMode` y con límites (checks `arc-runner-image-matches`, `runner-pod-nonroot`, `runner-pod-no-k8s-token`, `arc-no-dind`, `runner-pod-limits`) | 5 |
| 04 — El pod del runner endurecido | Enseña con el pod de prueba `id`, `sudo` bloqueado y la ausencia de token, reproduce el `CreateContainerConfigError` sin `runAsUser` y explica por qué `dind` sería root en el nodo; borra los pods de prueba | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 16` con 17/17. Cada comprobación en rojo
resta la parte proporcional (unos 0,7 puntos).

**Calidad manual de la capa 16 (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| La GitHub App no tiene webhook ni más permisos que Administration y Metadata, y está instalada en `tablero` y en ningún otro repo | 3 |
| La clave `.pem` vive fuera del repo con permisos `600`, y `git log -p` no la contiene en ningún commit | 3 |
| `values.yaml` explica con un comentario cada decisión discutible: alcance de repo, `minRunners: 0`, sin `containerMode`, uid numérico | 3 |
| `install.sh` es idempotente: lanzarlo dos veces no falla ni duplica nada, y no escribe la clave en disco ni en el log | 3 |
| Los límites de CPU y memoria caben en tu máquina con `maxRunners` pods a la vez | 2 |
| Los pods de prueba de las prácticas están borrados: `kubectl get pods -n arc-runners` solo enseña runners mientras hay un job | 1 |
| Commits en Conventional Commits, uno por mecanismo (`ci: add arc scale set for tablero`, `ci: run lab on arc runners`…) | 2 |
| Sin `TODO` en el repo | 1 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log | Grave: Producto a 0 hasta rotar el secreto y retirar el log |
| Clave privada de la GitHub App comiteada (en cualquier commit del historial) o impresa en un log | Grave: Producto a 0 hasta borrar esa clave en la App, generar otra, recrear el secret y retirar el commit o el log |
| ARC autenticado con un PAT (`github_token` en `values.yaml` o en el secret) | Grave: −10, y revocar el token |
| `containerMode` `dind` o cualquier contenedor `privileged` en el scale set de `tablero` | Grave: −10 |
| Scale set al alcance de PRs de forks: un workflow con `pull_request*` que pide `tablero-runners`, o una política de aprobación distinta de `all_external_contributors` | Grave: −10 |
| `pull_request_target` con checkout del head del PR | Grave: −10 |
| `uses:` remota sin SHA, o con un SHA copiado que no pertenece al repo oficial | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}`, `github.head_ref`, `inputs.*`, `secrets.*` o `vars.*` interpolado dentro de `run:` | Grave: −10 |
| Imagen sin tag o con `latest`, en `values.yaml` o en el `FROM` del runner | Grave: −10 |
| Chart de ARC sin `--version`, o controller y scale set con versiones distintas | −5 |
| Scale set registrado en la organización, o App instalada en más repos que `tablero` | −5 |
| Pod del runner con el token de la API montado o sin límites | −3 |
| Job con `runs-on` sin `timeout-minutes` | −3 por cada uno |
| `pip`, `npm` o Compose v1 en un workflow o en la documentación de tu repo | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 16 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
