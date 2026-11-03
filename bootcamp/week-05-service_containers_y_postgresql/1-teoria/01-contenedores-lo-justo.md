# Contenedores, lo justo

> Un service container es un contenedor de Docker que el runner arranca por ti. Para leer qué
> hace, y para arreglarlo cuando no arranca, necesitas seis ideas: imagen, contenedor, puerto
> publicado, volumen, red y healthcheck. Este archivo cuenta esas seis y nada más.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Distinguir una imagen de un contenedor y explicar por qué el tag lleva parche y nunca `latest`
- Arrancar PostgreSQL con `docker run` pasándole variables, un puerto en `127.0.0.1` y un
  healthcheck
- Explicar qué guarda un volumen y por qué dos contenedores se encuentran por nombre en una red
- Mirar dentro de un contenedor con `docker ps`, `docker logs`, `docker inspect` y `docker exec`
- Leer los estados `starting`, `healthy` y `unhealthy` y saber qué los provoca

## 1. Qué problema resuelve

Los tests de integración de `tablero` necesitan un PostgreSQL 17. Instalarlo en tu máquina y en
cada runner tiene tres problemas: la versión depende de lo que traiga el sistema (el runner
`ubuntu-24.04` trae PostgreSQL 16, no 17), deja estado entre ejecuciones y cuesta borrarlo sin
dejar restos.

Un contenedor resuelve los tres: es PostgreSQL 17.11 exacto, se crea limpio en segundos y se
borra entero con un comando. Es lo mismo que hará el runner en la teoría 03, así que si lo
entiendes aquí en local, entiendes lo que pasa en CI.

## 2. Cómo funciona

### Imagen y contenedor

Una **imagen** es una plantilla de solo lectura: el sistema de archivos con PostgreSQL ya
instalado y la orden que se ejecuta al arrancar. Un **contenedor** es una ejecución de esa
imagen: un proceso aislado con su propia capa escribible encima. De una imagen salen tantos
contenedores como quieras, y borrar un contenedor no toca la imagen.

La imagen se nombra `repositorio:tag`. En `postgres:17.11-alpine`, `postgres` es el repositorio
oficial de Docker Hub y `17.11-alpine` el tag: PostgreSQL 17.11 sobre Alpine Linux, que pesa menos
que la variante Debian (424 MB frente a 646 MB en esta máquina).

### Por qué el tag lleva parche

Un tag es una etiqueta que el publicador puede mover. `postgres:17-alpine` apunta hoy a 17.11 y
mañana a 17.12; `postgres:latest` apuntará a la 18 o a la que salga después. Si tu CI usa un tag
que se mueve, un día pasa a probar contra otra base de datos sin que nadie haya cambiado nada en
el repo, y el fallo parece tuyo.

Por eso la regla 10 de seguridad pide **tag completo**: `17.11-alpine`, con mayor, menor y
variante. Cambiar de parche es entonces un commit que se ve en el historial. La versión vigente
está en [`docs/stack-versions.md`](../../../docs/stack-versions.md). Desde la Semana 14 irás un
paso más allá y fijarás las imágenes por digest, que no se puede mover.

### Variables, puertos y la interfaz `127.0.0.1`

La imagen de PostgreSQL se configura con variables de entorno que lee en el primer arranque:
`POSTGRES_USER`, `POSTGRES_PASSWORD` y `POSTGRES_DB` (la teoría 04 las cuenta). Se pasan con `-e`.

Un contenedor escucha en su propia red, no en la de tu máquina. Para llegar a él desde fuera hay
que **publicar** el puerto con `-p`, que se lee `[interfaz:]puerto-del-host:puerto-del-contenedor`:

| Flag | Qué publica |
|---|---|
| `-p 127.0.0.1:5433:5432` | El 5432 del contenedor en el 5433 de tu máquina, solo para ti |
| `-p 5433:5432` | Lo mismo, pero en **todas** las interfaces: cualquiera de tu red llega a tu base |

La regla 12 del repositorio obliga a la primera forma. Con la contraseña `cambiame` y el puerto
abierto a la red de una cafetería, la segunda es una base de datos regalada.

### Volúmenes: lo que sobrevive al contenedor

La capa escribible del contenedor muere con él. Un **volumen** es un directorio que gestiona
Docker y que se monta dentro del contenedor: `-v lab-pgdata:/var/lib/postgresql/data` guarda los
datos de PostgreSQL en el volumen `lab-pgdata`. Borras el contenedor, creas otro con el mismo
volumen y las tablas siguen ahí.

En CI casi nunca quieres eso: quieres una base vacía en cada ejecución. En local sí, y por eso
`docker compose down` sin `--volumes` deja los datos (teoría 02).

### Redes y resolución por nombre

Docker conecta los contenedores a redes. En una red creada por ti (`docker network create`),
Docker ofrece un DNS interno: cada contenedor se resuelve **por su nombre**. Dos contenedores en
la misma red se hablan por nombre y por el puerto interno, sin publicar nada.

Esta es la clave de la semana entera: desde tu máquina llegas a PostgreSQL por
`127.0.0.1:<puerto publicado>`; desde otro contenedor de la misma red, por `<nombre>:5432`. Son
dos caminos distintos al mismo proceso, y en CI pasa exactamente lo mismo.

### Healthcheck: arrancado no es listo

Un contenedor "arrancado" solo significa que su proceso principal existe. PostgreSQL tarda unos
segundos en inicializar el directorio de datos y en aceptar conexiones; si un cliente llega
antes, recibe `connection refused`.

Un **healthcheck** es una orden que Docker ejecuta dentro del contenedor cada cierto tiempo. Si
sale con 0, el contenedor está sano. El estado pasa por tres valores:

| Estado | Cuándo |
|---|---|
| `starting` | Recién arrancado, aún sin un chequeo bueno |
| `healthy` | El último chequeo salió con 0 |
| `unhealthy` | Falló `--health-retries` veces seguidas |

Se configura con `--health-cmd` (la orden), `--health-interval` (cada cuánto), `--health-timeout`
(cuánto puede tardar un chequeo) y `--health-retries` (fallos seguidos antes de `unhealthy`).
Docker solo informa del estado: no reinicia ni para el contenedor. Quien espera a `healthy` es
el que lo usa: Compose con `--wait` (teoría 02) o el runner con un service (teoría 03).

## 3. Cómo se usa

Todo lo que sigue lo puedes ejecutar tal cual; la práctica 01 lo recorre paso a paso.

### Una red y un PostgreSQL con healthcheck

```bash
docker network create lab-net
docker run -d --name lab-pg --network lab-net \
  -e POSTGRES_USER=tablero \
  -e POSTGRES_PASSWORD=cambiame \
  -e POSTGRES_DB=tablero \
  -p 127.0.0.1:5433:5432 \
  -v lab-pgdata:/var/lib/postgresql/data \
  --health-cmd "pg_isready -U tablero -d tablero" \
  --health-interval 2s --health-timeout 5s --health-retries 10 \
  postgres:17.11-alpine
docker inspect --format '{{.State.Health.Status}}' lab-pg
# starting
```

`-d` lo deja en segundo plano. El puerto del host es el 5433 para no chocar con un PostgreSQL que
ya tengas en el 5432. Unos segundos después:

```bash
docker ps --filter name=lab-pg --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
# NAMES     IMAGE                   STATUS                   PORTS
# lab-pg    postgres:17.11-alpine   Up 6 seconds (healthy)   127.0.0.1:5433->5432/tcp
```

### Mirar dentro: `logs`, `exec`, `inspect`

```bash
docker logs lab-pg 2>&1 | tail -1
# ... LOG:  database system is ready to accept connections
docker exec lab-pg psql -U tablero -d tablero -tAc 'select version()' | cut -c1-40
# PostgreSQL 17.11 on x86_64-pc-linux-musl
docker port lab-pg
# 5432/tcp -> 127.0.0.1:5433
```

`docker logs` es la salida del proceso principal: lo primero que miras cuando algo no arranca.
`docker exec` ejecuta una orden dentro del contenedor que ya corre. `docker inspect` devuelve
todo su estado en JSON; con `--format` sacas el trozo que te interesa.

### La resolución por nombre, demostrada

```bash
docker run --rm --network lab-net postgres:17.11-alpine pg_isready -h lab-pg -U tablero
# lab-pg:5432 - accepting connections
docker run --rm postgres:17.11-alpine pg_isready -h lab-pg -U tablero
# lab-pg:5432 - no response
```

El primer contenedor está en `lab-net` y encuentra `lab-pg` por nombre. El segundo está en la red
por defecto, donde no hay DNS por nombre: no llega. `--rm` borra el contenedor al terminar.

### Un healthcheck que nunca pasa

```bash
docker run -d --name lab-bad -e POSTGRES_PASSWORD=cambiame \
  --health-cmd "pg_isready -p 5555" --health-interval 1s --health-retries 3 \
  postgres:17.11-alpine
sleep 6
docker ps --filter name=lab-bad --format '{{.Status}}'
# Up 6 seconds (unhealthy)
docker inspect --format '{{json .State.Health.Log}}' lab-bad | tail -c 120
# ... "ExitCode":2,"Output":"/var/run/postgresql:5555 - no response\n"}]
```

PostgreSQL está bien; el chequeo pregunta en el puerto equivocado. `State.Health.Log` guarda la
salida de los últimos chequeos: es donde ves **por qué** un contenedor está `unhealthy`.

### Limpiar

```bash
docker rm -f lab-pg lab-bad
docker volume rm lab-pgdata
docker network rm lab-net
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `postgres:latest` o `postgres` sin tag | El día que sale una mayor nueva, tu CI cambia de base sin un commit | `postgres:17.11-alpine` |
| `postgres:17-alpine` | Se mueve de parche sin aviso; el fallo de un parche no tiene commit que lo explique | Tag con parche y subirlo a propósito |
| `-p 5432:5432` en local | Publica la base en todas tus interfaces, con contraseña `cambiame` | `-p 127.0.0.1:5432:5432` |
| `sleep 10` antes de conectar | En una máquina lenta no basta; en una rápida, sobra | Healthcheck y esperar a `healthy` |
| Conectar por la IP del contenedor | Cambia en cada arranque | El nombre del contenedor en una red propia |
| Borrar el contenedor y creer que la base está vacía | El volumen sigue ahí con los datos | `docker volume rm` o `down --volumes` |

## 5. Trucos

- **`docker inspect --format '{{json .State.Health}}' <nombre>`** te da estado, racha de fallos y
  la salida de los últimos chequeos en una línea. Pásalo por `python3 -m json.tool` para leerlo.
- **`docker logs --since 1m <nombre>`** acota a lo último cuando el log es largo.
- **`docker ps -a`** enseña también los contenedores parados: uno que se cayó al arrancar no sale
  en `docker ps` a secas.

Verificado con Docker Engine 29.9.2 y `postgres:17.11-alpine`, noviembre de 2026.

## 📚 Recursos Adicionales

- [Docker: What is a container?](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/)
- [Docker: Publishing and exposing ports](https://docs.docker.com/get-started/docker-concepts/running-containers/publishing-ports/)
- [Docker: `HEALTHCHECK` y opciones `--health-*`](https://docs.docker.com/reference/dockerfile/#healthcheck)
- [Imagen oficial `postgres` en Docker Hub](https://hub.docker.com/_/postgres)

## ✅ Checklist de Verificación

- [ ] Sé explicar la diferencia entre imagen y contenedor
- [ ] Sé por qué el tag lleva parche y nunca es `latest`
- [ ] Publico puertos siempre en `127.0.0.1`
- [ ] Sé qué guarda un volumen y cuándo sobrevive al contenedor
- [ ] Sé por qué dos contenedores en la misma red se encuentran por nombre
- [ ] Sé leer `starting`, `healthy` y `unhealthy` y encontrar la salida del chequeo que falla

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Semana 05 — Service containers y PostgreSQL](../README.md) | [Compose, lo justo](02-compose-lo-justo.md) |
