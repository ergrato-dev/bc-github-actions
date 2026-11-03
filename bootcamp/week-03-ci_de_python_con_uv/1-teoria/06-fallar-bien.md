# Fallar bien

> Un CI que nunca falla no sirve, y uno que falla sin decir por qué tampoco. Esta teoría va de que
> cada fallo llegue pronto, diga qué y dónde, y no se esconda.

## 🎯 Objetivos

- Repartir las comprobaciones de Python en jobs que fallen por separado y en paralelo
- Ordenar los steps para que lo barato falle antes que lo caro
- Hacer que cada herramienta diga qué falló y en qué línea
- Leer los códigos de salida de uv, ruff y pytest
- Reconocer las formas de esconder un fallo y cuándo sí tiene sentido seguir después de uno

## 1. Qué problema resuelve

Imagina un único job que ejecuta, uno detrás de otro, `uv sync`, `ruff check`, `ruff format
--check` y `pytest`. Te olvidas un import sin usar: `ruff check` falla y los steps siguientes no
corren (el `success()` implícito de la Semana 02). Lo arreglas, haces push, esperas, y ahora falla
el formato. Lo arreglas, haces push, esperas, y falla un test. Tres vueltas para tres errores que
estaban ahí desde el principio.

El problema contrario es igual de malo: un CI que siempre sale verde porque alguien añadió `|| true`
para "desbloquear" un día y nadie lo quitó. Ese verde no demuestra nada.

Fallar bien es encontrar el equilibrio:

- **Pronto**: lo que tarda segundos va antes que lo que tarda minutos.
- **Completo**: un push te enseña todos los problemas independientes, no solo el primero.
- **Claro**: el mensaje dice qué regla, qué archivo y qué línea.
- **Honesto**: si algo falla, el job es rojo.

## 2. Cómo funciona

### Un código de salida decide el color

Un step de `run:` falla si el último comando del script sale con un código distinto de 0. El shell
del step es `bash -e` y, con `shell: bash` explícito, además `-o pipefail` (Semana 02): cualquier
comando que falle corta el script, también dentro de una tubería. Cada herramienta tiene su
contrato:

| Herramienta | 0 | 1 | Otros |
|---|---|---|---|
| `uv sync --locked` | Entorno igual al lockfile | El lockfile no coincide con `pyproject.toml`, o falla la resolución | — |
| `ruff check` | Sin infracciones | Hay infracciones | 2: configuración o argumentos inválidos |
| `ruff format --check` | Todo formateado | Algún archivo se reformatearía | 2: error de ruff |
| `pytest` | Todos los tests pasan | Algún test falla, o no se alcanza `--cov-fail-under` | 2: interrumpido; 3: error interno; 4: error de uso (argumentos); 5: no se recogió ningún test |

El 5 de pytest merece atención: un `pytest tests/unitarios` con la carpeta mal escrita no "pasa con
cero tests", falla. Es justo lo que quieres.

### Jobs separados frente a steps seguidos

Dos jobs sin `needs:` corren a la vez en máquinas distintas, y el fallo de uno no detiene al otro.
Si el lint y los tests van en jobs separados, un push te devuelve los dos resultados a la vez:

| Organización | Un import sobrante y un test roto | Tiempo hasta saberlo todo |
|---|---|---|
| Un job: sync → check → format → pytest | Ves el import. El test, en el siguiente push | Dos runs |
| Dos jobs en paralelo: lint y test | Ves los dos en el mismo run | Un run |

El precio es repetir la preparación (checkout, `setup-uv`, `uv sync`) en cada job. Con la caché de
la teoría anterior son unos segundos, y lo que compras es una respuesta completa en cada push.

### Dentro de un job, lo barato primero

Dentro de un mismo job sí conviene que el primer fallo corte. `uv sync --locked` va antes que todo:
si el lockfile no coincide, nada de lo que venga después se ejecuta con las dependencias correctas.
El mensaje es exacto:

```text
error: The lockfile at `uv.lock` needs to be updated, but `--locked` was provided.

hint: To update the lockfile, run `uv lock`.
```

## 3. Cómo se usa

### Que el fallo diga dónde

`ruff check --output-format=github` imprime cada infracción en el formato de anotaciones de GitHub
Actions. La UI las recoge y las pinta en el resumen del run y, en un pull request, junto a la línea
del diff, con la regla (`F401`, `E401`...) y su explicación. Cómo funcionan las anotaciones por
dentro lo verás en la Semana 08; aquí te basta con que la herramienta las genere.

`ruff format --check` no corrige nada: dice qué archivos se reformatearían y enseña el diff. En
local, `uv run ruff format .` lo arregla.

Para la cobertura, `--cov-report=term-missing` añade la columna de líneas sin cubrir:

```text
Name                      Stmts   Miss  Cover   Missing
-------------------------------------------------------
src/tablero/db.py            21      7    67%   23, 26, 31, 37, 43, 48-49
src/tablero/migrate.py       19     19     0%   6-34
...
TOTAL                        79     30    62%
FAIL Required test coverage of 99% not reached. Total coverage: 62.03%
6 passed in 0.32s
```

Lee la última línea con cuidado: **los seis tests pasan y aun así el step sale con 1**. Lo que falla
es el umbral. Un mensaje que solo diga `exit code 1` haría pensar que se rompió un test.

### Seguir después de un fallo, cuando tiene sentido

A veces dos comprobaciones van en el mismo job y son independientes: si `ruff check` falla, sigue
interesándote saber si el formato también está mal. Con `if: ${{ !cancelled() }}` un step corre
aunque el anterior haya fallado, y el job sigue terminando en rojo:

```yaml
name: py-quality

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  quality:
    runs-on: ubuntu-24.04
    defaults:
      run:
        shell: bash
        working-directory: api
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
        with:
          version: "0.13.6"
          enable-cache: true
          cache-dependency-glob: api/uv.lock
      # Sin entorno no tiene sentido nada más: aquí el primer fallo sí corta.
      - id: sync
        run: uv sync --locked
      - name: Reglas de ruff
        run: uv run --no-sync ruff check --output-format=github .
      # Independiente de las reglas: que se vea también en el mismo run.
      - name: Formato
        if: ${{ !cancelled() && steps.sync.outcome != 'failure' }}
        run: uv run --no-sync ruff format --check .
```

El `if:` del último step combina dos cosas: no correr si cancelas el run, y no correr si falló la
instalación (el step con `id: sync`), porque sin `.venv` el error de formato sería ruido.

Nunca uses `always()` para esto: un step con `always()` corre también cuando cancelas, y un run
cancelado debería pararse cuanto antes.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `pytest ... \|\| true` | El job sale verde con tests rotos: el CI deja de significar algo | Que el comando falle; si un test es inestable, arréglalo o márcalo y explícalo |
| `continue-on-error: true` en un step de calidad | El step se ve rojo pero el job, y el check del PR, verde | Solo para pasos opcionales (un informe que no bloquea), con un comentario de por qué |
| Lint, formato y tests en un solo job sin `if:` | Cada push te enseña solo el primer problema | Jobs separados, o `if: ${{ !cancelled() }}` en los steps independientes |
| `ruff check --fix` o `ruff format` sin `--check` en CI | El CI corrige en su copia, sale verde y el código del repo sigue igual | En CI solo se comprueba; se corrige en local |
| `pytest tests/` sin distinguir unidad e integración | Los tests que necesitan PostgreSQL fallan o se saltan en silencio | `pytest tests/unit` aquí; la integración llega con su base en la Semana 05 |
| `if: always()` en un step de limpieza o de diagnóstico | Corre también al cancelar el run, que debería pararse ya | `if: ${{ !cancelled() }}` o `if: failure()` |
| `ruff check --exit-zero` | La versión "oficial" de `\|\| true`: ruff informa y siempre sale con 0 | Sin ese flag; si una regla no aplica, desactívala en `pyproject.toml` con un comentario |
| Silenciar la salida (`> /dev/null`) | El fallo llega sin contexto y hay que reproducirlo en local | Deja la salida; si es enorme, usa el modo silencioso de la herramienta (`pytest -q`) |

## 5. Trucos

- **`gh run view <id> --log-failed`** (Semana 01) imprime solo los steps rojos. Con dos jobs, ves el
  error de ruff y el de pytest uno debajo de otro.
- **`pytest -q`** reduce la salida a un punto por test y deja visibles solo los fallos y el resumen.
  Con `-x` para en el primer fallo: útil en local, nunca en CI, donde quieres verlos todos.
- **Un fallo, un step**: si cada herramienta va en su propio step con `name:`, la lista de steps del
  job ya te dice qué falló sin abrir el log. Un único `run:` con cuatro comandos solo dice
  `exit code 1`.
- **`uv lock --check`** comprueba el lockfile sin instalar nada: es lo mismo que hará
  `uv sync --locked` en CI, en un segundo y antes del push.

_Verificado con uv 0.13.6, ruff 0.17.3, pytest 9.2.0, pytest-cov 7.1.0 y ubuntu-24.04, noviembre de
2026._

## 📚 Recursos Adicionales

- [Exit codes de pytest](https://docs.pytest.org/en/stable/reference/exit-codes.html)
- [ruff: exit codes y formatos de salida](https://docs.astral.sh/ruff/linter/#exit-codes)
- [pytest-cov: opciones de informe y `--cov-fail-under`](https://pytest-cov.readthedocs.io/en/latest/config.html)
- [Workflow syntax: `jobs.<job_id>.steps[*].continue-on-error`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepscontinue-on-error)

## ✅ Checklist de Verificación

- [ ] Sé qué significan los códigos 0, 1, 2 y 5 de pytest, y el 1 de `--cov-fail-under`
- [ ] Mi lint y mis tests fallan por separado: un push me enseña los dos problemas
- [ ] `uv sync --locked` va antes que cualquier comprobación
- [ ] Ningún step de calidad lleva `|| true` ni `continue-on-error`
- [ ] Sé cuándo usar `if: ${{ !cancelled() }}` y por qué no `always()`

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Caché de dependencias](05-cache-de-dependencias.md) | [Antipatrones de Python en CI](07-antipatrones-de-python-en-ci.md) |
