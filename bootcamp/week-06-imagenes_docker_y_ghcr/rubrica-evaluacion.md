# Rúbrica de evaluación — Semana 06

> Imágenes Docker y GHCR. Se aprueba con un **mínimo del 70 % en cada evidencia**, no en el promedio.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de `images.yml` y de los paquetes publicados |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** `ghcr.io/<tu-org>/tablero-api:main` y `ghcr.io/<tu-org>/tablero-api@sha256:4e7a…` apuntan
hoy a la misma imagen. ¿Seguirá siendo así mañana? ¿Qué diferencia hay entre una etiqueta y un
digest?

<details>
<summary>Respuesta</summary>

No tiene por qué. Una **etiqueta** es un nombre que el registro asocia a un manifiesto y que se
reasigna con cada `push`: el próximo commit de `main` publica otra imagen con la misma etiqueta
`main`, y quien descargue `:main` mañana recibe otra cosa. Un **digest** es el `sha256` del propio
manifiesto (o del índice): se calcula a partir del contenido, así que no se puede mover; si cambia
un solo byte de una capa, cambia el digest de la capa, el del manifiesto que la lista y el del
índice. Por eso se prueba y se despliega por digest: lo que pasó los tests es exactamente lo que
llega al clúster, aunque alguien vuelva a publicar `main` entre medias.

</details>

**2.** `docker buildx imagetools inspect` sobre tu imagen enseña dos manifiestos: `linux/amd64` y
`unknown/unknown`. ¿Está rota la segunda? ¿Qué digest devuelve el output `digest` de
`build-push-action`?

<details>
<summary>Respuesta</summary>

No está rota. Lo que se publica es un **índice** OCI con dos entradas: el manifiesto de la imagen
para `linux/amd64` y un manifiesto de **attestation** (la procedencia que BuildKit genera por
defecto), que no es ejecutable y por eso no tiene plataforma. Sus anotaciones
`vnd.docker.reference.type: attestation-manifest` y `vnd.docker.reference.digest` dicen a qué
imagen describe. El output `digest` es el del **índice**, no el del manifiesto `amd64`: es el que
se usa para el pull, porque desde él el cliente elige la plataforma. Quitar la attestation con
`provenance: false` para que la UI "se vea limpia" tira justo lo que la Semana 14 va a verificar.

</details>

**3.** En el `Dockerfile` de la API, `COPY pyproject.toml uv.lock ./` y el `RUN uv sync … --no-install-project`
van antes de `COPY src ./src`. ¿Qué pasa en el build si cambias una línea de `main.py`? ¿Y si
invirtieras el orden?

<details>
<summary>Respuesta</summary>

Cada instrucción produce una capa cuya clave de caché depende de la instrucción y de lo que hay
antes. Cambiar `main.py` invalida `COPY src` y todo lo que va detrás, pero las capas anteriores
(uv, el lockfile y la instalación de dependencias) salen `CACHED`: solo se rehace la instalación
del propio proyecto y el `COPY` de la etapa final. Si copiaras todo el código antes de instalar, el
cambio de una línea invalidaría el `COPY` del que depende `uv sync`, y cada commit reinstalaría
todas las dependencias. La regla: lo que cambia poco, arriba; lo que cambia en cada commit, abajo.

</details>

**4.** ¿Para qué sirven las dos etapas del `Dockerfile` de `tablero-web` y qué aporta el
`.dockerignore`?

<details>
<summary>Respuesta</summary>

La etapa `build` tiene Node, pnpm y `node_modules` para ejecutar `pnpm install --frozen-lockfile` y
generar `dist/`. La etapa final parte de nginx y copia solo `dist/` y `nginx.conf`: la imagen
publicada no lleva ni Node ni dependencias de desarrollo, pesa una fracción y ofrece menos
superficie de ataque. El `.dockerignore` decide qué entra en el **contexto** que se envía a
BuildKit: sin él, tu `node_modules` o tu `.venv` locales viajan al builder (la práctica 01 lo mide:
de bytes a decenas de MB), pueden colarse en la imagen con un `COPY` y cambian la caché sin que el
código haya cambiado.

</details>

**5.** En `build-lab.yml` el build lleva `load: true` y en `images.yml` no. ¿Qué hacen `push`,
`load` y un build sin ninguno de los dos?

<details>
<summary>Respuesta</summary>

`setup-buildx-action` crea un builder con el driver `docker-container`: BuildKit corre en su propio
contenedor y lo que construye no aparece en el Docker del runner salvo que lo exportes. `push: true`
lo envía al registro; `load: true` lo importa al Docker local para que un `docker run` posterior lo
encuentre. Sin ninguno, el build se ejecuta entero y el resultado se queda en la caché del builder:
sirve para comprobar que el `Dockerfile` construye, que es lo que necesita un PR. `build-lab.yml`
arranca la imagen y le pide la portada, así que necesita `load`; `images.yml` no ejecuta nada, y
cargar "por si acaso" solo exporta la imagen otra vez para nada.

</details>

**6.** ¿Por qué `packages: write` va en el job `build` y no en la raíz, y por qué ese job repite
`contents: read`?

<details>
<summary>Respuesta</summary>

En la raíz, el permiso de escritura lo recibiría el token de todos los jobs del workflow, también
los que se añadan mañana y los que ejecuten código de terceros; en el job, solo el que publica. Y
los permisos de un job **sustituyen** a los de la raíz, no se suman: si el job declara solo
`packages: write`, todo lo demás vale `none`, su token pierde `contents: read` y `actions/checkout`
falla al clonar. Por eso el job declara los dos. Es la fila que comprueba `images-packages-write`.

</details>

**7.** El login a GHCR lleva `if: github.event_name != 'pull_request'` y el build lleva
`push: ${{ github.event_name != 'pull_request' }}`. ¿Por qué la condición va en dos sitios
distintos, y por qué `!=` y no `== 'push'`?

<details>
<summary>Respuesta</summary>

En el login es un `if:` porque en un PR no hace falta credencial: el step se salta y no queda
ningún token con escritura en el runner. En el build no puede ser un `if:`, porque entonces los PR
no construirían nada y un `Dockerfile` roto se descubriría tras fusionar; la condición va en el
**valor** de `push`, de modo que el step corre siempre y solo cambia si exporta al registro. Además,
en un PR desde un fork el token es de solo lectura declare lo que declare, así que publicar fallaría
igual. `== 'push'` dejaría fuera `workflow_dispatch`, el botón para republicar sin commit; con
`!= 'pull_request'` publican los dos eventos de confianza y solo el PR queda fuera.

</details>

**8.** ¿Por qué `images.yml` usa `type=sha` y `flavor: latest=false` en `metadata-action`, si
`latest` es lo que todo el mundo descarga por defecto?

<details>
<summary>Respuesta</summary>

`latest` no dice de qué commit sale la imagen y se mueve en silencio con cada push: es imposible
volver a la de ayer o saber qué está corriendo. `type=sha` añade una etiqueta `sha-1a2b3c4` por
commit, que enlaza la imagen con su código, y `type=ref,event=branch` da la etiqueta `main` para
quien quiera "lo último de main". Con `latest=auto`, el valor por defecto, `metadata-action` puede
generar `latest` por su cuenta (por ejemplo, el día que añadas `type=semver`) sin que el diff lo
diga; `latest=false` lo cierra explícitamente. Y los `labels` OCI que calcula
(`org.opencontainers.image.source`, `revision`) dicen de qué repo y commit salió, y el primero es
el que enlaza el paquete con el repo.

</details>

**9.** ¿Qué pasa con la caché `type=gha` si quitas el `scope`, y qué ganas con `mode=max` en un
`Dockerfile` multi-stage?

<details>
<summary>Respuesta</summary>

Sin `scope`, todos los builds del repo escriben su índice en el mismo nombre (`buildkit`): en la
matriz, la web pisa el índice de la API y viceversa, y ninguna encuentra el suyo en el run
siguiente. Con `scope=${{ matrix.image }}`, el mismo en `cache-from` y en `cache-to`, cada imagen
tiene su índice; los blobs se comparten igual, porque su clave es el digest. `mode=min` (por
defecto) solo exporta las capas de la imagen final; en un multi-stage deja fuera el `uv sync` y el
`pnpm install` de la etapa `build`, que son las capas lentas y las que se reutilizan en casi todos
los commits. `mode=max` exporta todas las etapas a cambio de más espacio en la cuota de 10 GB.

</details>

**10.** Tu primer push a `main` publica `tablero-api`, pero `docker pull ghcr.io/<tu-org>/tablero-api:main`
sin sesión responde `denied`. ¿Por qué, y por qué no debes arreglarlo publicando a mano desde tu
máquina?

<details>
<summary>Respuesta</summary>

Un paquete nuevo de GHCR nace **privado**, aunque el repo sea público: hay que cambiar su
visibilidad a pública una vez, en los ajustes del paquete. El `GITHUB_TOKEN` del workflow lo crea
**enlazado** al repo (por la label `org.opencontainers.image.source`), aparece en la pestaña
Packages de `tablero` y el repo conserva permiso de escritura sobre él. Si lo creas tú con un
`docker push` desde tu máquina, el paquete nace a tu nombre, sin ese acceso, y el workflow recibe
`denied` o `permission_denied: write_package` al publicar. El diagnóstico se hace contra el
registro, no solo contra el log: `gh api /orgs/<tu-org>/packages/container/tablero-api` dice
visibilidad y repo enlazado.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Construir en local con buildx | Las dos imágenes construidas con buildx; enseña sus capas, el usuario no root y el digest sacado de `--metadata-file` | 5 |
| 01 — Construir en local con buildx | Tras cambiar una línea, señala qué pasos salieron `CACHED` y cuáles no; mide el contexto con y sin `.dockerignore` y borra el builder `lab` | 5 |
| 02 — Primer build en Actions | `build-lab.yml` lanzado a mano y en verde (check `build-lab-dispatched`) | 5 |
| 02 — Primer build en Actions | En el run roto a propósito señala el `host not found in upstream "api"` y explica para qué están `load: true` y `--add-host` | 5 |
| 03 — Publicar en GHCR | `tablero-api` publicado desde `main` con las etiquetas `main` y `sha-…`, sin `latest` | 5 |
| 03 — Publicar en GHCR | Enseña el `denied` con el paquete privado, lo hace público y lo descarga por digest con el mismo digest que el output de la action | 5 |
| 04 — Matriz y caché de capas | Las dos imágenes en matriz; compara la duración en frío y en caliente y cuenta los `CACHED` de las dependencias | 5 |
| 04 — Matriz y caché de capas | Un PR en verde con el login saltado y nada publicado; el digest llega al resumen por `env:` y `tablero-web` es público | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 06` con 17/17. Cada comprobación en rojo
resta la parte proporcional (12/17 de punto).

**Calidad manual de `images.yml` y de los paquetes (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| Un comentario explica por qué el job repite `contents: read` al declarar sus permisos | 3 |
| `fail-fast: false`: si la web no construye, la API se publica igual y el fallo se ve aislado | 2 |
| El nombre del job incluye la imagen (`Imagen tablero-api`) y se lee en la lista de checks del PR | 2 |
| El resumen del job enseña el digest y, cuando se publica, el comando `docker pull` por digest | 3 |
| Los dos paquetes aparecen en la pestaña **Packages** de `<tu-org>/tablero`, enlazados al repo | 3 |
| Ningún paquete se publicó a mano desde tu máquina: lo crea el `GITHUB_TOKEN` del workflow | 3 |
| Sin `TODO` en `.github/workflows/` y commits en Conventional Commits | 2 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log, también un PAT para publicar en GHCR | Grave: Producto a 0 hasta rotarlo y retirarlo |
| `uses:` remota sin SHA | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}` o `${{ steps.*.outputs.digest }}` interpolado dentro de `run:` | Grave: −10 |
| Imagen sin tag o con `latest`, también como imagen base de un `Dockerfile` | Grave: −10 |
| Publicar la etiqueta `latest` en GHCR | −5 |
| Login a GHCR o `push: true` que se ejecutan en `pull_request` | −5 |
| `packages: write` en la raíz del workflow | −5 |
| Paquete creado a mano con `docker push` desde tu máquina | −3 |
| `pip`, `npm` o Compose v1 en un workflow, un `Dockerfile` o la documentación de tu repo | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 06 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
