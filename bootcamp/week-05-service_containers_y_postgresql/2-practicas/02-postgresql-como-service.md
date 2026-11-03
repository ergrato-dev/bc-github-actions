# Práctica 02 — PostgreSQL como service

> Lo que en la práctica 01 arrancaste con `docker run`, ahora lo arranca el runner antes del primer
> step. Esta práctica monta un PostgreSQL 17 como service container, ve qué pasa sin healthcheck,
> pasa contra él los tests de integración y rompe la conexión a propósito para leer los logs de la
> base.

**Tiempo estimado**: 1 h 30 min

## 🎯 Qué vas a conseguir

- `service-lab.yml`, un workflow de laboratorio que se lanza a mano con un service `postgres`
- Hablar con el service desde el runner sin instalar nada, con `docker exec` y el id del contexto
  `job.services`
- Entender por qué `--health-cmd pg_isready` no es opcional
- Migraciones y `pytest tests/integration` contra el service, por `localhost:5432`
- Un step que vuelca los logs de PostgreSQL **solo** si algo falla, y verlo en acción

## 📋 Antes de empezar

Terminaste la [práctica 01](01-docker-y-compose-en-local.md) y no tienes cambios pendientes:

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
```

`service-lab.yml` es un banco de pruebas: solo se lanza a mano. El workflow que entregas es
`ci-api.yml`, en el proyecto de la semana, y su job `integration` saldrá casi entero de aquí.

---

## Paso 1: El service y una consulta desde su contenedor

**Por qué**: con `services:` el runner hace por ti el `docker run` de la práctica 01: descarga la
imagen, crea una red para el job, arranca el contenedor con las variables de `env` y publica los
`ports`, todo en *Initialize containers*, antes del primer step (teoría 03). El `env` del service
son variables **del contenedor**; `DATABASE_URL`, que lee tu código, irá en el `env` del job.

Para comprobar que la base responde no instalas ningún cliente en el runner: ejecutas `psql`
dentro del propio contenedor del service, como hiciste con `docker exec lab-pg`. Su id lo da
`job.services.postgres.id`, y llega al shell por `env:` (regla 4).

**Comando**: crea `.github/workflows/service-lab.yml`.

```yaml
name: service-lab

on:
  workflow_dispatch:

# Mínimo privilegio: el token solo lee. Lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  integration:
    name: PostgreSQL como service
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
    steps:
      - name: Preguntar a PostgreSQL desde su contenedor
        env:
          POSTGRES_CONTAINER: ${{ job.services.postgres.id }}
        run: docker exec "$POSTGRES_CONTAINER" psql -U tablero -d tablero_ci -tAc 'select version()'
```

`postgres` en la expresión es la clave bajo `services:`; si la llamas `db`, es `job.services.db.id`.

**Verifica**:

```bash
actionlint .github/workflows/service-lab.yml; echo "exit $?"
# exit 0
yq '.jobs.integration.services.postgres.image' .github/workflows/service-lab.yml
# postgres:17.11-alpine
yq '.jobs.integration.services.postgres.ports[0]' .github/workflows/service-lab.yml
# 5432:5432
```

No lo subas todavía: le falta lo del paso 2.

---

## Paso 2: El healthcheck, para que el runner espere

**Por qué**: sin healthcheck, el runner da el service por listo en cuanto el contenedor existe, y
el primer step arranca mientras PostgreSQL todavía está inicializando el directorio de datos. Lo
puedes reproducir en tu máquina con el mismo contenedor, sin `--health-cmd` y con la consulta
justo detrás:

```bash
docker run -d --name race-pg -e POSTGRES_USER=tablero -e POSTGRES_PASSWORD=cambiame \
  -e POSTGRES_DB=tablero_ci postgres:17.11-alpine >/dev/null \
  && docker exec race-pg psql -U tablero -d tablero_ci -tAc 'select 1'; echo "exit $?"
# psql: error: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed: No such file or directory
# 	Is the server running locally and accepting connections on that socket?
# exit 2
docker rm -f race-pg
```

Es una carrera: a veces gana la base y a veces el step, y un CI que falla "a veces" es peor que
uno que falla siempre. Con `--health-cmd`, *Initialize containers* no termina hasta que el
contenedor está `healthy`: el runner espera por ti, como tu bucle `until` de la práctica 01.

**Comando**: añade `options` al service, debajo de `ports`.

```yaml
        options: >-
          --health-cmd "pg_isready -U tablero -d tablero_ci"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10
```

`>-` pliega las cuatro líneas en una con espacios, que es lo que el runner pasa a `docker create`.
Con 10 intentos cada 5 s, la base tiene 50 s para estar lista; si no lo consigue, el job falla en
*Initialize containers* con un mensaje que lo dice, no en un step tuyo con un error confuso.

**Verifica**:

```bash
actionlint .github/workflows/service-lab.yml; echo "exit $?"
# exit 0
yq '.jobs.integration.services.postgres.options' .github/workflows/service-lab.yml
# --health-cmd "pg_isready -U tablero -d tablero_ci" --health-interval 5s --health-timeout 5s --health-retries 10
```

Es la forma que pide `integration-health-cmd` en el `ci-api.yml` del proyecto.

---

## Paso 3: Migraciones y tests de integración contra el service

**Por qué**: tus steps corren en el runner, fuera de la red de Docker, así que llegan a la base
por el puerto publicado: `localhost:5432`, igual que tu pytest en la práctica 01. `DATABASE_URL`
va en el `env` del **job** porque la necesitan dos steps (migraciones y tests). El resto es el CI
de Python de la Semana 03: checkout, uv con caché, `uv sync --locked` y `uv run --no-sync`.

**Comando**: añade el `env` del job encima de `steps:` y los steps al final.

```yaml
    env:
      DATABASE_URL: postgresql://tablero:cambiame@localhost:5432/tablero_ci
```

```yaml
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
        with:
          version: "0.13.6"
          enable-cache: true
          cache-dependency-glob: api/uv.lock

      - name: Dependencias
        working-directory: api
        run: uv sync --locked

      - name: Migraciones
        working-directory: api
        run: uv run --no-sync python -m tablero.migrate

      - name: Tests de integración
        working-directory: api
        run: uv run --no-sync pytest tests/integration -rs
```

El primer step, el del paso 1, no necesita checkout: corre antes y sigue siendo útil como prueba
de vida de la base.

**Verifica**:

```bash
actionlint .github/workflows/service-lab.yml; echo "exit $?"
# exit 0
yq '.jobs.integration.env.DATABASE_URL' .github/workflows/service-lab.yml
# postgresql://tablero:cambiame@localhost:5432/tablero_ci
yq '.jobs.integration.steps[].run // "" | select(. != "")' .github/workflows/service-lab.yml | grep -c 'uv run --no-sync'
# 2
```

---

## Paso 4: Los logs de la base si algo falla, y un fallo a propósito

**Por qué**: cuando falla un step contra la base, el error de tu código dice *que* no pudo
conectar; el *porqué* lo dice PostgreSQL en su log. El step con `if: failure()` solo corre si uno
anterior falló, así que un run verde no gana ni una línea (teoría 07). Al final de todo job con
services, *Stop containers* también imprime el log de cada contenedor, pero lejos del fallo y sin
el estado del healthcheck; tu step lo pone justo debajo del step roto.

Para verlo trabajar, lo rompes: una contraseña equivocada en `DATABASE_URL`. La base arranca sana
(el healthcheck no usa contraseña), pero las migraciones no entran.

**Comando**: añade el step al final y cambia `cambiame` por `mal` **solo** en `DATABASE_URL`.

```yaml
      - name: Logs de PostgreSQL si algo falla
        if: failure()
        env:
          POSTGRES_CONTAINER: ${{ job.services.postgres.id }}
        run: |
          docker inspect --format '{{json .State.Health}}' "$POSTGRES_CONTAINER"
          docker logs "$POSTGRES_CONTAINER"
```

```bash
sed -i 's|tablero:cambiame@localhost|tablero:mal@localhost|' .github/workflows/service-lab.yml
actionlint .github/workflows/service-lab.yml; echo "exit $?"
# exit 0
git add .github/workflows/service-lab.yml
git commit -m "ci(lab): add service-lab with a wrong password on purpose"
git push
gh workflow run service-lab.yml
sleep 5   # el run tarda unos segundos en aparecer en la lista
id=$(gh run list --workflow service-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status; echo "exit $?"
# ... X Migraciones
# exit 1
gh run view "$id" --log-failed | grep -E 'OperationalError|FATAL' | cut -c1-160
# ... psycopg.OperationalError: connection failed: ... FATAL:  password authentication failed for user "tablero"
gh run view "$id" --log | grep 'Logs de PostgreSQL' | grep -E 'FATAL|DETAIL' | cut -c1-160
# ... FATAL:  password authentication failed for user "tablero"
# ... DETAIL:  Connection matched file "/var/lib/postgresql/data/pg_hba.conf" line 128: "host all all all scram-sha-256"
```

Las dos primeras líneas son el error de psycopg en el step `Migraciones`; las dos últimas, el lado
de PostgreSQL, que además dice qué regla de `pg_hba.conf` rechazó la conexión. Tests de
integración no aparece en el log: un step tras un fallo se salta, salvo que lleve `if:`.

Ahora deshazlo:

```bash
sed -i 's|tablero:mal@localhost|tablero:cambiame@localhost|' .github/workflows/service-lab.yml
```

**Verifica**:

```bash
gh run view "$id" --json conclusion --jq .conclusion
# failure
grep -c 'tablero:mal@' .github/workflows/service-lab.yml
# 0
yq '.jobs.integration.steps[-1].if' .github/workflows/service-lab.yml
# failure()
```

---

## Paso 5: En verde y lanzado a mano

**Por qué**: con la contraseña buena, el run tiene que terminar en `success`: el step de logs se
salta y el resumen de pytest dice `3 passed`. `gh workflow run` solo lanza workflows que ya están
en la rama por defecto, y `service-lab.yml` no escucha `push`, así que subirlo no lanza nada: el
único run es el que pides tú. La comprobación `service-lab-dispatched` busca exactamente eso: un
run `workflow_dispatch` en `success`.

**Comando**:

```bash
git add .github/workflows/service-lab.yml
git commit -m "ci(lab): fix service-lab database password"
git push
gh workflow run service-lab.yml
sleep 5
id=$(gh run list --workflow service-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status; echo "exit $?"
# ... ✓ Tests de integración
# exit 0
gh run view "$id" --log | grep -E 'PostgreSQL 17|aplicada|passed' | cut -c1-120
# ... PostgreSQL 17.11 on x86_64-pc-linux-musl, ...
# ... aplicada 001_tasks.sql
# ... 3 passed in ...
```

**Verifica**:

```bash
gh run list --workflow service-lab.yml --event workflow_dispatch --status success \
  --json databaseId --jq length
# 1
```

Pide al menos uno.

---

## ✅ Resultado

- [ ] `service-lab.yml` está en `main` y solo se lanza a mano
- [ ] El service usa `postgres:17.11-alpine`, publica `5432:5432` y tiene healthcheck con `pg_isready`
- [ ] Sabes qué falla sin healthcheck y por qué falla solo a veces
- [ ] `DATABASE_URL` apunta a `localhost:5432` porque los steps corren en el runner
- [ ] Las migraciones van antes de `pytest tests/integration`
- [ ] Has visto `password authentication failed` en el log de PostgreSQL gracias a `if: failure()`
- [ ] Un run de `service-lab.yml` lanzado a mano terminó en `success`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 05
```

Ya pasa `service-lab-dispatched`.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `gh workflow run` dice `could not find any workflows named service-lab.yml` | El archivo no está en `main` | `git ls-tree --name-only origin/main .github/workflows/` tiene que listarlo |
| *Initialize containers* falla con `unhealthy` | El `-U`/`-d` de `--health-cmd` no coinciden con `POSTGRES_USER`/`POSTGRES_DB` | Paso 2; reprodúcelo en local con la orden de la práctica 01 |
| `docker exec` dice `requires at least 2 arguments` | `POSTGRES_CONTAINER` llegó vacío: la clave de `services:` no se llama `postgres` | La expresión es `job.services.<clave>.id` |
| `connection refused` en `Migraciones` | Falta `ports: - 5432:5432`, o la URL dice otro puerto | Paso 1: sin publicar, el runner no ve el puerto |
| `password authentication failed` sin haberlo provocado | Quedó el `mal` del paso 4 | `grep -n '@localhost' .github/workflows/service-lab.yml` |
| `relation "tasks" does not exist` | Los tests van antes que las migraciones | Paso 3: el orden de los steps |
| `1 skipped` y exit 5 en `Tests de integración` | `DATABASE_URL` no está en el `env` del job (o está en el del service) | Paso 3: va en `jobs.integration.env` |
| El run falla con `startup_failure` | Tienes `sha_pinning_required` activo y una `uses:` va por tag | `scripts/resolve-sha.sh` (Semana 01, práctica 04, paso 3) |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Docker y Compose en local](01-docker-y-compose-en-local.md) | [Job en contenedor frente a runner](03-job-en-contenedor-frente-a-runner.md) |
