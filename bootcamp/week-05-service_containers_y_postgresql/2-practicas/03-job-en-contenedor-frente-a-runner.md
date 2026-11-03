# Práctica 03 — Job en contenedor frente a runner

> El mismo PostgreSQL, dos sitios desde los que llamarlo. Esta práctica pone un job en el runner y
> otro dentro de un contenedor, los dos contra un service, y te enseña por qué uno dice
> `localhost` y el otro `postgres`, qué pasa si los confundes y cómo leer un puerto que elige
> Docker.

**Tiempo estimado**: 1 h 15 min

## 🎯 Qué vas a conseguir

- `container-lab.yml`, un workflow de laboratorio con tres jobs que se lanza a mano
- Un job en el runner que llega al service por `localhost` y el puerto publicado
- Un job con `container:` que llega al service por su nombre, sin publicar nada
- Reconocer en un log el error de usar `localhost` dentro de un contenedor
- Un puerto aleatorio con `- 5432`, leído de `job.services.postgres.ports['5432']`

## 📋 Antes de empezar

Terminaste la [práctica 02](02-postgresql-como-service.md): `service-lab.yml` tiene un run en
`success` y no tienes cambios pendientes.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
```

Ninguno de los tres jobs necesita checkout: no tocan el código de `tablero`, solo la red.

---

## Paso 1: Un job en el runner, por localhost

**Por qué**: es el caso de la práctica 02, reducido a lo mínimo. Tus steps son procesos de la
máquina virtual, **fuera** de la red de Docker que crea el runner; para ellos el service solo
existe si su puerto se publica en el host (`ports: - 5432:5432`), y entonces está en `localhost`.
La imagen `ubuntu-24.04` trae instalado el cliente de PostgreSQL (con un servidor PostgreSQL 16
parado que no vas a usar), así que `pg_isready` existe en el runner sin instalar nada.

**Comando**: crea `.github/workflows/container-lab.yml`.

```yaml
name: container-lab

on:
  workflow_dispatch:

# Mínimo privilegio: el token solo lee. Lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  on-runner:
    name: Desde el runner (localhost)
    runs-on: ubuntu-24.04
    services:
      postgres:
        image: postgres:17.11-alpine
        env:
          POSTGRES_USER: tablero
          # Credencial desechable de CI: el contenedor muere con el job.
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
      - name: pg_isready contra el puerto publicado
        run: pg_isready -h localhost -p 5432 -U tablero -d tablero_ci
```

**Verifica**:

```bash
actionlint .github/workflows/container-lab.yml; echo "exit $?"
# exit 0
yq '.jobs.on-runner.services.postgres.ports[0]' .github/workflows/container-lab.yml
# 5432:5432
```

---

## Paso 2: Un job dentro de un contenedor, por nombre

**Por qué**: con `container:` el runner arranca **tu job** en un contenedor y lo conecta a la misma
red que el service. Dentro de esa red, Docker resuelve cada service por su clave bajo
`services:` (el runner se la pone como alias de red), así que el host es `postgres` y el puerto el
del contenedor, `5432`. No hace falta `ports`: no sales al host. Como contenedor del job usas la
propia imagen `postgres:17.11-alpine` porque trae `pg_isready` y `psql`; el runner le cambia el
punto de entrada para que se quede esperando órdenes, así que dentro **no** arranca otro
servidor. Esa imagen es Alpine, sin bash: los `run:` corren con `sh`.

**Comando**: añade el job debajo de `on-runner`.

```yaml
  in-container:
    name: Desde un contenedor (nombre del servicio)
    runs-on: ubuntu-24.04
    container: postgres:17.11-alpine
    services:
      postgres:
        image: postgres:17.11-alpine
        env:
          POSTGRES_USER: tablero
          POSTGRES_PASSWORD: cambiame
          POSTGRES_DB: tablero_ci
        options: >-
          --health-cmd "pg_isready -U tablero -d tablero_ci"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10
    steps:
      - name: pg_isready contra el nombre del servicio
        run: pg_isready -h postgres -p 5432 -U tablero -d tablero_ci
      - name: Una consulta por la red del job
        env:
          PGPASSWORD: cambiame
        run: psql -h postgres -U tablero -d tablero_ci -tAc 'select current_database()'
```

`PGPASSWORD` es la variable que lee `psql`; va por `env:` y vale el mismo `cambiame` desechable.

**Verifica**:

```bash
actionlint .github/workflows/container-lab.yml; echo "exit $?"
# exit 0
yq '.jobs.in-container.container' .github/workflows/container-lab.yml
# postgres:17.11-alpine
yq '.jobs.in-container.services.postgres | has("ports")' .github/workflows/container-lab.yml
# false
```

---

## Paso 3: localhost dentro del contenedor no es el service

**Por qué**: dentro de un contenedor, `localhost` es **el propio contenedor**, no el runner ni el
service. En el job `in-container`, `localhost:5432` apunta al contenedor del job, donde no escucha
ningún PostgreSQL. Es el error más típico al mover un job del runner a `container:` (o al revés):
copiar la `DATABASE_URL` sin cambiar el host.

Lo reproduces en tu máquina con lo mismo que monta el runner: una red, un service con alias
`postgres` y un contenedor cliente en esa red.

**Comando**:

```bash
docker network create lab-net
docker run -d --name lab-svc --network lab-net --network-alias postgres \
  -e POSTGRES_USER=tablero -e POSTGRES_PASSWORD=cambiame -e POSTGRES_DB=tablero_ci \
  --health-cmd "pg_isready -U tablero -d tablero_ci" --health-interval 2s \
  postgres:17.11-alpine
until [ "$(docker inspect --format '{{.State.Health.Status}}' lab-svc)" = healthy ]; do sleep 1; done
docker run --rm --network lab-net postgres:17.11-alpine \
  pg_isready -h postgres -p 5432 -U tablero -d tablero_ci
# postgres:5432 - accepting connections
docker run --rm --network lab-net postgres:17.11-alpine \
  pg_isready -h localhost -p 5432 -U tablero -d tablero_ci; echo "exit $?"
# localhost:5432 - no response
# exit 2
docker run --rm --network lab-net -e PGPASSWORD=cambiame postgres:17.11-alpine \
  psql -h localhost -U tablero -d tablero_ci -c 'select 1'
# psql: error: connection to server at "localhost" (::1), port 5432 failed: Connection refused
# 	Is the server running on that host and accepting TCP/IP connections?
# connection to server at "localhost" (127.0.0.1), port 5432 failed: Connection refused
# 	Is the server running on that host and accepting TCP/IP connections?
docker rm -f lab-svc
docker network rm lab-net
```

En CI verías esas mismas líneas en el step, con el service `healthy` en *Initialize containers*:
la base está bien, lo que está mal es la dirección. El error simétrico, `-h postgres` desde el
runner, da `could not translate host name "postgres"`: el runner no está en la red de Docker y no
resuelve ese nombre (teoría 07, causa 3).

**Verifica**:

```bash
yq '.jobs.in-container.steps[].run' .github/workflows/container-lab.yml | grep -c localhost
# 0
docker ps -a --filter name=lab-svc -q | wc -l
# 0
```

---

## Paso 4: Un puerto aleatorio leído del contexto

**Por qué**: `5432:5432` funciona porque el runner alojado está vacío. Con dos services del mismo
tipo en un job, o en un runner propio con varios jobs a la vez (Semana 15), el 5432 del host puede
estar ocupado. Con `- 5432` (solo el puerto del contenedor) Docker elige uno libre del host, y el
runner lo deja en `job.services.postgres.ports['5432']`. Como cualquier contexto, llega al shell por
`env:`.

En tu máquina es `-p 127.0.0.1::5432` (sin puerto de host) y `docker port`:

```bash
docker run -d --name rnd-pg -e POSTGRES_PASSWORD=cambiame -p 127.0.0.1::5432 postgres:17.11-alpine
docker port rnd-pg 5432
# 127.0.0.1:32768
docker rm -f rnd-pg
```

El número cambia de una vez a otra: por eso se lee, no se escribe.

**Comando**: añade el tercer job.

```yaml
  random-port:
    name: Puerto aleatorio en el runner
    runs-on: ubuntu-24.04
    services:
      postgres:
        image: postgres:17.11-alpine
        env:
          POSTGRES_USER: tablero
          POSTGRES_PASSWORD: cambiame
          POSTGRES_DB: tablero_ci
        ports:
          - 5432
        options: >-
          --health-cmd "pg_isready -U tablero -d tablero_ci"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10
    steps:
      - name: Leer el puerto que eligió Docker
        env:
          DB_PORT: ${{ job.services.postgres.ports['5432'] }}
        run: |
          echo "PostgreSQL en localhost:$DB_PORT"
          pg_isready -h localhost -p "$DB_PORT" -U tablero -d tablero_ci
```

La clave del mapa es `'5432'`, el puerto **del contenedor**, entre comillas: es un texto.

**Verifica**:

```bash
actionlint .github/workflows/container-lab.yml; echo "exit $?"
# exit 0
yq '.jobs | keys | join(",")' .github/workflows/container-lab.yml
# on-runner,in-container,random-port
yq '.jobs.random-port.services.postgres.ports[0]' .github/workflows/container-lab.yml
# 5432
```

---

## Paso 5: En verde y lanzado a mano

**Por qué**: los tres jobs no dependen entre sí y corren en paralelo, cada uno en su runner y con
su propio PostgreSQL. El run solo es `success` si los tres lo son; la comprobación
`container-lab-dispatched` pide un run `workflow_dispatch` en `success`.

**Comando**:

```bash
git add .github/workflows/container-lab.yml
git commit -m "ci(lab): add container-lab workflow"
git push
gh workflow run container-lab.yml
sleep 5   # el run tarda unos segundos en aparecer en la lista
id=$(gh run list --workflow container-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status; echo "exit $?"
# ...
# exit 0
gh run view "$id" --log | grep -E 'accepting connections|tablero_ci$|PostgreSQL en' | cut -c1-120
# ... localhost:5432 - accepting connections
# ... postgres:5432 - accepting connections
# ... tablero_ci
# ... PostgreSQL en localhost:...
# ... localhost:... - accepting connections
```

El orden de las líneas depende de qué job termine antes. En la del job `random-port` verás el
número que eligió Docker; no será 5432.

**Verifica**:

```bash
gh run view "$id" --json jobs --jq '.jobs[] | [.name, .conclusion] | @tsv'
# ...	success   (una línea por job, las tres en success)
gh run list --workflow container-lab.yml --event workflow_dispatch --status success \
  --json databaseId --jq length
# 1
```

---

## ✅ Resultado

- [ ] `container-lab.yml` está en `main`, solo se lanza a mano y tiene tres jobs
- [ ] Sabes por qué el job en el runner necesita `ports` y el job en contenedor no
- [ ] Sabes qué host usar en cada caso: `localhost` en el runner, la clave del service en `container:`
- [ ] Reconoces `localhost:5432 - no response` y `could not translate host name` en un log
- [ ] Has leído un puerto aleatorio de `job.services.postgres.ports['5432']` por `env:`
- [ ] Un run de `container-lab.yml` lanzado a mano terminó en `success`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 05
```

Ya pasan `service-lab-dispatched` y `container-lab-dispatched`.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `localhost:5432 - no response` en `in-container` | Usaste `localhost` dentro del contenedor | Paso 3: el host es `postgres`, la clave bajo `services:` |
| `could not translate host name "postgres"` en `on-runner` | Usaste el nombre del service desde el runner | Paso 1: desde el runner es `localhost` y el puerto publicado |
| `localhost:5432 - no response` en `on-runner` | Falta `ports: - 5432:5432` | Paso 1: sin publicar, el runner no ve el puerto |
| `pg_isready: command not found` en `on-runner` o `random-port` | La imagen del runner dejó de traer el cliente de PostgreSQL | Usa `docker exec "$POSTGRES_CONTAINER" pg_isready ...` con el id por `env:`, como en la práctica 02 |
| `random-port` dice `PostgreSQL en localhost:` sin número | La clave de `ports[...]` no es `'5432'`, o el service no se llama `postgres` | Paso 4: `job.services.<clave>.ports['5432']` |
| `in-container` falla en un step con `shell: bash` | La imagen Alpine no trae bash | Quita el `shell`: los `run:` de ese job van con `sh` |
| `network with name lab-net already exists` o `"/lab-svc" is already in use` en local | Quedó la red o el contenedor de un intento anterior del paso 3 | `docker rm -f lab-svc; docker network rm lab-net` y repite |
| El run falla con `startup_failure` | Tienes `sha_pinning_required` activo y una `uses:` va por tag | `scripts/resolve-sha.sh` (Semana 01, práctica 04, paso 3) |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [PostgreSQL como service](02-postgresql-como-service.md) | [Smoke test con Compose](04-smoke-con-compose.md) |
