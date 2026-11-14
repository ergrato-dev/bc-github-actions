# Rúbrica de evaluación — Semana 17

> Despliegue continuo a Kubernetes. Se aprueba con un **mínimo del 70 % en cada evidencia**, no
> en el promedio. Esta semana cierra la Fase 5 e incluye su minisimulacro.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de la capa 17 |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** Un compañero propone que `deploy.yml` escuche `on: release: types: [published]` y quitar
el job `deploy` de `release.yml`, "que es más limpio". ¿Qué pasa en la siguiente release? ¿Por qué
el job `deploy` usa `gh workflow run ... --ref main` y qué permiso necesita?

<details>
<summary>Respuesta</summary>

**No se despliega nada**: la release la crea release-please con `GITHUB_TOKEN`, y los eventos que
provoca ese token no disparan workflows, para evitar bucles. Las dos excepciones son
`workflow_dispatch` y `repository_dispatch`. Es el mismo motivo por el que `images` vive en
`release.yml` desde la Semana 14.

Por eso el job `deploy`, con `needs: [release-please, images]`, lanza `deploy.yml` por dispatch
cuando las dos imágenes ya están publicadas y firmadas. Su único permiso es `actions: write`, el
que pide la API de dispatch. `--ref main` importa por el clúster: el apiserver solo acepta tokens
con `ref == 'refs/heads/main'` y con el `job_workflow_ref` de `deploy.yml` en `main`; un run sobre
otra rama ni siquiera se autenticaría. La versión llega por `env:`, nunca interpolada en `run:`.
Teoría 01.

</details>

**2.** Entre el job `staging` y el `production` de un mismo run pasan dos días esperando tu
aprobación. Mientras tanto, alguien con permiso de escritura en GHCR mueve el tag `1.4.0` a otra
imagen. ¿Qué despliega `production`? ¿Y si alguien edita el input para pasar
`ghcr.io/<tu-org>/tablero-api:1.4.0` al chart en lugar de un digest?

<details>
<summary>Respuesta</summary>

**Lo mismo que staging.** `production` no vuelve a preguntar a GHCR: lee los digests de
`needs.verify.outputs`, que `verify` sacó del `subject` de la attestation (el digest que firmó
`release.yml`), no del tag. Mover el tag después de `verify` no cambia nada. Es la regla de oro
del CD: se promueve un artefacto, no se reconstruye ni se vuelve a resolver en cada etapa.

Pasar un tag no llega a desplegar: `api.yaml` y `web.yaml` fallan al renderizar si la imagen no
acaba en `@sha256:<64 hex>` (check `chart-digest-only`). Y el input de `deploy.yml` es solo la
versión `X.Y.Z`, validada con una expresión regular antes de usarla. Teorías 01 y 07, práctica 02
paso 1.

</details>

**3.** ¿Por qué `verify` es un job aparte, en `ubuntu-24.04` y con `attestations: read` como único
permiso, en vez de un step dentro de `staging`? ¿Qué rechaza `--deny-self-hosted-runners` que
`--signer-workflow` no rechaza, y por qué hasta la Semana 15 daba igual?

<details>
<summary>Respuesta</summary>

- **Sin `id-token: write`**: si un paso de la verificación se comprometiera, no podría pedir un
  token para el clúster. Los jobs que sí lo piden no verifican nada.
- **Sin runner propio**: verificar no necesita llegar a kind, así que no ocupa un pod de
  `tablero-runners`.
- **Una vez para los dos environments**: los dos leen los mismos outputs.

`--signer-workflow` exige que firmara `release.yml` de `tablero`; no dice **dónde** corrió.
`--deny-self-hosted-runners` exige que el build corriera en un runner de GitHub. Si alguien
cambiara el `runs-on` de `images` a `tablero-runners`, la firma seguiría siendo de `release.yml`,
pero el despliegue se pararía en `verify`. Hasta la Semana 15 `tablero` no tenía runners propios
y la opción no excluía nada. Teoría 07.

</details>

**4.** En `deploy.yml`, `helm upgrade` lleva `--rollback-on-failure --timeout 3m`, y aun así hay
un step `helm rollback` con `if: failure() && steps.deploy.outcome == 'success'`. ¿Qué caso cubre
cada uno? ¿Qué pasaría con `if: failure()` a secas? ¿Y si el primer despliegue a un namespace
vacío falla?

<details>
<summary>Respuesta</summary>

`--rollback-on-failure` cubre **"no arranca"**: si a los tres minutos los recursos no están
listos (readiness), Helm marca la revisión `failed` y crea otra con `Rollback to N`. En Helm 4
sustituye a `--atomic`, que ya no existe, y pone `--wait` en `watcher`; sin espera, el upgrade
terminaría en verde con la API en `CrashLoopBackOff`.

El step cubre **"arranca pero está roto"**: los pods llegan a Ready y el smoke test falla. Con
`if: failure()` a secas, también correría cuando falló el propio upgrade; Helm ya habría vuelto
atrás y ese segundo rollback desharía el primero, dejando la versión rota. Por eso la condición
pide que el step `deploy` terminara bien.

En el primer `install` no hay revisión anterior: `--rollback-on-failure` **desinstala** la release
(`has been uninstalled due to rollback-on-failure being set`). Teoría 03, práctica 02 paso 4.

</details>

**5.** Production vuelve de la `1.4.0` a la `1.3.2` con un rollback. La `1.4.0` añadió una columna
y los usuarios crearon tareas. ¿Qué devuelve Helm a su estado anterior y qué no? ¿Por qué el PVC
`db-data` lleva `helm.sh/resource-policy: keep`, y por qué no basta con cambiar el secreto
`DATABASE_PASSWORD` del environment para cambiar la contraseña de la base?

<details>
<summary>Respuesta</summary>

Helm devuelve los **objetos** de Kubernetes a la revisión anterior: imágenes, Services, Secrets.
No toca lo que los pods hicieron mientras corrían: la columna sigue en la base y las tareas
también. Por eso las migraciones de una app que se despliega así tienen que ser compatibles hacia
atrás al menos una versión.

`keep` hace que Helm no borre el PVC aunque una revisión ya no lo incluya o desinstales la
release: los datos sobreviven a un rollback que se equivoque o a un `--rollback-on-failure` en
el primer install. El precio es que borrarlo lo haces tú con `kubectl delete pvc`.

La contraseña: PostgreSQL la guarda en el volumen al **inicializarse**. Cambiar el secreto cambia
el Secret `db` en el siguiente despliegue, pero la base sigue esperando la de siempre y la API
deja de conectar. Por eso la práctica 02 genera la contraseña una vez y la guarda a la vez en el
clúster y en el environment. Teoría 03, práctica 02 paso 3.

</details>

**6.** Explica qué rechaza cada una de las cuatro `claimValidationRules` de
`authentication-config.yaml`. ¿Por qué `repository_id` y no `repository`, y por qué entre comillas?
¿Por qué una audiencia propia, `kind-gha`? Cuando un token no pasa, ¿qué ves y dónde?

<details>
<summary>Respuesta</summary>

| Regla | Rechaza |
|---|---|
| `repository_id == '<id>'` | Tokens de cualquier otro repo, incluido uno que ocupe el nombre de `tablero` tras borrarlo o renombrarlo |
| `ref == 'refs/heads/main'` | Un run lanzado desde otra rama |
| `job_workflow_ref == '.../deploy.yml@refs/heads/main'` | Cualquier otro workflow de `tablero`, aunque corra en `main` |
| `has(claims.environment) && environment in [...]` | Un job sin environment o con otro que no sea staging o production |

El nombre de un repo se puede reutilizar; el id, no. En el token de GitHub el id va **como
texto**, así que la expresión CEL compara con `'123...'`. La audiencia propia evita que un token
pedido para otro consumidor (una nube, por ejemplo) valga aquí: sin reglas ni audiencia propia,
cualquier repo de GitHub conseguiría un token aceptable.

Si algo falla, el cliente solo recibe un `401 Unauthorized` sin detalle: quien prueba tokens no
aprende qué le falta. El motivo queda en el log del apiserver. Teoría 04, práctica 01 paso 3.

</details>

**7.** Alguien saca el token OIDC del job de staging (un step comprometido). ¿Qué puede hacer con
él y qué no? ¿Por qué cada environment es un usuario con un `Role` en su namespace y no un
`ClusterRole`, y por qué el `Role` deja leer pods pero no crearlos?

<details>
<summary>Respuesta</summary>

Con él actúa como `github:staging` unos 5 minutos, lo que vive el token: leer el Secret `db` de
`tablero-staging`, cambiar sus Deployments a otra imagen, borrar su PVC. No puede tocar nada de
`tablero-production` ni de `arc-systems` o `arc-runners`, no puede crear un pod root (Pod Security
lo rechaza) y no puede pedir otro token: eso solo lo hace el job.

Un `ClusterRole` con su `ClusterRoleBinding` daría permisos en todos los namespaces: el token de
staging, el environment **sin** aprobación, llegaría a production y la aprobación de la Semana 13
dejaría de significar algo. Los pods los crea el ReplicaSet en nombre del Deployment, no el
usuario: el usuario solo los lee, igual que eventos y ReplicaSets, para que Helm espere el rollout
y tú veas por qué falla. `kubectl auth can-i --list -n tablero-production --as github:staging`
debe salir vacío. Teoría 05, práctica 01 paso 4.

</details>

**8.** Etiquetas `tablero-staging` con `pod-security.kubernetes.io/enforce: restricted`. Un pod de
prueba que corre como root no llega a crearse; el pod `web` del chart se crea pero queda en
`CreateContainerConfigError`. ¿Qué exige `restricted` y qué falla en cada caso?

<details>
<summary>Respuesta</summary>

`restricted` exige `allowPrivilegeEscalation: false`, quitar todas las capacidades
(`drop: [ALL]`), `runAsNonRoot: true` y `seccompProfile: RuntimeDefault`. El pod root incumple
todo y el **admission controller** lo rechaza antes de crearlo:
`violates PodSecurity "restricted:latest"`.

El pod `web` sí cumple el estándar, pero la imagen declara `USER nginx` por **nombre**. Con
`runAsNonRoot`, el kubelet tiene que comprobar que el uid no es 0 y, con un nombre, no puede:
`image has non-numeric user (nginx), cannot verify user is non-root`. Se arregla con
`runAsUser: 101`, el uid de `nginx` (y `70` para `postgres` en la imagen alpine), el mismo
problema que la Semana 16 resolvió con el uid 1001 del runner. Teoría 05, práctica 02 paso 2.

</details>

**9.** `ops/deploy/kubeconfig.yaml` está en el repo, público. ¿Por qué no es un riesgo? Explica
qué hace `github-token.sh`, por qué declara la caducidad a 4 minutos y por qué el token no va a
`$GITHUB_ENV`. ¿De dónde saca Helm el CA si el pod del runner no tiene token de ServiceAccount?

<details>
<summary>Respuesta</summary>

No lleva **ninguna credencial**: el servidor (`https://kubernetes.default.svc`), la ruta del CA y
un usuario con un plugin `exec`. client-go ejecuta `github-token.sh`, que pide a GitHub un token
OIDC con audiencia `kind-gha` (con `ACTIONS_ID_TOKEN_REQUEST_URL` y `..._TOKEN`, que solo existen
en un job con `id-token: write`) y lo devuelve como `ExecCredential` con `expirationTimestamp`.

El token de GitHub vive 5 minutos y un despliegue con `--timeout 3m` más un rollback puede
pasar de eso. Declarando la caducidad a 4, client-go vuelve a llamar al script antes de que el
token muera. El token vive en memoria de Helm: en `$GITHUB_ENV` lo verían todos los steps
siguientes y acabaría en disco. Es el patrón de `aws eks get-token`.

El CA es público: Kubernetes lo publica en el ConfigMap `kube-root-ca.crt` de cada namespace, y
`ops/arc/values.yaml` lo monta en `/etc/kube-ca`. El pod sigue con
`automountServiceAccountToken: false`: la única identidad es la del job. Teoría 06, práctica 01
paso 2.

</details>

**10.** Los jobs `staging` y `production` llevan `concurrency` con `cancel-in-progress: false` y
grupos `deploy-staging` y `deploy-production`. ¿Por qué el grupo va en el job y no en el
workflow, por qué no `true`, y qué pasa si llegan tres releases seguidas? ¿Por qué `tablero` no
usa `queue: max`?

<details>
<summary>Respuesta</summary>

En el **job**, para que el run B pueda verificar mientras el run A despliega y solo espere al
tocar el namespace; y con grupos distintos, que production espere tu aprobación no bloquea el
siguiente despliegue a staging. Con `true`, el segundo run cancelaría al primero quizá a mitad de
un `helm upgrade`, dejando la release a medias.

Con `false` solo hay **un** pendiente por grupo: el tercer run sustituye al pendiente, que se
cancela, y la release del medio no llega a ese environment. No es grave: el último run despliega
la versión más reciente, que incluye los cambios de la anterior. `queue: max` lo convertiría en
una fila, pero actionlint 1.7.12 aún la rechaza y rompería el CI de `tablero`. Teoría 07,
práctica 04 paso 4.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — El clúster confía en GitHub | El runner monta el CA desde `kube-root-ca.crt` sin token; `authentication-config.yaml` con audiencia `kind-gha` y las cuatro reglas; el apiserver la tiene cargada; namespaces `restricted` y un `Role` por environment aplicados (checks `runner-mounts-kube-ca`, `oidc-authn-config`, `apiserver-oidc-config-loaded`, `namespaces-restricted`, `rbac-per-environment`, `cluster-rbac-applied`) | 5 |
| 01 — El clúster confía en GitHub | Enseña el hash de la métrica igual al `sha256sum` del archivo, copiado con `cp` y `mv`; el `401 Unauthorized` con un token falso; y la matriz de `kubectl auth can-i` con `yes` solo en el namespace de cada usuario | 5 |
| 02 — Chart y rollback con Helm | El chart rechaza tags y renderiza con digests; cada pod sin root, sin token, sin escalada ni capacidades, con seccomp y límites; historial de staging con una revisión `failed` y su rollback automático (checks `chart-digest-only`, `chart-pods-restricted`, `rollback-drill`) | 5 |
| 02 — Chart y rollback con Helm | Enseña el pod root rechazado por `restricted`, la instalación como `github:staging` con el smoke test en verde por port-forward en `127.0.0.1`, y el `helm rollback` a mano con su revisión `Rollback to N` | 5 |
| 03 — deploy.yml | Solo `lab.yml` y `deploy.yml` piden runners propios, por dispatch; `verify` en `ubuntu-24.04` con `attestations: read`; staging y production en su environment, en cola sin cancelar; kubeconfig sin credenciales con el plugin; Helm con checksum, `--rollback-on-failure` y rollback tras el smoke test; actionlint y zizmor limpios (checks `own-runners-dispatch-only`, `deploy-verifies-attestations`, `deploy-environments`, `deploy-kubeconfig-oidc`, `deploy-helm-rollback`, `workflows-lint`) | 5 |
| 03 — deploy.yml | `deploy-gate.yml` borrado; `github-token.sh` falla fuera de un job (`ACTIONS_ID_TOKEN_REQUEST_TOKEN: unbound variable`); el primer run lanzado a mano con `Verificar imágenes`, `Staging` y `Production` en `success` | 5 |
| 04 — Promoción, aprobación y rollback | `release.yml` lanza `deploy.yml` tras las imágenes, desde un job con `actions: write`; production corre la última release por el digest de su attestation; el run de esa versión y su deployment de production en `success` (checks `release-dispatches-deploy`, `production-runs-latest-release`, `deploy-green-for-release`) | 5 |
| 04 — Promoción, aprobación y rollback | La aprobación con su comentario en el run; el rollback de negocio a la versión anterior por dispatch y la vuelta a la última, visibles en `helm history` de production; y dos despliegues a la vez con el segundo `Staging` en espera, no cancelado | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 17` con 18/18. Cada comprobación en rojo
resta la parte proporcional (12/18 de punto).

**Calidad manual de la capa 17 (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| `production` tiene un revisor obligatorio y solo admite la rama `main`, y lo enseñas con la API, no de memoria | 3 |
| Las contraseñas de `DATABASE_PASSWORD` son distintas en staging y production, solo letras y números, y ninguna aparece en un log ni en un commit | 3 |
| Cada regla de `authentication-config.yaml` lleva un `message` que dice qué falló, en una frase | 2 |
| Los Roles no tienen un verbo ni un recurso que el chart no use, y un comentario dice por qué Helm necesita `secrets` | 3 |
| Los recursos de prueba de las prácticas están borrados: ni ServiceAccounts de prueba en los namespaces de `tablero` ni pods sueltos en `arc-runners` | 2 |
| El chart de `deploy/k8s/` es el de `app/` sin cambios, o cada cambio va explicado en el commit | 3 |
| Sin `TODO` en el repo | 2 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log, o el token OIDC impreso en un log, en el resumen del job o escrito en `$GITHUB_ENV` | Grave: Producto a 0 hasta rotar el secreto y retirar el log |
| Credencial de Kubernetes guardada en GitHub o en el repo: un kubeconfig con certificado o token, un token de ServiceAccount, en un secreto, una variable o un commit | Grave: Producto a 0 hasta invalidarla (borrar el ServiceAccount o recrear el clúster) y retirar el secreto o el commit |
| `authentication-config.yaml` sin las reglas de `repository_id`, `ref`, `job_workflow_ref` y `environment`, o con una audiencia que no es propia | Grave: −10 |
| Runner propio al alcance de PRs de forks: un workflow con `pull_request*` que pide `tablero-runners`, o una política de aprobación distinta de `all_external_contributors` | Grave: −10 |
| `pull_request_target` con checkout del head del PR | Grave: −10 |
| `uses:` remota sin SHA, o con un SHA copiado que no pertenece al repo oficial | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}`, `github.head_ref`, `inputs.*`, `secrets.*` o `vars.*` interpolado dentro de `run:` | Grave: −10 |
| Imagen sin tag o con `latest`, o un despliegue que no va por digest | Grave: −10 |
| `ClusterRole`, `ClusterRoleBinding` o comodines (`*`) para los usuarios `github:<env>` | −5 |
| Namespace de `tablero` sin `enforce: restricted`, o un pod del chart con root, escalada o token montado | −5 |
| Helm descargado sin comprobar el checksum, o instalado con `curl \| bash` | −5 |
| `cancel-in-progress: true` en un job de despliegue, o un job de despliegue sin `concurrency` | −5 |
| `id-token: write` en la raíz, en `verify` o en cualquier job sin environment | −5 |
| Desplegar sin pasar por `verify`, o `verify` sin `--signer-workflow` | −5 |
| Apiserver de `kind-gha` publicado fuera de `127.0.0.1` | −5 |
| `secrets: inherit` al llamar a un reutilizable | −3 |
| Job con `runs-on` sin `timeout-minutes` | −3 por cada uno |
| `pip`, `npm` o Compose v1 en un workflow o en la documentación de tu repo | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

## 🏁 Minisimulacro de cierre de la Fase 5

Cierra las semanas 15-17 en las condiciones del examen GH-200: **60 minutos cronometrados**, sin
abrir la teoría ni buscar en la web. Cubre los dominios D1 (escribir y mantener workflows) y D2
(consumir y depurar workflows), con repaso de D4 (gestionar Actions en la organización). Pon el
reloj antes de leer la primera pregunta.

| Parte | Qué es | Tiempo | Puntos |
|---|---|:--:|:--:|
| A | 12 preguntas tipo test, una sola respuesta correcta | 35 min | 12 |
| B | Un arreglo de parche de `tablero` que llega a production | 25 min | 8 |
| **Total** | | **60 min** | **20** |

**Aprobado: 14 puntos (70 %).** No suma a los pesos de la semana: es tu termómetro de la fase. Si
no llegas, la explicación de cada fallo te dice qué semana repasar antes de la Fase 6.

### Parte A — Preguntas tipo test (35 minutos)

Marca una opción por pregunta y apunta tus respuestas; abre las soluciones solo al final.

**A1.** Un runner propio tiene las etiquetas `self-hosted`, `Linux`, `X64` y `tablero-lab`. ¿Qué
job recoge?

- A) `runs-on: [self-hosted, tablero-lab, gpu]`, porque coincide en dos etiquetas
- B) `runs-on: [self-hosted, linux]`: el runner tiene todas las etiquetas pedidas
- C) `runs-on: ubuntu-24.04`, porque es Linux X64
- D) Ninguno: `runs-on` solo acepta una etiqueta

<details>
<summary>Solución</summary>

**B.** Una lista en `runs-on` exige **todas** sus etiquetas, y un runner con más de las pedidas
también vale. A queda en cola por `gpu`; `ubuntu-24.04` es una etiqueta de los runners de
GitHub. Semana 15, teoría 03.

</details>

**A2.** Quieres que un runner propio solo lo pueda usar `tablero` en una organización del plan
Free. ¿Qué haces?

- A) Creas un runner group con solo `tablero` y registras ahí un runner de organización
- B) Registras un runner de repositorio en `tablero` y limitas la política de runners de repositorio de la org a `tablero`
- C) Pones `if: github.repository == '<tu-org>/tablero'` en cada job
- D) Basta con una etiqueta única que solo conozca `tablero`

<details>
<summary>Solución</summary>

**B.** En Free no hay garantía de poder crear grupos adicionales; el runner de repositorio no lo
ve ningún otro repo, y la política impide que otro repo registre los suyos. C y D no impiden nada:
cualquiera puede escribir esa etiqueta o quitar ese `if`. Semana 15, teoría 06.

</details>

**A3.** `tablero` es público y tiene un runner propio. ¿Qué frena que un PR desde un fork ejecute
código en tu máquina?

- A) Que los workflows con runner propio solo escuchen `workflow_dispatch`
- B) Que el PR de un fork no recibe secretos
- C) La aprobación obligatoria para todos los contribuidores externos antes de que corra ningún workflow de su PR
- D) La aprobación solo para quien contribuye por primera vez

<details>
<summary>Solución</summary>

**C.** En un `pull_request` corren los workflows del commit del PR: el atacante trae el suyo con
`runs-on` hacia tu runner, así que A no basta. B no protege la máquina, y D se esquiva con un
primer PR inocente. Semana 15, teoría 07.

</details>

**A4.** ¿Qué distingue a un runner JIT de uno persistente?

- A) Corre más rápido porque reutiliza `_work`
- B) Acepta un solo job y su configuración no sirve para registrar otro; tras el job se da de baja
- C) Solo funciona en runners alojados por GitHub
- D) No necesita ninguna credencial para registrarse

<details>
<summary>Solución</summary>

**B.** La configuración JIT es de un solo uso y el runner acepta un job como mucho. Aun así,
"efímero" es el runner, no la máquina: lo que garantiza que nada pasa al siguiente job es
destruirla, por eso el contenedor con `--rm`. Semana 15, teoría 04.

</details>

**A5.** Un scale set de ARC se llama `tablero-runners`. ¿Qué escribe un job para usarlo?

- A) `runs-on: [self-hosted, tablero-runners]`
- B) `runs-on: tablero-runners`
- C) `runs-on: arc`
- D) `runs-on: kubernetes`

<details>
<summary>Solución</summary>

**B.** ARC elige el scale set por su nombre; nada garantiza que el runner lleve la etiqueta
`self-hosted`, y pedir una etiqueta que no tiene deja el job en cola hasta caducar a las 24
horas. Semana 16, teoría 05.

</details>

**A6.** Con `minRunners: 0` y `maxRunners: 2` llegan tres jobs a la vez para el mismo scale set.
¿Qué pasa?

- A) ARC crea tres pods y borra el sobrante
- B) Dos pods corren dos jobs; el tercero espera en cola a que acabe uno
- C) El tercer job falla de inmediato
- D) Los tres comparten los dos pods

<details>
<summary>Solución</summary>

**B.** ARC crea runners hasta `maxRunners`, uno por job; el resto espera. Sin jobs y con
`minRunners: 0` no hay ningún pod. Semana 16, teoría 05.

</details>

**A7.** ¿Con qué credencial debería autenticarse ARC ante GitHub en una organización?

- A) Un PAT clásico con scope `repo`
- B) El `GITHUB_TOKEN` del workflow que pide el runner
- C) Una GitHub App instalada solo en los repos que la necesitan
- D) Una deploy key del repo

<details>
<summary>Solución</summary>

**C.** La App tiene permisos uno a uno y solo alcanza los repos donde está instalada; ARC firma
con su clave un JWT corto y lo cambia por un token de instalación de una hora. El PAT es de una
persona y alcanza todo lo que ella puede tocar. Semana 16, teoría 04.

</details>

**A8.** Un job declara `environment: production`, con un revisor obligatorio. ¿Qué es cierto?

- A) El job arranca y se detiene antes del primer step que use un secreto
- B) El job no arranca ni ve los secretos del environment hasta que alguien lo aprueba, y GitHub registra un deployment de ese environment
- C) La aprobación se pide en el PR que cambió el workflow
- D) Solo los administradores de la org pueden aprobarlo

<details>
<summary>Solución</summary>

**B.** Las reglas de protección se evalúan antes de que el job empiece; hasta entonces no hay
runner ni secretos. Un job con `environment` crea un deployment con sus estados, visible en la
portada del repo, en la página de environments y en la API. Semana 13, teoría 03, y Semana 17,
teoría 01.

</details>

**A9.** Un workflow de despliegue tiene en su job
`concurrency: { group: deploy-production, cancel-in-progress: false }`. Hay un run desplegando y
llegan dos más. ¿Qué pasa?

- A) Los dos esperan en fila y se ejecutan en orden
- B) El primero que llegó queda pendiente y el segundo lo sustituye: solo queda uno pendiente
- C) Se cancela el run que está desplegando
- D) Los tres corren a la vez, porque `false` desactiva la concurrencia

<details>
<summary>Solución</summary>

**B.** Solo hay un pendiente por grupo; el nuevo cancela al que esperaba. Con
`cancel-in-progress: true` se cancelaría el que despliega (C), que es lo que un despliegue no
quiere. Semana 07 y Semana 17, teoría 07.

</details>

**A10.** Un job crea una release con `GITHUB_TOKEN`. Otro workflow escucha `on: release`. ¿Cómo
se lanza el despliegue tras la release sin añadir credenciales?

- A) No se puede: hace falta un PAT
- B) El workflow `on: release` se dispara solo; no hay que hacer nada
- C) Desde el mismo run, un job con `actions: write` lanza el workflow de despliegue por `workflow_dispatch`
- D) Con `on: workflow_run` sobre cualquier workflow, que no necesita permisos

<details>
<summary>Solución</summary>

**C.** Los eventos que provoca `GITHUB_TOKEN` no disparan workflows, salvo `workflow_dispatch` y
`repository_dispatch`. B es justo lo que no ocurre; A añade una credencial sin necesidad.
Semana 17, teoría 01.

</details>

**A11.** Un consumidor de tokens OIDC de GitHub quiere aceptar solo los de un workflow concreto
de un repo, desde `main`. ¿Qué claim lo identifica mejor?

- A) `aud`
- B) `actor`
- C) `job_workflow_ref`, junto al id del repo y el `ref`
- D) `iss`

<details>
<summary>Solución</summary>

**C.** `job_workflow_ref` dice qué archivo de workflow y en qué ref corrió el job. `iss` es el
mismo para todos los tokens de GitHub, `aud` lo elige quien pide el token y `actor` es una
persona, no un workflow. La decisión siempre la toma el consumidor. Semana 13, teoría 04, y
Semana 17, teoría 04.

</details>

**A12.** Quieres saber qué commit llegó a production y cuándo, meses después, cuando los runs ya
han caducado. ¿Dónde miras?

- A) En los logs del último run de despliegue
- B) En la API de deployments: `repos/{owner}/{repo}/deployments?environment=production`
- C) En `gh run list`, que guarda los runs para siempre
- D) En los artefactos del workflow

<details>
<summary>Solución</summary>

**B.** Cada deployment guarda commit, environment y estados (`deployments/<id>/statuses`), y no
caduca con los logs. Semana 17, teoría 01.

</details>

### Parte B — Un arreglo de parche que llega a production (25 minutos)

Lleva a `tablero-production` la siguiente versión de **parche** de `tablero` con un arreglo
pequeño de tu elección en `api/`: un mensaje de error más claro, una validación que faltaba. Nada
de cambios en `.github/`, `ops/` ni `deploy/`: la cadena de la Fase 5 tiene que llevar ese cambio
hasta el clúster sin que la toques. Antes de empezar, `kind-gha` arrancado y ARC con su scale set
`deployed`.

> ⚠️ **Una release publicada no se rehace.** Si el despliegue falla, no muevas el tag ni borres la
> release: Helm ya habrá vuelto atrás, y el arreglo es otro `fix` y la siguiente versión.

Lo que tienes que hacer, sin más guía que lo aprendido en la fase:

1. Una rama con el arreglo en un commit `fix(api): ...`, su PR con los checks en verde y el merge.
2. El PR de release que abre release-please, revisado y fusionado.
3. El run de `deploy.yml` que lanza `release.yml`, con staging en verde y tu aprobación de
   production con un comentario.

Corrige con estas ocho comprobaciones, 1 punto cada una:

```bash
cd ~/code/tablero && git switch -q main && git pull -q --ff-only && git fetch -q --tags
export GH_REPO=<tu-org>/tablero
o=$(gh repo view "$GH_REPO" --json owner --jq '.owner.login | ascii_downcase')
new=$(gh release view --json tagName --jq .tagName); v=${new#v}
prev=$(git describe --tags --abbrev=0 "$new^")
# 1. La versión nueva es el parche siguiente, publicada por release-please
echo "$prev -> $new $(gh release view --json author --jq .author.login)"
# v1.4.0 -> v1.4.1 github-actions[bot]
# 2. Nadie tocó la cadena entre las dos versiones
git diff --name-only "$prev" "$new" -- .github ops deploy | wc -l
# 0
# 3. release.yml en verde sobre el commit del tag, con el despliegue lanzado
run=$(gh run list --workflow release.yml --commit "$(git rev-list -n 1 "$new")" --json databaseId --jq '.[0].databaseId')
gh run view "$run" --json jobs --jq '.jobs[] | select(.name == "Lanzar el despliegue") | .conclusion'
# success
# 4. Un run de deploy.yml con esa versión, lanzado por dispatch y en verde
gh run list --workflow deploy.yml --json displayTitle,event,conclusion \
  --jq "[.[] | select(.displayTitle == \"deploy $v\")][0] | \"\(.event) \(.conclusion)\""
# workflow_dispatch success
# 5. Production lo aprobó una persona, con comentario
id=$(gh run list --workflow deploy.yml --json databaseId,displayTitle --jq "[.[] | select(.displayTitle == \"deploy $v\")][0].databaseId")
gh api "repos/{owner}/{repo}/actions/runs/$id/approvals" --jq '.[0] | "\(.state) \(.comment != "")"'
# approved true
# 6. Su deployment de production terminó en success
sha=$(gh run view "$id" --json headSha --jq .headSha)
dep=$(gh api "repos/{owner}/{repo}/deployments?environment=production&sha=$sha" --jq '.[0].id')
gh api "repos/{owner}/{repo}/deployments/$dep/statuses" --jq '.[0].state'
# success
# 7. production corre el digest que cubre la attestation de esa versión
for c in api web; do
  want="ghcr.io/$o/tablero-$c@sha256:$(gh attestation verify "oci://ghcr.io/$o/tablero-$c:$v" --repo "$GH_REPO" \
    --signer-workflow "$GH_REPO/.github/workflows/release.yml" --source-ref refs/heads/main --format json --jq '.[0].verificationResult.statement.subject[0].digest.sha256')"
  have=$(kubectl --context kind-gha -n tablero-production get deploy $c -o jsonpath='{.spec.template.spec.containers[0].image}')
  [[ "$have" == "$want" ]] && printf 'ok ' || printf 'mal '
done; echo
# ok ok
# 8. La capa sigue completa
cd ~/code/bc-github-actions && ./scripts/check-week.sh 17 | tail -1
# 18/18 comprobaciones superadas.
```

<details>
<summary>Solución de referencia y fallos típicos</summary>

```bash
# 1. El arreglo, por PR
cd ~/code/tablero && git switch -c fix/api-empty-title
# ... el arreglo en api/ y su test ...
git commit -am "fix(api): reject tasks with an empty title" && git push -u origin HEAD
gh pr create --fill && gh pr checks --watch > /dev/null && gh pr merge --squash --delete-branch

# 2. El PR de release
git switch main && git pull -q --ff-only && sleep 5
pr=$(gh pr list --label "autorelease: pending" --json number --jq '.[0].number')
gh pr diff "$pr"
gh pr merge "$pr" --squash --delete-branch

# 3. release.yml publica y lanza deploy.yml; aprueba production cuando staging esté en verde
git switch main && git pull -q --ff-only && sleep 10
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
id=$(gh run list --workflow deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId')
pending="repos/{owner}/{repo}/actions/runs/$id/pending_deployments"
until [ "$(gh api "$pending" --jq length)" -gt 0 ]; do sleep 10; done
gh api -X POST "$pending" -F "environment_ids[]=$(gh api "$pending" --jq '.[0].environment.id')" \
  -f state=approved -f comment="Staging en verde" > /dev/null
gh run watch "$id" --exit-status > /dev/null && echo deploy ok
```

Fallos que cuestan puntos:

- **El clúster no estaba arrancado o ARC no tenía su scale set**: `staging` se queda en cola
  esperando a `tablero-runners` y el reloj corre. Arranca el laboratorio antes de poner el reloj.
  Semana 16, práctica 03.
- **`deploy.yml` no arranca tras la release**: falta el job `deploy` en `release.yml` o no tiene
  `actions: write`. No lo arregles con un `on: release`: no se dispararía. Semana 17, teoría 01.
- **`Staging` falla con `the server has asked for the client to provide credentials`**: el
  apiserver rechazó el token. Mira su log y la regla que no pasa; si recreaste el clúster, falta
  copiar `authentication-config.yaml` con `cp` y `mv`. Semana 17, práctica 01 paso 3.
- **`Staging` falla con `secrets is forbidden`**: el `Role` no se aplicó tras recrear el clúster.
  Semana 17, práctica 01 paso 4.
- **Aprobar production sin mirar staging**: la aprobación vale lo que la comprobación que hay
  detrás. Abre el resumen de `Staging` y el smoke test antes de pulsar. Semana 17, teoría 01.
- **Retocar `deploy.yml` "ya que estabas"**: la comprobación 2 lo ve. Un cambio de la cadena va
  en su propio PR con su `ci:`. Semana 14, teoría 01.

</details>

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 17 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
