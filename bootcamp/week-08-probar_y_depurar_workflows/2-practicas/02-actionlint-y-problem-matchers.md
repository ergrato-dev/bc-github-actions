# Práctica 02 — actionlint y problem matchers

> Hasta hoy actionlint corría cuando te acordabas. En esta práctica lo conviertes en una puerta:
> un job que lo instala con checksum, un problem matcher que convierte su salida en anotaciones y
> un PR con un workflow roto que se queda en rojo con el error marcado en la línea exacta.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- actionlint en verde sobre todos tus workflows, labs incluidos
- `.github/workflows/lint-workflows.yml` con el job `actionlint`: actionlint 1.7.12 descargado de
  su release y comprobado con `sha256sum -c` contra el `digest` que publica GitHub
- `.github/actionlint-matcher.json`, copia exacta del matcher oficial en `v1.7.12`, registrado con
  `::add-matcher::`
- Un filtro de rutas: el workflow solo corre cuando cambian los workflows o el matcher
- Un PR con un workflow inseguro que `lint-workflows` deja en rojo, con su anotación leída desde
  la API, cerrado sin fusionar

## 📋 Antes de empezar

Terminaste la [práctica 01](01-depurar-un-run-que-falla.md): `debug-lab.yml` está en `main`.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
ls .github/workflows/lint-workflows.yml 2>/dev/null || echo "sin lint-workflows"
# sin lint-workflows
```

---

## Paso 1: actionlint en verde en tu máquina

**Por qué**: una puerta nueva tiene que abrirse con lo que ya hay. Si subes el job con un error
pendiente en un lab de hace cuatro semanas, el primer run sale rojo y no sabrás si falla la puerta
o el lab. Sin argumentos, actionlint revisa todo `.github/workflows/`; si tienes `shellcheck` en
el `PATH`, revisa también el shell de cada `run:`, igual que hará en el runner `ubuntu-24.04`, que
lo trae instalado ([teoría 04](../1-teoria/04-problem-matchers-y-actionlint-en-ci.md#qué-caza-actionlint)).

**Comando**: una línea por error, para contarlos y repasarlos de uno en uno.

```bash
actionlint -oneline
# (sin salida si todo está bien)
```

Si sale algo, cada línea dice archivo, línea, columna, mensaje y regla entre corchetes. Lo más
habitual en los labs de semanas anteriores:

| Regla | Qué significa | Arreglo |
|---|---|---|
| `[expression]` con `is potentially untrusted` | Un `${{ github.event.* }}` o `${{ inputs.* }}` dentro de `run:` | Pásalo por `env:` (regla 4 de seguridad) |
| `[shellcheck]` con `SC2086` | Una variable sin comillas en un `run:` | `"$VAR"` en lugar de `$VAR` |
| `[syntax-check]` con `could not parse as YAML` | Un `: ` dentro de un `run:` de una línea | Pasa a `run: \|` o entrecomilla el valor |
| `[runner-label]` | Una etiqueta de runner que no existe | `ubuntu-24.04` |

**Verifica**: la misma orden que `workflows-actionlint`.

```bash
actionlint; echo "exit $?"
# exit 0
```

Si arreglaste algo, súbelo antes de seguir:
`git commit -am "ci: fix actionlint findings in lab workflows" && git push`.

---

## Paso 2: El job `actionlint`, con checksum

**Por qué**: actionlint es un binario de Go sin action oficial, y la regla 9 de seguridad dice
cómo se instala: **versión fijada y checksum**, nunca `bash <(curl ...)`
([teoría 04](../1-teoria/04-problem-matchers-y-actionlint-en-ci.md#actionlint-en-ci-con-checksum)).
El hash no se copia de ningún sitio: lo publica la propia release en el campo `digest` de cada
archivo. Si mañana alguien cambia el tarball, `sha256sum -c` falla y el step para antes de
descomprimir nada.

**Comando**: primero el hash, desde la API.

```bash
gh api repos/rhysd/actionlint/releases/tags/v1.7.12 \
  --jq '.assets[] | select(.name == "actionlint_1.7.12_linux_amd64.tar.gz") | .digest'
# sha256:8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
```

Crea `.github/workflows/lint-workflows.yml`. El filtro de rutas llega en el paso 4 y el job
`zizmor`, en la práctica 03.

```yaml
name: lint-workflows

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

# Un run por workflow y ref: en un PR, el push nuevo cancela el run anterior;
# en main cada commit termina su run.
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  actionlint:
    name: actionlint
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    env:
      ACTIONLINT_VERSION: "1.7.12"
      # Digest del tarball publicado en la release; si el archivo cambia, sha256sum -c falla.
      ACTIONLINT_SHA256: 8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: Instalar actionlint con checksum
        run: |
          archive="actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz"
          curl -fsSLO "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${archive}"
          echo "${ACTIONLINT_SHA256}  ${archive}" | sha256sum -c
          tar -xzf "$archive" actionlint
      - name: actionlint con anotaciones
        run: |
          # El matcher convierte cada línea archivo:línea:col: mensaje en una anotación del PR.
          echo "::add-matcher::.github/actionlint-matcher.json"
          ./actionlint -color
```

Tres detalles: `curl -fsSLO` descarga un archivo, no ejecuta nada; el `set -e` implícito del
shell para el step si `sha256sum -c` falla; y `-color` deja el log legible, porque el matcher
oficial tolera los códigos de color.

**Verifica**: el workflow pasa actionlint, la orden de `actionlint-checksum` lo reconoce y el hash
casa de verdad con el tarball. Esto último lo pruebas en una carpeta temporal, con los mismos
comandos que el step.

```bash
actionlint .github/workflows/lint-workflows.yml; echo "exit $?"
# exit 0
yq '(.jobs.actionlint.env.ACTIONLINT_VERSION // "") + " " + ([.jobs.actionlint.steps[].run // ""] | join(" ") | test("sha256sum -c") | tostring)' .github/workflows/lint-workflows.yml
# 1.7.12 true
tmp=$(mktemp -d) && cd "$tmp"
gh release download v1.7.12 -R rhysd/actionlint -p actionlint_1.7.12_linux_amd64.tar.gz
echo "8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8  actionlint_1.7.12_linux_amd64.tar.gz" | sha256sum -c
# actionlint_1.7.12_linux_amd64.tar.gz: OK
cd ~/code/tablero && rm -rf "$tmp"
```

---

## Paso 3: El problem matcher oficial

**Por qué**: sin matcher, un error de actionlint es una línea más en un log que nadie abre. Con
él, el runner pasa cada línea del log por una expresión regular y crea una anotación con archivo,
línea, columna y mensaje: el error aparece **sobre la línea del diff** del PR
([teoría 04](../1-teoria/04-problem-matchers-y-actionlint-en-ci.md#el-archivo)). No escribes tu
propia regex: la del repo de actionlint ya absorbe los códigos de color. Y la copias del **tag**
`v1.7.12`, no de `main`: el matcher tiene que entender la salida de la versión que instalas.

**Comando**: la API de contenidos devuelve el archivo en base64.

```bash
gh api 'repos/rhysd/actionlint/contents/.github/actionlint-matcher.json?ref=v1.7.12' \
  --jq .content | base64 -d > .github/actionlint-matcher.json
```

El job lo registra con `::add-matcher::` en el mismo step que ejecuta actionlint, después del
checkout: la ruta es relativa al espacio de trabajo y antes del checkout no existe
([teoría 04](../1-teoria/04-problem-matchers-y-actionlint-en-ci.md#registrar-y-retirar)).

**Verifica**: la orden de `actionlint-matcher-file`, la de `actionlint-matcher-registered` y que
la regex casa con una línea real de actionlint.

```bash
jq -r '.problemMatcher[0].owner' .github/actionlint-matcher.json
# actionlint
yq '[.jobs.actionlint.steps[].run // ""] | join(" ")' .github/workflows/lint-workflows.yml | grep -o '::add-matcher::[^"]*'
# ::add-matcher::.github/actionlint-matcher.json
echo '.github/workflows/x.yml:3:5: unexpected key "job" [syntax-check]' \
  | grep -P "$(jq -r '.problemMatcher[0].pattern[0].regexp' .github/actionlint-matcher.json)"
# .github/workflows/x.yml:3:5: unexpected key "job" [syntax-check]
```

`grep -P` entiende la misma sintaxis de grupos que la regex del matcher: si la línea sale, el
runner la habría convertido en anotación.

---

## Paso 4: Solo cuando cambian los workflows

**Por qué**: un PR que toca `api/` no puede romper un workflow, así que no tiene sentido gastar un
runner en lintearlos. El filtro de rutas que aprendiste en la Semana 07 incluye el propio matcher:
si alguien lo cambia, el job tiene que demostrar que sigue funcionando. `workflow_dispatch` se
queda para lanzarlo sobre `main` cuando el último commit no tocó workflows.

**Comando**: sustituye el bloque `on:` por este.

```yaml
on:
  push:
    branches: [main]
    paths:
      - ".github/workflows/**"
      - ".github/actionlint-matcher.json"
  pull_request:
    paths:
      - ".github/workflows/**"
      - ".github/actionlint-matcher.json"
  workflow_dispatch:
```

```bash
actionlint; echo "exit $?"
# exit 0
git add .github/workflows/lint-workflows.yml .github/actionlint-matcher.json
git commit -m "ci: lint workflows with actionlint on every pr"
git push
sleep 10
id=$(gh run list --workflow lint-workflows.yml --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
```

**Verifica**: la orden de `lint-paths` y el log del run, con el checksum comprobado.

```bash
yq '.on.pull_request.paths // [] | join(",")' .github/workflows/lint-workflows.yml
# .github/workflows/**,.github/actionlint-matcher.json
gh run view "$id" --log | grep -F 'tar.gz: OK'
# actionlint  Instalar actionlint con checksum  ...Z actionlint_1.7.12_linux_amd64.tar.gz: OK
```

---

## Paso 5: Un PR que la puerta tiene que parar

**Por qué**: una puerta que nunca has visto en rojo no está probada
([teoría 07](../1-teoria/07-estrategia-de-pruebas-de-workflows.md#probar-que-la-puerta-falla)).
Le das un workflow que funciona pero es inseguro: el título de un PR interpolado en un `run:` es
una inyección de comandos de manual. actionlint lo caza con la regla `expression`.

> ⚠️ **Excepción consciente a la regla 4 de seguridad.** `broken.yml` interpola un dato no
> confiable en `run:` a propósito. Vive solo en la rama `lab/broken-workflow`, que borras al final
> del paso, y solo escucha `workflow_dispatch`: como no está en `main`, nadie puede lanzarlo.
> Nunca lo copies a otro sitio.

**Comando**: la rama, el workflow y el PR.

```bash
git switch -c lab/broken-workflow
```

`.github/workflows/broken.yml`:

```yaml
name: broken

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  greet:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - name: Saludar al PR
        run: echo "Revisando ${{ github.event.pull_request.title }}"
```

```bash
actionlint -oneline .github/workflows/broken.yml
# .github/workflows/broken.yml:16:34: "github.event.pull_request.title" is potentially untrusted. ... [expression]
git add .github/workflows/broken.yml
git commit -m "test: add an unsafe workflow to prove lint-workflows fails"
git push -u origin lab/broken-workflow
gh pr create --title "test: broken workflow for lint-workflows" \
  --body "Workflow roto a propósito (Semana 08, práctica 02). Se cierra sin fusionar."
sleep 15
gh pr checks --watch > /dev/null; echo "exit $?"
# exit 1
```

Esa línea de `-oneline` es justo la forma `archivo:línea:col: mensaje [regla]` que casa con el
matcher.

**Verifica**: el check `actionlint` en rojo y su anotación, con archivo y línea, leída desde la
API del check run. El id del job sale del enlace del check.

```bash
gh pr checks --json workflow,name,bucket --jq '.[] | select(.workflow == "lint-workflows") | "\(.name) \(.bucket)"'
# actionlint fail
link=$(gh pr checks --json name,link --jq '.[] | select(.name == "actionlint") | .link')
gh api "repos/{owner}/{repo}/check-runs/${link##*/}/annotations" \
  --jq '.[] | select(.path != ".github") | "\(.path):\(.start_line)\t\(.message)"'
# .github/workflows/broken.yml:16	"github.event.pull_request.title" is potentially untrusted. ...
```

Abre `gh pr view --web`, pestaña **Files changed**: la anotación está pegada a la línea 16 de
`broken.yml`. Es lo que verá cualquiera que revise un PR así.

> ⚠️ Lo siguiente **cierra el PR sin fusionar y borra `lab/broken-workflow`** en local y en
> GitHub. Solo contiene `broken.yml`; el run rojo se queda en el historial, que es lo que cuenta
> `lint-caught-a-pr`.

```bash
pr=$(gh pr view --json number --jq .number)
git switch main
gh pr close "$pr" --delete-branch
git ls-remote origin refs/heads/lab/broken-workflow | wc -l
# 0
gh pr view "$pr" --json state --jq .state
# CLOSED
gh run list --workflow lint-workflows.yml --event pull_request --status failure --json databaseId --jq length
# 1
```

---

## ✅ Resultado

- [ ] actionlint pasa en local sobre todos tus workflows
- [ ] `lint-workflows.yml` instala actionlint 1.7.12 y comprueba su checksum
- [ ] `.github/actionlint-matcher.json` es la copia del tag `v1.7.12` y el job lo registra
- [ ] `lint-workflows` solo corre cuando cambian los workflows o el matcher
- [ ] Viste el job en verde en `main` y en rojo en un PR, con la anotación en la línea 16
- [ ] El PR está cerrado sin fusionar y su rama borrada

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 08
# ✅ lint-workflows.yml corre en los PR que cambian .github/workflows/
# ✅ El job actionlint instala actionlint 1.7.12 desde su release y comprueba el checksum
# ✅ .github/actionlint-matcher.json es el problem matcher de actionlint
# ✅ El job actionlint registra el problem matcher antes de ejecutar actionlint
# ✅ lint-workflows.yml paró al menos un pull request con un workflow roto
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `actionlint_1.7.12_linux_amd64.tar.gz: FAILED` | `ACTIONLINT_SHA256` no es el del tarball | Paso 2: cópialo de la salida de `gh api`, sin el prefijo `sha256:` |
| `curl: (22) The requested URL returned error: 404` | `ACTIONLINT_VERSION` lleva la `v` delante, y la URL queda con `vv1.7.12` | `ACTIONLINT_VERSION: "1.7.12"`: la `v` ya está en la URL |
| `base64: invalid input` al copiar el matcher | Falta `--jq .content` o las comillas de la URL | Copia la orden del paso 3 tal cual |
| El PR está en rojo pero sin anotaciones | El matcher no se registró o su ruta no existe en el checkout | `::add-matcher::.github/actionlint-matcher.json` en el step de actionlint, tras el checkout |
| `lint-workflows` no aparece en el PR | El PR no toca ninguna ruta del filtro | El PR tiene que cambiar algo bajo `.github/workflows/` |
| `gh pr checks` sale con 8 | Hay checks pendientes todavía | Repite `gh pr checks --watch` |
| `lint-caught-a-pr` cuenta 0 | El run del PR se canceló o terminó en verde | Comprueba con `gh run list --workflow lint-workflows.yml --event pull_request`; repite el paso 5 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Depurar un run que falla](01-depurar-un-run-que-falla.md) | [zizmor: primer contacto](03-zizmor-primer-contacto.md) |
