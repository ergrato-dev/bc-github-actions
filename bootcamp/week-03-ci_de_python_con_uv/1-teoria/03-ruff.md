# ruff: lint y formato

> ruff hace dos trabajos con un solo binario: busca errores probables en el código (`ruff check`)
> y comprueba que el formato es el acordado (`ruff format`). En CI los dos tienen que fallar sin
> arreglar nada: arreglar es trabajo de tu máquina.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué hace `ruff check` y qué hace `ruff format`, y por qué son dos comprobaciones
- Leer la configuración de ruff de `api/pyproject.toml` y saber qué detecta cada familia de reglas
- Ejecutar los dos en modo comprobación (`ruff check` y `ruff format --check`) y leer su salida
- Usar `--output-format=github` para que los errores aparezcan sobre las líneas del pull request
- Saber por qué `--fix` se usa en local y nunca en CI

## 1. Qué problema resuelve

Un import que nadie usa, una lista como valor por defecto de un argumento o un `typing.List` de
hace cinco versiones de Python no rompen ningún test hoy. Rompen algo dentro de seis meses, o
hacen que una revisión de código se gaste en espacios y comas en lugar de en lógica.

Un linter en CI convierte esas discusiones en una regla que se cumple sola: el pull request no
pasa hasta que el código la cumple, y nadie tiene que acordarse de pedirlo.

ruff está en el grupo `dev` de `tablero`, así que `uv sync --locked` lo instala con la versión
exacta del lockfile: la misma en tu máquina y en el runner.

## 2. Cómo funciona

### La configuración vive en `pyproject.toml`

```toml
[tool.ruff]
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "I", "B", "UP"]
```

`line-length` vale para las dos herramientas: el linter avisa de líneas más largas y el formateador
corta en esa longitud. `select` elige las familias de reglas del linter:

| Código | Familia | Ejemplo de lo que detecta |
|---|---|---|
| `E` | pycodestyle | Líneas demasiado largas (`E501`), sintaxis dudosa |
| `F` | Pyflakes | Imports sin usar (`F401`), nombres sin definir |
| `I` | isort | Imports desordenados (`I001`) |
| `B` | flake8-bugbear | Argumentos mutables por defecto (`B006`) y otros errores probables |
| `UP` | pyupgrade | Sintaxis que la versión de Python del proyecto ya no necesita (`UP006`, `UP035`) |

`UP` lee `requires-python = ">=3.15"` de `[project]` para saber qué sintaxis antigua sobra. No
hace falta repetir la versión en `[tool.ruff]`.

### `ruff check`: errores probables

Con este archivo de prueba:

```python
import sys
import os
from typing import List


def titles(tasks: List[dict], seen=[]):
    for t in tasks:
        seen.append(t["title"])
    return seen
```

ruff 0.17.3 encuentra seis problemas y sale con código 1:

```text
src/tablero/bad.py:1:1: I001 [*] Import block is un-sorted or un-formatted
src/tablero/bad.py:1:8: F401 [*] `sys` imported but unused
src/tablero/bad.py:2:8: F401 [*] `os` imported but unused
src/tablero/bad.py:3:1: UP035 `typing.List` is deprecated, use `list` instead
src/tablero/bad.py:6:19: UP006 [*] Use `list` instead of `List` for type annotation
src/tablero/bad.py:6:36: B006 Do not use mutable data structures for argument defaults
Found 6 errors.
[*] 4 fixable with `--fix` (1 unsafe fix available with `--fix --unsafe-fixes`).
```

Esa es la salida de `--output-format=concise`. La salida por defecto añade, para cada error, el
fragmento de código y la corrección propuesta. El `B006` es el más interesante: la lista `[]` se
crea una vez y se comparte entre llamadas, así que la segunda llamada a `titles()` devuelve
también los títulos de la primera. Ningún test de un solo caso lo ve.

### `ruff format --check`: el formato acordado

`ruff format` reescribe los archivos con un estilo fijo. Con `--check` no reescribe nada: dice
qué archivos cambiaría y sale con 1.

```text
$ uv run --no-sync ruff format --check .
unformatted: File would be reformatted
 --> src/tablero/bad.py:2:16
  |
1 | def total(xs):
  -     return sum( [x for x in xs] )
2 +     return sum([x for x in xs])
  |

1 file would be reformatted, 7 files already formatted
```

Son dos comprobaciones distintas porque miden cosas distintas: un archivo puede estar
perfectamente formateado y tener un import sin usar, o al revés. Tu CI ejecuta las dos.

### `--output-format=github`: errores sobre la línea del PR

Con este formato, ruff imprime cada error como un comando de workflow que el runner entiende:

```text
::error title=ruff (F401),file=.../src/tablero/bad.py,line=1,col=8,endLine=1,endColumn=11::src/tablero/bad.py:1:8: F401 `sys` imported but unused
```

El runner convierte cada línea en una **anotación**: aparece en el resumen del run y, en un pull
request, en la pestaña *Files changed* sobre la línea exacta. Quien revisa ve el error sin abrir el
log. Cómo escribir esos comandos tú mismo con `::error` es de la Semana 08; aquí solo los genera
ruff.

`ruff format --check` no tiene ese formato: su salida es el diff de arriba, en el log del step.

### `--fix` es para tu máquina

`ruff check --fix` corrige lo que puede (los `[*]` de la salida) y `ruff format` sin `--check`
reformatea. Si lo hicieras en CI:

- la corrección se haría en la copia del runner, que se destruye al terminar el job;
- el job pasaría en verde con el error todavía en el repo;
- y las correcciones "unsafe" pueden cambiar el comportamiento, como avisa la propia salida.

En local, el ciclo es: `ruff check --fix .`, `ruff format .`, revisar el diff, commit.

## 3. Cómo se usa

En local, antes de cada push:

```bash
cd ~/code/tablero/api
uv run --no-sync ruff check --fix .
uv run --no-sync ruff format .
git diff --stat
```

En CI, en modo comprobación, como steps de un job que ya hizo `uv sync --locked`:

```yaml
      - name: Reglas de ruff
        run: uv run --no-sync ruff check --output-format=github .
      - name: Formato de ruff
        run: uv run --no-sync ruff format --check .
```

Los dos steps van separados para que el log diga cuál de los dos falló. Como cada step con exit
distinto de 0 para el job, si falla el primero no verás el segundo: con
`if: ${{ !cancelled() }}` en el segundo (Semana 02) verías los dos resultados en el mismo run.

Para ignorar una regla en una línea concreta, `# noqa: B006` al final de la línea, con un
comentario de por qué. Para ignorarla en todo el proyecto, `ignore = ["B006"]` en
`[tool.ruff.lint]`: es una decisión del equipo y va en un commit propio.

Verificado con ruff 0.17.3, astral-sh/setup-uv@v10.3.3 y ubuntu-24.04, noviembre de 2026.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `ruff check --fix` o `ruff format` sin `--check` en CI | Arregla el runner, no el repo: verde con el error dentro | Comprobar en CI, arreglar en local |
| Solo `ruff check`, sin `ruff format --check` | El formato se degrada poco a poco | Las dos comprobaciones |
| ruff instalado aparte en el workflow, con otra versión | Tu máquina y el CI no están de acuerdo sobre qué es un error | El ruff del lockfile: `uv run --no-sync ruff` |
| `select = ["ALL"]` el primer día | Cientos de avisos que nadie va a leer | Familias concretas y ampliar con un commit por familia |
| `# noqa` sin código de regla | Silencia todas las reglas de la línea, también las futuras | `# noqa: F401` con el código exacto |
| Configuración de ruff en un archivo aparte sin motivo | Dos sitios donde buscar | `[tool.ruff]` en `pyproject.toml` |

## 5. Trucos

- **`ruff check --statistics .`** cuenta los errores por regla. Antes de activar una familia nueva,
  te dice cuánto trabajo es.
- **`ruff rule B006`** explica una regla con ejemplos sin salir de la terminal.
- **`ruff format --diff .`** enseña el diff completo que aplicaría el formateador, sin tocar nada.
  Es lo que necesitas cuando el CI dice "would be reformatted" y no ves por qué.

## 📚 Recursos Adicionales

- [Ruff: The Ruff Linter](https://docs.astral.sh/ruff/linter/)
- [Ruff: The Ruff Formatter](https://docs.astral.sh/ruff/formatter/)
- [Ruff: Rules](https://docs.astral.sh/ruff/rules/)
- [Ruff: Integrations (GitHub Actions)](https://docs.astral.sh/ruff/integrations/)

## ✅ Checklist de Verificación

- [ ] Sé qué detecta cada familia de `select` en `api/pyproject.toml`
- [ ] Sé por qué `ruff check` y `ruff format --check` son dos comprobaciones
- [ ] Sé qué hace `--output-format=github` y dónde aparecen sus errores
- [ ] Sé por qué `--fix` no se usa en CI
- [ ] He visto un `B006` y entiendo por qué ningún test de un caso lo detecta

---

| ← Anterior | Siguiente → |
|:---|---:|
| [uv en CI](02-uv-en-ci.md) | [pytest y cobertura](04-pytest-y-cobertura.md) |
