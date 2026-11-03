# Dockerfile multi-stage y contexto

> Los dos `Dockerfile` de `tablero` existen desde la Semana 05, pero hasta ahora solo se usaban
> para levantar la pila. Antes de publicarlos conviene leerlos despacio: el orden de sus
> instrucciones decide cuánto tarda cada build y cuánto pesa cada imagen.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Leer los `Dockerfile` de `app/api` y `app/web` instrucción a instrucción
- Explicar qué es una etapa, qué copia `COPY --from` y por qué la imagen final no lleva uv ni pnpm
- Predecir qué capas se reconstruyen cuando cambia el código, el lockfile o la imagen base
- Explicar qué es el contexto de build y qué deja fuera `.dockerignore`
- Saber qué contexto usa `build-push-action` en `tablero` y por qué

## 1. Qué problema resuelve

Un `Dockerfile` ingenuo (una etapa, `COPY . .` al principio, instalar después) funciona, pero
tiene dos costes que en CI se pagan en cada commit:

- **Tamaño**: la imagen final arrastra el compilador, el gestor de paquetes, las cachés de descarga
  y los tests. Más megas que subir a GHCR, que bajar en cada despliegue y que escanear en la
  Semana 14.
- **Tiempo**: si el código se copia antes que las dependencias, cambiar una línea de `main.py`
  invalida la capa de `uv sync` y se reinstala todo. Con la caché de capas de la teoría 06 eso
  significa no aprovecharla nunca.

El multi-stage arregla lo primero; el orden de las instrucciones, lo segundo.

## 2. Cómo funciona

### Etapas

Cada `FROM` empieza una **etapa** nueva, con su propio sistema de archivos. `FROM ... AS build` le
da nombre. La imagen que se publica es la **última** etapa; las demás solo existen durante el build,
y de ellas solo llega a la final lo que copies explícitamente con `COPY --from=<etapa>`.

`COPY --from` también acepta una imagen: `COPY --from=ghcr.io/astral-sh/uv:0.13.6 /uv ...` saca un
binario de una imagen sin heredar nada más de ella.

### La caché de capas, regla por regla

BuildKit recorre las instrucciones en orden y, para cada una, mira si ya tiene una capa hecha con
la misma instrucción, sobre la misma capa anterior y, en `COPY` y `ADD`, con los mismos archivos
(compara su contenido, no la fecha). Si la tiene, la reutiliza (`CACHED`). En cuanto una
instrucción no coincide, **esa y todas las que vienen detrás en la misma etapa** se reconstruyen.

De ahí la regla de oro: **lo que cambia poco, arriba; lo que cambia mucho, abajo**.

### `app/api/Dockerfile`

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.15.2-slim-trixie AS build
COPY --from=ghcr.io/astral-sh/uv:0.13.6 /uv /usr/local/bin/uv
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev --no-install-project
COPY src ./src
COPY migrations ./migrations
RUN uv sync --locked --no-dev

FROM python:3.15.2-slim-trixie
...
COPY --from=build --chown=10001:10001 /app /app
USER 10001
```

| Instrucción | Para qué |
|---|---|
| `# syntax=docker/dockerfile:1` | Usa la última versión 1.x del frontend de `Dockerfile`: habilita `ADD --checksum` y otras opciones aunque el BuildKit del runner sea más viejo |
| `COPY --from=ghcr.io/astral-sh/uv:0.13.6` | uv con versión fija, solo en la etapa `build` |
| `UV_COMPILE_BYTECODE=1` | Compila los `.pyc` en el build: la API arranca más rápido |
| `UV_LINK_MODE=copy` | Copia los paquetes al `.venv` en vez de enlazarlos desde la caché de uv, que no llega a la imagen final |
| `UV_PYTHON_DOWNLOADS=never` | Usa el Python de la imagen base; uv no baja otro |
| `COPY pyproject.toml uv.lock` y primer `uv sync` con `--no-install-project` | Instala **solo las dependencias**. Esta capa depende únicamente del lockfile |
| `COPY src`, `COPY migrations` y segundo `uv sync` | Instala el proyecto encima: rápido, porque las dependencias ya están |
| Segunda etapa sin uv | La imagen final lleva Python, el `.venv` y el código. Nada más |
| `useradd` y `USER 10001` | Corre sin root, con un UID numérico que Kubernetes puede comprobar (Semana 17) |

### `app/web/Dockerfile`

La etapa `build` parte de `node:26.13.0-trixie-slim`, instala pnpm 12.16.1 desde la release
oficial con `ADD --checksum=sha256:…` (si el archivo descargado no tiene ese hash, el build falla:
es la regla 9 de seguridad aplicada dentro de un `Dockerfile`), copia `package.json` y
`pnpm-lock.yaml`, ejecuta `pnpm install --frozen-lockfile`, copia el resto y ejecuta `pnpm build`.

La etapa final es `nginxinc/nginx-unprivileged:1.31.7-alpine` con `nginx.conf` y la carpeta `dist`
copiada de la etapa anterior. La imagen publicada **no tiene Node**: solo nginx y archivos
estáticos.

### Qué se reconstruye cuando cambia algo

| Cambias... | En la API | En la web |
|---|---|---|
| Una línea de código | Desde `COPY src` (el primer `uv sync` sale `CACHED`) | Desde `COPY . .` (el `pnpm install` sale `CACHED`) |
| El lockfile | Desde `COPY pyproject.toml uv.lock` | Desde `COPY package.json pnpm-lock.yaml` |
| El tag de la imagen base | Todo | Todo |
| `nginx.conf` | Nada | Solo la etapa final |
| Un archivo de `tests/` | Nada: `.dockerignore` lo excluye | Desde `COPY . .` |

### Contexto de build y `.dockerignore`

El **contexto** es el conjunto de archivos que el cliente entrega a BuildKit para el build. `COPY`
solo puede leer de ahí: `COPY ../compose.yaml` no funciona. En `docker build api`, el contexto es
la carpeta `api/` y el `Dockerfile` se busca en `api/Dockerfile`.

`.dockerignore`, en la raíz del contexto, saca archivos del contexto antes de que nada los vea:

| Archivo | Excluye | Por qué |
|---|---|---|
| `app/api/.dockerignore` | `.venv`, `.pytest_cache`, `.ruff_cache`, `.coverage`, `htmlcov`, `tests`, `**/__pycache__` | Tu `.venv` local es de otra máquina y pisaría el de la imagen; los tests y las cachés no pintan nada en producción |
| `app/web/.dockerignore` | `node_modules`, `dist`, `coverage` | Si tu `node_modules` local entrara con `COPY . .`, pisaría el que acaba de instalar `pnpm install` |

Fíjate en el segundo caso: en la web, `COPY . .` copia todo lo que no esté ignorado. Sin
`.dockerignore`, un `node_modules` de tu portátil (de otra versión de Node, quizá de otro sistema
operativo) acabaría dentro de la imagen.

### El contexto en Actions

`build-push-action` tiene dos formas de conseguir el contexto (teoría 03 las detalla):

- **Git context**, si no le pasas `context`: BuildKit clona el repo en el commit del evento.
- **Path context**, con `context: <ruta>`: usa los archivos del checkout del runner.

En `<tu-org>/tablero` las carpetas `api/` y `web/` están en la raíz (copiaste `app/` ahí en la
Semana 01), así que `images.yml` usa `context: ${{ matrix.image }}`, es decir, `api` o `web`, después
de `actions/checkout`. Y como `file` vale por defecto `{context}/Dockerfile`, no hace falta decir
dónde está el `Dockerfile`.

## 3. Cómo se usa

### Ver la caché de capas en acción

```bash
cd ~/code/tablero
docker build -t tablero-api:dev api
echo '# probe' >> api/src/tablero/main.py
docker build -t tablero-api:dev api --progress=plain 2>&1 | grep -E '^#[0-9]+ (\[build|CACHED)'
# #10 [build 2/8] COPY --from=ghcr.io/astral-sh/uv:0.13.6 /uv /usr/local/bin/uv
# #10 CACHED
# #11 [build 4/8] COPY pyproject.toml uv.lock ./
# #11 CACHED
# #13 [build 5/8] RUN uv sync --locked --no-dev --no-install-project
# #13 CACHED
# #14 [build 6/8] COPY src ./src
# #15 [build 7/8] COPY migrations ./migrations
# #16 [build 8/8] RUN uv sync --locked --no-dev
git checkout api/src/tablero/main.py
```

Las dependencias salen `CACHED`; desde `COPY src` todo se rehace. Es exactamente la tabla de
arriba. `--progress=plain` imprime el log completo en vez de la barra interactiva.

### Ver qué entra en el contexto

```bash
docker build -t tablero-api:dev api --progress=plain 2>&1 | grep 'transferring context'
# #6 transferring context: 111B done
# #9 transferring context: 58.15kB done
```

La primera línea es el `Dockerfile` y el `.dockerignore`; la segunda, el contexto: unos 58 kB de
código y lockfile la primera vez. En los builds siguientes BuildKit solo transfiere lo que cambió,
así que verás cifras más pequeñas. Si un día ves cientos de megas, algo que debería estar en
`.dockerignore` no lo está: con 50 MB de basura dentro de `api/.venv`, la cifra no se mueve,
porque `.venv` está ignorado.

### Construir solo una etapa

```bash
docker build --target build -t tablero-api:build-stage api
docker run --rm tablero-api:build-stage uv --version
# uv 0.13.6 (x86_64-unknown-linux-musl)
docker run --rm tablero-api:dev sh -c 'command -v uv || echo "sin uv"'
# sin uv
```

`--target` para en la etapa que nombres. Sirve para depurar lo que pasa dentro del build y para
comprobar que la imagen final no lleva las herramientas de la etapa anterior.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `COPY . .` antes de instalar dependencias | Cualquier cambio de código reinstala todo | Copiar primero el lockfile, instalar, y luego el código |
| Una sola etapa | La imagen final lleva uv, Node, pnpm, cachés y compiladores | Etapa `build` y etapa final mínima |
| Sin `.dockerignore` | Tu `.venv` o tu `node_modules` acaba dentro de la imagen | Excluir lo que se genera en local |
| Imagen base sin parche (`python:3.15-slim`) | El build de hoy y el de mañana parten de bases distintas | Tag completo; el digest llega en la Semana 14 |
| Descargar con `curl` sin comprobar el hash | Si alguien cambia el archivo en origen, entra en tu imagen | `ADD --checksum=sha256:…` |
| Correr como root en la imagen final | Una fuga del proceso es root en el contenedor | `USER` con UID numérico |

## 5. Trucos

- **`docker build --check api`** pasa las comprobaciones de BuildKit sobre el `Dockerfile` (por
  ejemplo, mayúsculas incoherentes en `FROM ... AS`) sin construir nada.
- **`--no-cache-filter build`** reconstruye solo la etapa `build` y reutiliza la caché del resto:
  útil cuando sospechas de una capa cacheada concreta sin tirar todo.
- **`docker build --progress=plain ... 2>&1 | grep -c CACHED`** te da en un número cuántos pasos
  reutilizó un build. Compáralo antes y después de tocar el orden de un `Dockerfile`.

Verificado con Docker Engine 29.9.2 y buildx v0.38.1, noviembre de 2026.

## 📚 Recursos Adicionales

- [Docker: Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [Docker: Build cache, cómo se invalida](https://docs.docker.com/build/cache/invalidation/)
- [Docker: Build context y `.dockerignore`](https://docs.docker.com/build/concepts/context/)
- [uv: Using uv in Docker](https://docs.astral.sh/uv/guides/integration/docker/)

## ✅ Checklist de Verificación

- [ ] Sé qué es una etapa y qué llega de ella a la imagen final
- [ ] Sé por qué el lockfile se copia antes que el código
- [ ] Sé predecir qué capas se reconstruyen al cambiar código, lockfile o base
- [ ] Sé qué es el contexto de build y para qué sirve `.dockerignore`
- [ ] Sé qué contexto usa `images.yml` y por qué no necesita `file`
- [ ] Sé construir una etapa concreta con `--target`

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Imágenes, capas y registros](01-imagenes-capas-y-registros.md) | [BuildKit y buildx](03-buildkit-y-buildx.md) |
