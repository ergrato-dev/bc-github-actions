# PostgreSQL 17 en CI

> Un service de PostgreSQL bien hecho tiene cuatro piezas: una imagen con parche, tres variables,
> un healthcheck que pregunta lo correcto y un step de migraciones antes de los tests. Si falta
> cualquiera, el job falla de forma confusa o, peor, pasa sin probar nada.

![Arranque con healthcheck: el primer step espera a healthy; sin healthcheck llega antes](../0-assets/02-arranque-con-healthcheck.svg)

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Elegir la imagen de PostgreSQL y configurarla con `POSTGRES_USER`, `POSTGRES_PASSWORD` y
  `POSTGRES_DB`
- Explicar por qué `cambiame` no es un secreto y cuándo dejaría de valer
- Escribir un healthcheck con `pg_isready` y elegir `interval`, `timeout` y `retries`
- Distinguir una base sana de una base migrada, y migrar con `tablero.migrate`
- Construir la `DATABASE_URL` correcta para un job en el runner

## 1. Qué problema resuelve

La teoría 03 te dio un contenedor junto al job. Ahora tiene que ser **la** base de `tablero`: la
versión que usa producción, con un usuario y una base conocidos, lista antes del primer test y
con el esquema creado. Cada uno de esos puntos tiene una trampa:

- La versión: un tag que se mueve cambia la base sin commit (teoría 01).
- El arranque: sin healthcheck, el primer step llega a una base que aún no escucha.
- El esquema: con healthcheck, la base acepta conexiones, pero la tabla `tasks` no existe.

## 2. Cómo funciona

### La imagen

`postgres:17.11-alpine`, la fila de PostgreSQL en
[`docs/stack-versions.md`](../../../docs/stack-versions.md). Es la misma que usa
`app/compose.yaml`: el CI prueba contra lo que levantas en local. El runner `ubuntu-24.04` trae
un PostgreSQL 16 instalado y parado; no lo uses: es otra versión mayor y no la controla tu repo.

### Las variables `POSTGRES_*`

La imagen oficial las lee **solo la primera vez**, cuando el directorio de datos está vacío. En
un service siempre lo está, así que siempre se aplican.

| Variable | Qué hace | Si falta |
|---|---|---|
| `POSTGRES_PASSWORD` | Contraseña del superusuario | El contenedor se niega a arrancar |
| `POSTGRES_USER` | Nombre del superusuario | `postgres` |
| `POSTGRES_DB` | Base que se crea al iniciar | Una con el nombre de `POSTGRES_USER` |

En `tablero` el usuario es `tablero` y la base de los tests, `tablero_test`: un nombre distinto
del de local deja claro en cualquier log contra qué base se corrió.

### `cambiame`, una credencial desechable

La regla 7 dice que las credenciales de CI desechables valen `cambiame` y se dice. Esta lo es por
tres razones: el contenedor solo existe mientras dura el job, no publica nada fuera de la máquina
virtual y no guarda datos de nadie. Por eso va escrita en el YAML con un comentario, no en
`secrets`. Meterla en un secreto no la protege más y hace creer que protege algo.

Deja de ser desechable en cuanto la base sobrevive al job o es alcanzable desde fuera: un
PostgreSQL compartido o una base de staging. Ahí sí es un secreto (Semana 13).

### El healthcheck con `pg_isready`

`pg_isready` es el cliente que pregunta "¿aceptas conexiones?" y sale con 0 (sí), 1 (rechaza,
por ejemplo arrancando), 2 (sin respuesta) o 3 (parámetros inválidos). Viene en la imagen, así
que el chequeo corre **dentro** del contenedor.

```yaml
options: >-
  --health-cmd "pg_isready -U tablero -d tablero_test"
  --health-interval 5s
  --health-timeout 5s
  --health-retries 10
```

- **`-U` y `-d`**: el chequeo corre como `root`. Sin `-U`, `pg_isready` se presenta como un rol
  `root` que no existe y el log de PostgreSQL se llena de `FATAL: role "root" does not exist` cada
  `interval`. El contenedor sigue sano, pero cuando busques el error de verdad en `docker logs`
  estará enterrado entre esas líneas.
- **`interval: 5s`**: cada cuánto pregunta. Más bajo da `healthy` antes; más alto ensucia menos.
- **`timeout: 5s`**: un chequeo que tarda más cuenta como fallo.
- **`retries: 10`**: diez fallos seguidos lo marcan `unhealthy`. Con `interval` de 5 s son unos
  50 s de margen, de sobra para PostgreSQL, que en el runner arranca en pocos segundos.

### `healthy` no es `migrado`

`pg_isready` dice que el servidor acepta conexiones. No sabe nada de tus tablas. Si los tests
empiezan ahí, el primer `INSERT` falla con `relation "tasks" does not exist`. El esquema lo crea
un step aparte, antes de los tests.

En `tablero` ese step es [`tablero.migrate`](../../../app/api/src/tablero/migrate.py):

1. Se conecta con `DATABASE_URL`.
2. Crea, si no existe, la tabla `schema_migrations`, que guarda qué migraciones ya se aplicaron.
3. Recorre `api/migrations/*.sql` en orden de nombre (`001_tasks.sql`, `002_...`) y aplica las
   que no estén en `schema_migrations`, imprimiendo `aplicada <archivo>` por cada una.

Es **idempotente**: la segunda ejecución no aplica nada y no imprime nada. Es lo que permite
llamarlo en CI, en local y al arrancar el contenedor de la API (lo hace su `Dockerfile`) sin
miedo a duplicar tablas.

Se ejecuta con `uv run --no-sync python -m tablero.migrate`: `--no-sync` porque el step anterior
ya hizo `uv sync --locked` y no quieres que `uv run` vuelva a resolver nada.

### `DATABASE_URL`

`tablero` lee la conexión de una sola variable, con el formato
`postgresql://usuario:contraseña@host:puerto/base`. Si falta, la API y `migrate` fallan con
`Falta DATABASE_URL`. Para un job en el runner con el puerto publicado:

```
postgresql://tablero:cambiame@localhost:5432/tablero_test
```

El host es `localhost` porque el job corre en la máquina virtual (teoría 03). La API dentro de
Compose usa `@db:5432` porque está en la red de Docker. Misma base, otro camino.

## 3. Cómo se usa

Un workflow que solo comprueba el esquema: migra dos veces y exige que la segunda no aplique nada.

```yaml
name: schema-check

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  schema:
    name: Migraciones sobre PostgreSQL 17
    runs-on: ubuntu-24.04
    defaults:
      run:
        working-directory: api
    services:
      pg:
        image: postgres:17.11-alpine
        env:
          POSTGRES_USER: tablero
          # Credencial desechable: no es un secreto, vive lo que dura el job.
          POSTGRES_PASSWORD: cambiame
          POSTGRES_DB: tablero_ci
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U tablero -d tablero_ci"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10
    env:
      # El job corre en el runner: llega al servicio por el puerto publicado en localhost.
      DATABASE_URL: postgresql://tablero:cambiame@localhost:5432/tablero_ci
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
        with:
          version: "0.13.6"
          enable-cache: true
          cache-dependency-glob: api/uv.lock
      - name: Dependencias exactas del lockfile
        run: uv sync --locked
      - name: Migrar
        run: uv run --no-sync python -m tablero.migrate
      - name: Migrar otra vez (no debe aplicar nada)
        run: |
          out=$(uv run --no-sync python -m tablero.migrate)
          test -z "$out"
```

Lo mismo en local, contra el PostgreSQL de la teoría 01 en el puerto 5433:

```bash
cd api
export DATABASE_URL=postgresql://tablero:cambiame@127.0.0.1:5433/tablero
uv run --no-sync python -m tablero.migrate
# aplicada 001_tasks.sql
uv run --no-sync python -m tablero.migrate
# (nada: ya estaba aplicada)
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `postgres:latest` en el service | El CI cambia de versión mayor sin commit | `postgres:17.11-alpine` |
| Usar el PostgreSQL 16 que trae el runner | Otra mayor; no la fija tu repo | El service con la imagen de `stack-versions.md` |
| `POSTGRES_PASSWORD` en `secrets` | No protege nada y sugiere que es sensible | `cambiame` con comentario de desechable |
| `--health-cmd pg_isready` sin `-U` | Log lleno de `role "root" does not exist` que tapa el error real | `pg_isready -U <usuario> -d <base>` |
| Tests justo después del healthcheck | `relation "tasks" does not exist` | Step de migraciones antes |
| Crear las tablas desde los tests | Lo que prueba CI no es lo que despliegas | La misma herramienta de migraciones que producción |
| `uv run` sin `--no-sync` tras `uv sync --locked` | Puede volver a resolver y ocultar un lockfile desfasado | `uv run --no-sync` |

## 5. Trucos

- **`psql` ya está en el runner**: con `PGPASSWORD` por `env:`, `psql -h localhost -U tablero -d
  tablero_test -c '\dt'` te enseña en el log qué tablas creó la migración.
- **Una base por propósito**: `POSTGRES_DB` distinto en cada workflow (`tablero_test`,
  `tablero_ci`) hace evidente en cualquier traza contra qué base corrió.
- **`select * from schema_migrations`** dice qué migraciones ve la base, con fecha.

Verificado con `postgres:17.11-alpine`, astral-sh/setup-uv@v10.3.3 y ubuntu-24.04, noviembre de
2026.

## 📚 Recursos Adicionales

- [Imagen oficial `postgres`: variables de entorno](https://hub.docker.com/_/postgres)
- [`pg_isready`](https://www.postgresql.org/docs/17/app-pg-isready.html)
- [Creating PostgreSQL service containers](https://docs.github.com/en/actions/tutorials/use-containerized-services/create-postgresql-service-containers)
- [Connection URIs de libpq](https://www.postgresql.org/docs/17/libpq-connect.html#LIBPQ-CONNSTRING-URIS)

## ✅ Checklist de Verificación

- [ ] Uso la imagen de PostgreSQL de `docs/stack-versions.md`, con parche
- [ ] Sé qué hace cada variable `POSTGRES_*` y qué pasa si falta
- [ ] Sé por qué `cambiame` no es un secreto y cuándo lo sería
- [ ] Mi healthcheck lleva `-U` y `-d`, y sé qué margen dan `interval` y `retries`
- [ ] Migro antes de los tests y sé por qué `migrate` es idempotente
- [ ] Sé escribir la `DATABASE_URL` de un job en el runner

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Service containers](03-service-containers.md) | [Tests de integración](05-tests-de-integracion.md) |
