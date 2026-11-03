# Práctica 04 — Límites y depuración

> Los tres reutilizables funcionan, pero hay cuatro fallos que no se ven hasta que pasan: un
> cambio en el reutilizable que ningún run prueba, un permiso que no alcanza, una `concurrency`
> que se cancela a sí misma y un `timeout-minutes` en el sitio equivocado. En esta práctica los
> provocas en una rama de prueba y cierras la semana con la puerta de linters.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Los `paths` de `ci-api`, `ci-web` e `images` con su reutilizable, en `push` y en `pull_request`
- Un PR que solo toca `_python.yml` y aun así lanza `ci-api`
- Un run de `images` que no arranca por falta de `packages: write`, y el porqué
- La trampa de `concurrency` con `github.workflow` y la de `timeout-minutes` en el job que llama
- `actionlint && zizmor --offline` en verde, con los cuatro `ignore` explicados

## 📋 Antes de empezar

Terminaste la [práctica 03](03-secretos-y-outputs.md): los tres reutilizables y sus llamadores
están en `main`.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
ls .github/workflows/_*.yml
# .github/workflows/_image.yml  .github/workflows/_node.yml  .github/workflows/_python.yml
```

---

## Paso 1: Los `paths` siguen al reutilizable

**Por qué**: GitHub decide si dispara `ci-api` mirando los archivos que cambia el push o el PR, y
no sabe que `ci-api.yml` usa `_python.yml`. Con los `paths` de la Semana 07, un PR que solo toca
el reutilizable no dispara a nadie: el cambio entra sin que ningún run lo pruebe y el fallo
aparece en el siguiente PR que toque `api/` ([teoría 06](../1-teoria/06-limites-y-depuracion.md#los-paths-no-siguen-las-llamadas)).
Cada llamador lista su reutilizable, en `push` y en `pull_request`.

**Comando**: en una rama, cada llamador gana una línea en sus dos listas de `paths`.

```bash
git switch -c ci/reusable-paths
sed -i 's|^      - "\.github/workflows/ci-api\.yml"$|&\n      - ".github/workflows/_python.yml"|' .github/workflows/ci-api.yml
sed -i 's|^      - "\.github/workflows/ci-web\.yml"$|&\n      - ".github/workflows/_node.yml"|' .github/workflows/ci-web.yml
sed -i 's|^      - "\.github/workflows/images\.yml"$|&\n      - ".github/workflows/_image.yml"|' .github/workflows/images.yml
```

(En macOS, `sed -i ''`.) El `on:` de `ci-api.yml` queda así; los otros dos, igual con `_node.yml`
e `_image.yml`:

```yaml
on:
  push:
    branches: [main]
    paths:
      - "api/**"
      - ".github/workflows/ci-api.yml"
      - ".github/workflows/_python.yml"
  pull_request:
    paths:
      - "api/**"
      - ".github/workflows/ci-api.yml"
      - ".github/workflows/_python.yml"
  workflow_dispatch:
```

**Verifica**: la orden de `paths-include-reusable` no imprime nada. Luego el PR y `main`: el
commit toca los tres llamadores, así que los tres corren sobre él.

```bash
for p in ci-api:_python ci-web:_node images:_image; do w=${p%%:*}; r=${p#*:}; for e in push pull_request; do yq ".on.$e.paths // [] | contains([\".github/workflows/$r.yml\"])" .github/workflows/$w.yml | grep -qx true || echo "$w $e: falta .github/workflows/$r.yml"; done; done
# (sin salida)
git commit -am "ci: trigger callers when their reusable workflow changes"
git push -u origin ci/reusable-paths
gh pr create --fill
```

Con el PR en verde:

```bash
gh pr merge --squash --delete-branch
git switch main && git pull --ff-only
sleep 10
for w in ci-api ci-web images; do
  id=$(gh run list --workflow "$w.yml" --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')
  gh run watch "$id" --exit-status > /dev/null && echo "$w ok"
done
# ci-api ok
# ci-web ok
# images ok
```

---

## Paso 2: Un PR que solo toca el reutilizable

**Por qué**: es la prueba de que el paso 1 sirve. Esta rama es **de prueba**: la usas en los
pasos 2 a 4 para provocar fallos y la cierras sin fusionar. Un PR en borrador (`--draft`) deja
claro que no es para revisar.

**Comando**: un cambio inocuo, solo en la descripción de un input de `_python.yml`.

```bash
git switch -c test/reusable-limits
sed -i 's/en porcentaje$/en porcentaje (0-100)/' .github/workflows/_python.yml
git diff --stat
#  .github/workflows/_python.yml | 2 +-
#  1 file changed, 1 insertion(+), 1 deletion(-)
git commit -am "test: touch only the python reusable workflow"
git push -u origin test/reusable-limits
gh pr create --draft --fill
sleep 15
```

**Verifica**: corren `ci-api`, por su nuevo `paths`, y `lint-workflows`, por `.github/workflows/**`.
Ni `ci-web` ni `images`.

```bash
gh run list --branch test/reusable-limits --json workflowName --jq '[.[].workflowName] | unique | join(",")'
# ci-api,lint-workflows
```

---

## Paso 3: Un permiso que no alcanza

**Por qué**: `_image.yml` declara en su raíz `packages: write`, y un reutilizable solo puede
mantener o bajar lo que le da el job que llama. Si `api` en `images.yml` deja de concederlo, la
llamada no valida y GitHub no crea ningún job
([teoría 05](../1-teoria/05-contexto-permisos-y-concurrencia.md#permisos-que-solo-bajan)).
Ningún linter lo ve: actionlint y zizmor pasan en verde. El aviso llega solo del run.

**Comando**: borra la primera línea `packages: write` de `images.yml`, la del job `api`.

```bash
sed -i '0,/^      packages: write$/{//d}' .github/workflows/images.yml
yq '[.jobs.api.permissions.packages // "sin permiso", .jobs.web.permissions.packages] | join(",")' .github/workflows/images.yml
# sin permiso,write
actionlint && zizmor --offline -q .github/workflows/ > /dev/null && echo "linters ok"
# linters ok
git commit -am "test: drop packages write from the api image caller"
git push
sleep 15
```

(Ese `sed` es de GNU; en macOS borra la línea a mano.)

**Verifica**: el run de `images` de la rama falla sin llegar a ejecutar ningún job. Abre su
página en la UI: arriba explica qué job pide un permiso que no se le concede.

```bash
gh run list --branch test/reusable-limits --workflow images.yml --limit 1 --json conclusion --jq '.[0].conclusion'
# failure
```

Deshazlo para que el siguiente experimento no herede el fallo:

```bash
git revert --no-edit HEAD && git push
yq '.jobs.api.permissions.packages' .github/workflows/images.yml
# write
```

---

## Paso 4: Dos trampas en la frontera

**Por qué**: las dos vienen de copiar al sitio equivocado algo que en un llamador es correcto.

La primera es `timeout-minutes` en el job que llama. Ese job no tiene runner, así que no hay
nada que cronometrar, y actionlint lo para
([teoría 02](../1-teoria/02-llamar-a-un-reutilizable.md#timeout-minutes-va-en-los-jobs-del-reutilizable)).
Su lista de claves admitidas se queda corta (no nombra `strategy` ni `concurrency`, que GitHub
sí acepta), pero el error es real.

La segunda es una `concurrency` con `github.workflow` dentro del reutilizable. Dentro de
`_python.yml`, `github.workflow` vale `ci-api`, porque el contexto `github` es el del llamador:
el grupo sale idéntico al de `ci-api.yml` y, con `cancel-in-progress: true`, el reutilizable
cancela a su propio llamador ([teoría 05](../1-teoria/05-contexto-permisos-y-concurrencia.md#concurrency-y-el-interbloqueo-de-githubworkflow)).
Ningún linter lo ve.

**Comando**: la primera, en local y sin commit.

```bash
sed -i 's|^    uses: ./.github/workflows/_python.yml.*|&\n    timeout-minutes: 30|' .github/workflows/ci-api.yml
actionlint 2>&1 | head -1
# .github/workflows/ci-api.yml:31:5: when a reusable workflow is called with "uses", "timeout-minutes" is not available. only following keys are allowed: "name", "uses", "with", "secrets", "needs", "if", and "permissions" in job "api" [syntax-check]
git restore .github/workflows/ci-api.yml
```

La segunda, en la rama de prueba. Escribe en `_python.yml`, justo encima de `permissions:`:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

```bash
actionlint && zizmor --offline -q .github/workflows/ > /dev/null && echo "linters ok"
# linters ok
git commit -am "test: add caller-like concurrency to the python reusable"
git push
sleep 15
id=$(gh run list --branch test/reusable-limits --workflow ci-api.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" > /dev/null
gh run view "$id" --json conclusion --jq '.conclusion'
# cancelled
```

Nadie empujó un commit nuevo y el run no termina en verde. En su página tienes el grupo y el
motivo.

> ⚠️ Lo siguiente cierra el PR de prueba y **borra la rama** en local y en GitHub. Nada de ella
> va a `main`: lo que importa ya está fusionado en el paso 1.

```bash
gh pr close test/reusable-limits --delete-branch
git switch main && git pull --ff-only
```

**Verifica**: en `main`, ningún reutilizable declara `concurrency`; solo los llamadores.

```bash
for f in _python _node _image; do printf '%s: %s\n' "$f" "$(yq '.concurrency // "sin concurrency"' .github/workflows/$f.yml)"; done
# _python: sin concurrency
# _node: sin concurrency
# _image: sin concurrency
git branch --list 'test/*'
# (sin salida)
```

---

## Paso 5: La puerta de linters

**Por qué**: es la orden de `workflows-lint` y la misma que `lint-workflows.yml` (Semana 08) ya
corre en cada PR, porque los reutilizables viven en `.github/workflows/`, que está en sus
`paths` ([teoría 06](../1-teoria/06-limites-y-depuracion.md#2-zizmor-la-misma-puerta)).

Los **cuatro ignorados** son los `# zizmor: ignore[self-repository]` de las cuatro llamadas
(`ci-api`, `ci-web` y las dos de `images`). zizmor 1.31.1 propone la sintaxis `$/` de GitHub
para llamar a un archivo del mismo repo, pero actionlint 1.7.12 no la conoce y la rechaza
([rhysd/actionlint#711](https://github.com/rhysd/actionlint/issues/711)). Las dos herramientas no
pueden quedar en verde a la vez sin el comentario, y la regla del bootcamp es que las dos pasen.
El comentario dice por qué, y no se silencia nada más. El día que actionlint acepte `$/`, se
cambia `./` por `$/` y se quitan los cuatro.

**Comando**: la puerta, y lo que pasa sin uno de los `ignore` y con `$/`, en local.

```bash
actionlint && zizmor --offline .github/workflows/
# No findings to report. Good job! (4 ignored, 6 suppressed)
sed -i 's| # zizmor: ignore\[self-repository\].*||' .github/workflows/ci-api.yml
zizmor --offline .github/workflows/ci-api.yml 2>&1 | grep -E '^help|-->|instead'
# help[self-repository]: use GitHub's dedicated self-repository syntax
#   --> .github/workflows/ci-api.yml:30:11
#    |           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ use '$/...' instead of './...'
zizmor --offline -q .github/workflows/ci-api.yml > /dev/null 2>&1; echo "exit $?"
# exit 12
sed -i 's|uses: \./\.github|uses: $/.github|' .github/workflows/ci-api.yml
actionlint 2>&1 | head -1
# .github/workflows/ci-api.yml:30:11: reusable workflow call "$/.github/workflows/_python.yml" at "uses" is not following the format "owner/repo/path/to/workflow.yml@ref" nor "./path/to/workflow.yml". see https://docs.github.com/en/actions/learn-github-actions/reusing-workflows for more details [workflow-call]
git restore .github/workflows/ci-api.yml
```

Fíjate en el código 12: el hallazgo es solo `help`, pero zizmor sale con error igual, y con él
`lint-workflows` y `workflows-lint`. Por eso no basta con "es solo una sugerencia".

**Verifica**: el árbol limpio y la puerta en verde.

```bash
git status --short
# (sin salida)
actionlint && zizmor --offline -q .github/workflows/ > /dev/null; echo "exit $?"
# exit 0
```

---

## ✅ Resultado

- [ ] Los `paths` de `ci-api`, `ci-web` e `images` incluyen su reutilizable en `push` y en `pull_request`
- [ ] Un PR que solo tocó `_python.yml` lanzó `ci-api`
- [ ] Viste fallar `images` sin jobs al quitar `packages: write` del job que llama
- [ ] Sabes por qué `timeout-minutes` y `concurrency` no van donde los pusiste en el paso 4
- [ ] Ningún reutilizable de `main` declara `concurrency` y la rama de prueba ya no existe
- [ ] `actionlint && zizmor --offline .github/workflows/` termina en verde con 4 ignorados

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 09
# ✅ _python.yml, _node.yml e _image.yml solo se disparan con workflow_call
# ✅ Los filtros paths de ci-api, ci-web e images, en push y en pull_request, incluyen el reutilizable que llaman
# ✅ Todos tus workflows pasan actionlint y zizmor
# ✅ ci-api, ci-web e images terminaron en success sobre el último commit de main
# ...
# 18/18 comprobaciones superadas.
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El PR del paso 2 no lanza `ci-api` | El paso 1 no llegó a `main` o falta `_python.yml` en `pull_request.paths` | Repite la orden de verificación del paso 1 en `main` |
| `paths-include-reusable` en rojo solo para `push` | Añadiste el reutilizable en una sola lista | Paso 1: el `sed` cambia las dos líneas del llamador |
| `images` falla en la rama y no lo provocaste tú | El `revert` del paso 3 no se empujó | `git log --oneline -3` y `git push` |
| `when a reusable workflow is called with "uses", "timeout-minutes" is not available` | `timeout-minutes` en el job que llama | Muévelo a cada job del reutilizable |
| `ci-api` se cancela solo al empezar | Una `concurrency` con `github.workflow` en `_python.yml` | Quítala: la `concurrency` vive en los llamadores |
| zizmor sale con código 12 | Falta un `# zizmor: ignore[self-repository]` en una llamada | Paso 5: el comentario en la misma línea del `uses:` |
| `callers-green-on-main` en rojo | El último commit de `main` no tocó los tres llamadores | `gh workflow run <workflow>.yml --ref main` para el que falte |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Secretos y outputs](03-secretos-y-outputs.md) | [Proyecto: capa 09 de tablero](../3-proyecto/README.md) |
