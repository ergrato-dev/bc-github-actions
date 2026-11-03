# Antipatrones de Python en CI

> Casi todo lo que encuentras en internet sobre "CI de Python" se escribió antes de que existieran
> los lockfiles de uv. Esta teoría reúne lo que vas a ver copiado en otros repos, por qué falla y
> cómo se escribe en `tablero`.

## 🎯 Objetivos

- Reconocer los patrones heredados de Python en CI y el problema concreto de cada uno
- Reescribir cada uno con uv, el lockfile y `setup-uv`
- Saber qué hace de verdad `uv run` si no le dices nada y por qué en CI importa
- Revisar un workflow de Python ajeno y encontrar en él lo que no es reproducible

## 1. Qué problema resuelve

Un CI de Python tiene que responder a una pregunta: **¿este commit funciona con exactamente estas
dependencias?** Para eso hacen falta tres cosas fijas:

1. La versión de Python.
2. La versión de cada dependencia, también las transitivas.
3. La versión de las herramientas que instalan y comprueban (uv, ruff, pytest).

La mayoría de los antipatrones de esta teoría rompen una de las tres en silencio. El síntoma es
siempre el mismo: un día el CI se pone rojo sin que nadie haya tocado el código, o, peor, sale verde
con una combinación de versiones que no es la que corre en producción.

## 2. Cómo funciona

En `tablero` las tres cosas viven en el repo y uv las aplica:

| Qué se fija | Dónde | Quién lo aplica |
|---|---|---|
| Python 3.15 | `api/.python-version` y `requires-python` en `pyproject.toml` | `uv sync`, que descarga ese Python si el runner no lo tiene |
| Cada dependencia, con hash | `api/uv.lock` | `uv sync --locked`, que además comprueba que el lock coincide con `pyproject.toml` |
| uv | `version:` en `astral-sh/setup-uv` | La action |
| ruff, pytest, pytest-cov | Grupo `dev` de `pyproject.toml`, fijado en `uv.lock` | `uv sync` las instala; `uv run --no-sync` las ejecuta |

El runner `ubuntu-24.04` trae su propio Python (3.12, el de la imagen). `tablero` no lo usa: pide
3.15 y uv instala uno gestionado. No hace falta `actions/setup-python`.

### Lo que hace `uv run` si no le dices nada

`uv run` no solo ejecuta: antes **bloquea y sincroniza** el proyecto. Si `pyproject.toml` cambió y
`uv.lock` no, `uv run` resuelve de nuevo y **reescribe `uv.lock`** en la máquina del CI. Se comprobó
con un `pyproject.toml` al que se le añadió una dependencia: el hash de `uv.lock` cambió tras un
simple `uv run python -c 'print(1)'`. El CI sale verde con un lockfile que nadie ha revisado ni
comiteado.

Por eso en CI la pareja es siempre:

```bash
uv sync --locked          # falla si uv.lock no coincide con pyproject.toml
uv run --no-sync pytest   # ejecuta en el entorno ya creado, sin tocar nada
```

`--frozen` también evita la reescritura, pero instala lo que diga el lock **sin comprobar** que
coincide con `pyproject.toml`. En CI quieres la comprobación: `--locked`.

## 3. Cómo se usa

Cada antipatrón, con lo que hace mal y su reescritura. Los fragmentos malos llevan la marca
`antipatron` para que `scripts/check-repo.sh` no los confunda con material vigente.

### Instalar con pip desde un archivo de requisitos

```yaml
- run: pip install -r requirements.txt  # antipatron
```

Un `requirements.txt` sin hashes ni versiones transitivas fijadas instala lo último que PyPI tenga ese día. <!-- antipatron -->
Además usa el Python del sistema y no comprueba nada. Reescritura:

```yaml
- run: uv sync --locked
```

### `actions/setup-python` + pip + caché de pip

```yaml
- uses: actions/setup-python@v5  # antipatron
  with:
    python-version: "3.x"
    cache: pip  # antipatron
- run: pip install -e ".[dev]"  # antipatron
```

Tres problemas: la action va por tag, `3.x` es "la última que haya", y la instalación no se ata a
ningún lockfile. Reescritura: `astral-sh/setup-uv` por SHA con `version:` y `enable-cache: true`, y
`uv sync --locked`. Python sale de `.python-version`.

### Crear el entorno a mano

```yaml
- run: python -m venv .venv && . .venv/bin/activate  # antipatron
```

`uv sync` crea `.venv` solo, con el Python correcto. Activarlo tampoco hace falta: `uv run --no-sync`
ejecuta dentro del entorno. Y cada `run:` es un shell nuevo: un `activate` en un step no sirve en el
siguiente.

### `uv pip install` en un proyecto con lockfile <!-- antipatron -->

```yaml
- run: uv pip install fastapi pytest ruff  # antipatron
```

Es la interfaz compatible con pip de uv: rápida, pero ignora `uv.lock`. Resuelve otra vez y puede
instalar versiones distintas de las de tu máquina. En un proyecto con `pyproject.toml` y `uv.lock`,
la orden es `uv sync --locked`.

### `uv sync` o `uv run` sin `--locked`

```yaml
- run: uv sync  # antipatron
- run: uv run pytest  # antipatron
```

Los dos pueden reescribir `uv.lock` dentro del runner (sección 2). El CI prueba un lock que no está en
el repo. Reescritura: `uv sync --locked` y `uv run --no-sync`.

### Cachear `.venv`

Restaurar el entorno entero parece más rápido, pero `.venv` tiene rutas absolutas al intérprete y se
salta `uv sync --locked`, que es la comprobación. Se cachea la caché de uv (teoría 05).

### uv sin versión fijada

```yaml
- uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
  # sin version: instala la última uv publicada ese día
```

La action está fijada por SHA, pero la herramienta no. Un cambio de comportamiento de uv entra en tu
CI sin commit. Reescritura: `version: "0.13.6"`, la de `docs/stack-versions.md`.

### Herramientas con `uvx` sin versión

```yaml
- run: uvx ruff check .  # antipatron
```

`uvx` descarga la herramienta en un entorno aparte, en la versión más reciente, que puede no ser la
del lockfile. Si la herramienta es del proyecto (ruff, pytest), va en el grupo `dev` y se ejecuta con
`uv run --no-sync`. Si es externa, con versión: `uvx zizmor@1.31.1`.

### Corregir en CI

```yaml
- run: uv run --no-sync ruff check --fix .  # antipatron
- run: uv run --no-sync ruff format .  # antipatron
```

El runner corrige su copia, que se destruye al terminar. El job sale verde y el código del repo sigue
mal. En CI solo se comprueba: `ruff check` y `ruff format --check`.

### Tests que dependen de internet

Un test que llama a una API pública o a una base de datos compartida falla cuando esa API está caída
o cuando otro run cambió los datos. Los tests de `tests/unit` sustituyen el repositorio por un doble
en memoria; los de integración van contra un PostgreSQL desechable que el propio job levanta
(Semana 05).

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `pip install -r requirements.txt` | Versiones del día, sin hashes, con el Python del sistema | `uv sync --locked` <!-- antipatron --> |
| `actions/setup-python` + `cache: pip` | Action por tag, Python sin fijar, instalación sin lockfile | `setup-uv` por SHA con `version:` y `enable-cache` <!-- antipatron --> |
| `python -m venv` y `activate` | uv ya crea el entorno; cada `run:` es un shell nuevo | `uv sync --locked` y `uv run --no-sync` <!-- antipatron --> |
| `uv pip install paquete` en un proyecto con lock | Ignora `uv.lock` y resuelve de nuevo | `uv sync --locked` <!-- antipatron --> |
| `uv sync` o `uv run` sin flags | Pueden reescribir `uv.lock` en el runner | `uv sync --locked` y `uv run --no-sync` |
| `uv sync --frozen` en CI | No comprueba que el lock coincida con `pyproject.toml` | `--locked` en CI; `--frozen` solo si otro paso ya comprobó el lock |
| Cachear `.venv` | Rutas absolutas y sin comprobación del lock | Cachear la caché de uv |
| `setup-uv` sin `version:` | La herramienta cambia sin commit | `version: "0.13.6"` |
| `uvx herramienta` sin versión | Versión distinta de la del lockfile | `uv run --no-sync` para las del proyecto; `uvx herramienta@X.Y.Z` para las externas |
| `ruff check --fix` en CI | Corrige una copia que se destruye | `ruff check` y `ruff format --check` |
| Python del sistema del runner | Cambia con la imagen y no es la versión del proyecto | `.python-version`; uv lo instala |
| `pytest` contra servicios de internet | Fallos que no dependen de tu código | Dobles en `tests/unit`; base desechable en la Semana 05 |

## 5. Trucos

- **`uv lock --check`** en local antes del push te dice lo mismo que dirá `uv sync --locked` en el
  CI, sin instalar nada.
- **Para revisar un workflow ajeno**, busca de una vez los patrones de esta teoría:
  `grep -nE 'pip[0-9]* +install|setup-python|uv (sync|run)( |$)' .github/workflows/*.yml`.
  Cada coincidencia es una pregunta: ¿qué fija esto?
- **`uv tree --locked`** imprime el árbol de dependencias tal como está en el lock: es la respuesta
  a "¿qué versión de pydantic usa el CI?" sin abrir `uv.lock`.

_Verificado con uv 0.13.6, astral-sh/setup-uv@v10.3.3 y ubuntu-24.04, noviembre de 2026._

## 📚 Recursos Adicionales

- [uv: locking and syncing](https://docs.astral.sh/uv/concepts/projects/sync/) — qué hacen
  `--locked`, `--frozen` y el bloqueo automático de `uv run`
- [uv: Using uv in GitHub Actions](https://docs.astral.sh/uv/guides/integration/github/) — la guía
  oficial, con la recomendación de fijar la versión de uv
- [uv: Python versions](https://docs.astral.sh/uv/concepts/python-versions/) — cómo elige e
  instala Python a partir de `.python-version`

## ✅ Checklist de Verificación

- [ ] Ningún workflow mío instala con pip ni crea entornos a mano
- [ ] Instalo siempre con `uv sync --locked` y ejecuto con `uv run --no-sync`
- [ ] Sé por qué `uv run` sin flags puede cambiar `uv.lock` en el runner
- [ ] Sé la diferencia entre `--locked` y `--frozen`
- [ ] Mi `setup-uv` fija la versión de uv y la action va por SHA
- [ ] En CI solo compruebo con ruff; corrijo en local

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Fallar bien](06-fallar-bien.md) | [uv en local](../2-practicas/01-uv-en-local.md) |
