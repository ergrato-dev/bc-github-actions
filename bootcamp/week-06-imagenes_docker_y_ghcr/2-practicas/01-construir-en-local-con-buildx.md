# Práctica 01 — Construir en local con buildx

> Antes de pedirle a un runner que construya y publique, construyes tú las dos imágenes de
> `tablero` en tu máquina. Lees sus capas, sacas su digest, ves qué capas reutiliza BuildKit cuando
> tocas una línea de código y compruebas qué pasa con el contexto si falta `.dockerignore`.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `tablero-api:dev` y `tablero-web:dev` construidas con `docker buildx build`
- Leer una imagen con `docker history` y `docker image inspect`
- El digest de un build con `--metadata-file`, y la prueba de que sin cambios no se mueve
- Ver en el log qué capas salen `CACHED` cuando cambias un archivo de `src/`
- Medir el contexto de build con y sin `.dockerignore`
- Un builder `docker-container` como el del runner, y por qué necesita `--load`

## 📋 Antes de empezar

Tienes `check-week.sh 05` en verde y no hay cambios pendientes en tu copia de `tablero`:

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
docker buildx version
# github.com/docker/buildx v0.38.1 ...
```

Si `docker buildx` no existe, instala el plugin como dice
[`docs/setup-entorno.md`](../../../docs/setup-entorno.md), apartado 6. Esta práctica no crea ningún
workflow ni comitea nada: todo pasa en tu Docker local.

---

## Paso 1: Las dos imágenes con buildx

**Por qué**: `docker buildx build` es el cliente de BuildKit, el mismo motor que usa
`build-push-action` en el runner ([teoría 03](../1-teoria/03-buildkit-y-buildx.md#tres-piezas)).
El builder `default` usa el driver `docker`: construye dentro de tu Docker Engine y deja la imagen
en `docker image ls` sin que se lo pidas. El último argumento es el **contexto**: `api` o `web`, la
carpeta cuyos archivos ve el `Dockerfile` ([teoría 02](../1-teoria/02-dockerfile-multi-stage-y-contexto.md#contexto-de-build-y-dockerignore)).

**Comando**:

```bash
docker buildx ls | grep -E '^default'
# default*      docker
docker buildx build -t tablero-api:dev api
docker buildx build -t tablero-web:dev web
```

La primera vez descarga `python:3.15.2-slim-trixie`, `node:26.13.0-trixie-slim` y
`nginxinc/nginx-unprivileged:1.31.7-alpine`, y tarda unos minutos.

**Verifica**:

```bash
docker image ls --format '{{.Repository}}:{{.Tag}}' | grep -E '^tablero-(api|web):dev$' | sort
# tablero-api:dev
# tablero-web:dev
```

---

## Paso 2: Leer las capas y la configuración

**Por qué**: una imagen es una lista de capas más una configuración
([teoría 01](../1-teoria/01-imagenes-capas-y-registros.md#capas)). `docker history` enseña una fila
por instrucción de la **etapa final**: lo que hizo la etapa `build` no aparece, solo lo que
`COPY --from=build` trajo. Por eso la imagen de la API no lleva uv y la de la web no lleva Node:
el multi-stage deja las herramientas fuera.

**Comando**:

```bash
docker history tablero-api:dev --format '{{.Size}}\t{{.CreatedBy}}' | head -4 | cut -c1-70
# 0B	CMD ["sh" "-c" "python -m tablero.migrate &&…
# 0B	EXPOSE [8000/tcp]
# 0B	USER 10001
# 42.7MB	COPY --chown=10001:10001 /app /app # buildkit
docker history tablero-web:dev --format '{{.Size}}\t{{.CreatedBy}}' | head -3 | cut -c1-70
# 0B	EXPOSE [8080/tcp]
# 250kB	COPY /app/dist /usr/share/nginx/html # build…
# 20.5kB	COPY nginx.conf /etc/nginx/conf.d/default.co…
```

Los tamaños exactos dependen de tus dependencias; el orden de las filas, no. Las filas de `0B`
solo cambian la configuración, no añaden archivos.

**Verifica**:

```bash
docker image inspect tablero-api:dev --format '{{.Config.User}} {{json .Config.ExposedPorts}}'
# 10001 {"8000/tcp":{}}
docker image inspect tablero-web:dev --format '{{.Config.User}} {{json .Config.ExposedPorts}}'
# 101 {"8080/tcp":{}}
```

Ninguna de las dos corre como `root`: la API usa el usuario que crea su `Dockerfile` y la web, el
de `nginx-unprivileged`. Por eso nginx escucha en el 8080 y no en el 80.

---

## Paso 3: El digest de un build

**Por qué**: el digest es el `sha256` de los bytes del manifiesto o del índice
([teoría 01](../1-teoria/01-imagenes-capas-y-registros.md#digest)). Con `--metadata-file`, buildx
escribe un JSON con lo que produjo el build, y su clave `containerimage.digest` es el mismo dato
que `build-push-action` devuelve en su output `digest` ([teoría 08](../1-teoria/08-digest-y-consumo.md#el-output-digest)).
Un build sin ningún cambio sale entero de caché y produce los mismos bytes: el mismo digest.

**Comando**:

```bash
docker buildx build -t tablero-api:dev --metadata-file /tmp/api-1.json -q api >/dev/null
docker buildx build -t tablero-api:dev --metadata-file /tmp/api-2.json -q api >/dev/null
jq -r 'keys[]' /tmp/api-1.json
# buildx.build.provenance
# buildx.build.ref
# containerimage.descriptor
# containerimage.digest
# image.name
jq -r '."containerimage.digest"' /tmp/api-1.json
# sha256:<64 caracteres hexadecimales>
```

**Verifica**:

```bash
[ "$(jq -r '."containerimage.digest"' /tmp/api-1.json)" = \
  "$(jq -r '."containerimage.digest"' /tmp/api-2.json)" ] && echo "mismo digest"
# mismo digest
```

Guarda `/tmp/api-1.json`: lo comparas en el paso siguiente.

---

## Paso 4: Una línea de código y la caché de capas

**Por qué**: BuildKit reutiliza una capa mientras su instrucción y sus entradas no cambien, y en
cuanto una cambia rehace esa y todas las que vienen detrás
([teoría 02](../1-teoria/02-dockerfile-multi-stage-y-contexto.md#la-caché-de-capas-regla-por-regla)).
El `Dockerfile` de la API copia primero `pyproject.toml` y `uv.lock` y sincroniza las dependencias,
y solo después copia `src`. Si tocas `main.py`, el `uv sync` caro sale de caché y solo se rehace lo
que viene desde `COPY src`.

**Comando**:

```bash
echo "# probe $(date +%s)" >> api/src/tablero/main.py
docker buildx build -t tablero-api:dev --metadata-file /tmp/api-3.json --progress=plain api 2>&1 \
  | grep -E '^#[0-9]+ (\[build|\[stage-1|CACHED)' | cut -c1-80
# #3 CACHED
# #8 [build 1/8] FROM docker.io/library/python:3.15.2-slim-trixie@sha256:8c13a3f37
# #10 [build 3/8] WORKDIR /app
# #10 CACHED
# #11 [build 2/8] COPY --from=ghcr.io/astral-sh/uv:0.13.6 /uv /usr/local/bin/uv
# #11 CACHED
# #12 [build 4/8] COPY pyproject.toml uv.lock ./
# #12 CACHED
# #13 [build 5/8] RUN uv sync --locked --no-dev --no-install-project
# #13 CACHED
# #14 [build 6/8] COPY src ./src
# #15 [build 7/8] COPY migrations ./migrations
# #16 [build 8/8] RUN uv sync --locked --no-dev
# #17 [stage-1 2/4] RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nol
# #17 CACHED
# #18 [stage-1 3/4] WORKDIR /app
# #18 CACHED
# #19 [stage-1 4/4] COPY --from=build --chown=10001:10001 /app /app
git checkout api/src/tablero/main.py
```

Fíjate en la etapa final: `useradd` sale de caché porque no depende de `src`, pero el
`COPY --from=build` se rehace porque la etapa `build` cambió. BuildKit ejecuta en paralelo lo que
puede, así que el orden de las líneas y los `#N` varían: fíjate en qué paso lleva `CACHED` debajo.

La marca lleva la hora para que cada intento sea un contenido nuevo. La caché va por contenido, no
por fecha: si repites el build con exactamente la misma línea añadida, todo sale `CACHED`.

**Verifica**:

```bash
[ "$(jq -r '."containerimage.digest"' /tmp/api-1.json)" != \
  "$(jq -r '."containerimage.digest"' /tmp/api-3.json)" ] && echo "digest distinto"
# digest distinto
git status --porcelain api/
# (sin salida: main.py está como estaba)
```

Un byte distinto en una capa da otro digest. Es lo que hace que un digest identifique
exactamente lo que se probó.

---

## Paso 5: El contexto con y sin `.dockerignore`

**Por qué**: `.dockerignore` saca archivos del contexto antes de que lleguen a BuildKit. En la web
importa doble: `COPY . .` copia todo el contexto, y un `node_modules` de tu máquina pisaría el que
acaba de instalar `pnpm install` dentro de la imagen
([teoría 02](../1-teoria/02-dockerfile-multi-stage-y-contexto.md#contexto-de-build-y-dockerignore)).
Lo mides con un archivo de 30 MB que finge ser una dependencia.

**Comando**: con `.dockerignore`, el archivo no viaja.

```bash
mkdir -p web/node_modules/.probe
head -c 30000000 /dev/urandom > web/node_modules/.probe/blob.bin
docker buildx build -t tablero-web:dev --progress=plain web 2>&1 | grep 'transferring context'
# #6 transferring context: 67B done
# #10 transferring context: 510B done
```

La primera línea es el `Dockerfile`; la segunda, el contexto. Sale pequeña (la cifra exacta varía) porque BuildKit solo
transfiere lo que cambió desde el último build, y `node_modules` está ignorado.

Ahora aparta `.dockerignore` un momento. No borras nada: `git checkout` lo devuelve.

```bash
mv web/.dockerignore /tmp/web.dockerignore
docker buildx build -t tablero-web:noignore --progress=plain web 2>&1 | grep 'transferring context'
# #6 transferring context: 2B done
# #10 transferring context: 30.01MB 0.1s done
git checkout web/.dockerignore
```

Si en tu máquina hay un `node_modules` real de la Semana 04, la cifra sale todavía mayor: viajan
también todas tus dependencias.

**Verifica**:

```bash
rm -rf web/node_modules/.probe
docker image rm tablero-web:noignore >/dev/null
git status --porcelain web/
# (sin salida: .dockerignore ha vuelto y no queda nada nuevo)
grep -c node_modules web/.dockerignore
# 1
```

---

## Paso 6: Un builder como el del runner

**Por qué**: `setup-buildx-action` no usa el builder `default`: crea uno con el driver
`docker-container`, que corre BuildKit en un contenedor aparte y admite la caché `type=gha`
([teoría 03](../1-teoria/03-buildkit-y-buildx.md#tres-piezas)). Ese builder no deja la imagen en
tu Docker salvo que se lo pidas: es la diferencia entre `push`, `load` o ninguno
([teoría 03](../1-teoria/03-buildkit-y-buildx.md#push-load-o-ninguno)), y la razón de que la
práctica 02 lleve `load: true`.

**Comando**:

```bash
docker buildx create --name lab --driver docker-container >/dev/null
docker buildx build --builder lab -t tablero-web:lab web 2>&1 | grep WARNING
# WARNING: No output specified with docker-container driver. Build result will only remain in the build cache. To push result image into registry use --push or to load image into docker use --load
docker image ls -q tablero-web:lab | wc -l
# 0
docker buildx build --builder lab --load -t tablero-web:lab web 2>&1 | grep 'importing to docker'
# #21 importing to docker
```

Sin `--load` el build termina bien, pero la imagen se queda en la caché del builder. Con `--load`,
buildx la exporta a tu Docker.

**Verifica**:

```bash
docker image ls --format '{{.Repository}}:{{.Tag}}' | grep -c '^tablero-web:lab$'
# 1
docker buildx rm lab
# lab removed
docker image rm tablero-web:lab >/dev/null
docker buildx ls | grep -E '^(lab|default)'
# default*      docker
```

---

## ✅ Resultado

- [ ] `tablero-api:dev` y `tablero-web:dev` construidas con `docker buildx build`
- [ ] Sabes leer la etapa final con `docker history` y su usuario y puerto con `docker image inspect`
- [ ] Sacas el digest de un build con `--metadata-file` y sabes por qué no se mueve sin cambios
- [ ] Has visto el `uv sync` de dependencias salir `CACHED` tras tocar `main.py`
- [ ] Has medido 30 MB de contexto sin `.dockerignore` y casi nada con él
- [ ] Sabes por qué un builder `docker-container` necesita `--load` para que `docker run` vea la imagen
- [ ] `git status` limpio y sin builder `lab`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 06
```

Esta práctica no tiene check propio: todo pasa en tu máquina. Lo que aprendes aquí lo usa el runner
desde la práctica 02.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `docker: 'buildx' is not a docker command` | Falta el plugin buildx | [`docs/setup-entorno.md`](../../../docs/setup-entorno.md), apartado 6 |
| `failed to compute cache key: ... not found` | Lanzaste el build desde otra carpeta y el contexto no tiene los archivos | Desde la raíz de `tablero`, con `api` o `web` como último argumento |
| `ADD --checksum` falla en la web | Descarga cortada o archivo distinto del esperado | Repite el build; si persiste, es el aviso de que el archivo no es el que fija el `Dockerfile` |
| Ninguna capa sale `CACHED` en el paso 4 | Hiciste `docker builder prune` entre medias, o cambiaste el lockfile | Repite el paso 3 y después el 4 |
| `transferring context` enorme también con `.dockerignore` | `.dockerignore` no está en la raíz del contexto (`web/.dockerignore`) | `git checkout web/.dockerignore` |
| `ERROR: existing instance for "lab"` | Quedó el builder de un intento anterior | `docker buildx rm lab` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Digest y consumo](../1-teoria/08-digest-y-consumo.md) | [Primer build en Actions](02-primer-build-en-actions.md) |
