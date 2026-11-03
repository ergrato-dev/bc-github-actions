# La API de tablero

> Antes de escribir el CI de un proyecto tienes que saber qué hay dentro y qué puede romperse.
> Este archivo recorre `api/` carpeta por carpeta y termina con la lista de lo que su CI tiene que
> comprobar.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Describir qué hace cada archivo de `api/` y qué parte de él toca el CI
- Leer `pyproject.toml` y saber qué dependencias son de la app y cuáles solo del desarrollo
- Distinguir los tests unitarios de los de integración de `tablero` y saber por qué unos corren
  esta semana y otros en la Semana 05
- Hacer la lista de comprobaciones que un CI de esta API necesita, y en qué orden

## 1. Qué problema resuelve

Un CI que no entiende el proyecto acaba siendo una copia de otro: ejecuta `pytest` sin saber qué
tests hay, se salta en silencio los que necesitan una base de datos o instala dependencias que la
app no usa. Pasa en verde y no demuestra nada.

`tablero` es pequeño a propósito: una tabla, cinco endpoints y nueve tests. Todo cabe en la cabeza,
así que puedes razonar sobre cada decisión del pipeline en lugar de copiarla.

## 2. Cómo funciona

### Lo que hay en `api/`

| Ruta | Qué es | Lo usa el CI |
|---|---|:--:|
| `pyproject.toml` | Metadatos, dependencias, configuración de ruff y pytest | Sí |
| `uv.lock` | Versión exacta y hash de las 31 paquetes resueltos (el propio `tablero` incluido) | Sí |
| `.python-version` | `3.15`: la versión de Python del proyecto | Sí |
| `src/tablero/` | El código: `main.py`, `db.py`, `migrate.py`, `settings.py` | Sí |
| `tests/unit/` | Tests sin base de datos | Sí, esta semana |
| `tests/integration/` | Tests contra PostgreSQL | Semana 05 |
| `migrations/001_tasks.sql` | El esquema de la tabla `tasks` | Semana 05 |
| `Dockerfile` | La imagen de la API | Semana 06 |

### `pyproject.toml`: dos grupos de dependencias

```toml
[project]
name = "tablero"
version = "1.0.0"
requires-python = ">=3.15"
dependencies = [
    "fastapi>=0.162.0",
    "uvicorn>=0.54.0",
    "psycopg[binary]>=3.3.6",
]

[dependency-groups]
dev = [
    "ruff>=0.17.3",
    "pytest>=9.2.0",
    "pytest-cov>=7.1.0",
    "httpx2>=2.16.0",
]
```

- `dependencies` es lo que la app necesita para arrancar en producción: FastAPI, el servidor
  uvicorn y psycopg para hablar con PostgreSQL.
- `dev` es lo que necesitas para comprobarla: ruff, pytest, la cobertura y `httpx2`, que es el
  cliente HTTP que usa el `TestClient` de FastAPI.

`uv sync` instala los dos por defecto. La imagen de la Semana 06 usa `uv sync --no-dev` y deja
fuera el segundo. Los rangos (`>=0.162.0`) dicen qué versiones acepta el proyecto; la versión
exacta que se instala la fija `uv.lock`, que verás en el archivo siguiente.

El `project.version` de aquí es el mismo que tu job `version` de la Semana 02 lee con
`yq -oy '.project.version' api/pyproject.toml`.

### El código: cuatro módulos

- **`main.py`** define la app de FastAPI y cinco endpoints: `GET /api/health` (sin base de datos),
  y `GET`, `POST`, `PATCH` y `DELETE` sobre `/api/tasks`. Valida el título con Pydantic: entre 1 y
  200 caracteres.
- **`db.py`** define `TaskRepository`, un `Protocol` con cuatro métodos, y `PostgresTasks`, que los
  implementa con SQL directo. `get_tasks()` es la dependencia de FastAPI que abre una conexión por
  petición.
- **`settings.py`** lee `DATABASE_URL` y `APP_VERSION` del entorno. Si falta `DATABASE_URL`, lanza
  un error claro en lugar de usar un valor por defecto.
- **`migrate.py`** aplica en orden los `.sql` de `migrations/` que aún no se aplicaron.

### Los tests unitarios: la API sin PostgreSQL

`tests/unit/test_api.py` sustituye el repositorio real por uno en memoria:

```python
class FakeTasks:
    def __init__(self) -> None:
        self.rows: dict[int, Task] = {}
        self.next_id = 1
    # ... list, create, set_done y delete sobre un diccionario


@pytest.fixture
def client():
    fake = FakeTasks()
    app.dependency_overrides[get_tasks] = lambda: fake
    yield TestClient(app)
    app.dependency_overrides.clear()
```

`dependency_overrides` es el mecanismo de FastAPI para cambiar una dependencia en los tests: cada
endpoint que pide `get_tasks` recibe `FakeTasks` y nunca abre una conexión. Por eso estos seis
tests:

- comprueban el contrato HTTP (códigos 201, 204, 404 y 422, el recorte de espacios del título,
  la versión de `/api/health`);
- no comprueban el SQL de `PostgresTasks` ni las migraciones;
- corren en menos de un segundo y sin nada más que Python.

### Los tests de integración: la API contra PostgreSQL

`tests/integration/test_postgres.py` empieza así:

```python
pytestmark = pytest.mark.integration

if not os.environ.get("DATABASE_URL"):
    pytest.skip("necesita DATABASE_URL apuntando a PostgreSQL", allow_module_level=True)
```

Sin `DATABASE_URL`, el módulo entero se salta. Con ella, aplica las migraciones, vacía la tabla
antes de cada test y comprueba lo que los unitarios no pueden: que las migraciones son
idempotentes, que una tarea hace el viaje completo por la base y que el `CHECK` de la tabla
rechaza un título vacío aunque alguien se salte la API.

Esta semana el CI no tiene PostgreSQL, así que esos tres tests salen como `skipped`. En la Semana
05 un service container les da una base real.

## 3. Cómo se usa

En local, con lo que verás en las prácticas:

```bash
cd ~/code/tablero/api
uv sync --locked
uv run --no-sync pytest -q -rs
# ......                                                                   [100%]
# =========================== short test summary info ============================
# SKIPPED [1] tests/integration/test_postgres.py:15: necesita DATABASE_URL apuntando a PostgreSQL
# 6 passed, 1 skipped in 0.26s
```

El `1 skipped` es el módulo de integración entero. `-rs` es lo que te enseña el motivo: sin él solo
ves el número.

### Lo que el CI de la API tiene que comprobar

De barato a caro, para fallar lo antes posible:

| Comprobación | Herramienta | Qué rompe si falta |
|---|---|---|
| El lockfile casa con `pyproject.toml` | `uv sync --locked` | Instalas versiones que nadie revisó |
| El código respeta las reglas de estilo y no tiene errores obvios | `ruff check` | Imports sin usar, argumentos mutables por defecto, sintaxis antigua |
| El formato es el acordado | `ruff format --check` | Diffs llenos de cambios de espacios |
| El contrato HTTP funciona | `pytest tests/unit` | Un endpoint que devuelve 200 donde debía dar 404 |
| Los tests recorren suficiente código | `--cov-fail-under` | Código nuevo sin ningún test |
| El SQL y las migraciones funcionan | `pytest tests/integration` | Semana 05 |

Cada fila tiene su archivo esta semana: `uv` en el 02, ruff en el 03 y pytest con la cobertura en
el 04.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `pytest` a secas en CI, sin mirar los `skipped` | Los tests de integración se saltan y el verde parece completo | Lanza `tests/unit` explícitamente y deja la integración para su job (Semana 05) |
| Instalar solo `dependencies` en el CI de tests | Faltan pytest y ruff: el job falla o los instala por otra vía | `uv sync --locked` instala `dev` por defecto |
| Un `DATABASE_URL` falso para que "pasen" los de integración | Los tests fallan al conectar o, peor, alguien los marca para ignorarlos | Sin base, sin `DATABASE_URL`: el `skip` es el comportamiento correcto |
| Leer la versión de la app con `grep` sobre `pyproject.toml` | Se rompe con un cambio de formato | `yq -oy '.project.version'` o `importlib.metadata.version` |
| Probar los endpoints contra el PostgreSQL de tu máquina | El test depende de un estado que el CI no tiene | `dependency_overrides` para unitarios; base efímera para integración |

## 5. Trucos

- **`pytest --collect-only -q`** lista los tests que pytest va a ejecutar sin ejecutarlos. Si
  cambias `testpaths` o mueves un archivo, te dice en un segundo si sigue encontrándolos.
- **`pytest -rs`** imprime el motivo de cada test saltado. Es la forma más rápida de saber si un
  `skipped` es esperado o es un test de integración que debería haber corrido.
- **`uv tree --depth 1`** enseña qué dependencias directas tiene el proyecto y qué versión fijó el
  lockfile para cada una, sin abrir `uv.lock`.

## 📚 Recursos Adicionales

- [FastAPI: Testing Dependencies with Overrides](https://fastapi.tiangolo.com/advanced/testing-dependencies/)
- [pytest: How to use skip and xfail](https://docs.pytest.org/en/stable/how-to/skipping.html)
- [uv: Managing dependencies](https://docs.astral.sh/uv/concepts/projects/dependencies/)
- [`app/README.md`](../../../app/README.md): cómo arrancar `tablero` entero en local

## ✅ Checklist de Verificación

- [ ] Sé qué dependencias son de la app y cuáles del grupo `dev`
- [ ] Sé qué comprueban los tests unitarios y qué se quedan sin comprobar
- [ ] Sé por qué los tests de integración salen `skipped` sin `DATABASE_URL`
- [ ] Puedo ordenar de barato a caro lo que el CI de la API tiene que comprobar
- [ ] He ejecutado `uv run --no-sync pytest -q -rs` y he visto el motivo del `skipped`

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Semana 03](../README.md) | [uv en CI](02-uv-en-ci.md) |
