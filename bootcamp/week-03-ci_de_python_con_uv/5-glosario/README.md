# 📖 Glosario — Semana 03

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **Acierto de caché** (*cache hit*): una ejecución encuentra una caché cuya clave coincide
  exactamente con la que busca y la restaura. setup-uv lo expone en su output `cache-hit`.
- **Anotación** (*annotation*): aviso que el runner pinta en el resumen del run y, en un pull
  request, junto a la línea del diff. ruff las genera con `--output-format=github`.

## C

- **Caché** (*cache*): archivos que una ejecución guarda en GitHub para que otras los restauren y no
  tengan que descargarlos o construirlos de nuevo. Nunca es la fuente de verdad: si falta, el job
  tiene que funcionar igual, solo más lento.
- **Caché de uv**: el directorio donde uv guarda paquetes descargados y construidos. Es lo que
  setup-uv guarda entre ejecuciones con `enable-cache: true`, no el `.venv`.
- **`cache-dependency-glob`**: input de setup-uv con los archivos cuyo hash forma parte de la clave
  de la caché. En `tablero` es `api/uv.lock`.
- **Clave de caché** (*cache key*): cadena que identifica una caché. Se suele construir con el
  sistema operativo y `hashFiles()` del lockfile, para que cambie cuando cambian las dependencias.
- **Cobertura** (*coverage*): porcentaje de líneas del código que se ejecutan durante los tests. La
  mide coverage.py y la presenta pytest-cov.

## D

- **Dependency override**: mecanismo de FastAPI (`app.dependency_overrides`) para sustituir una
  dependencia en los tests. Los tests unitarios de `tablero` lo usan para no necesitar PostgreSQL.

## E

- **Entorno virtual** (*virtual environment*, `.venv`): directorio con un intérprete de Python y los
  paquetes del proyecto, aislado del sistema. uv lo crea y lo rellena con `uv sync`; no se comitea
  ni se cachea.
- **Expulsión** (*eviction*): borrado automático de cachés. GitHub expulsa las que llevan 7 días sin
  usarse y las más antiguas cuando el repo pasa de 10 GB.

## F

- **Fallo de caché** (*cache miss*): no hay ninguna caché con la clave buscada. El job descarga
  todo y, al terminar, guarda una caché nueva con esa clave.
- **Fixture**: en pytest, función que prepara algo que un test necesita (un cliente HTTP, una
  conexión) y que el test recibe como argumento.
- **Formateador** (*formatter*): herramienta que reescribe el código con un estilo fijo. En CI se
  ejecuta en modo comprobación (`ruff format --check`) para fallar si alguien no formateó.
- **`--frozen`**: opción de `uv sync` y `uv run` que instala lo que dice `uv.lock` sin comprobar si
  corresponde a `pyproject.toml`. No es la que va en CI.

## H

- **`hashFiles()`**: función de expresión que devuelve el SHA-256 de los archivos que casan con un
  patrón. Se usa para construir claves de caché con `actions/cache`.

## L

- **Linter**: herramienta que analiza el código sin ejecutarlo y avisa de errores probables o
  estilo prohibido. En `tablero` es `ruff check`.
- **`--locked`**: opción de `uv sync` que falla si `uv.lock` no está al día con `pyproject.toml`.
  Es la que va en CI.
- **Lockfile**: archivo con el resultado exacto de resolver las dependencias: versión y hash de cada
  paquete, directo o transitivo. En `tablero`, `api/uv.lock` y `web/pnpm-lock.yaml`.

## M

- **Marker**: etiqueta de pytest para clasificar tests (`@pytest.mark.integration`). Con `-m` se
  seleccionan o excluyen.

## N

- **`--no-sync`**: opción de `uv run` que ejecuta el comando en el entorno tal como está, sin volver
  a resolver ni sincronizar. Va detrás de un `uv sync --locked`.

## P

- **Poda de la caché** (*cache pruning*): `uv cache prune --ci` quita de la caché lo que se
  descarga casi tan rápido como se restaura y conserva lo compilado. setup-uv la hace antes de
  guardar.
- **pytest**: el framework de tests de Python que usa `tablero`. Descubre los tests en `tests/` y
  los ejecuta con `uv run --no-sync pytest`.
- **pytest-cov**: plugin de pytest que mide la cobertura y añade `--cov`, `--cov-report` y
  `--cov-fail-under`.
- **Python gestionado** (*managed Python*): versión de Python que uv descarga e instala por su
  cuenta, sin depender del Python del sistema ni de `setup-python`.
- **`.python-version`**: archivo con la versión de Python del proyecto (`3.15` en `api/`). uv lo
  lee para elegir o descargar el intérprete.

## R

- **Regla** (*rule*): cada comprobación de ruff, con un código como `F401` (import sin usar) o
  `E501` (línea demasiado larga). Se activan por familias en `[tool.ruff.lint]`.
- **`restore-keys`**: input de `actions/cache` con prefijos de clave alternativos. Si no hay acierto
  exacto, restaura la caché más reciente que empiece por uno de ellos.
- **ruff**: linter y formateador de Python de Astral. Un solo binario sustituye a varias
  herramientas clásicas.

## S

- **setup-uv** (`astral-sh/setup-uv`): action que instala una versión fijada de uv en el runner y
  gestiona su caché.

## U

- **Umbral de cobertura** (*fail-under*): cobertura mínima por debajo de la cual pytest-cov hace
  fallar la ejecución (`--cov-fail-under=60`).
- **uv**: gestor de proyectos y paquetes de Python de Astral. En este bootcamp es la única forma de
  instalar Python y dependencias.
- **`uv.lock`**: lockfile de uv. Universal: resuelve para todas las plataformas a la vez. Se
  comitea y se actualiza con `uv lock`.
- **`uv lock --check`**: comprueba sin escribir nada que `uv.lock` está al día con
  `pyproject.toml`.
- **`uv run`**: ejecuta un comando dentro del entorno del proyecto. Sin `--no-sync`, sincroniza
  antes.
- **`uv sync`**: deja `.venv` exactamente como dice el lockfile: instala lo que falta y quita lo que
  sobra.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Semana 04 — CI de frontend con pnpm, matrices y artefactos](../../week-04-ci_de_frontend_pnpm_matrices_y_artefactos/README.md) |
