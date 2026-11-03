# Práctica 04 — Romper y arreglar

> Un CI no se conoce cuando sale en verde, se conoce cuando falla. Aquí siembras cuatro fallos,
> uno detrás de otro, en una rama de pruebas, y aprendes a encontrar en el log la línea exacta que
> lo delata.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `python-lab.yml` con los cuatro pasos de un CI de Python: sync, lint, formato y tests
- Cuatro fallos distintos, cada uno con la línea del log que lo identifica
- Lanzar un workflow sobre una rama con `gh workflow run -r` sin tocar `main`
- Dejar `python-lab.yml` en verde y la rama de pruebas borrada

## 📋 Antes de empezar

Terminaste la [práctica 03](03-cache-y-tiempos.md): `python-lab.yml` usa la caché de `setup-uv`.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
```

Primero deja `python-lab.yml` con los steps de un CI completo. Quita los steps de diagnóstico de
las prácticas 02 y 03 (`Qué Python usa el proyecto`, `Lo que dice setup-uv`, `¿Hubo acierto?`) y
deja `steps` así:

```yaml
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

      - name: ruff check
        run: uv run --no-sync ruff check --output-format=github .

      - name: ruff format
        run: uv run --no-sync ruff format --check .

      - name: pytest con cobertura
        run: uv run --no-sync pytest tests/unit --cov=tablero --cov-report=term-missing --cov-fail-under=60
```

`--output-format=github` hace que ruff escriba sus errores como anotaciones de GitHub: aparecen
en la página del run y en la pestaña *Files changed* de un PR, en la línea exacta. Lo verás a fondo
en la Semana 08.

```bash
actionlint .github/workflows/python-lab.yml
git commit -am "ci(lab): run lint, format and tests"
git push
gh workflow run python-lab.yml
sleep 5
id=$(gh run list --workflow python-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null && echo "verde"
# verde
```

Todos los fallos de esta práctica van en la rama `lab/broken`. `main` no se toca hasta el paso 5.

---

## Paso 1: Lockfile desincronizado

**Por qué**: es el fallo de la práctica 01, ahora en el runner. Es el primero que tienes que saber
reconocer porque falla **antes** de ejecutar ningún test: si el lockfile no cuadra, nada de lo que
venga detrás demuestra algo.

`gh workflow run -r lab/broken` lanza el `python-lab.yml` **de esa rama**. El archivo tiene que
existir también en `main` (para que GitHub conozca el workflow), pero lo que se ejecuta es la
versión de la rama, con su código.

**Comando**:

```bash
git switch -c lab/broken
sed -i 's/"uvicorn>=0.54.0"/"uvicorn>=0.53.0"/' api/pyproject.toml
git commit -am "test: change uvicorn bound without uv lock"
git push -u origin lab/broken
gh workflow run python-lab.yml -r lab/broken
sleep 5
id=$(gh run list --workflow python-lab.yml --branch lab/broken --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 1
gh run view "$id" --log-failed | grep -E 'error:|hint:'
# ... error: The lockfile at `uv.lock` needs to be updated, but `--locked` was provided.
# ... hint: To update the lockfile, run `uv lock`.
```

Fíjate en qué steps ni siquiera empezaron:

```bash
gh run view "$id" --json jobs --jq '.jobs[0].steps[] | "\(.conclusion)  \(.name)"' | grep -E 'ruff|pytest|lockfile'
# failure  Dependencias exactas del lockfile
# skipped  ruff check
# skipped  ruff format
# skipped  pytest con cobertura
```

Arréglalo como se arregla de verdad: deshaciendo el cambio. Si el cambio de cota fuera
intencionado, el arreglo sería `uv lock` y comitear los dos archivos juntos.

```bash
git revert --no-edit HEAD
git push
```

**Verifica**:

```bash
gh run list --workflow python-lab.yml --status failure --json databaseId --jq length
# 1   (o más, si alguno de tus runs anteriores también falló)
(cd api && uv lock --check > /dev/null 2>&1) && echo "lockfile al día"
# lockfile al día
```

---

## Paso 2: Código sin formatear

**Por qué**: `ruff format --check` no cambia nada: dice qué cambiaría y sale con 1. Así el CI
obliga a formatear **antes** del commit en lugar de reformatear en el runner y tirar el resultado.

**Comando**:

```bash
sed -i 's/^Tasks = Annotated\[TaskRepository, Depends(get_tasks)\]$/Tasks = Annotated[ TaskRepository,Depends(get_tasks) ]/' api/src/tablero/main.py
git commit -am "test: break formatting"
git push
gh workflow run python-lab.yml -r lab/broken
sleep 5
id=$(gh run list --workflow python-lab.yml --branch lab/broken --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null
gh run view "$id" --log-failed | grep -E 'would be reformatted|[-+] Tasks'
# ... - Tasks = Annotated[ TaskRepository,Depends(get_tasks) ]
# ... + Tasks = Annotated[TaskRepository, Depends(get_tasks)]
# ... 1 file would be reformatted, 6 files already formatted
```

El log dice qué línea y cómo quedaría. `ruff check` pasó: el código es correcto, solo está mal
escrito. Por eso son dos steps.

Arreglo: formatear en local, que es lo que el CI te está pidiendo.

```bash
(cd api && uv run --no-sync ruff format .)
# 1 file reformatted, 6 files left unchanged
git commit -am "style: format main.py"
git push
```

**Verifica**:

```bash
(cd api && uv run --no-sync ruff format --check .)
# 7 files already formatted
```

---

## Paso 3: Un test roto

**Por qué**: el fallo que todo el mundo espera. Lo útil es saber ir directo a la línea `E` de
pytest, que dice qué se esperaba y qué llegó, sin leer las 80 líneas de alrededor.

**Comando**: cambia lo que espera `test_missing_task_is_404` (línea 70 de `tests/unit/test_api.py`):

```bash
sed -i '70s/== 404/== 400/' api/tests/unit/test_api.py
git commit -am "test: expect the wrong status code"
git push
gh workflow run python-lab.yml -r lab/broken
sleep 5
id=$(gh run list --workflow python-lab.yml --branch lab/broken --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null
gh run view "$id" --log-failed | grep -E 'AssertionError|FAILED'
# ... E       AssertionError: assert 404 == 400
# ... tests/unit/test_api.py:70: AssertionError
# ... FAILED tests/unit/test_api.py::test_missing_task_is_404 - AssertionError: ass...
```

`assert 404 == 400`: la API devolvió 404 (lo correcto) y el test esperaba 400. El error está en el
test, no en el código. Leer el orden de la comparación te ahorra arreglar lo que no está roto.

```bash
git revert --no-edit HEAD
git push
```

**Verifica**:

```bash
(cd api && uv run --no-sync pytest tests/unit -q | tail -1)
# 6 passed in 0.30s
```

---

## Paso 4: Cobertura por debajo del umbral

**Por qué**: todos los tests pasan y aun así el job falla. `--cov-fail-under` convierte la
cobertura en una condición del CI. El mensaje es fácil de confundir con un test roto si no lo has
visto antes.

**Comando**: sube el umbral a 90 en la rama.

```bash
sed -i 's/--cov-fail-under=60/--cov-fail-under=90/' .github/workflows/python-lab.yml
git commit -am "test: raise coverage threshold to 90"
git push
gh workflow run python-lab.yml -r lab/broken
sleep 5
id=$(gh run list --workflow python-lab.yml --branch lab/broken --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null
gh run view "$id" --log-failed | grep -E 'Required test coverage|passed'
# ... FAIL Required test coverage of 90% not reached. Total coverage: 62.03%
# ... 6 passed in ...
```

`6 passed` y aun así `failure`. El 62 % sale de los tests unitarios: `migrate.py` y `db.py` solo
se prueban contra PostgreSQL, y eso llega en la Semana 05. Un umbral que el código no puede
alcanzar no mide calidad; solo bloquea.

```bash
git revert --no-edit HEAD
git push
```

**Verifica**:

```bash
git diff main -- .github/workflows/python-lab.yml
# (sin salida: la rama vuelve a tener el mismo workflow que main)
```

---

## Paso 5: Todo en verde y la rama fuera

**Por qué**: un banco de pruebas que se queda en rojo, o una rama `lab/broken` olvidada, acaban
confundiendo a quien llegue después. Compruebas que la rama vuelve a pasar y la borras.

**Comando**:

```bash
gh workflow run python-lab.yml -r lab/broken
sleep 5
id=$(gh run list --workflow python-lab.yml --branch lab/broken --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null && echo "lab/broken en verde"
# lab/broken en verde
```

> [!WARNING]
> Vas a borrar la rama `lab/broken` en local y en GitHub. Solo contiene los commits de prueba de
> esta práctica y sus reverts. Antes de borrarla, comprueba con
> `git log --oneline main..lab/broken` que no hay nada más que quieras conservar.

```bash
git log --oneline main..lab/broken
# ... Revert "test: raise coverage threshold to 90"
# ... test: raise coverage threshold to 90
# ...
git switch main
git branch -D lab/broken
git push origin --delete lab/broken
```

`style: format main.py` deja el archivo igual que en `main`, así que no se pierde nada.

Para acabar, un último run en `main`:

```bash
gh workflow run python-lab.yml
sleep 5
id=$(gh run list --workflow python-lab.yml --branch main --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null && echo "main en verde"
# main en verde
```

**Verifica**:

```bash
git branch -a | grep -c lab/broken
# 0
gh run list --workflow python-lab.yml --branch main --limit 1 --json conclusion --jq '.[0].conclusion'
# success
```

---

## ✅ Resultado

- [ ] `python-lab.yml` ejecuta sync, `ruff check`, `ruff format --check` y pytest con cobertura
- [ ] Has visto fallar el lockfile, el formato, un test y la cobertura, cada uno con su línea del log
- [ ] Sabes leer `assert 404 == 400` y decidir si el error está en el test o en el código
- [ ] Has lanzado un workflow sobre una rama con `gh workflow run -r`
- [ ] `lab/broken` está borrada y el último run de `python-lab.yml` en `main` está en verde

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 03
```

Ya pasan los cuatro checks de las prácticas. Los demás llegan con `ci-api.yml`, en el proyecto.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `gh workflow run -r lab/broken` dice `could not create workflow dispatch event` | La rama no existe en GitHub | `git push -u origin lab/broken` antes de lanzarlo |
| El run de la rama ejecuta el `python-lab.yml` antiguo | La rama se creó antes de actualizar el workflow en `main` | Crea la rama desde `main` actualizado (antes del paso 1) |
| `gh run list --branch lab/broken` devuelve el run de antes | El run nuevo aún no aparece | Sube el `sleep` o repite `gh run list` hasta que el `databaseId` cambie |
| `--log-failed` no imprime nada | El run terminó en `success` o seguía en marcha | `gh run view "$id" --json conclusion,status` |
| En el paso 2 `ruff check` también falla | El `sed` rompió algo más que el formato | `git diff HEAD~1` para ver qué cambió y corrígelo a mano |
| `git revert` pide resolver conflictos | Hiciste otros cambios en los mismos archivos | `git revert --abort` y deshazlo con `git restore --source=main <archivo>` |
| El paso 1 no cuenta como fallido en `check-week.sh` | El run terminó `cancelled`, no `failure` | Vuelve a lanzar el paso 1 y deja que termine |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Caché y tiempos](03-cache-y-tiempos.md) | [Proyecto: capa 03 de tablero](../3-proyecto/README.md) |
