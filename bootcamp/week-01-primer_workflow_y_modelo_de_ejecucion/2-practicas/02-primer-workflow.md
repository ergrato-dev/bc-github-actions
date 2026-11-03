# Práctica 02 — Tu primer workflow

> Un archivo YAML en `.github/workflows/`, un push, y GitHub arranca una máquina
> virtual nueva solo para ti. Esta práctica escribe `hello.yml`, lo ejecuta y lo rompe
> a propósito para que veas qué pasa dentro de un runner.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `hello.yml`, un workflow de un job que corre en cada push a `main` y a mano
- Ver el mismo run en la UI y con `gh run list`
- Descubrir que el runner empieza con el workspace **vacío**
- Ver qué le pasa a un job cuando un step sale con un código distinto de 0

## 📋 Antes de empezar

Terminaste la [práctica 01](01-organizacion-y-repo-tablero.md): tu clon de `<tu-org>/tablero`
está en `~/code/tablero` y el último commit ya está en `origin/main`.

```bash
cd ~/code/tablero
git status -sb
# ## main...origin/main
```

`hello.yml` es un workflow de aprendizaje. El que entregas como proyecto es `ci.yml`, que harás al
final de la semana; `hello.yml` se queda en el repo como banco de pruebas.

---

## Paso 1: Crear hello.yml

**Por qué**: GitHub solo busca workflows en `.github/workflows/` de la raíz del repo, con
extensión `.yml` o `.yaml`. Cada archivo es un workflow independiente. Este tiene las tres partes
mínimas: **cuándo** corre (`on:`), **con qué permisos** (`permissions:`) y **qué** hace (`jobs:`).
`workflow_dispatch` añade el botón *Run workflow* y permite lanzarlo con `gh` (práctica 03).

**Comando**: crea el archivo a mano, sin copiar y pegar a ciegas: escribirlo es parte del
aprendizaje.

```bash
mkdir -p .github/workflows
```

`.github/workflows/hello.yml`:

```yaml
name: hello

on:
  push:
    branches: [main]
  workflow_dispatch:

# Mínimo privilegio: el token de este workflow solo lee. Lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  hello:
    name: Saludo desde el runner
    runs-on: ubuntu-24.04
    steps:
      - name: Quién y qué
        run: echo "$GITHUB_ACTOR $GITHUB_EVENT_NAME $GITHUB_SHA"

      - name: Qué máquina
        run: uname -a
```

Fíjate en tres detalles:

- `workflow_dispatch:` va vacío. En YAML eso es una clave con valor nulo, y GitHub lo lee como
  "activado, sin opciones".
- `runs-on: ubuntu-24.04` y no `ubuntu-latest`: la etiqueta `latest` cambia de imagen cuando
  GitHub decide (teoría 04).
- `$GITHUB_ACTOR`, `$GITHUB_EVENT_NAME` y `$GITHUB_SHA` son variables de entorno que el runner
  define en todo job: quién lanzó el run, qué evento lo disparó y sobre qué commit.

**Verifica**:

```bash
yq '.jobs.hello."runs-on"' .github/workflows/hello.yml
# ubuntu-24.04
yq '.on | keys | join(",")' .github/workflows/hello.yml
# push,workflow_dispatch
```

---

## Paso 2: Push y ver el run

**Por qué**: el push a `main` es el evento que dispara `hello.yml`. GitHub lee el workflow **del
commit que acabas de subir**, pone el job en cola, le asigna una máquina virtual nueva con
Ubuntu 24.04 y ejecuta los steps en orden. Al terminar, la máquina se destruye.

**Comando**:

```bash
git add .github/workflows/hello.yml
git commit -m "ci: add hello workflow"
git push
```

Abre `https://github.com/<tu-org>/tablero/actions`. Verás el workflow `hello` a la izquierda y un
run con el título de tu commit. Entra en el run, después en el job *Saludo desde el runner*, y
despliega cada step. Además de los tuyos hay dos que añade GitHub: **Set up job** (prepara el
runner y descarga lo que haga falta) y **Complete job** (limpia).

Desde la terminal, la misma información:

```bash
gh run list --workflow hello.yml --limit 1
# STATUS  TITLE                    WORKFLOW  BRANCH  EVENT  ID           ELAPSED  AGE
# ✓       ci: add hello workflow   hello     main    push   <run-id>     12s      1m
```

Si la columna `STATUS` muestra `*`, el run sigue en marcha: espera unos segundos y repite.

**Verifica**:

```bash
gh run list --workflow hello.yml --limit 1 --json event,conclusion,headSha \
  --jq '.[0] | .event + " " + .conclusion + " " + .headSha[0:7]'
# push success <sha corto>
git rev-parse --short=7 HEAD
# <el mismo sha corto>
```

El SHA del run coincide con tu último commit: el run corresponde a ese código y a ningún otro.

---

## Paso 3: Un step multilínea y el workspace vacío

**Por qué**: un `run:` puede tener varias líneas con `|` (bloque literal de YAML: conserva los
saltos de línea). El runner las guarda en un script temporal y lo ejecuta con `bash -e`: si una
línea falla, el step se para ahí. Con este step vas a comprobar algo que sorprende la primera
vez: **el runner no tiene tu código**. Es una máquina recién creada y el workspace
(`$GITHUB_WORKSPACE`) existe pero está vacío. Descargar el repo es un step más, que añadirás en la
práctica 04.

**Comando**: añade este step al final de `steps:` en `hello.yml`:

```yaml
      - name: Qué hay en el workspace
        run: |
          echo "Workspace: $GITHUB_WORKSPACE"
          pwd
          ls -A
```

```bash
git add .github/workflows/hello.yml
git commit -m "ci(hello): inspect workspace"
git push
```

**Verifica**:

```bash
RUN_ID=$(gh run list --workflow hello.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run view "$RUN_ID" --log | grep -A3 'Workspace:'
# hello  Qué hay en el workspace  ...  Workspace: /home/runner/work/tablero/tablero
# hello  Qué hay en el workspace  ...  /home/runner/work/tablero/tablero
```

Después de la ruta de `pwd` no aparece ningún archivo: `ls -A` no imprimió nada. Ni `api/`, ni
`web/`, ni siquiera `.github/`. Si el run aún está en marcha, `gh run view --log` responde
`run ... is still in progress`: espera y repite.

---

## Paso 4: Romper un step a propósito

**Por qué**: un step termina bien si su proceso sale con código 0. Con cualquier otro código el
step falla, **los steps siguientes del mismo job no se ejecutan** (salen como *skipped*) y el job
termina en `failure`. Saber leer ese patrón es la mitad de depurar un pipeline.

**Comando**: añade dos steps al final de `hello.yml`:

```yaml
      - name: Un step que falla
        run: |
          echo "Voy a salir con código 3"
          exit 3

      - name: Esto ya no corre
        run: echo "Nunca verás esta línea"
```

```bash
git add .github/workflows/hello.yml
git commit -m "ci(hello): add failing step"
git push
```

En la UI el run sale en rojo. El step *Un step que falla* muestra
`Error: Process completed with exit code 3.` y *Esto ya no corre* aparece tachado.

**Verifica**:

```bash
RUN_ID=$(gh run list --workflow hello.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run view "$RUN_ID" --json jobs \
  --jq '.jobs[0].steps[] | select(.name | test("falla|ya no")) | .name + ": " + .conclusion'
# Un step que falla: failure
# Esto ya no corre: skipped
gh run view "$RUN_ID" --json conclusion --jq .conclusion
# failure
```

Si aparece `Esto ya no corre: success`, el step que falla no salió con error: revisa que `exit 3`
esté dentro de su `run:`.

---

## Paso 5: Arreglarlo

**Por qué**: el run en rojo no se arregla "volviendo a ejecutarlo": un re-run usa el **mismo
commit** y, por tanto, el mismo YAML, y volvería a fallar. El arreglo es un commit nuevo. Ese
commit dispara otro run, con otro ID, y el run en rojo queda en el historial como lo que fue.

**Comando**: borra de `hello.yml` los dos steps del paso 4. El archivo vuelve a tener tres steps:
*Quién y qué*, *Qué máquina* y *Qué hay en el workspace*.

```bash
git add .github/workflows/hello.yml
git commit -m "ci(hello): remove failing step"
git push
```

**Verifica**:

```bash
yq '[.jobs.hello.steps[].name] | join(" | ")' .github/workflows/hello.yml
# Quién y qué | Qué máquina | Qué hay en el workspace
gh run list --workflow hello.yml --limit 3 --json conclusion,displayTitle \
  --jq '.[] | .conclusion + "  " + .displayTitle'
# success  ci(hello): remove failing step
# failure  ci(hello): add failing step
# success  ci(hello): inspect workspace
```

Si el primero aparece vacío, el run sigue en marcha: la conclusión solo existe cuando termina.

---

## ✅ Resultado

- [ ] `.github/workflows/hello.yml` corre en cada push a `main` y a mano
- [ ] Has visto el mismo run en la UI y con `gh run list`
- [ ] Sabes que el workspace del runner empieza vacío
- [ ] Has visto un step fallido: el siguiente queda en `skipped` y el job en `failure`
- [ ] El último run de `hello.yml` en `main` está en verde

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 01
```

El check de `hello.yml` lanzado a mano sigue en rojo: lo cumples en la práctica 03.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| No aparece ningún run tras el push | El archivo no está en `.github/workflows/` de la raíz, o tiene otra extensión | `git ls-files .github/workflows` debe mostrar `.github/workflows/hello.yml` |
| El push falla con `refusing to allow an OAuth App to create or update workflow` | Al token de `gh` le falta el scope `workflow` | `gh auth refresh -s workflow` y repite el push |
| El run sale en rojo al instante con `Invalid workflow file` | Error de sintaxis o de indentación en el YAML | Abre el run: la UI señala la línea. En la práctica 04 aprendes a cazarlo antes con actionlint |
| `gh run list` no muestra nada | Estás fuera de `~/code/tablero` | `cd ~/code/tablero` o exporta `GH_REPO=<tu-org>/tablero` |
| `ls -A` muestra archivos en el workspace | Ya añadiste un `actions/checkout` | Es lo que hace la práctica 04: quítalo de momento |
| El run se queda en `Queued` varios minutos | Cola de GitHub o límite de jobs simultáneos de la org | Espera; mira <https://www.githubstatus.com> si tarda más de 10 minutos |
| `gh run view --log` dice `still in progress` | El log completo solo se puede descargar al terminar | Espera a que acabe y repite |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Organización y repo tablero](01-organizacion-y-repo-tablero.md) | [gh CLI para Actions](03-gh-cli-para-actions.md) |
