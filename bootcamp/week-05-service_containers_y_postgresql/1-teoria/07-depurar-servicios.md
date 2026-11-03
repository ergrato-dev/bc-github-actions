# Depurar servicios

> Cuando un job con servicios falla, casi siempre es por una de cinco causas, y cada una deja una
> huella reconocible en el log. Este archivo te enseña a leer esas huellas y a dejar preparado el
> step que vuelca los logs de la base justo donde falló.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Leer el step *Initialize containers* y encontrar en qué fase se rompió
- Reconocer un servicio `unhealthy`, un `connection refused`, un host que no resuelve y un puerto
  ocupado por su mensaje
- Volcar los logs y el estado de salud de PostgreSQL con `docker logs` y el id de
  `job.services.postgres.id`, solo si algo falla
- Reproducir el fallo en local con los mismos flags

## 1. Qué problema resuelve

Un job con `services:` puede fallar en dos sitios muy distintos: **antes** de tus steps, cuando
el runner levanta los contenedores, o **dentro** de tus steps, cuando tu código intenta hablar con
la base. El mensaje que ves arriba del todo ("Process completed with exit code 1", "One or more
containers failed to start") casi nunca dice el porqué. El porqué está en el log del contenedor,
y hay que saber dónde está y cómo traerlo.

## 2. Cómo funciona

### Qué hay dentro de *Initialize containers*

Despliega el step en la UI. Tiene grupos, en este orden:

| Grupo | Qué hace | Si falla aquí |
|---|---|---|
| Checking docker version | `docker version` | Runner sin Docker: no es Linux o es un runner propio mal montado |
| Clean up resources from previous jobs | Borra restos con la etiqueta del runner | Raro; casi siempre en runners propios |
| Create local container network | `docker network create` | Raro |
| Starting `<id>` service container | `docker pull` y `docker create` con tus `options`, y `docker start` | Imagen o tag inexistente, `options` inválidas |
| Waiting for all services to be ready | Consulta el estado de salud con esperas crecientes | El healthcheck terminó en `unhealthy` |

Mientras espera verás líneas como `postgres service is starting, waiting 2 seconds before
checking again.` y, al final, `postgres service is healthy.`.

### Causa 1: el servicio nunca está sano

Si el healthcheck acaba en `unhealthy`, el runner abre un grupo `Service container postgres
failed.`, vuelca ahí el `docker logs` del contenedor, marca el error `Failed to initialize
container postgres:17.11-alpine` y el step termina con `One or more containers failed to start.`
**Tus steps no se ejecutan**: el fallo es anterior a ellos.

Lo primero es leer ese grupo. Las dos causas típicas:

- **El contenedor no arranca**: falta `POSTGRES_PASSWORD` y la imagen se niega a inicializar
  (`Database is uninitialized and superuser password is not specified`).
- **El chequeo pregunta mal**: `PostgreSQL` está bien, pero `--health-cmd` apunta a otro puerto o
  tiene una errata. El log de PostgreSQL dice `ready to accept connections` y aun así no hay
  `healthy`. Reprodúcelo en local con los mismos flags y mira `.State.Health.Log` (teoría 01).

### Causa 2: `connection refused`

El servicio está sano, *Initialize containers* en verde, y tu step falla con:

```
psycopg.OperationalError: connection failed: connection to server at "127.0.0.1", port 5432 failed: Connection refused
```

Nadie escucha en ese puerto **del runner**. Tres sospechosos, por orden de frecuencia:

1. **Falta `ports`**: el job corre en el runner y el servicio no publica el 5432. El contenedor
   escucha en la red de Docker, no en la máquina virtual.
2. **Puerto distinto**: publicaste `5433:5432` o `- 5432` (aleatorio) y `DATABASE_URL` dice 5432.
3. **Sin healthcheck**: el runner no tuvo a qué esperar y tu step llegó antes que PostgreSQL. Si
   reintentas a mano y funciona, es esto.

### Causa 3: el host no resuelve

```
psycopg.OperationalError: failed to resolve host 'postgres': [Errno -2] Name or service not known
```

`DATABASE_URL` usa el nombre del servicio, pero el job corre en el runner, fuera de la red de
Docker, donde ese nombre no existe. En el runner, `localhost`; con `container:`, el nombre
(teoría 03). Si el job sí está en un contenedor, revisa que el nombre coincida con la clave bajo
`services:`.

### Causa 4: puerto ocupado

```
Bind for 127.0.0.1:5433 failed: port is already allocated
```

Otro proceso ya tiene ese puerto del host. En un runner alojado, dos servicios del mismo job que
publican el mismo puerto. En un runner propio o en local, un PostgreSQL de otro job o tuyo. En CI
sale en el grupo *Starting ... service container*; en local, al hacer `docker run` o `compose up`.
La salida es un puerto aleatorio (`- 5432` y el contexto) o un `COMPOSE_PROJECT_NAME` y puertos
propios por job.

### Causa 5: sano pero sin esquema

`relation "tasks" does not exist`: la base acepta conexiones y está vacía. Falta el step de
migraciones o va después de los tests (teoría 04).

### Los logs de la base, cuando el fallo es tuyo

En las causas 2, 3 y 5 el runner no vuelca nada en el momento: tu step falló, no el servicio. El
log de PostgreSQL sí sale al final, en *Stop containers*, bajo `Print service container logs`,
pero lejos del error y mezclado con el apagado. Lo práctico es un step que, solo si algo falló,
pida a Docker el estado y el log del contenedor del servicio. Para eso necesita su id, y lo tiene
el contexto: `job.services.postgres.id`.

## 3. Cómo se usa

```yaml
name: service-debug

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  probe:
    name: Sonda contra PostgreSQL
    runs-on: ubuntu-24.04
    services:
      postgres:
        image: postgres:17.11-alpine
        env:
          POSTGRES_USER: tablero
          # Credencial desechable de CI, no un secreto.
          POSTGRES_PASSWORD: cambiame
          POSTGRES_DB: tablero_ci
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U tablero -d tablero_ci"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10
    steps:
      - name: Conectar
        env:
          PGPASSWORD: cambiame
        run: psql -h localhost -U tablero -d tablero_ci -c 'select 1'
      - name: Logs de PostgreSQL si algo falla
        if: failure()
        env:
          POSTGRES_CONTAINER: ${{ job.services.postgres.id }}
        run: |
          docker inspect --format '{{json .State.Health}}' "$POSTGRES_CONTAINER"
          docker logs "$POSTGRES_CONTAINER"
```

- **`if: failure()`**: el step solo corre si uno anterior falló. En un run verde no añade ni una
  línea.
- **El id por `env:`**: `${{ job.services.postgres.id }}` se resuelve en `POSTGRES_CONTAINER` y
  el shell lo usa entre comillas. Nunca interpolado dentro de `run:` (regla 4).
- **`docker inspect ... .State.Health`**: la racha de fallos y la salida de los últimos chequeos.
- **`docker logs`**: lo que dijo PostgreSQL, por ejemplo `FATAL: password authentication failed
  for user "tablero"` si `DATABASE_URL` y `POSTGRES_PASSWORD` no coinciden.

`postgres` en la expresión es la clave del servicio bajo `services:`; si tu servicio se llama
`db`, es `job.services.db.id`.

### Reproducir en local

Casi todo se reproduce con los mismos valores:

```bash
docker run -d --name repro-pg \
  -e POSTGRES_USER=tablero -e POSTGRES_PASSWORD=cambiame -e POSTGRES_DB=tablero_ci \
  -p 127.0.0.1:5432:5432 \
  --health-cmd "pg_isready -U tablero -d tablero_ci" \
  --health-interval 5s --health-timeout 5s --health-retries 10 \
  postgres:17.11-alpine
docker inspect --format '{{.State.Health.Status}}' repro-pg
# starting  (y, unos segundos después, healthy)
docker rm -f repro-pg
```

Si en local llega a `healthy` y en CI no, compara las `options` con la orden `docker create` que
imprime *Initialize containers*: una comilla de más en el YAML es suficiente.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Reintentar el run sin leer *Initialize containers* | El fallo es determinista y vuelve | Desplegar el step y leer el grupo que falló |
| `docker logs ${{ job.services.postgres.id }}` en `run:` | Interpolación en el shell, la puerta de la inyección | `env:` y `"$POSTGRES_CONTAINER"` |
| Step de logs sin `if: failure()` | Un `if` implícito `success()` lo salta justo cuando hace falta | `if: failure()` |
| `sleep` para arreglar `connection refused` | Tapa la falta de healthcheck y falla en un runner lento | `--health-cmd` |
| `docker ps -q \| head -1` para encontrar el contenedor | Con varios servicios, eliges uno al azar | `job.services.<id>.id` |
| Cambiar a `localhost` sin saber por qué funcionó | El siguiente job en `container:` falla igual | Decidir el host según dónde corre el job |

## 5. Trucos

- **`gh run view <id> --log-failed`** imprime solo los steps que fallaron, *Initialize
  containers* incluido: el grupo `Service container ... failed.` sale sin abrir el navegador.
- **`gh run view <id> --log | grep 'service is'`** enseña cuánto esperó el runner al healthcheck
  y cuántas veces volvió a preguntar.
- **`docker logs --tail 50 "$POSTGRES_CONTAINER"`** cuando el log es largo: el error de PostgreSQL
  suele estar al final.

Verificado con actions/runner (código de `ContainerOperationProvider`), `postgres:17.11-alpine` y
ubuntu-24.04, noviembre de 2026.

## 📚 Recursos Adicionales

- [Communicating with Docker service containers](https://docs.github.com/en/actions/tutorials/use-containerized-services/use-docker-service-containers)
- [Contexts: `job`](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#job-context)
- [`ContainerOperationProvider.cs` en actions/runner](https://github.com/actions/runner/blob/main/src/Runner.Worker/ContainerOperationProvider.cs)
- [`gh run view`](https://cli.github.com/manual/gh_run_view)

## ✅ Checklist de Verificación

- [ ] Sé leer los grupos de *Initialize containers* y en cuál falló
- [ ] Reconozco `unhealthy`, `connection refused`, host que no resuelve y puerto ocupado por su
      mensaje
- [ ] Sé que con un servicio `unhealthy` mis steps no llegan a correr
- [ ] Mi step de logs lleva `if: failure()` y recibe el id por `env:`
- [ ] Sé dónde imprime el runner los logs del servicio por su cuenta
- [ ] Sé reproducir el servicio en local con los mismos flags

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Compose en CI](06-compose-en-ci.md) | [Docker y Compose en local](../2-practicas/01-docker-y-compose-en-local.md) |
