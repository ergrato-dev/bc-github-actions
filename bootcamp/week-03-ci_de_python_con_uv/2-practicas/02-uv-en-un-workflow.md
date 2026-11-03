# Práctica 02 — uv en un workflow

> En tu máquina uv ya funciona. Ahora lo instalas en un runner que no tiene nada, con la versión
> fijada, y compruebas que el Python que usa el proyecto no es el que trae Ubuntu.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `python-lab.yml`, un workflow de laboratorio que se lanza a mano y trabaja dentro de `api/`
- `astral-sh/setup-uv` fijado por SHA y con la versión exacta de uv
- Ver en el log que el proyecto corre con CPython 3.15 y no con el Python 3.12 del runner
- Leer los outputs de `setup-uv` desde otro step

## 📋 Antes de empezar

Terminaste la [práctica 01](01-uv-en-local.md): `uv lock --check` sale con 0 en `api/`.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
```

`python-lab.yml` es un banco de pruebas, como `hello.yml` en la Semana 01: solo se lanza a mano.
El workflow que entregas es `ci-api.yml`, en el proyecto de la semana.

---

## Paso 1: El esqueleto, dentro de api/

**Por qué**: todo lo de esta semana pasa en `api/`. Con `defaults.run.working-directory` lo dices
una vez y cada `run:` empieza ahí, sin un `cd api` en cada step. Ojo: `defaults.run` afecta solo a
los `run:`; un `uses:` no lo ve y sigue trabajando desde la raíz del workspace. Eso importará en el
paso 2 y en la práctica 03.

**Comando**: crea `.github/workflows/python-lab.yml`.

```yaml
name: python-lab

on:
  workflow_dispatch:

# Mínimo privilegio: el token solo lee. Lo verás a fondo en la Semana 12.
permissions:
  contents: read

defaults:
  run:
    shell: bash
    working-directory: api

jobs:
  lab:
    name: uv en el runner
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Dónde estoy
        run: pwd && ls
```

**Verifica**:

```bash
actionlint .github/workflows/python-lab.yml
# (sin salida: no hay errores)
yq '.defaults.run."working-directory"' .github/workflows/python-lab.yml
# api
```

---

## Paso 2: Instalar uv con la versión fijada

**Por qué**: el runner no trae uv. `astral-sh/setup-uv` lo descarga, comprueba su checksum y lo
pone en el `PATH`. Sin `version`, la action instala la que diga `pyproject.toml` o, si no dice
nada, **la última**: el mismo commit podría pasar hoy y fallar mañana porque salió un uv nuevo. Con
`version: "0.13.6"` el runner usa la misma que tu máquina (práctica 01, paso 1). Las comillas
importan: sin ellas YAML lee `0.13.6` como texto por suerte, pero `1.10` lo leería como el número
`1.1`.

Los inputs que existen están en el `action.yml` de la action **en el SHA fijado**, no en el README
de la rama principal:

```bash
gh api "repos/astral-sh/setup-uv/contents/action.yml?ref=68559e99cc807c1eb7e9238fd43a15bba460eec2" \
  --jq .content | base64 -d | yq '.inputs | keys | .[0:4]'
# - version
# - version-file
# - python-version
# - python-arch
```

**Comando**: sustituye el step `Dónde estoy` por este:

```yaml
      - name: Instalar uv
        id: setup-uv
        uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
        with:
          version: "0.13.6"
```

El `id: setup-uv` es para el paso 4: sin `id`, no puedes leer los outputs de un step.

**Verifica**:

```bash
yq '.jobs.lab.steps[1].with.version' .github/workflows/python-lab.yml
# 0.13.6
actionlint .github/workflows/python-lab.yml
# (sin salida: no hay errores)
```

---

## Paso 3: Sincronizar y ver qué Python usa el proyecto

**Por qué**: la imagen `ubuntu-24.04` trae Python 3.12.3 (lo dice el README de
`actions/runner-images`). El proyecto pide 3.15 en `.python-version`. No necesitas
`actions/setup-python`: `uv sync --locked` lee `.python-version`, descarga CPython 3.15 y crea
`api/.venv` igual que en tu máquina. Este step lo demuestra imprimiendo los dos Pythons.

**Comando**: añade al final de `steps`:

```yaml
      - name: Dependencias exactas del lockfile
        run: uv sync --locked

      - name: Qué Python usa el proyecto
        run: |
          uv run --no-sync python -c 'import sys; print(sys.version)'
          uv run --no-sync which python
          echo "python3 del sistema: $(python3 --version)"
```

Cuando lo lances (paso 5), el log de `Qué Python usa el proyecto` dirá:

```
3.15.2 (main, ...) [Clang ...]
/home/runner/work/tablero/tablero/api/.venv/bin/python
python3 del sistema: Python 3.12.3
```

**Verifica**:

```bash
yq '.jobs.lab.steps[].run // ""' .github/workflows/python-lab.yml | grep -c 'uv sync --locked'
# 1
```

---

## Paso 4: Leer los outputs de setup-uv

**Por qué**: una action devuelve datos con `outputs`, igual que tus steps con `$GITHUB_OUTPUT`
(Semana 02). `setup-uv` publica, entre otros, `uv-version` (la versión instalada) y `cache-hit`
(si encontró caché). Se leen con `steps.<id>.outputs.<nombre>` y, como cualquier valor, llegan al
shell por `env:`.

Fíjate en el `run: |` de abajo. Un `run:` en una sola línea con `: ` dentro del texto
(`encontrada: ...`) es YAML inválido: el parser lo toma por otra clave. actionlint lo caza con
`mapping values are not allowed in this context`. El bloque literal `|` lo evita.

**Comando**: añade al final de `steps`:

```yaml
      - name: Lo que dice setup-uv
        env:
          UV_VERSION: ${{ steps.setup-uv.outputs.uv-version }}
          CACHE_HIT: ${{ steps.setup-uv.outputs.cache-hit }}
        run: |
          echo "uv ${UV_VERSION}, caché encontrada: ${CACHE_HIT:-false}"
```

Que `cache-hit` salga `true` o `false` depende de si ya hay caché: `setup-uv` la activa sola en
los runners de GitHub (`enable-cache` vale `auto` por defecto). Lo mides en la práctica 03.

**Verifica**:

```bash
actionlint .github/workflows/python-lab.yml
# (sin salida: no hay errores)
yq '.jobs.lab.steps[] | select(.name == "Lo que dice setup-uv") | .env | keys | join(",")' \
  .github/workflows/python-lab.yml
# UV_VERSION,CACHE_HIT
```

---

## Paso 5: Subirlo y lanzarlo a mano

**Por qué**: `workflow_dispatch` solo aparece cuando el archivo está en la rama por defecto
(Semana 01, teoría 05). Así que primero va a `main` y después lo lanzas. Como `python-lab.yml` no
escucha `push`, subirlo no lanza ningún run: el único es el que pides tú.

**Comando**:

```bash
git add .github/workflows/python-lab.yml
git commit -m "ci(lab): add python-lab workflow"
git push
gh workflow run python-lab.yml
sleep 5   # el run tarda unos segundos en aparecer en la lista
id=$(gh run list --workflow python-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status
```

Busca en el log las tres líneas del paso 3 y la del paso 4:

```bash
gh run view "$id" --log | grep -E 'sistema:|/\.venv/bin/python|caché encontrada'
# uv en el runner  Qué Python usa el proyecto  ... /home/runner/work/tablero/tablero/api/.venv/bin/python
# uv en el runner  Qué Python usa el proyecto  ... python3 del sistema: Python 3.12.3
# uv en el runner  Lo que dice setup-uv  ... uv 0.13.6, caché encontrada: false
```

**Verifica**:

```bash
gh run list --workflow python-lab.yml --event workflow_dispatch --status success \
  --json databaseId --jq length
# 1
```

---

## ✅ Resultado

- [ ] `python-lab.yml` está en `main` y solo se lanza a mano
- [ ] Todos sus `run:` trabajan dentro de `api/` sin un solo `cd`
- [ ] `setup-uv` va fijado por SHA y con `version: "0.13.6"`
- [ ] Has visto en el log CPython 3.15.2 en `.venv` frente al Python 3.12.3 del sistema
- [ ] Has leído `uv-version` y `cache-hit` desde otro step, por `env:`
- [ ] Un run de `python-lab.yml` lanzado a mano terminó en `success`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 03
```

Ya pasan `uv-lock-in-sync` y `python-lab-dispatched`.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `gh workflow run` dice `could not find any workflows named python-lab.yml` | El archivo no está en `main`, o está en otra carpeta | `git ls-tree --name-only origin/main .github/workflows/` tiene que listarlo |
| `uv sync` falla con `No pyproject.toml found` | Falta `working-directory: api` en `defaults.run`, o está mal indentado | Paso 1: `yq '.defaults.run."working-directory"'` tiene que dar `api` |
| `setup-uv` instala otra versión de uv | Falta `version` o está en otro nivel de indentación | Va dentro de `with:` del step de `setup-uv` (paso 2) |
| actionlint: `mapping values are not allowed in this context` | Un `run:` de una línea con `: ` en el texto | Pásalo a bloque `run: \|` (paso 4) |
| actionlint: `property "setup-uv" is not defined` | Falta `id: setup-uv` en el step o está mal escrito | El `id` del step y el de la expresión tienen que coincidir |
| `uv-version` sale vacío | La expresión usa otro nombre de output | Los nombres reales están en el `action.yml` del SHA: `yq '.outputs \| keys'` |
| El run falla con `startup_failure` | Tienes `sha_pinning_required` activo y una `uses:` va por tag | `scripts/resolve-sha.sh` (Semana 01, práctica 04, paso 3) |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [uv en local](01-uv-en-local.md) | [Caché y tiempos](03-cache-y-tiempos.md) |
