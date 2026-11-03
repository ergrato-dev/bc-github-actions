# Tests de integración

> Los tests unitarios de `tablero` usan un repositorio en memoria: son rápidos y no saben nada de
> SQL. Los de integración hablan con PostgreSQL de verdad. Los dos hacen falta, en jobs distintos,
> y hay que vigilar que los segundos se ejecuten de verdad y no "pasen" saltándose.

![Niveles de prueba en el pipeline: unit, integración con PostgreSQL y smoke con Compose](../0-assets/03-niveles-de-prueba-en-el-pipeline.svg)

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Distinguir test unitario, de integración y smoke, y qué fallo detecta cada uno en `tablero`
- Leer `tests/integration/test_postgres.py` y explicar cómo aísla un test de otro
- Detectar el falso verde de unos tests saltados con `pytest -rs`
- Separar unitarios e integración en dos jobs encadenados con `needs:`

## 1. Qué problema resuelve

`tests/unit/test_api.py` sustituye la base por `FakeTasks`, un diccionario en memoria. Eso hace
que los tests corran en milisegundos y sin Docker, pero deja fuera todo lo que hace PostgreSQL:
el SQL de `PostgresTasks`, los ids que genera `GENERATED ALWAYS AS IDENTITY`, el `CHECK` que
limita el título a 1-200 caracteres. Un `UPDATE` mal escrito pasa en verde en unit y revienta en
producción.

Los tests de integración cubren ese hueco. Su coste es que necesitan una base, y una base que no
esté se puede confundir con una base que funciona.

## 2. Cómo funciona

### Tres niveles en `tablero`

| Nivel | Dónde | Qué ejecuta | Qué detecta | Coste |
|---|---|---|---|---|
| Unitario | `tests/unit/` | La API con `FakeTasks` | Lógica de la API, validación de Pydantic, códigos HTTP | Milisegundos, sin servicios |
| Integración | `tests/integration/` | La API y `migrate` contra PostgreSQL 17 | SQL, restricciones, migraciones, tipos | Segundos más el arranque del service |
| Smoke | `scripts/smoke-test.sh` | La pila entera con Compose, a través de nginx | Imágenes, red entre servicios, proxy, healthchecks | Un par de minutos de build |

Es la pirámide de pruebas aplicada: muchos unitarios abajo porque son baratos, menos de
integración en medio y un smoke arriba que solo comprueba que todo junto responde. Cada nivel
detecta lo que el de abajo no puede ver, y ninguno sustituye al de abajo: un smoke no te dice qué
validación falla.

### Cómo se aísla `test_postgres.py`

Abre [`app/api/tests/integration/test_postgres.py`](../../../app/api/tests/integration/test_postgres.py).
Tiene cuatro piezas antes de los tests:

```python
pytestmark = pytest.mark.integration

if not os.environ.get("DATABASE_URL"):
    pytest.skip("necesita DATABASE_URL apuntando a PostgreSQL", allow_module_level=True)

@pytest.fixture(scope="module", autouse=True)
def schema():
    migrate()

@pytest.fixture(autouse=True)
def empty_table():
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        conn.execute("TRUNCATE tasks RESTART IDENTITY")
```

- **`pytestmark`**: marca todos los tests del módulo como `integration` (la marca está declarada
  en `pyproject.toml`). Sirve para seleccionarlos con `-m integration`.
- **El `skip` de módulo**: sin `DATABASE_URL` el archivo entero se salta. Es lo que permite
  ejecutar `pytest` en tu portátil sin Docker; también es el origen del falso verde.
- **`schema`**, una vez por módulo: aplica las migraciones. Como `migrate` es idempotente, da
  igual que el step del workflow ya las haya aplicado.
- **`empty_table`**, antes de **cada** test: `TRUNCATE ... RESTART IDENTITY` vacía la tabla y
  reinicia el contador de ids. Por eso `test_task_roundtrip` puede afirmar `task["id"] == 1`: no
  depende de qué test corrió antes.

Y los tres tests prueban justo lo que unit no puede:

| Test | Qué comprueba |
|---|---|
| `test_migrations_are_idempotent` | Una segunda migración no aplica nada |
| `test_task_roundtrip` | Crear, marcar, listar y borrar a través de la API, persistido en PostgreSQL |
| `test_database_enforces_title_length` | El `CHECK` del esquema rechaza un título vacío con `CheckViolation` |

### El falso verde

Un test saltado no es un test fallido. Si el job no tiene `DATABASE_URL` (un `env:` en el job
equivocado, una errata en el nombre), `pytest` salta el módulo y el resto de la suite sigue. Con
la suite entera:

```bash
uv run --no-sync pytest -rs
# SKIPPED [1] tests/integration/test_postgres.py:15: necesita DATABASE_URL apuntando a PostgreSQL
# ========================= 6 passed, 1 skipped in 0.22s =========================
echo $?
# 0
```

Código 0: el job sale en verde y nadie ha probado nada contra PostgreSQL. Si ejecutas **solo**
`tests/integration` sin la variable, `pytest` no encuentra ningún test que ejecutar y sale con
código 5, así que el job falla; pero basta con que el `skip` pase a ser por test, o con que
alguien junte los directorios en un `pytest` sin argumentos, para volver al 0.

Dos defensas, y caben las dos:

- **`-rs`** añade al final el resumen de tests saltados con su motivo. Un `SKIPPED` en el log de
  un job que se llama "integración" es una alarma que se ve.
- **Comprobar el número**: el job de integración espera ver `3 passed`. Un cambio de ese número
  sin un cambio en los tests merece una pregunta en la revisión.

Con la base levantada y `DATABASE_URL` puesta:

```bash
uv run --no-sync pytest tests/integration -rs
# ============================== 3 passed in 0.31s ===============================
```

### Por qué dos jobs y `needs`

Podrías correr unit e integración en el mismo job con el service. Separarlos da tres cosas:

- **Fallo rápido y barato**: si la lógica ya falla sin base, `needs: unit` evita gastar el
  arranque de PostgreSQL. El job de integración aparece como saltado, no como fallido.
- **Un log que dice qué nivel falló**: el nombre del job ya te dice si es lógica o es SQL.
- **El service solo donde hace falta**: el job unitario no espera a ningún healthcheck.

## 3. Cómo se usa

```yaml
name: api-tests

on:
  pull_request:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

defaults:
  run:
    working-directory: api

jobs:
  unit:
    name: Unitarios
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
        with:
          version: "0.13.6"
          enable-cache: true
          cache-dependency-glob: api/uv.lock
      - run: uv sync --locked
      - run: uv run --no-sync pytest tests/unit -rs

  db-tests:
    name: Contra PostgreSQL
    needs: unit
    runs-on: ubuntu-24.04
    services:
      pg:
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
    env:
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
      - run: uv sync --locked
      - run: uv run --no-sync python -m tablero.migrate
      - run: uv run --no-sync pytest tests/integration -rs
```

`DATABASE_URL` va en el `env:` del job, no del step: la leen el step de migraciones y el de
`pytest`, y una sola definición no puede quedar distinta en los dos.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `pytest` sin `-rs` en el job de integración | Un `SKIPPED` del módulo entero no se ve | `pytest tests/integration -rs` |
| Unit e integración en un solo `pytest` sin base | `6 passed, 1 skipped` y código 0: falso verde | Jobs separados y `DATABASE_URL` en el de integración |
| Tests que dependen del orden | El id 1 deja de serlo según qué corrió antes | `TRUNCATE ... RESTART IDENTITY` por test |
| Mockear la base en "integración" | Vuelves a no probar el SQL | PostgreSQL de verdad como service |
| Integración sin `needs` | Arranca PostgreSQL aunque la lógica ya falle | `needs:` al job unitario |
| Smoke en lugar de integración | Sabes que algo falla, no qué | Los tres niveles, cada uno en su sitio |

## 5. Trucos

- **`pytest -m integration`** selecciona por la marca, no por la carpeta: útil si un día hay tests
  de integración repartidos.
- **`pytest -rs` también en local** te recuerda que sin `DATABASE_URL` no has probado la base.
- **`pytest --co -q tests/integration`** lista lo que pytest va a ejecutar sin ejecutarlo: si dice
  `no tests collected`, el `skip` de módulo ha saltado.

Verificado con pytest 9.2.0, `postgres:17.11-alpine` y ubuntu-24.04, noviembre de 2026.

## 📚 Recursos Adicionales

- [pytest: Skip and xfail](https://docs.pytest.org/en/stable/how-to/skipping.html)
- [pytest: Exit codes](https://docs.pytest.org/en/stable/reference/exit-codes.html)
- [Workflow syntax: `jobs.<job_id>.needs`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idneeds)
- [Martin Fowler: The Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)

## ✅ Checklist de Verificación

- [ ] Sé qué detecta cada nivel de prueba en `tablero` y qué no
- [ ] Sé cómo `test_postgres.py` aísla cada test
- [ ] Sé por qué un test saltado puede dejar el job en verde
- [ ] Ejecuto los tests de integración con `-rs`
- [ ] Separo unitarios e integración con `needs:` y sé qué ganas con ello
- [ ] `DATABASE_URL` está en el `env:` del job de integración

---

| ← Anterior | Siguiente → |
|:---|---:|
| [PostgreSQL 17 en CI](04-postgresql-17-en-ci.md) | [Compose en CI](06-compose-en-ci.md) |
