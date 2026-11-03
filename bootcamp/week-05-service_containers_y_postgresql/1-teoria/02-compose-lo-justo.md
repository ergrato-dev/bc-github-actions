# Compose, lo justo

> `docker run` con diez flags vale para un contenedor. `tablero` tiene tres que dependen unos de
> otros, y Compose los describe en un archivo, los arranca en orden y espera a que estén sanos.
> Es la forma en que levantas `tablero` en local y, en la teoría 06, en el runner.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Leer el `compose.yaml` de `tablero` línea a línea y traducir cada clave a un flag de `docker run`
- Explicar qué garantiza `depends_on` con `condition: service_healthy` y qué no
- Levantar la pila con `up --build --wait`, inspeccionarla con `ps` y `logs` y apagarla sin restos
- Usar el nombre de proyecto para que dos pilas no se pisen

## 1. Qué problema resuelve

Para levantar `tablero` a mano necesitarías una red, un volumen, PostgreSQL con su healthcheck,
construir la imagen de la API, arrancarla cuando la base esté sana, construir la web y arrancarla
cuando la API esté sana. Son una docena de órdenes en un orden concreto, y cualquiera que las
repita de memoria se salta una.

Compose convierte eso en un archivo declarativo, `compose.yaml`, y en una orden: `docker compose
up`. El archivo vive en el repo, así que tu máquina y el runner levantan exactamente lo mismo.

Compose es hoy un **plugin** de Docker: se invoca como `docker compose`, con espacio. El binario
antiguo `docker-compose` (v1) está retirado y no se usa en este bootcamp. <!-- antipatron -->

## 2. Cómo funciona

### El `compose.yaml` de `tablero`

Es [`app/compose.yaml`](../../../app/compose.yaml), que copiaste a la raíz de `<tu-org>/tablero`.
La parte de la base:

```yaml
name: tablero

services:
  db:
    image: postgres:17.11-alpine
    environment:
      POSTGRES_USER: tablero
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-cambiame}   # desechable, solo para local
      POSTGRES_DB: tablero
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U tablero -d tablero"]
      interval: 5s
      timeout: 5s
      retries: 10
    volumes:
      - db-data:/var/lib/postgresql/data
```

| Línea | Qué hace | Equivalente en `docker run` |
|---|---|---|
| `name: tablero` | Nombre de proyecto por defecto: prefijo de contenedores, red y volumen | — |
| `services.db` | Un servicio llamado `db`; también es su nombre en la red | `--name`, `--network-alias` |
| `image:` | La imagen, con tag completo | El último argumento |
| `environment:` | Variables del contenedor | `-e` |
| `${POSTGRES_PASSWORD:-cambiame}` | Interpolación: el valor de tu shell, o `cambiame` si no existe | — |
| `healthcheck.test` | La orden del chequeo; `CMD-SHELL` la pasa por `sh -c` | `--health-cmd` |
| `interval`, `timeout`, `retries` | Igual que en la teoría 01 | `--health-interval`, etc. |
| `volumes: - db-data:...` | Monta el volumen con nombre `db-data` | `-v` |

`db` **no publica puertos**: nadie de fuera necesita llegar a la base. La API llega por la red.

La API y la web:

```yaml
  api:
    build:
      context: api
      args:
        APP_VERSION: ${APP_VERSION:-dev}
    environment:
      DATABASE_URL: postgresql://tablero:${POSTGRES_PASSWORD:-cambiame}@db:5432/tablero
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "127.0.0.1:8000:8000"
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/health')"]
      ...

  web:
    build: web
    depends_on:
      api:
        condition: service_healthy
    ports:
      - "127.0.0.1:8080:8080"
    ...

volumes:
  db-data:
```

- **`build: context: api`**: Compose construye la imagen a partir de `api/Dockerfile` en vez de
  descargarla. Cómo se escribe ese `Dockerfile` es la Semana 06; aquí basta con saber que existe.
- **`@db:5432`** en `DATABASE_URL`: la API está en la red del proyecto y llega a la base por el
  nombre del servicio y el puerto interno. Es la resolución por nombre de la teoría 01.
- **`ports: "127.0.0.1:8000:8000"`**: publicado solo en tu loopback (regla 12). La
  documentación de Compose recomienda escribir los puertos entre comillas.
- **`volumes: db-data:`** al final declara el volumen; sin esa línea Compose no lo crea.
- **`test: ["CMD", ...]`** ejecuta la orden sin shell; `CMD-SHELL` la pasa por `sh`.

### `depends_on` con `service_healthy`

`depends_on` a secas solo ordena el **arranque**: `api` se crea después de `db`, pero puede
arrancar cuando PostgreSQL aún no acepta conexiones. Con `condition: service_healthy`, Compose
espera a que el healthcheck de `db` diga `healthy` antes de arrancar `api`. Así la cadena es
`db` sano → `api` arranca y migra → `api` sana → `web` arranca.

Fíjate en lo que **no** garantiza: si `db` se cae después, Compose no para la API. Es una
condición de arranque, no un vigilante.

### La red y el nombre de proyecto

Compose crea una red por proyecto, `<proyecto>_default`, y conecta ahí todos los servicios. Los
contenedores se llaman `<proyecto>-<servicio>-<n>` y el volumen `<proyecto>_db-data`.

El **nombre de proyecto** sale, por orden de prioridad, de `-p`, de la variable
`COMPOSE_PROJECT_NAME`, de `name:` en el archivo y, si no hay nada, del nombre del directorio.
Con dos proyectos distintos, dos copias de la pila conviven sin compartir red, volumen ni
contenedores. En CI es lo que hace que `down` borre solo lo tuyo (teoría 06).

## 3. Cómo se usa

Desde la raíz de tu copia de `tablero`, con un nombre de proyecto de laboratorio:

```bash
export COMPOSE_PROJECT_NAME=tablero-lab
docker compose config --services
# db
# api
# web
docker compose up --build --wait --quiet-pull
#  ...
#  Container tablero-lab-db-1 Healthy
#  Container tablero-lab-api-1 Healthy
#  Container tablero-lab-web-1 Healthy
```

- `--build` reconstruye las imágenes de `api` y `web` si cambió algo; sin él usaría las de la vez
  anterior.
- `--wait` implica `-d` y **no termina hasta que todos los servicios estén `healthy`**. Si uno
  llega a `unhealthy`, sale con código 1 y dice cuál: `container ...-db-1 is unhealthy`.
- `--quiet-pull` quita las barras de progreso de la descarga, que en un log de CI son ruido.

```bash
docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
# SERVICE   STATUS                    PORTS
# api       Up 11 seconds (healthy)   127.0.0.1:8000->8000/tcp
# db        Up 16 seconds (healthy)   5432/tcp
# web       Up 5 seconds (healthy)    127.0.0.1:8080->8080/tcp
./scripts/smoke-test.sh | tail -1
# borrada. Smoke test OK
docker compose logs --no-color --tail 1 db
# db-1  | ... LOG:  database system is ready to accept connections
```

`db` enseña `5432/tcp` sin flecha: el puerto existe dentro de la red, pero no está publicado.
`logs` sin nombre de servicio mezcla los tres, cada línea con su prefijo.

Para apagar:

```bash
docker compose down --volumes --rmi local
#  ...
#  Volume tablero-lab_db-data Removed
#  Network tablero-lab_default Removed
#  Image tablero-lab-api:latest Removed
#  Image tablero-lab-web:latest Removed
```

| Flag de `down` | Qué borra además de contenedores y red |
|---|---|
| (ninguno) | Nada más: el volumen con los datos sigue |
| `--volumes` | Los volúmenes con nombre del archivo, como `db-data` |
| `--rmi local` | Las imágenes que construyó Compose (las que no tienen `image:` propio) |

> ⚠️ `down --volumes` borra los datos de tu `tablero` local. Si tienes tareas que quieras
> conservar, apágalo con `down` a secas.

Las imágenes construidas salen con el tag `latest` porque el archivo no les da otro: son locales y
desechables, y no se publican. Darles un tag de verdad y subirlas a GHCR es la Semana 06.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `docker-compose up` <!-- antipatron --> | Binario v1 retirado; puede no existir o ser otra versión | `docker compose up` |
| `depends_on` sin `condition` | La API arranca antes de que la base acepte conexiones | `condition: service_healthy` |
| `ports: "5432:5432"` en `db` | Publica la base a toda tu red sin que nadie lo necesite | Sin `ports` en `db`; si lo necesitas, `127.0.0.1:` |
| `up -d` y luego `sleep` | Ni espera lo justo ni detecta un servicio que no llega a sano | `up --wait` |
| `up` sin `--build` tras cambiar código | Prueba la imagen vieja | `up --build` |
| `down` sin `--volumes` en CI | El siguiente arranque en un runner propio encuentra datos viejos | `down --volumes --rmi local` |

## 5. Trucos

- **`docker compose config`** imprime el archivo ya resuelto, con las variables interpoladas: la
  forma de ver qué `DATABASE_URL` recibe de verdad la API.
- **`docker compose ps --all`** incluye los contenedores que salieron; un servicio que se cayó al
  arrancar no aparece sin `--all`.
- **`docker compose logs -f api`** sigue el log de un servicio mientras pruebas en el navegador.

Verificado con Docker Engine 29.9.2 y Docker Compose v5.6.1, noviembre de 2026.

## 📚 Recursos Adicionales

- [Compose file reference: services](https://docs.docker.com/reference/compose-file/services/)
- [Control startup order in Compose](https://docs.docker.com/compose/how-tos/startup-order/)
- [`docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/)
- [Specify a project name](https://docs.docker.com/compose/how-tos/project-name/)

## ✅ Checklist de Verificación

- [ ] Sé traducir cada clave del servicio `db` a un flag de `docker run`
- [ ] Sé por qué la API usa `db:5432` y tú `127.0.0.1:8000`
- [ ] Sé qué garantiza `condition: service_healthy` y qué no
- [ ] Levanto con `up --build --wait` y sé qué pasa si un servicio no llega a sano
- [ ] Sé qué borra `down` con y sin `--volumes` y `--rmi local`
- [ ] Sé de dónde sale el nombre de proyecto y para qué sirve cambiarlo

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Contenedores, lo justo](01-contenedores-lo-justo.md) | [Service containers](03-service-containers.md) |
