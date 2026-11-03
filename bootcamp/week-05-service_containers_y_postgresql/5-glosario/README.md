# 📖 Glosario — Semana 05

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **Alias de red** (*network alias*): nombre por el que un contenedor se alcanza dentro de una red de
  Docker. En un job, el alias de cada service es su clave bajo `services:` (`postgres`); en Compose,
  el nombre del servicio (`db`).

## C

- **Código de salida 5 de pytest** (*no tests collected*): pytest no ejecutó ningún test. Sale así
  `pytest tests/integration` sin `DATABASE_URL`, porque el módulo entero se salta; el job falla.
- **`container:`** (job en contenedor): clave de un job que hace correr todos sus steps dentro de un
  contenedor de la red del job. Desde ahí, los services se alcanzan por nombre, no por `localhost`.
- **Contenedor** (*container*): ejecución de una imagen: un proceso aislado con su propia capa
  escribible. Borrarlo no toca la imagen; sus datos se pierden salvo que estén en un volumen.
- **Credencial desechable**: usuario y contraseña que solo existen dentro de un contenedor efímero
  de CI. En `tablero` la contraseña vale `cambiame`, se dice en un comentario y no es un secreto.

## D

- **`DATABASE_URL`**: variable de entorno con la URI de conexión
  `postgresql://usuario:contraseña@host:puerto/base`. La leen la API, `tablero.migrate` y los tests
  de integración; si falta, estos últimos se saltan.
- **`depends_on`**: clave de Compose que ordena el arranque de los servicios. Sola no espera a que
  la dependencia esté lista.
- **Digest**: hash `sha256:…` que identifica el contenido exacto de una imagen, a diferencia del tag,
  que se puede mover. Se menciona aquí; lo usarás en la Semana 06.
- **`docker compose`**: plugin de Docker que levanta varios contenedores, redes y volúmenes a partir
  de un `compose.yaml`. Siempre como plugin, nunca el binario v1.
- **`down --volumes`**: `docker compose down` que además borra los volúmenes con nombre del
  proyecto. Con `--rmi local` borra también las imágenes construidas.

## H

- **Healthcheck**: orden que Docker ejecuta periódicamente dentro del contenedor para decidir su
  estado. En un service va en `options` como `--health-cmd`; en Compose, en `healthcheck:`.

## I

- **Imagen** (*image*): plantilla de solo lectura con el sistema de archivos y la orden de arranque.
  Se nombra `repositorio:tag`, por ejemplo `postgres:17.11-alpine`.
- **Initialize containers**: step que el runner añade al principio de un job con `services:` o
  `container:`. Crea la red, descarga las imágenes, arranca los servicios y espera a que estén
  `healthy`.

## J

- **`job.services`**: contexto con un objeto por service del job: `id` del contenedor, `network` y
  `ports`. `job.services.postgres.ports['5432']` da el puerto del host; se pasa al shell por `env:`.

## M

- **Migración** (*migration*): archivo SQL versionado que cambia el esquema. `tablero.migrate`
  aplica en orden las de `api/migrations/` que no estén en `schema_migrations`.

## P

- **`pg_isready`**: cliente de PostgreSQL que dice si el servidor acepta conexiones (código 0) o
  no. Es el `--health-cmd` del service; no sabe nada de tablas ni de migraciones.
- **Proyecto de Compose** (*Compose project*): conjunto de contenedores, redes y volúmenes que crea
  un `compose.yaml`, con un prefijo común. El nombre sale de `-p`, de `COMPOSE_PROJECT_NAME` o del
  `name:` del archivo, en ese orden.
- **Puerto publicado** (*published port*): puerto del host que Docker redirige a uno del contenedor
  (`-p 127.0.0.1:5433:5432`, `ports: [5432:5432]`). Sin él, un proceso fuera de la red de Docker no
  llega al contenedor.

## R

- **Red puente** (*bridge network*): red privada de Docker en una máquina. En una definida por el
  usuario, como la que crea el runner para cada job, los contenedores se encuentran por nombre.
- **`-rs`**: flag de pytest que imprime al final el resumen de tests saltados con su motivo. Hace
  visible el falso verde.

## S

- **Service container**: contenedor que el runner arranca junto a un job (`services:`), espera con
  su healthcheck y borra al terminar. Solo usa imágenes publicadas.
- **`service_healthy`**: condición de `depends_on` en Compose que espera a que la dependencia esté
  `healthy` antes de arrancar el servicio.
- **Smoke test**: prueba corta de extremo a extremo que comprueba que la pila arranca y responde. En
  `tablero`, `scripts/smoke-test.sh` crea, lista y borra una tarea a través de nginx.
- **`starting`, `healthy`, `unhealthy`**: los tres estados de un contenedor con healthcheck:
  arrancando, chequeo superado, y demasiados fallos seguidos.
- **Stop containers**: step que el runner añade al final de un job con servicios. Imprime sus logs,
  los para y borra los contenedores y la red.

## T

- **Tag**: etiqueta móvil de una imagen (`17.11-alpine`). En este bootcamp lleva siempre parche y
  nunca es `latest`.
- **Test de integración** (*integration test*): test que habla con una dependencia real, aquí
  PostgreSQL, en lugar de sustituirla. En `tablero` viven en `api/tests/integration/`.

## V

- **Volumen** (*volume*): directorio gestionado por Docker que vive fuera de cualquier contenedor.
  Guarda los datos de PostgreSQL entre contenedores; se borra con `docker volume rm` o
  `down --volumes`.

## W

- **`--wait`**: flag de `docker compose up` que no vuelve hasta que todos los servicios estén
  `healthy` y falla si alguno queda `unhealthy`. Sustituye a cualquier `sleep`.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Semana 06 — Imágenes Docker y GHCR](../../week-06-imagenes_docker_y_ghcr/README.md) |
