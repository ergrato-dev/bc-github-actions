# Práctica 01 — Docker y Compose en local

> Antes de pedirle a un runner que levante PostgreSQL, levántalo tú. Esta práctica arranca un
> PostgreSQL 17 suelto, pasa contra él los tests de integración de la API, ve el falso verde que
> sale sin base y termina con `tablero` entero levantado por Compose y probado de punta a punta.

**Tiempo estimado**: 1 h 30 min

## 🎯 Qué vas a conseguir

- Docker y el plugin de Compose funcionando en tu máquina, y saber qué versiones tiene el runner
- Un PostgreSQL `17.11-alpine` escuchando solo en `127.0.0.1`, con healthcheck, y esperar a que
  esté `healthy` en lugar de "arrancado"
- Las migraciones y `pytest tests/integration` en verde contra esa base
- Ver con tus ojos que, sin `DATABASE_URL`, el test de integración se salta y pytest sale con `5`
- `tablero` completo con `docker compose up --build --wait` y el smoke test en verde
- Apagarlo todo sin dejar contenedores, volúmenes ni imágenes

## 📋 Antes de empezar

Tienes `check-week.sh 04` en verde y tu clon de `<tu-org>/tablero` en `~/code/tablero`, con la
rama `main` al día:

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
```

Todo lo de esta práctica pasa en tu máquina: no subes nada a GitHub hasta la práctica 02. Lo que
haces aquí con `docker run` y Compose es lo mismo que hará el runner en las prácticas siguientes;
si algo falla en CI, este es el sitio para reproducirlo.

---

## Paso 1: Docker y el plugin de Compose

**Por qué**: todo lo de esta semana habla con el demonio de Docker. `docker version` enseña las
dos mitades: el cliente que escribes y el servidor (el *Engine*) que crea los contenedores. Si el
servidor no responde, el cliente sale con `Cannot connect to the Docker daemon`. Compose va como
**plugin** (`docker compose`, con espacio), no como el binario `docker-compose` v1, que está <!-- antipatron -->
retirado. La instalación está en [`docs/setup-entorno.md`](../../../docs/setup-entorno.md).

**Comando**:

```bash
docker version
docker compose version
```

**Verifica**:

```bash
docker version --format '{{.Server.Version}}'
# 29.9.2
docker compose version --short
# 5.6.1
```

Esas son las versiones de la máquina del autor en noviembre de 2026; las tuyas pueden ser otras.
Lo que importa es que las dos órdenes respondan. El runner `ubuntu-24.04` (imagen
`20261026.354.1`) trae Docker 28.0.4 y Compose 2.38.2: todo lo que usas esta semana, incluido
`--wait`, existe en las dos.

`{{.Server.Version}}` es una plantilla de Go de `docker`, no una expresión de Actions.

---

## Paso 2: Un PostgreSQL suelto, sano y solo en 127.0.0.1

**Por qué**: es el mismo contenedor que el runner levantará como *service* en la práctica 02.
`-p 127.0.0.1:5432:5432` publica el puerto solo en tu máquina: sin la IP delante, Docker lo abre
en todas las interfaces y cualquiera de tu red llega a la base (regla 12). `--health-cmd` hace
que Docker ejecute `pg_isready` cada 5 s; hasta que pasa, el contenedor está `starting`, no
`healthy`. "Arrancado" no es "listo": la teoría 01 lo explica y el paso 2 de la práctica 02 te lo
hará ver en CI.

`cambiame` es una credencial desechable de laboratorio, no un secreto: la base vive lo que dura la
práctica.

**Comando**:

```bash
docker run -d --name lab-pg \
  -e POSTGRES_USER=tablero -e POSTGRES_PASSWORD=cambiame -e POSTGRES_DB=tablero_ci \
  -p 127.0.0.1:5432:5432 \
  --health-cmd "pg_isready -U tablero -d tablero_ci" \
  --health-interval 5s --health-timeout 5s --health-retries 10 \
  postgres:17.11-alpine
docker inspect --format '{{.State.Health.Status}}' lab-pg
# starting
until [ "$(docker inspect --format '{{.State.Health.Status}}' lab-pg)" = healthy ]; do sleep 1; done
docker ps --filter name=lab-pg --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
# NAMES     IMAGE                   STATUS                   PORTS
# lab-pg    postgres:17.11-alpine   Up 7 seconds (healthy)   127.0.0.1:5432->5432/tcp
```

El bucle `until` es lo que hace el runner por ti con un service que tiene healthcheck: esperar.

**Verifica**:

```bash
docker inspect --format '{{.State.Health.Status}}' lab-pg
# healthy
docker exec lab-pg psql -U tablero -d tablero_ci -tAc 'select version()' | cut -c1-45
# PostgreSQL 17.11 on x86_64-pc-linux-musl, com
```

`docker exec` ejecuta `psql` **dentro** del contenedor: no necesitas el cliente de PostgreSQL en
tu máquina. Es el mismo truco que usarás en el runner en la práctica 02.

---

## Paso 3: Migraciones y tests de integración contra la base

**Por qué**: `tests/integration/test_postgres.py` solo corre si existe `DATABASE_URL`; si no, se
salta entero (teoría 05). La URL apunta a `localhost:5432` porque pytest corre en tu máquina, fuera
de la red de Docker, y llega por el puerto publicado. Las migraciones van antes que los tests:
una base `healthy` está viva, pero vacía. Ejecutar `migrate` dos veces demuestra que es
idempotente: la segunda no aplica nada.

**Comando**:

```bash
cd ~/code/tablero/api
uv sync --locked
export DATABASE_URL=postgresql://tablero:cambiame@localhost:5432/tablero_ci
uv run --no-sync python -m tablero.migrate
# aplicada 001_tasks.sql
uv run --no-sync python -m tablero.migrate
# (nada: ya estaba aplicada)
uv run --no-sync pytest tests/integration -rs
# tests/integration/test_postgres.py ...                                   [100%]
#
# ============================== 3 passed in 0.31s ===============================
```

Ahora el falso verde. Quita la variable y repite:

```bash
unset DATABASE_URL
uv run --no-sync pytest tests/integration -rs; echo "exit $?"
# =========================== short test summary info ============================
# SKIPPED [1] tests/integration/test_postgres.py:15: necesita DATABASE_URL apuntando a PostgreSQL
# ============================== 1 skipped in 0.17s ==============================
# exit 5
```

Pytest sale con `5` ("no se ejecutó ningún test") y no con `1`: no es un fallo, es un aviso. Si
lanzas `pytest` sin acotar la carpeta, los tests unitarios pasan y el resultado es `0` con
`1 skipped` escondido en el resumen. Ese es el falso verde que un CI sin base produce sin que
nadie lo note; `-rs` imprime el motivo de cada test saltado.

**Verifica**:

```bash
docker exec lab-pg psql -U tablero -d tablero_ci -tAc '\dt' | cut -d'|' -f2
# schema_migrations
# tasks
```

Las dos tablas son la huella de `migrate`: `tasks` y el registro de qué migraciones se aplicaron.

---

## Paso 4: tablero entero con Compose

**Por qué**: el service container de la práctica 02 te da una base; Compose te da la **pila**:
PostgreSQL, la API construida desde su `Dockerfile` y la web con nginx delante, en el orden que
marcan los `depends_on` con `service_healthy` (teoría 02). `--build` reconstruye las imágenes de
`api` y `web` con tu código actual; `--wait` no devuelve el control hasta que los tres servicios
están `healthy`, y sale con error si alguno no llega. Sin `--wait`, el smoke test podría llegar
antes que la API.

Antes, borra el PostgreSQL suelto: ya cumplió su función y así no hay dos bases en tu máquina. No
pierdes nada que necesites.

**Comando**:

```bash
docker rm -f lab-pg
cd ~/code/tablero
docker compose up --build --wait
# ...
#  Container tablero-db-1 Healthy
#  Container tablero-api-1 Healthy
#  Container tablero-web-1 Healthy
docker compose ps
# NAME            IMAGE                   COMMAND                  SERVICE   CREATED          STATUS                    PORTS
# tablero-api-1   tablero-api             "sh -c 'python -m ta…"   api       17 seconds ago   Up 11 seconds (healthy)   127.0.0.1:8000->8000/tcp
# tablero-db-1    postgres:17.11-alpine   "docker-entrypoint.s…"   db        17 seconds ago   Up 17 seconds (healthy)   5432/tcp
# tablero-web-1   tablero-web             "/docker-entrypoint.…"   web       17 seconds ago   Up 5 seconds (healthy)    127.0.0.1:8080->8080/tcp
```

Fíjate en las columnas: `db` no publica nada (`5432/tcp` sin flecha), porque solo la API habla con
ella por la red de Compose, y los puertos de `api` y `web` van atados a `127.0.0.1`. Los
`CREATED` iguales y los `Up` escalonados son los `depends_on`: `web` esperó a `api`, y `api` a
`db`.

**Verifica**:

```bash
./scripts/smoke-test.sh; echo "exit $?"
# health:
# {"status":"ok","version":"dev"}
# creada la tarea 1
# la tarea aparece en el listado
# borrada. Smoke test OK
# exit 0
```

El script entra por nginx (`127.0.0.1:8080`), así que prueba también el proxy hacia la API, crea
una tarea, la busca y la borra. Es el mismo que correrá el runner en la práctica 04.

---

## Paso 5: Apagar y limpiar

> ⚠️ **Advertencia**: `docker compose down --volumes` **borra el volumen `tablero_db-data`**, es
> decir, todas las tareas que hayas creado en tu `tablero` local. `--rmi local` borra además las
> imágenes `tablero-api` y `tablero-web` (la siguiente vez se reconstruyen con `--build`). Si
> quieres conservar algo de esa base, haz antes un volcado:
>
> ```bash
> docker compose exec db pg_dump -U tablero tablero > ~/tablero-backup.sql
> ```

**Por qué**: `docker compose down` a secas para y borra contenedores y red, pero deja el volumen:
la próxima vez la base arranca con los datos de hoy. En CI eso no importa (la máquina se borra),
pero en tu portátil los volúmenes y las imágenes se acumulan sin hacer ruido. `--volumes` y
`--rmi local` dejan la máquina como estaba; `local` solo toca las imágenes **construidas** por este
proyecto, no `postgres:17.11-alpine`, que se queda en caché para la próxima vez.

**Comando**:

```bash
docker compose down --volumes --rmi local
# ...
#  Volume tablero_db-data Removed
#  Network tablero_default Removed
#  Image tablero-api:latest Removed
#  Image tablero-web:latest Removed
```

`latest` aquí es el tag que Compose pone a las imágenes que construye en local y que nunca salen de
tu máquina. En la Semana 06 les darás un tag de verdad antes de publicarlas.

**Verifica**:

```bash
docker compose ps --all --format '{{.Name}}' | wc -l
# 0
docker volume ls -q --filter name=tablero | wc -l
# 0
docker ps -a --filter name=lab-pg -q | wc -l
# 0
```

---

## ✅ Resultado

- [ ] `docker version` responde con cliente y servidor, y `docker compose version` con el plugin
- [ ] Has esperado a `healthy` con `docker inspect`, no a "arrancado"
- [ ] Sabes por qué el puerto va en `127.0.0.1` y por qué la URL de los tests dice `localhost`
- [ ] `migrate` aplica `001_tasks.sql` la primera vez y nada la segunda
- [ ] `pytest tests/integration` da `3 passed` con base y `1 skipped` con código `5` sin ella
- [ ] `docker compose up --build --wait` deja los tres servicios `healthy` y el smoke test pasa
- [ ] No queda ningún contenedor, volumen ni imagen de `tablero` en tu máquina

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 05
```

De momento solo pasan las que heredas de semanas anteriores, como `workflows-pinned`: el resto
llega con los workflows de las prácticas siguientes y del proyecto.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `Cannot connect to the Docker daemon` | El servicio de Docker no está arrancado, o tu usuario no está en el grupo `docker` | `docs/setup-entorno.md`; en Linux, `sudo systemctl start docker` |
| `docker: 'compose' is not a docker command` | Falta el plugin de Compose | Instálalo como plugin (`setup-entorno.md`); no uses `docker-compose` v1 | <!-- antipatron -->
| `Bind for 127.0.0.1:5432 failed: port is already allocated` | Ya tienes algo en el 5432: otro contenedor o un PostgreSQL instalado en tu máquina | `docker ps` o `ss -ltn \| grep 5432`; para lo que sea, o usa `-p 127.0.0.1:5433:5432` y `localhost:5433` en `DATABASE_URL` |
| `Conflict. The container name "/lab-pg" is already in use` | Quedó un `lab-pg` de un intento anterior | `docker rm -f lab-pg` y repite el paso 2 |
| El estado se queda en `starting` y acaba en `unhealthy` | El `-U` o el `-d` de `--health-cmd` no coinciden con `POSTGRES_USER`/`POSTGRES_DB` | `docker inspect --format '{{json .State.Health}}' lab-pg` enseña la salida de `pg_isready` |
| `password authentication failed for user "tablero"` | La contraseña de `DATABASE_URL` no es la de `POSTGRES_PASSWORD` | Las dos valen `cambiame` |
| `pytest` da `1 skipped` aunque exportaste la URL | La exportaste en otra terminal, o hiciste `unset` antes | `echo "$DATABASE_URL"` en la misma terminal donde lanzas pytest |
| `docker compose up --wait` sale con `dependency failed to start` | Un servicio no llegó a `healthy` | `docker compose ps --all` y `docker compose logs <servicio>` |
| El smoke test falla con `curl: (7) Failed to connect` | La pila no está levantada, o la apagaste | `docker compose ps`: los tres tienen que estar `healthy` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Depurar servicios](../1-teoria/07-depurar-servicios.md) | [PostgreSQL como service](02-postgresql-como-service.md) |
