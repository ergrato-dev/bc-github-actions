# Práctica 02 — pnpm en un workflow

> En tu máquina pnpm ya funciona. Ahora lo llevas a un runner que no lo tiene, en el orden que
> exige `setup-node` para cachear el store, y compruebas en el log que la segunda ejecución ya no
> descarga nada.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `web-lab.yml`, un workflow de laboratorio que se lanza a mano y trabaja dentro de `web/`
- `pnpm/action-setup` leyendo la versión de pnpm de `web/package.json`
- `actions/setup-node` con Node 26 y la caché del store de pnpm
- Entender por qué el orden de esas dos actions no es negociable
- Leer el output `cache-hit` de `setup-node` en dos ejecuciones seguidas

## 📋 Antes de empezar

Terminaste la [práctica 01](01-pnpm-en-local.md): `pnpm install --frozen-lockfile` sale con 0 en
`web/` y no tienes cambios pendientes.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
```

`web-lab.yml` es un banco de pruebas, como `python-lab.yml` en la Semana 03: solo se lanza a mano.
El workflow que entregas es `ci-web.yml`, en el proyecto de la semana.

---

## Paso 1: El esqueleto, dentro de web/

**Por qué**: todo lo de esta práctica pasa en `web/`. Con `defaults.run.working-directory` lo
dices una vez y cada `run:` empieza ahí. Recuerda la regla de la Semana 03: `defaults.run` solo
afecta a los `run:`. Las actions de los pasos 2 y 3 siguen trabajando desde la raíz del repo, y
por eso sus rutas llevarán `web/` delante.

**Comando**: crea `.github/workflows/web-lab.yml`.

```yaml
name: web-lab

on:
  workflow_dispatch:

# Mínimo privilegio: el token solo lee. Lo verás a fondo en la Semana 12.
permissions:
  contents: read

defaults:
  run:
    shell: bash
    working-directory: web

jobs:
  lab:
    name: pnpm en el runner
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
```

**Verifica**:

```bash
actionlint .github/workflows/web-lab.yml; echo "exit $?"
# exit 0
yq '.defaults.run."working-directory"' .github/workflows/web-lab.yml
# web
```

---

## Paso 2: pnpm en el runner, con la versión de package.json

**Por qué**: la imagen `ubuntu-24.04` no trae pnpm. `pnpm/action-setup` lo instala, y si no le
das `version`, lee `packageManager` del archivo que indica `package_json_file`. Ese input vale
`package.json` por defecto y es relativo a la raíz del repo, donde `tablero` no tiene
`package.json`: sin `package_json_file: web/package.json` el step falla con
`No pnpm version is specified.` No le pongas también `version`: con dos fuentes distintas falla
con `Multiple versions of pnpm specified`. Una sola fuente, `packageManager`, y el número vive en
un único sitio.

**Comando**: añade el step detrás del checkout.

```yaml
      # Antes que setup-node: con cache: pnpm, setup-node ejecuta "pnpm store path".
      - uses: pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413 # v6.1.0
        with:
          package_json_file: web/package.json
```

Los inputs de la v6.1.0 están en su `action.yml` en ese SHA. Compruébalo tú:

```bash
gh api 'repos/pnpm/action-setup/contents/action.yml?ref=ea17c68df8912ef543352723c149a84f56e3d413' \
  --jq .content | base64 -d | yq '.inputs | keys | join(",")'
# version,dest,run_install,cache,cache_dependency_path,package_json_file,standalone
```

**Verifica**:

```bash
yq '.jobs.lab.steps[1].with.package_json_file' .github/workflows/web-lab.yml
# web/package.json
yq '.jobs.lab.steps[1].with | has("version")' .github/workflows/web-lab.yml
# false
```

---

## Paso 3: Node 26 y la caché del store, después de pnpm

**Por qué**: `setup-node` instala Node y, con `cache: pnpm`, restaura el store que guardó un run
anterior. Para saber qué directorio restaurar, su código (`src/cache-utils.ts` en el SHA de la
v7.1.0) ejecuta `pnpm store path --silent`. Si pnpm todavía no existe, no hay a quién
preguntar. La clave de la caché sale del hash del lockfile, que busca en la raíz:
`cache-dependency-path` le dice que está en `web/`.

**Comando**: añade el step detrás de `pnpm/action-setup`.

```yaml
      - id: setup-node
        uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version: "26"
          cache: pnpm
          cache-dependency-path: web/pnpm-lock.yaml
```

`"26"` va entre comillas: es una versión, no un número. El `id` sirve para leer sus outputs en el
paso 4.

**Qué pasa si los pones al revés**. Con `setup-node` antes que `pnpm/action-setup`, el step de
`setup-node` falla al restaurar la caché, antes de que pnpm llegue a instalarse. El mensaje no lo
escribe la action, sino la librería `@actions/exec` que usa para lanzar el comando; está en su
`dist/setup/index.js` en ese SHA:

```
# ... Unable to locate executable file: pnpm. Please verify either the file path exists or the
# file can be found within a directory specified by the PATH environment variable. Also check the
# file mode to verify the file is executable.
```

Si `pnpm` existiera pero no devolviera nada, el mensaje sería el propio de la action:
`Could not get pnpm cache folder path`. Cualquiera de los dos en un log significa lo mismo: mira
el orden de los steps.

**Verifica**:

```bash
actionlint .github/workflows/web-lab.yml; echo "exit $?"
# exit 0
yq '.jobs.lab.steps[].uses | select(. != null)' .github/workflows/web-lab.yml | cut -d@ -f1
# actions/checkout
# pnpm/action-setup
# actions/setup-node
yq '.jobs.lab.steps[2].with.cache' .github/workflows/web-lab.yml
# pnpm
```

`actionlint` no detecta el orden al revés: los dos órdenes son YAML válido. Por eso lo
compruebas tú con el segundo comando.

---

## Paso 4: Instalar, lint, tests, build y el output cache-hit

**Por qué**: son las mismas órdenes de la práctica 01, ahora en el runner. Cada una en su step,
para que el log te diga en cuál falló sin leer cien líneas. El último step lee dos outputs de
`setup-node`: `node-version` (qué 26.x tomó de verdad) y `cache-hit` (si restauró el store). Los
lee por `env:`, como cualquier dato que llega al shell desde una expresión.

**Comando**: añade los steps al final del job.

```yaml
      - name: Qué hay en el runner
        run: |
          echo "pnpm $(pnpm --version), node $(node --version)"
          echo "store: $(pnpm store path)"

      - name: Instalar exactamente el lockfile
        run: pnpm install --frozen-lockfile

      - name: Lint
        run: pnpm lint

      - name: Tests
        run: pnpm test

      - name: Build
        run: pnpm build

      - name: Lo que dice setup-node
        env:
          CACHE_HIT: ${{ steps.setup-node.outputs.cache-hit }}
          NODE_VERSION: ${{ steps.setup-node.outputs.node-version }}
        run: |
          echo "node ${NODE_VERSION}, caché del store encontrada: ${CACHE_HIT}"
```

El último `run:` va en bloque `|` porque el texto lleva `: ` y en una sola línea YAML lo leería
como otra clave.

**Verifica**:

```bash
actionlint .github/workflows/web-lab.yml; echo "exit $?"
# exit 0
uvx zizmor@1.31.1 --offline .github/workflows/web-lab.yml 2>&1 | tail -1
# No findings to report. Good job! ...
yq '.jobs.lab.steps[].run // "" | select(. != "")' .github/workflows/web-lab.yml | grep -c '^pnpm '
# 4
```

Los cuatro `pnpm` de primer nivel son `install`, `lint`, `test` y `build`.

---

## Paso 5: Subirlo, lanzarlo dos veces y leer la caché

**Por qué**: `gh workflow run` solo lanza un workflow que ya está en la rama por defecto (Semana
01, teoría 05). Como `web-lab.yml` no escucha `push`, subirlo no lanza nada: el único run es el
que pides tú. Lo lanzas **dos** veces. En la primera no hay caché con esa clave: `setup-node`
descarga, y al terminar el job en `success` guarda el store. En la segunda la clave coincide
(mismo lockfile, misma rama) y `cache-hit` pasa a `true`.

**Comando**:

```bash
git add .github/workflows/web-lab.yml
git commit -m "ci(lab): add web-lab workflow"
git push
gh workflow run web-lab.yml
sleep 5   # el run tarda unos segundos en aparecer en la lista
id=$(gh run list --workflow web-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status
gh run view "$id" --log | grep -E 'pnpm 12|caché del store' | grep -v '\${'
# pnpm en el runner  Qué hay en el runner  ... pnpm 12.16.1, node v26...
# pnpm en el runner  Lo que dice setup-node  ... node v26..., caché del store encontrada: false
```

Ahora el segundo run:

```bash
gh workflow run web-lab.yml
sleep 5
id=$(gh run list --workflow web-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status
gh run view "$id" --log | grep -E 'caché del store|Cache restored' | grep -v '\${'
# ... Cache restored from key: node-cache-Linux-x64-pnpm-...
# ... caché del store encontrada: true
```

En el log del step de instalación de ese segundo run, la línea `Progress:` dice `downloaded 0`:
todo sale del store restaurado, como en tu máquina en la práctica 01. Las líneas exactas del log
dependen de la imagen del runner; lo que cuenta es `false` en el primero y `true` en el segundo.

La caché que guardó el primer run se ve desde fuera:

```bash
gh cache list --key node-cache-Linux-x64-pnpm --json key,ref --jq '.[] | [.key, .ref] | @tsv'
# node-cache-Linux-x64-pnpm-...  refs/heads/main
```

**Verifica**:

```bash
gh run list --workflow web-lab.yml --event workflow_dispatch --status success \
  --json databaseId --jq length
# 2
```

Es la comprobación `web-lab-dispatched`: pide al menos uno.

---

## ✅ Resultado

- [ ] `web-lab.yml` está en `main` y solo se lanza a mano
- [ ] Todos sus `run:` trabajan dentro de `web/` sin un solo `cd`
- [ ] `pnpm/action-setup` lee la versión de `web/package.json`, sin `version`
- [ ] `setup-node` va **después** de `pnpm/action-setup`, con `cache: pnpm` y el lockfile de `web/`
- [ ] Sabes qué error sale si inviertes el orden y de dónde viene
- [ ] Has visto `cache-hit` en `false` en el primer run y en `true` en el segundo
- [ ] Un run de `web-lab.yml` lanzado a mano terminó en `success`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 04
```

Ya pasan `web-package-manager` y `web-lab-dispatched`.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `gh workflow run` dice `could not find any workflows named web-lab.yml` | El archivo no está en `main`, o está en otra carpeta | `git ls-tree --name-only origin/main .github/workflows/` tiene que listarlo |
| `pnpm/action-setup` falla con `No pnpm version is specified.` | Falta `package_json_file: web/package.json` | Paso 2: la ruta es relativa a la raíz, no a `web/` |
| `pnpm/action-setup` falla con `Multiple versions of pnpm specified` | Pusiste `version` además de `packageManager` | Quita `version` del `with:` (paso 2) |
| `setup-node` falla con `Unable to locate executable file: pnpm` | `setup-node` va antes que `pnpm/action-setup` | Paso 3: invierte el orden |
| `setup-node` falla con `Dependencies lock file is not found` | Falta `cache-dependency-path: web/pnpm-lock.yaml` | Paso 3 |
| `ERR_PNPM_OUTDATED_LOCKFILE` en el runner | Comiteaste un `package.json` sin su lockfile | Práctica 01, paso 4: regenera en local y comitea los dos |
| `cache-hit` sigue en `false` en el segundo run | El primero no terminó en `success` y no guardó, o cambió el lockfile entre runs | `gh cache list` tiene que listar la clave; repite tras un verde |
| El run falla con `startup_failure` | Tienes `sha_pinning_required` activo y una `uses:` va por tag | `scripts/resolve-sha.sh` (Semana 01, práctica 04, paso 3) |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [pnpm en local](01-pnpm-en-local.md) | [Matrices](03-matrices.md) |
