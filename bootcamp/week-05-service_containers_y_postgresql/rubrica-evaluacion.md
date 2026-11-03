# Rúbrica de evaluación — Semana 05

> Service containers y PostgreSQL. Se aprueba con un **mínimo del 70 % en cada evidencia**, no en el promedio.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de `ci-api.yml` y `smoke.yml` |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** Ejecutas `docker rm -f lab-pg` y vuelves a lanzar `docker run ... postgres:17.11-alpine`.
¿Qué se ha borrado y qué sigue ahí? ¿Qué diferencia hay entre una imagen y un contenedor?

<details>
<summary>Respuesta</summary>

Una **imagen** es una plantilla de solo lectura: el sistema de archivos con PostgreSQL ya instalado
y la orden que se ejecuta al arrancar. Un **contenedor** es una ejecución de esa imagen: un proceso
aislado con su propia capa escribible encima. `docker rm` borra el contenedor y su capa escribible;
la imagen sigue en la máquina y el `docker run` siguiente arranca en segundos porque no la descarga.
De una imagen salen tantos contenedores como quieras. Los datos solo sobreviven si estaban en un
**volumen**, que no pertenece a ningún contenedor: por eso hace falta `docker volume rm` o
`down --volumes` para empezar con la base vacía de verdad.

</details>

**2.** El mismo service `postgres` se alcanza como `localhost:5432` desde un job sin `container:`
y como `postgres:5432` desde un job con `container:`. ¿Por qué cambia la dirección?

<details>
<summary>Respuesta</summary>

El runner crea una red puente de Docker para el job y conecta ahí todos los servicios. Si el job
corre **en el runner**, sus steps son procesos de la máquina virtual, fuera de esa red: solo ven el
servicio si su puerto se **publica** en el host (`ports:`), y entonces lo ven en `localhost`. Si el
job corre **en un contenedor**, es un contenedor más de la misma red y Docker resuelve el nombre del
servicio, que es su clave bajo `services:`. Al revés no funciona: dentro del contenedor del job,
`localhost` es el propio contenedor del job, donde no escucha ningún PostgreSQL, y `pg_isready`
responde `no response`.

</details>

**3.** ¿Qué hace `--health-cmd "pg_isready -U tablero -d tablero_ci"` en las `options` del service?
¿Qué pasa si lo quitas?

<details>
<summary>Respuesta</summary>

Le da a Docker una orden que ejecuta periódicamente dentro del contenedor (cada `--health-interval`)
para decidir su estado: `starting` mientras arranca, `healthy` cuando la orden sale con 0 y
`unhealthy` tras `--health-retries` fallos seguidos. En el step *Initialize containers*, el runner
espera a que el servicio esté `healthy` antes de pasar a tus steps, y si queda `unhealthy` el job
falla ahí. Sin healthcheck el runner no tiene a qué esperar: da el servicio por listo en cuanto el
contenedor arranca, y el primer step que habla con la base llega antes de que PostgreSQL escuche y
falla con un error de conexión, de forma intermitente según lo rápido que arranque ese día.

</details>

**4.** El service está `healthy` y el primer test de integración falla con
`relation "tasks" does not exist`. ¿Por qué, si la base estaba sana?

<details>
<summary>Respuesta</summary>

Porque `healthy` no es `migrado`. `pg_isready` solo dice que el servidor acepta conexiones; no
sabe nada de tus tablas. Una base recién creada está vacía, y el esquema lo crea un step aparte,
antes de los tests: `uv run --no-sync python -m tablero.migrate`, que crea `schema_migrations` si
no existe y aplica en orden los `api/migrations/*.sql` que falten. Es idempotente, así que la
segunda ejecución no hace nada. Healthcheck y migraciones resuelven problemas distintos y hacen
falta los dos.

</details>

**5.** ¿Qué diferencia hay entre `ports: [5432:5432]` y `ports: [5432]` en un service, y cómo
sabe el job a qué puerto conectarse en el segundo caso?

<details>
<summary>Respuesta</summary>

`5432:5432` publica el 5432 del contenedor en el 5432 del runner: la dirección es fija y es lo
normal en un runner alojado, que está vacío. `- 5432` deja que Docker elija un puerto libre del
host, lo que evita choques cuando hay dos servicios del mismo tipo en un job o varios jobs en un
runner propio. Ese puerto se lee del contexto: `job.services.<id>.ports['5432']` devuelve el puerto
del host que corresponde al 5432 del contenedor. Se pasa al shell por `env:` (`DB_PORT`) y se usa
como `"$DB_PORT"`, nunca interpolado dentro de `run:`.

</details>

**6.** En `ci-api.yml`, `integration` es un job aparte con `needs: test`. ¿Por qué no añadir el
service al job `test` y correr todo junto?

<details>
<summary>Respuesta</summary>

Por tres razones. **Fallo rápido y barato**: si la lógica ya falla sin base, `needs: test` evita
arrancar PostgreSQL para nada, e `integration` aparece como saltado, no como fallido. **Un log que
dice qué nivel falló**: el nombre del job ya te dice si el problema es de lógica o de SQL. **El
service solo donde hace falta**: el job unitario no espera ningún healthcheck. Además, cada job
tiene sus propios servicios: el PostgreSQL de `integration` no existe en ningún otro job.

</details>

**7.** Sin `DATABASE_URL`, `pytest tests/integration` sale con código 5 y `1 skipped`, y
`pytest` sobre toda la suite sale con código 0 y `6 passed, 1 skipped`. ¿Cuál de los dos es más
peligroso y cómo te defiendes?

<details>
<summary>Respuesta</summary>

El segundo. Con solo `tests/integration`, pytest no ejecuta ningún test y sale con código 5: el
job falla y te enteras. Con la suite entera, los unitarios pasan, el módulo de integración se salta
y el código es 0: el job sale en verde y nadie ha probado nada contra PostgreSQL. Es un **falso
verde**, y basta que alguien junte los directorios en un `pytest` sin argumentos para caer en él.
Defensas: `-rs`, que imprime el resumen de tests saltados con su motivo, de modo que un `SKIPPED`
en el job de integración se ve; y vigilar el número esperado (`3 passed`) en la revisión.

</details>

**8.** Un compañero propone `docker compose up -d` seguido de `sleep 30` en `smoke.yml`. ¿Qué
ganas con `docker compose up --build --wait`?

<details>
<summary>Respuesta</summary>

`--wait` no vuelve hasta que todos los servicios con healthcheck estén `healthy`, y si alguno queda
`unhealthy` sale con código 1 y el step falla. El `sleep` es una apuesta: si sobra, el job pierde
tiempo en cada ejecución; si no basta (un runner lento, un build sin caché), el smoke test llega a
una API que no escucha y falla con un error que no dice por qué. Y el `sleep` no detecta nunca un
`unhealthy`: espera lo mismo aunque la base no vaya a arrancar. Con `--wait` la espera dura lo justo
y apoya en los healthchecks de `compose.yaml`, que ya existen.

</details>

**9.** El runner alojado se destruye al acabar el job. ¿Para qué sirven entonces el `down` con
`if: always()` y `COMPOSE_PROJECT_NAME` en el `env:` del job?

<details>
<summary>Respuesta</summary>

Para los runners propios de la Semana 15, donde la máquina sigue: sin `down`, el siguiente job
encuentra contenedores, la red, el volumen con datos viejos y los puertos 8000 y 8080 ocupados.
`if: always()` hace que el `down` corra también cuando el smoke test falla, que es justo cuando más
restos deja. `COMPOSE_PROJECT_NAME` gana al `name:` del archivo y pone su prefijo a todo lo que crea
el job (`tablero-ci-api-1`, `tablero-ci_db-data`), así que el `down --volumes` borra exactamente eso
y no la pila de otro job en la misma máquina. Además, el workflow cuenta el ciclo completo: moverlo
de runner no exige recordar que faltaba limpiar.

</details>

**10.** `tablero` usa un service container en `ci-api.yml` y Compose en `smoke.yml`. ¿Cuándo eliges
cada uno?

<details>
<summary>Respuesta</summary>

**Service container** cuando necesitas una base ya publicada para `pytest` en el mismo job: el
runner espera el healthcheck en *Initialize containers*, limpia en *Stop containers*, deja los ids
en `job.services` y cuesta segundos. Pero solo usa imágenes publicadas: no construye tu código.
**Compose** cuando lo que pruebas es la pila entera: construir los `Dockerfile` de `api` y `web`,
nginx, la red entre servicios, con el mismo `compose.yaml` que en local. A cambio, la espera y la
limpieza son tuyas (`--wait`, `down` con `always()`) y el build cuesta minutos. Por eso
`integration` corre en cada cambio de la API y el smoke con Compose cubre lo que el service no ve.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Docker y Compose en local | PostgreSQL suelto `healthy`, publicado solo en `127.0.0.1`, con las migraciones aplicadas y `3 passed` en `tests/integration` | 5 |
| 01 — Docker y Compose en local | Enseña el `exit 5` de `tests/integration` sin `DATABASE_URL`, levanta `tablero` con Compose, pasa el smoke test y lo apaga sin dejar contenedores, volúmenes ni redes | 5 |
| 02 — PostgreSQL como service | `service-lab.yml` lanzado a mano y en verde (check `service-lab-dispatched`) | 5 |
| 02 — PostgreSQL como service | Con la contraseña rota a propósito, señala en el log el step que falló y el `FATAL: password authentication failed` de los logs de la base | 5 |
| 03 — Job en contenedor frente a runner | `container-lab.yml` lanzado a mano y en verde (check `container-lab-dispatched`) | 5 |
| 03 — Job en contenedor frente a runner | Explica por qué `localhost` falla dentro de `container:` y de dónde sale el puerto aleatorio del tercer job | 5 |
| 04 — Smoke test con Compose | `compose-lab.yml` en verde lanzado a mano, con el smoke test a través de nginx y sin ningún `sleep` | 5 |
| 04 — Smoke test con Compose | En el run fallido a propósito enseña que los logs salieron con `failure()` y que `down --volumes` corrió igual | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 05` con 18/18. Cada comprobación en rojo
resta la parte proporcional (12/18 de punto).

**Calidad manual de `ci-api.yml` y `smoke.yml` (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| Un comentario dice por qué `DATABASE_URL` usa `localhost` y no `postgres` | 3 |
| La contraseña de CI está marcada como credencial desechable y no es un secreto | 3 |
| El id del contenedor llega a `docker logs` por `env:`, no interpolado en `run:` | 3 |
| `pytest` lleva `-rs`, o algo equivalente, para que un test saltado se vea en el log | 3 |
| `smoke.yml` no tiene `sleep`: confía en `--wait` y en los healthchecks de `compose.yaml` | 3 |
| Sin `TODO` en `.github/workflows/` y commits en Conventional Commits | 3 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log, también en `POSTGRES_PASSWORD` | Grave: Producto a 0 hasta rotarlo y retirarlo |
| `uses:` remota sin SHA | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}` interpolado dentro de `run:` | Grave: −10 |
| Imagen sin tag o con `latest` | Grave: −10 |
| Puertos de Compose o de `docker run` publicados fuera de `127.0.0.1` | −5 |
| Id del contenedor o puerto del service interpolado con `${{ job.services.* }}` dentro de `run:` en vez de `env:` | −3 |
| Contraseña de CI sin marcar como credencial desechable | −2 |
| `pip`, `npm` o Compose v1 en un workflow, un script o la documentación de tu repo | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 05 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
