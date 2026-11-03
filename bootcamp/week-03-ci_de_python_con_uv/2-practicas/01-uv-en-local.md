# Práctica 01 — uv en local

> Antes de pedirle a un runner que instale la API, compruébalo en tu máquina. Esta práctica
> ejecuta en local los mismos comandos que correrá el CI, rompe el lockfile a propósito y te
> enseña por qué el CI usa `--locked` y no otra cosa.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- uv 0.13.6 instalado y el entorno de `api/` creado desde `uv.lock`
- Ruff y pytest ejecutados en local con la misma orden que usará el CI
- Ver con tus ojos qué pasa cuando `pyproject.toml` y `uv.lock` no coinciden
- Saber elegir entre `uv sync --locked`, `uv sync --frozen` y `uv sync` a secas

## 📋 Antes de empezar

Tienes `check-week.sh 02` en verde y tu clon de `<tu-org>/tablero` en `~/code/tablero`, con la
rama `main` al día:

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
```

Todo lo de esta práctica pasa en `~/code/tablero/api`. No subes nada a GitHub hasta la práctica 02.

---

## Paso 1: Comprobar que tienes uv 0.13.6

**Por qué**: el CI va a fijar la versión exacta de uv (práctica 02). Si en tu máquina tienes otra,
puedes ver resultados distintos de los del runner: un error que solo sale en CI, o un lockfile
que tu uv reescribe con otro formato. La versión del bootcamp está en
[`docs/stack-versions.md`](../../../docs/stack-versions.md) y se instala con checksum siguiendo
[`docs/setup-entorno.md`](../../../docs/setup-entorno.md), apartado 4.

**Comando**:

```bash
uv --version
```

Si sale otra versión o `command not found`, instálala con el apartado 4 de `setup-entorno.md`:
descarga del release, comprobación del digest e `install` en `~/.local/bin`.

**Verifica**:

```bash
uv --version
# uv 0.13.6 (x86_64-unknown-linux-gnu)
command -v uv
# /home/<tu-usuario>/.local/bin/uv
```

---

## Paso 2: Crear el entorno desde el lockfile

**Por qué**: `uv sync --locked` hace tres cosas en una orden. Lee `.python-version` y, si no tienes
ese Python, lo descarga. Crea `.venv/` dentro de `api/`. E instala en él **exactamente** lo que dice
`uv.lock`, con los hashes que el lockfile guarda. No necesitas el Python de tu distro, ni crear un
entorno virtual a mano, ni activar nada: uv lo hace todo y lo deja en `.venv/`, que ya está en
`.gitignore`.

**Comando**:

```bash
cd ~/code/tablero/api
cat .python-version
uv sync --locked
```

La primera vez ves la lista de paquetes instalados:

```
# Using CPython 3.15.2
# Creating virtual environment at: .venv
# Resolved 31 packages in ...
# ...
#  + pytest-cov==7.1.0
#  + ruff==0.17.3
#  + starlette==1.10.0
#  + tablero==1.0.0 (from file:///home/<tu-usuario>/code/tablero/api)
#  ...
#  + uvicorn==0.54.0
```

Fíjate en `tablero==1.0.0 (from file://...)`: el propio proyecto se instala en el entorno, así que
`import tablero` funciona en los tests sin tocar `PYTHONPATH`.

**Verifica**:

```bash
cat .python-version
# 3.15
ls -d .venv
# .venv
uv python list --only-installed | grep 3.15
# cpython-3.15.2-linux-x86_64-gnu     /home/<tu-usuario>/.local/share/uv/python/cpython-3.15-linux-x86_64-gnu/bin/python3.15
uv run --no-sync python -c 'import sys; print(sys.version)'
# 3.15.2 (main, Oct 26 2026, 14:06:56) [Clang 23.1.3 ]
```

Ese Python no es el de tu sistema: lo ha descargado uv y lo guarda en `~/.local/share/uv/python/`.

---

## Paso 3: Lint, formato y tests como los correrá el CI

**Por qué**: `uv run --no-sync` ejecuta el comando dentro de `.venv/` **sin** volver a sincronizar.
En CI eso importa: el step anterior ya hizo `uv sync --locked`, y si `uv run` sincronizara otra vez
podría tocar el entorno que acabas de comprobar. Son tres comandos distintos porque comprueban tres
cosas distintas: errores de código (`ruff check`), estilo (`ruff format --check`) y comportamiento
(`pytest`).

**Comando**:

```bash
uv run --no-sync ruff check .
uv run --no-sync ruff format --check .
uv run --no-sync pytest tests/unit --cov=tablero --cov-report=term-missing
```

Salida de los tres:

```
# All checks passed!
# 7 files already formatted
# ...
# Name                      Stmts   Miss  Cover   Missing
# -------------------------------------------------------
# src/tablero/__init__.py       0      0   100%
# src/tablero/db.py            21      7    67%   23, 26, 31, 37, 43, 48-49
# src/tablero/main.py          30      0   100%
# src/tablero/migrate.py       19     19     0%   6-34
# src/tablero/settings.py       9      4    56%   8-11
# -------------------------------------------------------
# TOTAL                        79     30    62%
# ============================== 6 passed in 0.75s ===============================
```

pytest-cov deja el archivo de datos `.coverage` en `api/`. No lo comitees: si `git status` lo
muestra, bórralo con `rm -f .coverage`.

El 62 % no es un descuido: `migrate.py` y casi todo `db.py` hablan con PostgreSQL, y eso lo prueban
los tests de `tests/integration/`, que necesitan una base de datos (Semana 05). Por eso el umbral
de esta semana es 60 %: lo que dan los tests unitarios, con un margen pequeño.

**Verifica**:

```bash
uv run --no-sync ruff check . && uv run --no-sync ruff format --check . && echo "lint OK"
# All checks passed!
# 7 files already formatted
# lint OK
uv run --no-sync pytest tests/unit -q --cov=tablero --cov-fail-under=60 | tail -2
# Required test coverage of 60% reached. Total coverage: 62.03%
# 6 passed in 0.30s
```

---

## Paso 4: Desincronizar el lockfile a propósito

**Por qué**: el fallo más típico de un CI de Python no es un test roto. Es que alguien cambia una
dependencia en `pyproject.toml` y se olvida de `uv lock`. El lockfile se queda describiendo un
proyecto que ya no existe. `--locked` está para eso: si `uv.lock` no coincide con `pyproject.toml`,
uv se niega a seguir en lugar de arreglarlo en silencio.

**Comando**: baja la cota mínima de `uvicorn` sin regenerar el lockfile.

```bash
sed -i 's/"uvicorn>=0.54.0"/"uvicorn>=0.53.0"/' pyproject.toml
git diff --stat
#  api/pyproject.toml | 2 +-
#  1 file changed, 1 insertion(+), 1 deletion(-)
uv sync --locked
# Resolved 31 packages in 9ms
# error: The lockfile at `uv.lock` needs to be updated, but `--locked` was provided.
#
# hint: To update the lockfile, run `uv lock`.
echo $?
# 1
```

`uv lock --check` hace la misma comprobación sin instalar nada. Es la orden que usa
`check-week.sh` para saber si tu lockfile está al día:

```bash
uv lock --check
# Resolved 31 packages in 9ms
# error: The lockfile at `uv.lock` needs to be updated, but `--check` was provided.
#
# hint: To update the lockfile, run `uv lock`.
```

Ahora deshaz el cambio. No hay nada que guardar: `pyproject.toml` vuelve a la versión de `main`.

```bash
git restore pyproject.toml
```

**Verifica**:

```bash
git status --short -- pyproject.toml uv.lock
# (sin salida: no hay cambios)
uv lock --check; echo "exit $?"
# Resolved 31 packages in 0.79ms
# exit 0
```

---

## Paso 5: --locked, --frozen o nada

**Por qué**: las tres formas de `uv sync` hacen cosas distintas cuando el lockfile no coincide, y
elegir mal es elegir un CI que miente. Repite la desincronización del paso 4 y prueba las otras dos.

**Comando**:

```bash
sed -i 's/"uvicorn>=0.54.0"/"uvicorn>=0.53.0"/' pyproject.toml

uv sync --frozen; echo "exit $?"
# Installed 1 package in 0.85ms
#  ~ tablero==1.0.0 (from file:///home/<tu-usuario>/code/tablero/api)
# exit 0
git status --short -- pyproject.toml uv.lock
#  M pyproject.toml

uv sync; echo "exit $?"
# Resolved 31 packages in 12ms
# Checked 28 packages in 0.35ms
# exit 0
git status --short -- pyproject.toml uv.lock
#  M pyproject.toml
#  M uv.lock
```

| Orden | Si `uv.lock` no coincide | Para qué sirve |
|---|---|---|
| `uv sync --locked` | Falla con exit 1 y no instala | **CI**: el lockfile comiteado es la verdad y tiene que estar al día |
| `uv sync --frozen` | Instala lo que dice `uv.lock` sin mirar `pyproject.toml` | Imágenes Docker, donde ya sabes que el lockfile vale y no quieres resolver nada |
| `uv sync` | Reescribe `uv.lock` y sigue | Tu máquina, cuando acabas de cambiar una dependencia |

`--frozen` pasó en verde con un `pyproject.toml` que el lockfile no describe. En CI eso es un falso
verde: el PR que olvidó `uv lock` se fusiona y el siguiente que ejecute `uv sync` se encuentra un
`uv.lock` modificado que nadie revisó. `uv sync` a secas es peor todavía en CI: arregla el lockfile
dentro del runner, el job sale en verde y el cambio se pierde al destruir la máquina.

Deshaz los dos cambios:

```bash
git restore pyproject.toml uv.lock
```

**Verifica**:

```bash
git status --short -- pyproject.toml uv.lock
# (sin salida: no hay cambios)
uv sync --locked; echo "exit $?"
# Resolved 31 packages in ...
# Checked 28 packages in ...
# exit 0
```

---

## ✅ Resultado

- [ ] `uv --version` dice `uv 0.13.6`
- [ ] `api/.venv` existe y usa CPython 3.15.2, descargado por uv
- [ ] Ruff y pytest pasan en local con las mismas órdenes que usará el CI
- [ ] Has visto fallar `uv sync --locked` y `uv lock --check` con un lockfile desincronizado
- [ ] Sabes por qué el CI usa `--locked` y no `--frozen` ni `uv sync` a secas
- [ ] `pyproject.toml` y `uv.lock` sin cambios y `uv lock --check` sale con 0

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 03
```

De momento solo pasa `uv-lock-in-sync`: el resto llega con los workflows de las prácticas
siguientes y del proyecto.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `uv: command not found` | `~/.local/bin` no está en tu `PATH` | `docs/setup-entorno.md`, apartado 7 |
| `uv --version` dice otra versión | Tienes otro uv antes en el `PATH` (de tu distro o de pipx) | `command -v uv` te dice cuál; instala la 0.13.6 en `~/.local/bin` y ponla delante |
| `uv sync --locked` tarda mucho la primera vez | Está descargando CPython 3.15 y las dependencias | Normal: la segunda vez tarda milisegundos porque todo sale de la caché de uv |
| `error: No interpreter found for Python 3.15` | Descargas de Python desactivadas (`UV_PYTHON_DOWNLOADS=never` o `python-downloads` en la config de uv) | `env \| grep UV_` y quita esa opción, o `uv python install 3.15` |
| `uv lock --check` falla sin que hayas tocado nada | Tu uv es de otra versión y reescribe el lockfile con otro formato | Vuelve a la 0.13.6 (paso 1); nunca comitees un `uv.lock` regenerado por otra versión |
| `git status` muestra `.venv/` como nuevo | Falta `.gitignore` en la raíz del repo | Copia `app/.gitignore` del bootcamp a la raíz de tu repo (Semana 01, práctica 01, paso 3) |
| pytest dice `ModuleNotFoundError: No module named 'tablero'` | Ejecutaste `pytest` fuera de `uv run`, con otro Python | Siempre `uv run --no-sync pytest` dentro de `api/` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Antipatrones de Python en CI](../1-teoria/07-antipatrones-de-python-en-ci.md) | [uv en un workflow](02-uv-en-un-workflow.md) |
