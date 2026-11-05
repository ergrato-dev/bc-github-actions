# Rúbrica de evaluación — Semana 13

> Secretos, entornos y OIDC. Se aprueba con un **mínimo del 70 % en cada evidencia**, no en el
> promedio.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de la capa 13 |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** Un compañero propone guardar `DATABASE_PASSWORD` también a nivel de repo "como valor por
defecto": como el secreto de environment gana, dice, los jobs de despliegue seguirán recibiendo
el suyo. ¿Tiene razón sobre la precedencia? ¿Por qué la propuesta empeora la seguridad igualmente?
¿Y qué pasa si alguien borra por error el secreto de staging y no hay ninguno de repo?

<details>
<summary>Respuesta</summary>

Sobre la precedencia tiene razón: gana el nivel más bajo, environment sobre repo y repo sobre
org. Un job con `environment: staging` recibe el valor de staging.

Pero la precedencia decide **qué valor** recibe un job, no **quién** lo recibe. Un secreto de
repo llega a cualquier job del repo que lo referencie, sin environment, sin regla de ramas y sin
revisor: el job de lint, un workflow nuevo en una rama o un reutilizable al que se lo pases. Lo
que protegía la contraseña era precisamente que solo existiera en el environment, cuyo job no
arranca desde otra rama ni antes de la aprobación. Por eso `env-secrets` exige que no exista a
nivel de repo.

Sin secreto de repo y sin el de staging, el job no da error: `secrets.DATABASE_PASSWORD` llega
como **cadena vacía**. El service container arranca con una contraseña vacía o falla, y el
síntoma (`password authentication failed`) no dice "falta el secreto". Se comprueba con
`gh secret list --env staging` o con un `test -n` al principio del job. Teoría 01.

</details>

**2.** En el laboratorio de la práctica 01, el base64 de `SHADOW_DEMO` salió como `***` y su
versión al revés salió en claro. Explica las dos cosas. Con eso en mente, ¿qué tiene de malo un
paso `echo "$DATABASE_PASSWORD"` "para comprobar que llega", y por qué no conviene guardar como
un único secreto un JSON con usuario, contraseña y host?

<details>
<summary>Respuesta</summary>

El runner registra como máscara el valor exacto del secreto y además algunas codificaciones que
conoce: base64 (con sus variantes desplazadas) y los escapes de URL, JSON y XML. Una línea que
contenga cualquiera de ellas se redacta. `rev` es una transformación que el runner no conoce:
da otra cadena y sale en claro, igual que una subcadena o un `sha256sum`.

La propia documentación dice que la redacción "is not guaranteed". `echo "$SECRET"` apuesta la
credencial a que ninguna transformación intermedia (una herramienta que la reformatea, un
`set -x`, un job distinto que no la referencia) la saque del patrón. Para comprobar que llega
basta `test -n`, la longitud o una comparación, que no imprimen el valor.

Con un JSON, la máscara es el JSON entero. Si un paso extrae el campo `password` con `jq` y lo
imprime, esa cadena no es la máscara y aparece en claro. Un secreto por valor. Teoría 02.

</details>

**3.** Alguien lanza `deploy-gate` con `gh workflow run deploy-gate.yml --ref feature/x`. Recorre
lo que pasa con el job `staging`: en qué momento se para, qué mensaje ves y si llega a recibir
`DATABASE_PASSWORD`. ¿Y si un desconocido abre desde un fork un PR que modifica
`deploy-gate.yml` para imprimir el secreto?

<details>
<summary>Respuesta</summary>

Las reglas de un environment se evalúan en orden: rama, revisores, wait timer y, solo al final,
arranque del job. La primera ya falla: `feature/x` no está en las ramas permitidas, y el job
termina en el acto con `Branch "feature/x" is not allowed to deploy to staging due to
environment protection rules.` No hay nada que aprobar y el runner **no recibe** los secretos
ni las variables del environment, que solo se entregan cuando el job arranca. Es el paso 6 de la
práctica 02.

El PR del fork no llega ni a eso. `deploy-gate` solo escucha `push` a `main` y
`workflow_dispatch`: un PR no lo dispara. Aunque escuchara `pull_request`, un PR de un fork no
recibe secretos (salvo un `GITHUB_TOKEN` de solo lectura), su ref no es `main` y el workflow que
corre es el del PR, sin acceso a lo que protege el environment. Teorías 01 y 03.

</details>

**4.** En `tablero`, production tiene un revisor obligatorio con `prevent_self_review: false`.
¿Qué protege esa regla si el único revisor eres tú, que también haces los push? ¿Qué cambiarías
en un equipo de cuatro personas? Y si haces dos push seguidos a `main` mientras el primer run
espera tu aprobación, ¿qué le pasa al segundo y por qué no queremos que lo cancele?

<details>
<summary>Respuesta</summary>

Trabajando solo, la regla no separa funciones, pero sí impone una **pausa deliberada**: nada
llega a production sin que alguien mire el diff y el resultado de staging, y la aprobación deja
un registro con su comentario. Con `prevent_self_review: true` y un solo revisor nadie podría
aprobar, y el despliegue caducaría a los 30 días.

En un equipo, `prevent_self_review: true` y varios revisores (basta con que apruebe uno): quien
lanza el despliegue no puede aprobárselo. Y "Allow administrators to bypass" desmarcada salvo
emergencias.

El segundo run queda en cola: `deploy-gate` declara `concurrency` con un grupo fijo y
`cancel-in-progress: false`. Espera a que el primero termine, aprobado o rechazado. Cancelar
cortaría un despliegue a medias, con una migración aplicada en staging y no en production. Que el
segundo se quede en `Pending` es el comportamiento buscado. Teoría 03.

</details>

**5.** El job de lint de `ci-api` no tiene `id-token: write`. Si alguien le añade el paso del
token con `curl`, el log dice `curl: (6) Could not resolve host: &audience=tablero-verifier`.
Explica el mensaje. Si `id-token: write` "no da acceso a nada", ¿por qué la regla es declararlo
solo en los jobs de `deploy-gate` y nunca en la raíz?

<details>
<summary>Respuesta</summary>

Sin el permiso, el runner no define `ACTIONS_ID_TOKEN_REQUEST_URL` ni
`ACTIONS_ID_TOKEN_REQUEST_TOKEN`. La URL se expande a cadena vacía y `curl` recibe
`&audience=tablero-verifier`, que interpreta como un nombre de host. El error no menciona
permisos: por eso es el síntoma típico.

Es cierto que `id-token: write` solo deja **pedir** un token de identidad: no escribe en el repo
ni da acceso por sí mismo. Pero ese token dice "soy un job de `tablero`", y lo que consiga lo
decide la política del otro lado. Si una nube acepta ese `sub`, cualquier job con el permiso
puede intentar conseguirlo. En la raíz lo tendrían el lint, los tests y cualquier action de
terceros de esos jobs. En los dos jobs de despliegue solo lo tiene código que pasa por la regla
de ramas y, en production, por tu aprobación. Es lo que comprueba `id-token-scoped`. Teoría 04.

</details>

**6.** En el paso del token de `deploy-gate`, el JWT va de `curl` a `jq` y de `jq` a
`oidc-verifier` por un pipe. ¿Qué se ganaría y qué se perdería guardándolo antes en
`$GITHUB_ENV`? ¿Qué papel tiene el `shell: bash` de `defaults.run` en ese pipe, si el verificador
ya falla cuando no le llega ningún token?

<details>
<summary>Respuesta</summary>

Se ganaría comodidad y nada más. Se perdería mucho: `$GITHUB_ENV` define la variable para
**todos los pasos siguientes** del job, incluidas actions de terceros, y el token es una
credencial válida durante minutos. Además un valor que el runner no conoce como secreto no se
enmascara: cualquier paso que lo imprima lo publica. En el pipe, el token vive solo en la memoria
de tres procesos del mismo paso y nunca toca el disco ni el log.

Con `shell: bash` explícito el runner ejecuta `bash --noprofile --norc -eo pipefail {0}`; sin
él, `bash -e {0}`, sin `pipefail`, y el estado del pipe es el de su último comando. Aquí, si
`curl` falla, `jq` no emite nada y el verificador acaba en `rechazado: no llegó ningún token por
stdin`: el paso falla, pero el mensaje apunta al sitio equivocado. Y basta con que alguien añada
al final un comando que tolere la entrada vacía (un `tee`, un `head`) para que el paso salga verde
sin token. `pipefail` hace que falle el primer eslabón roto. Teoría 04.

</details>

**7.** Un compañero quiere "simplificar" `oidc-verifier`: (a) usar el algoritmo que diga la
cabecera del token en lugar de fijar `RS256`, (b) no pedir audiencia y aceptar la de por defecto,
(c) no comprobar `exp`. Para cada cambio, describe un token que pasaría y no debería.

<details>
<summary>Respuesta</summary>

**(a)** La cabecera la escribe quien fabrica el token. Con `alg: none` no hay firma que
comprobar; con un algoritmo simétrico como `HS256`, la librería podría usar la clave pública
(que es pública) como secreto HMAC, y cualquiera firmaría tokens válidos. La lista cerrada
`RS256`, junto con el `kid` buscado en el JWKS del emisor, hace que solo valga una firma de
GitHub.

**(b)** Sin el parámetro `audience`, `aud` es la URL del propietario, `https://github.com/<tu-org>`,
igual para todos los consumidores. Un token que un job pidió para otra nube o para otra
herramienta pasaría aquí. Cada consumidor exige su audiencia (`tablero-verifier`) y el job la
pide.

**(c)** Un token filtrado (en un log, en un artefacto) sería válido para siempre. Con `exp`,
`iat` y `nbf` obligatorios y 30 s de margen, vale minutos. Teorías 05 y 06.

</details>

**8.** Compara tres valores de `OIDC_SUB` para production: `repo:<tu-org>/tablero:*` (con
comodín), el `sub` exacto con `environment:production` sin `job_workflow_ref`, y el `sub` exacto
de la plantilla `repo`, `context`, `job_workflow_ref`. Un colaborador añade a `main` un
`debug.yml` con un job que declara `environment: production` y pide un token con tu audiencia.
¿Con cuál de los tres lo consigue? ¿Por qué la `ref` se comprueba aparte?

<details>
<summary>Respuesta</summary>

Con el comodín, cualquier rama, tag, PR o environment de `tablero` coincide: el más débil, y una
rama de pruebas obtendría lo que se le dé a production. Con `environment:production` a secas,
`debug.yml` produce exactamente el mismo `sub` que `deploy-gate.yml`: el environment no dice qué
workflow lo usa. La regla de ramas no lo frena porque `debug.yml` ya está en `main`; solo lo
frena tu aprobación, si no te despistas.

Con la plantilla, el `sub` termina en
`job_workflow_ref:<tu-org>/tablero/.github/workflows/debug.yml@refs/heads/main`, que no es el
esperado: el verificador lo rechaza con `rechazado: sub '...' no es el esperado '...'`. Por eso
la comparación es igualdad exacta, sin comodines ni expresiones regulares.

La `ref` va aparte porque, con environment, el `sub` sustituye la rama por `environment:NAME`.
La regla de ramas garantiza que `environment:production` implica `main`, y el verificador lo
confirma con `--claim ref=refs/heads/main`, igual que `runner_environment=github-hosted`.
Teorías 05 y 06; práctica 04, paso 4.

</details>

**9.** Tu `sub` incluye `<tu-org>@<id-org>/tablero@<id-repo>`. ¿Qué ataque cierra ese formato
inmutable y por qué no basta con comprobar el claim `repository`? ¿Por qué la práctica 03 te
hace copiar `OIDC_SUB` de un token real en lugar de escribirlo a partir de la teoría?

<details>
<summary>Respuesta</summary>

Un nombre se reutiliza: si `<tu-org>/tablero` se borra o se renombra, otra cuenta puede crear
un repo con ese nombre, y su `sub` clásico sería idéntico al tuyo. Una política escrita sobre el
nombre aceptaría sus tokens. Los IDs numéricos del propietario y del repo no se reutilizan, así
que el `sub` inmutable de ese nuevo repo es distinto. `repository` es solo el nombre: tiene el
mismo problema. Si hace falta un claim aparte, `repository_id`.

El `sub` exacto tiene detalles que no se adivinan: los IDs, la codificación `%3A` de los `:`
dentro de un valor y, sobre todo, el formato con environment y plantilla, del que la
documentación no da ejemplo en formato inmutable. Escrito de memoria, un carácter de diferencia
hace que no coincida nunca. Copiado del payload de un token real, después de comprobar que es el
tuyo, coincide por construcción. Teoría 05; práctica 03, pasos 5 y 6.

</details>

**10.** En `tablero`, el verificador corre dentro del mismo job que pide el token. Alguien con
escritura en `main` podría borrar ese paso de `deploy-gate.yml`. Entonces, ¿qué demuestra de
verdad el verificador? ¿Dónde tiene que vivir la verificación cuando la Semana 17 despliegue de
verdad, y qué protege a `tablero` mientras tanto?

<details>
<summary>Respuesta</summary>

En `tablero`, el verificador es una **simulación del otro lado del trato**: enseña qué comprueba
un consumidor (firma con el JWKS, emisor, audiencia, caducidad, `sub` exacto y claims) y que el
token que firma GitHub cumple la política que escribiste. No es un control frente a quien
controla el workflow: quien puede editar el job puede saltarse el paso.

En el mundo real la verificación vive en el **consumidor**, fuera del alcance del workflow: la
trust policy de AWS, la federated credential de Entra ID, la attribute condition de Google Cloud
o el trusted publisher de PyPI. Ahí borrar un paso no sirve de nada: sin un token que cumpla la
política, la nube no entrega credenciales.

Mientras tanto protegen a `tablero` las capas que no dependen del YAML del job: la regla de
ramas de los dos environments, el revisor de production, los secretos solo de environment y que
`deploy-gate` no escuche eventos de PR. Teorías 03, 04 y 06.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Secretos de repo, environment y org | `DATABASE_PASSWORD` en staging y production y no en el repo; `deploy-gate.yml` da a PostgreSQL el secreto de su environment; ningún `run:` con `${{ }}` (checks `env-secrets`, `gate-env-secret`, `no-expressions-in-run`) | 5 |
| 01 — Secretos de repo, environment y org | Enseña las tres filas de precedencia (`gana=environment`, `gana=repo`, `gana=org`) sin imprimir ningún valor; explica por qué el base64 sale como `***` y el `rev` no; el secreto de org es `selected`; `SHADOW_DEMO` y `secrets-lab.yml` borrados | 5 |
| 02 — Environments y reglas de protección | Jobs `staging` y `production` con `needs`, `concurrency` sin cancelación, solo `main` despliega y production con revisor (checks `gate-environments`, `gate-concurrency`, `environments-protected`, `production-reviewers`) | 5 |
| 02 — Environments y reglas de protección | Aprueba production por la API de `pending_deployments` con un comentario que explica la decisión; enseña el rechazo de una rama que no es `main` y borra la rama de prueba | 5 |
| 03 — El token OIDC y sus claims | `id-token: write` solo en los dos jobs de despliegue, escrituras dentro de la lista, plantilla del `sub` y `OIDC_SUB` en cada environment (checks `id-token-scoped`, `writes-only-where-needed`, `oidc-sub-template`, `oidc-sub-vars`) | 5 |
| 03 — El token OIDC y sus claims | Lee el payload sin enseñar nunca el token; compara el `sub` sin y con environment y la audiencia por defecto con la pedida; explica por qué un PR nunca llega a ese token; `oidc-claims.yml` borrado | 5 |
| 04 — Verificador OIDC y deploy-gate | Verificador copiado y con 16 tests en verde, `ci-tools.yml` con el reutilizable central, token por stdin al verificador, linters limpios y la capa en verde con tu aprobación (checks `verifier-present`, `verifier-tests`, `ci-tools-reusable`, `gate-verifier`, `workflows-lint`, `green-on-main`) | 5 |
| 04 — Verificador OIDC y deploy-gate | Enseña el rechazo al cambiar `OIDC_SUB` de staging por el de production y lo restaura; explica el test de la clave ajena y por qué un token de otro workflow no vale; `dependabot.yml` vigila `/tools/oidc-verifier` | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 13` con 17/17. Cada comprobación en rojo
resta la parte proporcional (12/17 de punto).

**Calidad manual de la capa 13 (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| Las dos contraseñas se generaron con `openssl rand`, se cargaron por stdin y son distintas: no están en el historial del shell ni en un archivo | 3 |
| El token OIDC no se imprime en ningún sitio, ni siquiera enmascarado: va de `curl` a `jq` y de `jq` al verificador por un pipe | 3 |
| `OIDC_SUB` de cada environment es exactamente el `sub` que GitHub firmó, sin comodines | 2 |
| El secreto de prueba de la práctica 01 y los workflows temporales `secrets-lab.yml` y `oidc-claims.yml` están borrados | 2 |
| Si hay un secreto de org, su visibilidad es `selected` con solo los repos que lo usan | 2 |
| Los comentarios de `deploy-gate.yml` explican el porqué (concurrencia sin cancelación, `pipefail`, `id-token: write`), no repiten el YAML | 2 |
| Commits en Conventional Commits, uno por mecanismo (`ci: add deploy gate with environments`, `ci: verify oidc token in deploy gate`…) | 2 |
| Sin `TODO` en el repo | 2 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log, o el token OIDC impreso en un log o en el resumen del job | Grave: Producto a 0 hasta rotar el secreto y retirar el log |
| `pull_request_target` con checkout del head del PR | Grave: −10 |
| Runner propio al alcance de PRs de forks | Grave: −10 |
| `uses:` remota sin SHA, o con un SHA copiado que no pertenece al repo oficial | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}`, `github.head_ref`, `inputs.*`, `secrets.*` o `vars.*` interpolado dentro de `run:` o de `script:` | Grave: −10 |
| Imagen sin tag o con `latest` | Grave: −10 |
| `id-token: write` en la raíz de un workflow o en un job que no pide el token | −5 |
| `OIDC_SUB` con comodín, o un verificador o política que compara el `sub` por patrón | −5 |
| `DATABASE_PASSWORD` como secreto del repositorio | −5 |
| production sin revisor obligatorio, o con "Allow administrators to bypass" marcada sin motivo | −5 |
| `cancel-in-progress: true` en `deploy-gate` | −5 |
| La misma contraseña en staging y production | −3 |
| `prevent_self_review: false` en un repo con varios revisores posibles | −2 |
| `secrets: inherit` al llamar a un reutilizable | −3 |
| Job con `runs-on` sin `timeout-minutes` | −3 por cada uno |
| `pip`, `npm` o Compose v1 en un workflow o en la documentación de tu repo | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 13 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
