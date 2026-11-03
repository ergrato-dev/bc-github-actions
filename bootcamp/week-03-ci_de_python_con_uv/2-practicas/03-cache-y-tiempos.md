# Práctica 03 — Caché y tiempos

> Cada runner nace vacío, así que cada run descarga otra vez todas las dependencias. La caché lo
> evita, pero solo si sabes qué guardas, con qué clave y cómo comprobar que ha acertado. Aquí la
> montas a mano, la mides y luego dejas que `setup-uv` lo haga por ti.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Medir cuánto tarda cada step de `python-lab.yml` sin caché
- Una caché de uv hecha a mano con `actions/cache`, con su clave atada a `api/uv.lock`
- Ver un fallo de caché y después un acierto, con el output `cache-hit`
- Sustituirla por la caché integrada de `setup-uv` y listarla con `gh cache list`
- Borrar una caché y ver que el siguiente run vuelve a empezar de cero

## 📋 Antes de empezar

Terminaste la [práctica 02](02-uv-en-un-workflow.md): `python-lab.yml` está en `main` y ya
terminó en verde una vez.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
gh run list --workflow python-lab.yml --limit 1 --json conclusion --jq '.[0].conclusion'
# success
```

---

## Paso 1: Medir sin caché

**Por qué**: si no mides antes, no sabes si la caché ayuda. `setup-uv` activa su caché sola en los
runners de GitHub (`enable-cache: auto`), así que para tener una línea base de verdad la apagas.
`gh run view --json jobs` da la hora de inicio y de fin de cada step; con `fromdateiso8601` las
conviertes a segundos.

**Comando**: en `python-lab.yml`, desactiva la caché de `setup-uv`:

```yaml
      - name: Instalar uv
        id: setup-uv
        uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
        with:
          version: "0.13.6"
          enable-cache: false
```

```bash
git commit -am "ci(lab): disable uv cache for a baseline"
git push
gh workflow run python-lab.yml
sleep 5
id=$(gh run list --workflow python-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null
gh run view "$id" --json jobs --jq '.jobs[0].steps[]
  | "\((.completedAt | fromdateiso8601) - (.startedAt | fromdateiso8601))s  \(.name)"'
```

Apunta el tiempo de `Dependencias exactas del lockfile`: es lo que tarda descargar CPython 3.15 y
las 28 dependencias en una máquina vacía. Tus números serán otros; lo que importa es compararlos
en el paso 3.

**Verifica**:

```bash
yq '.jobs.lab.steps[] | select(.id == "setup-uv") | .with."enable-cache"' .github/workflows/python-lab.yml
# false
gh run view "$id" --json conclusion --jq .conclusion
# success
```

---

## Paso 2: Una caché a mano con actions/cache

**Por qué**: `actions/cache` es la herramienta general: guarda un directorio al final del job y lo
restaura al principio del siguiente si la **clave** coincide. Tres decisiones:

- **Qué guardar**: la caché de uv (los paquetes descargados), no `.venv`. `.venv` contiene rutas
  absolutas y enlaces al Python de esa máquina; la caché de uv es reutilizable y uv monta `.venv`
  desde ella en milisegundos. La ruta no se adivina: se la preguntas a uv con `uv cache dir`.
- **Con qué clave**: `hashFiles('api/uv.lock')`. Si el lockfile no cambia, las dependencias
  tampoco, y la clave es la misma. `hashFiles` mira desde la raíz del workspace, no desde
  `working-directory`.
- **Qué hacer si no hay acierto exacto**: `restore-keys` restaura la caché más reciente que
  empiece por ese prefijo. Un lockfile con un paquete nuevo aprovecha los otros 27.

**Comando**: deja `enable-cache: false` en `setup-uv` y añade estos tres steps justo después,
antes de `Dependencias exactas del lockfile`:

```yaml
      - name: Dónde guarda uv su caché
        id: uv-cache
        run: echo "dir=$(uv cache dir)" >> "$GITHUB_OUTPUT"

      - name: Restaurar la caché de uv
        id: cache
        uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
        with:
          path: ${{ steps.uv-cache.outputs.dir }}
          key: uv-${{ runner.os }}-${{ hashFiles('api/uv.lock') }}
          restore-keys: |
            uv-${{ runner.os }}-

      - name: ¿Hubo acierto exacto?
        env:
          CACHE_HIT: ${{ steps.cache.outputs.cache-hit }}
        run: echo "cache-hit=${CACHE_HIT:-false}"
```

`actions/cache` no guarda nada en este step: registra un step `Post` que se ejecuta al final del
job y sube el directorio si la clave no existía. Los inputs y outputs están en su `action.yml`:

```bash
gh api "repos/actions/cache/contents/action.yml?ref=55cc8345863c7cc4c66a329aec7e433d2d1c52a9" \
  --jq .content | base64 -d | yq '(.inputs | keys | join(" ")), (.outputs | keys | join(" "))'
# path key restore-keys upload-chunk-size enableCrossOsArchive fail-on-cache-miss lookup-only save-always
# cache-hit
```

**Verifica**:

```bash
actionlint .github/workflows/python-lab.yml
# (sin salida: no hay errores)
yq '.jobs.lab.steps[] | select(.id == "cache") | .with.key' .github/workflows/python-lab.yml
# uv-${{ runner.os }}-${{ hashFiles('api/uv.lock') }}
```

---

## Paso 3: Un fallo y un acierto

**Por qué**: el primer run con la clave nueva no encuentra nada (fallo) y guarda la caché al final.
El segundo, con el mismo `uv.lock`, la encuentra (acierto). Comparar los dos te dice cuánto ahorra
la caché de verdad, no cuánto crees que ahorra.

**Comando**:

```bash
git commit -am "ci(lab): cache uv with actions/cache"
git push

for intento in 1 2; do
  gh workflow run python-lab.yml
  sleep 5
  id=$(gh run list --workflow python-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
  gh run watch "$id" --exit-status > /dev/null
  echo "== run $intento ($id)"
  gh run view "$id" --log | grep -oE 'cache-hit=(true|false)'
  gh run view "$id" --json jobs --jq '.jobs[0].steps[]
    | select(.name == "Dependencias exactas del lockfile")
    | "\((.completedAt | fromdateiso8601) - (.startedAt | fromdateiso8601))s  \(.name)"'
done
# == run 1 (...)
# cache-hit=false
# ...s  Dependencias exactas del lockfile
# == run 2 (...)
# cache-hit=true
# ...s  Dependencias exactas del lockfile
```

En el run 1, el step `Post Restaurar la caché de uv` dice que ha guardado la caché. En el run 2,
`Restaurar la caché de uv` dice `Cache restored from key: uv-Linux-...`.

El ahorro tiene un techo: la caché de uv guarda paquetes, no el intérprete. CPython 3.15 se
descarga igual en los dos runs (para cachearlo, `setup-uv` tiene el input `cache-python`, que vale
`false` por defecto). En tu máquina la diferencia es más clara: `uv sync --locked` con la caché
vacía tarda alrededor de 1,3 s y con la caché llena, 0,03 s.

**Verifica**:

```bash
gh cache list --key uv-Linux- --json key,sizeInBytes --jq '.[] | .key[0:20] + "  " + (.sizeInBytes / 1048576 | floor | tostring) + " MB"'
# uv-Linux-...  ... MB
```

---

## Paso 4: La caché integrada de setup-uv

**Por qué**: lo que acabas de montar en tres steps, `setup-uv` lo hace con dos inputs, y además
calcula la clave con la plataforma, la versión de Python y el hash que elijas. Menos YAML que
mantener y el mismo efecto. Un detalle: `cache-dependency-glob` es **relativo al
`working-directory` de la action** (por defecto, la raíz del workspace), no al `defaults.run` del
workflow. Por eso es `api/uv.lock` y no `uv.lock`.

**Comando**: quita los tres steps del paso 2 y deja `setup-uv` así:

```yaml
      - name: Instalar uv con caché
        id: setup-uv
        uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
        with:
          version: "0.13.6"
          enable-cache: true
          cache-dependency-glob: api/uv.lock

      - name: ¿Hubo acierto?
        env:
          CACHE_HIT: ${{ steps.setup-uv.outputs.cache-hit }}
          CACHE_KEY: ${{ steps.setup-uv.outputs.cache-key }}
        run: echo "cache-hit=${CACHE_HIT:-false} key=${CACHE_KEY}"
```

El step `Lo que dice setup-uv` de la práctica 02 sigue funcionando; puedes dejarlo o quitarlo.

```bash
actionlint .github/workflows/python-lab.yml
git commit -am "ci(lab): use setup-uv built-in cache"
git push
gh workflow run python-lab.yml
sleep 5
id=$(gh run list --workflow python-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null
gh run view "$id" --log | grep -oE 'cache-hit=(true|false) key=setup-uv-[^ ]{0,30}'
# cache-hit=false key=setup-uv-2-x86_64-unknown-linux-gnu-
```

Es `false` porque la clave es nueva. La caché a mano tenía otro nombre, y la que creó `setup-uv`
en la práctica 02 (con `enable-cache: auto`) usaba su glob por defecto, que también mira
`pyproject.toml`: otro hash, otra clave. El siguiente run ya acertará.

**Verifica**:

```bash
gh cache list --key setup-uv- --json key --jq '.[].key[0:30]'
# setup-uv-2-x86_64-unknown-linu
# (una línea por caché de setup-uv: puede haber dos si la práctica 02 dejó la suya)
gh cache list --key uv-Linux- --json key --jq length
# 1
```

---

## Paso 5: Borrar una caché y ver el fallo

**Por qué**: una caché corrupta o demasiado vieja se arregla borrándola. Saber hacerlo, y saber
que el siguiente run vuelve a empezar de cero, te evita perder una tarde con un CI que restaura
algo roto una y otra vez. Además, la caché a mano del paso 2 ya no la usa nadie: ocupa sitio
hasta que GitHub la desaloje por falta de uso.

> [!WARNING]
> `gh cache delete` borra la caché del repo al que apunta `gh`, sin papelera. Comprueba que estás
> en `~/code/tablero` (o que `GH_REPO` vale `<tu-org>/tablero`) antes de ejecutarlo. Una caché no
> es un dato: lo peor que pasa es que el siguiente run tarda más. Aun así, nunca uses `--all` en un
> repo que no sea el tuyo.

**Comando**: borra la caché que ya no usas, la del paso 2, por su prefijo de clave:

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner
# <tu-org>/tablero
gh cache list --key uv-Linux- --json id,key --jq '.[] | "\(.id)  \(.key)"'
# 1234567890  uv-Linux-...
gh cache list --key uv-Linux- --json id --jq '.[].id' | xargs -r -n1 gh cache delete
# ✓ Deleted ...
```

Ahora borra también la de `setup-uv` y lanza otro run para ver el fallo:

```bash
gh cache list --key setup-uv- --json id --jq '.[].id' | xargs -r -n1 gh cache delete
gh workflow run python-lab.yml
sleep 5
id=$(gh run list --workflow python-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null
gh run view "$id" --log | grep -oE 'cache-hit=(true|false)'
# cache-hit=false
```

Ese run ha vuelto a guardar la caché al terminar, así que el siguiente acertará otra vez.

**Verifica**:

```bash
gh cache list --key uv-Linux- --json id --jq length
# 0
gh cache list --json key --jq length
# 1
```

---

## ✅ Resultado

- [ ] Tienes el tiempo de cada step sin caché, sacado con `gh run view --json jobs`
- [ ] Has montado una caché de uv con `actions/cache`, clave atada a `api/uv.lock`
- [ ] Has visto `cache-hit=false` y después `cache-hit=true` con el mismo lockfile
- [ ] `python-lab.yml` usa la caché integrada de `setup-uv` con `cache-dependency-glob: api/uv.lock`
- [ ] Has borrado una caché con `gh cache delete` y has visto el fallo siguiente
- [ ] `gh cache list` muestra la caché de `setup-uv`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 03
```

Ya pasa `uv-cache-saved`.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `cache-hit` sale `false` en todos los runs | La clave cambia en cada run, o el run 1 no llegó a guardar | Mira el step `Post ...`: si dice que no hay nada que guardar, `path` está mal; si guarda, compara las claves de los dos logs |
| `hashFiles('uv.lock')` da una clave vacía (`uv-Linux-`) | `hashFiles` busca desde la raíz del workspace, no desde `api/` | Escribe `hashFiles('api/uv.lock')` |
| `Warning: Path Validation Error: Path(s) specified in the action for caching do(es) not exist` | El directorio de `path` no existe al guardar | Usa el output de `uv cache dir` (paso 2); no escribas la ruta a mano |
| `setup-uv` avisa de que no encuentra archivos para el glob | `cache-dependency-glob: uv.lock` relativo a la raíz | `cache-dependency-glob: api/uv.lock` (paso 4) |
| `gh cache list` está vacío aunque los runs acertaban | Las cachés de una rama solo se ven con `--ref` o las borró GitHub por no usarse | `gh cache list --ref refs/heads/main` y vuelve a lanzar un run en `main` |
| `fromdateiso8601` falla con `cannot be parsed` | El job seguía en marcha: `completedAt` aún no tiene fecha válida | Espera a `gh run watch` antes de pedir los tiempos |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [uv en un workflow](02-uv-en-un-workflow.md) | [Romper y arreglar](04-romper-y-arreglar.md) |
