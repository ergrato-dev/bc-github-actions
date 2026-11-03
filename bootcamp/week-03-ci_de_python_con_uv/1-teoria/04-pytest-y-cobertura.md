# pytest y cobertura

> Que los tests pasen solo dice algo si sabes qué tests corrieron y qué parte del código
> recorrieron. pytest te da lo primero, pytest-cov lo segundo, y `--cov-fail-under` convierte la
> cobertura en una regla que el CI hace cumplir.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar cómo encuentra pytest los tests de `tablero` y qué hace un marker como `integration`
- Leer los códigos de salida de pytest y saber cuáles convierten un job en rojo
- Medir la cobertura con pytest-cov y leer el informe `term-missing`
- Fijar un umbral con `--cov-fail-under` y justificar el valor
- Decir qué no mide la cobertura

## 1. Qué problema resuelve

Un job que ejecuta `pytest` y sale en verde puede significar tres cosas: que todo funciona, que no
encontró ningún test, o que encontró muy pocos para lo que hay. Las dos últimas parecen iguales a
la primera en la lista de checks del pull request.

pytest distingue el segundo caso con su código de salida. La cobertura distingue el tercero: dice
qué líneas del código se ejecutaron al menos una vez durante los tests. Y un umbral en CI impide
que alguien añada un módulo entero sin ningún test sin que el pipeline se entere.

## 2. Cómo funciona

### Cómo encuentra pytest los tests

`api/pyproject.toml` lo dice:

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
markers = ["integration: necesita PostgreSQL en DATABASE_URL"]
```

- `testpaths` limita la búsqueda a `tests/` cuando ejecutas `pytest` sin rutas. Si le pasas una
  (`pytest tests/unit`), busca solo ahí.
- Dentro, pytest recoge archivos `test_*.py` y, en ellos, funciones `test_*`.
- `markers` registra el marker `integration`. Los tests de `tests/integration/` lo llevan todos
  con `pytestmark = pytest.mark.integration`, y puedes filtrarlos con `-m`:
  `pytest -m "not integration"`. Sin registrarlo, pytest avisa de un marker desconocido.

En `tablero` la separación es doble: por carpeta y por marker. En CI esta semana se usa la carpeta,
`tests/unit`, porque dice explícitamente qué corre. El marker queda para filtrar en local.

### Los códigos de salida

| Código | Qué significa | Job |
|:--:|---|:--:|
| 0 | Todos los tests recogidos pasaron | Verde |
| 1 | Algún test falló | Rojo |
| 2 | Lo interrumpiste o hubo un error al usar pytest | Rojo |
| 5 | **No se recogió ningún test** | Rojo |

El 5 es tu red contra el job que no prueba nada: si alguien renombra `tests/unit` o cambia
`testpaths`, el CI no pasa en verde con cero tests. Comprobado con `pytest tests/unit -k nada`:
sale con 5.

Los tests saltados (`skipped`) no cambian el código: `6 passed, 1 skipped` es un 0. Por eso un
`skip` tiene que ser intencionado y visible (`-rs`), como el del módulo de integración.

### pytest-cov: qué líneas se ejecutaron

pytest-cov conecta pytest con coverage.py. `--cov=tablero` mide el paquete `tablero` mientras
corren los tests; `--cov-report=term-missing` imprime la tabla con las líneas que nunca se
ejecutaron:

```text
$ uv run --no-sync pytest tests/unit --cov=tablero --cov-report=term-missing --cov-fail-under=60
...
Name                      Stmts   Miss  Cover   Missing
-------------------------------------------------------
src/tablero/__init__.py       0      0   100%
src/tablero/db.py            21      7    67%   23, 26, 31, 37, 43, 48-49
src/tablero/main.py          30      0   100%
src/tablero/migrate.py       19     19     0%   6-34
src/tablero/settings.py      9      4    56%   8-11
-------------------------------------------------------
TOTAL                        79     30    62%
Required test coverage of 60% reached. Total coverage: 62.03%
============================== 6 passed in 0.27s ===============================
```

La columna `Missing` cuenta la historia de los tests unitarios:

- `main.py` al 100 %: cada endpoint se ejecutó.
- `db.py` al 67 %: las líneas de `PostgresTasks` y `get_tasks()` nunca corren, porque
  `dependency_overrides` las sustituye por `FakeTasks`.
- `migrate.py` al 0 %: ningún test unitario aplica migraciones.
- `settings.py` al 56 %: `database_url()` no se llama sin base.

### `--cov-fail-under`: el umbral

Con `--cov-fail-under=60`, pytest sale con 1 si la cobertura total baja del 60 %, aunque todos los
tests pasen. Lo comprobé subiendo el umbral a 70:

```text
FAIL Required test coverage of 70% not reached. Total coverage: 62.03%
6 passed in 0.32s
```

`echo $?` da `1`: el job se pone rojo con los seis tests en verde.

**Por qué 60 y no 80.** Con solo los tests unitarios, `tablero` llega al 62 % (medido arriba): todo
lo que no está cubierto es código de base de datos. Un umbral por encima de lo que la suite actual
puede alcanzar obligaría a escribir tests que no prueban nada o a bajarlo en el primer pull
request. 60 deja dos puntos de margen y falla en cuanto alguien añade código sin tests.

En la Semana 05, con PostgreSQL en el CI, unitarios e integración juntos cubren el 96 % y el
umbral sube. El número no es un objetivo: es una red para que la cobertura no baje.

### Lo que la cobertura no mide

- **Que las aserciones sean correctas.** Una línea ejecutada por un test sin ningún `assert` cuenta
  igual que una comprobada.
- **Las ramas.** Por defecto mide líneas. Un `if` del que solo se ejecutó un camino cuenta como
  cubierto. `--cov-branch` añade las ramas: en `tablero` baja la cifra del 62 % al 57 %.
- **El código que no está en `--cov=tablero`**: los tests y las dependencias quedan fuera, que es
  lo correcto.
- **Lo que no es Python**: el SQL de `migrations/` solo lo comprueban los tests de integración.

## 3. Cómo se usa

En local, para ver qué te falta:

```bash
cd ~/code/tablero/api
uv run --no-sync pytest tests/unit --cov=tablero --cov-report=term-missing
uv run --no-sync pytest -m "not integration" -q   # lo mismo, filtrando por marker
```

En CI, la cobertura también puede ir al resumen del run. pytest-cov sabe escribir la tabla en
markdown y añadirla a un archivo, y `$GITHUB_STEP_SUMMARY` es un archivo (Semana 02):

```yaml
name: coverage-report

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  coverage:
    name: Cobertura de la API
    runs-on: ubuntu-24.04
    defaults:
      run:
        working-directory: api
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
        with:
          version: "0.13.6"
      - run: uv sync --locked
      - name: Tests unitarios con la tabla de cobertura en el resumen
        run: >-
          uv run --no-sync pytest tests/unit -q
          --cov=tablero
          --cov-report=term-missing
          --cov-report="markdown-append:$GITHUB_STEP_SUMMARY"
          --cov-fail-under=60
```

`>-` es un bloque plegado de YAML: junta las líneas en una sola separadas por espacios y quita el
salto final, así el comando largo se lee por partes. Los dos `--cov-report` conviven: uno para el log, otro para la página del run.

Verificado con pytest 9.2.0, pytest-cov 7.1.0, astral-sh/setup-uv@v10.3.3 y ubuntu-24.04,
noviembre de 2026.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `pytest || true` para que el job "no moleste" | Los tests dejan de proteger nada | Si un test es inestable, arréglalo o márcalo con un motivo |
| Umbral del 100 % o muy por encima de lo que hay | Tests sin aserciones para llegar al número | Lo que la suite alcanza hoy, con un poco de margen |
| Cobertura sin umbral | Un número que se mira una vez y se olvida | `--cov-fail-under` en CI |
| Medir con `--cov=.` | Los tests se cuentan a sí mismos y la cifra sube sola | `--cov=tablero`: solo el paquete |
| `pytest` sin ruta y con integración que se salta en silencio | El verde parece incluir la base de datos | `tests/unit` explícito y `-rs` cuando quieras ver los saltos |
| Subir la cobertura con tests que no comprueban nada | La cifra miente | Revisar aserciones en el PR, no solo el porcentaje |

## 5. Trucos

- **`--cov-report=markdown-append:$GITHUB_STEP_SUMMARY`** pone la tabla de cobertura en la página
  del run sin escribir ningún script.
- **`--cov-report=term-missing:skip-covered`** esconde los archivos al 100 % y deja solo los que
  tienen líneas sin cubrir: en un proyecto grande es la única tabla que se lee.
- **`pytest --lf`** vuelve a ejecutar solo los tests que fallaron la última vez. En local, después
  de un rojo del CI, es el camino más corto hasta el verde.
- **`pytest -x`** para en el primer fallo: útil en local, nunca en CI, donde quieres ver todos.

## 📚 Recursos Adicionales

- [pytest: Working with custom markers](https://docs.pytest.org/en/stable/example/markers.html)
- [pytest: Exit codes](https://docs.pytest.org/en/stable/reference/exit-codes.html)
- [pytest-cov: Reporting](https://pytest-cov.readthedocs.io/en/latest/reporting.html)
- [coverage.py: Branch coverage measurement](https://coverage.readthedocs.io/en/latest/branch.html)

## ✅ Checklist de Verificación

- [ ] Sé dónde busca pytest los tests de `tablero` y cómo filtrar por el marker `integration`
- [ ] Sé qué significa que pytest salga con 5
- [ ] Puedo leer la columna `Missing` y explicar por qué `migrate.py` está al 0 %
- [ ] Sé por qué el umbral es 60 esta semana y por qué subirá en la Semana 05
- [ ] Sé dos cosas que la cobertura no mide

---

| ← Anterior | Siguiente → |
|:---|---:|
| [ruff: lint y formato](03-ruff.md) | [Caché de dependencias](05-cache-de-dependencias.md) |
