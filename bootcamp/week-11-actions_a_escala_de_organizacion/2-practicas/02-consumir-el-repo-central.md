# Práctica 02 — Consumir el repo central

> `actions-tablero` ya tiene `v1.0.0`, pero `tablero` sigue usando sus copias locales. En esta
> práctica cambias cada llamada al SHA de esa release, borras las copias en el mismo commit y
> compruebas que el CI de `tablero` sigue en verde con el código que vive en otro repo.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `ci-api.yml`, `ci-web.yml` e `images.yml` llamando a los reutilizables de `actions-tablero`
- Los jobs `coverage` de `ci-web.yml` y `sql` de `ci.yml` usando las actions centrales
- `tablero` sin `.github/actions/`, sin `_*.yml` y sin `test-actions.yml`
- Una sola versión del repo central en todo `tablero`, comprobada contra el tag
- `ci`, `ci-api` y `ci-web` en verde sobre `main`

## 📋 Antes de empezar

Terminaste la [práctica 01](01-repo-central-y-primera-release.md): `v1.0.0` de
`actions-tablero` está publicada, es inmutable y su `ci.yml` terminó en verde.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git switch -c ci/central-actions
grep -rlE 'uses: \./' .github/workflows | sort
# .github/workflows/_node.yml
# .github/workflows/_python.yml
# .github/workflows/ci-api.yml
# .github/workflows/ci-web.yml
# .github/workflows/ci.yml
# .github/workflows/images.yml
# .github/workflows/test-actions.yml
```

Siete archivos con referencias locales. Al terminar no quedará ninguno.

---

## Paso 1: La versión que vas a fijar

**Por qué**: todas las referencias al repo central llevan el **mismo** SHA y el mismo tag en
comentario. Si lo resuelves una vez y lo guardas en variables de shell, ningún `sed` de los
pasos siguientes depende de que lo copies bien a mano. El SHA sale de la API, no del
`README.md` del central: el README lo escribiste tú; la API dice a qué commit apunta el tag.

**Comando**:

```bash
ORG=<tu-org>
TAG=v1.0.0
SHA=$(gh api "repos/$ORG/actions-tablero/commits/$TAG" --jq .sha)
~/code/bc-github-actions/scripts/resolve-sha.sh "$ORG/actions-tablero" "$TAG"
# uses: <tu-org>/actions-tablero@<sha-de-v1.0.0> # v1.0.0
```

**Verifica**: es un SHA de commit completo y coincide con el de `resolve-sha.sh`:

```bash
[[ $SHA =~ ^[0-9a-f]{40}$ ]] && echo "SHA válido"
# SHA válido
~/code/bc-github-actions/scripts/resolve-sha.sh "$ORG/actions-tablero" "$TAG" | grep -c "@$SHA "
# 1
```

---

## Paso 2: Los llamadores de los reutilizables

**Por qué**: un reutilizable de otro repo se llama con
`<owner>/<repo>/.github/workflows/<archivo>@<ref>`: la ruta completa, incluida la carpeta
`.github/workflows/` ([teoría 01](../1-teoria/01-un-repo-central-de-ci.md)). Los `with:` y los
`permissions` del job llamador no cambian: el contrato del reutilizable es el mismo que en la
Semana 09, solo cambia de dónde se lee. Y como `_python.yml` y `_node.yml` usan `$/`, su
`setup-tablero` sale de `actions-tablero` en el commit `$SHA`, no del workspace de `tablero`.

**Comando**: una sustitución por línea, con el comentario `# zizmor: ignore[...]` de la Semana 09
incluido (ya no hace falta: no hay `./`). El separador es `|` porque el texto nuevo lleva `#`:

```bash
sed -i -E "s|uses: \./\.github/workflows/(_[a-z]+\.yml).*|uses: $ORG/actions-tablero/.github/workflows/\1@$SHA # $TAG|" \
  .github/workflows/ci-api.yml .github/workflows/ci-web.yml .github/workflows/images.yml
```

El job `python` de `ci-api.yml` queda así:

```yaml
  python:
    name: Python
    uses: <tu-org>/actions-tablero/.github/workflows/_python.yml@<sha-de-v1.0.0> # v1.0.0
```

**Verifica**: la misma cuenta que `tablero-calls-central-reusables`; `images.yml` tiene dos
(imagen de `api` e imagen de `web`):

```bash
for f in ci-api ci-web images; do
  printf '%s=%s ' "$f" "$(grep -cE "uses: $ORG/actions-tablero/\.github/workflows/_[a-z]+\.yml@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+$" .github/workflows/$f.yml)"
done; echo
# ci-api=1 ci-web=1 images=2
```

---

## Paso 3: Las actions en los jobs `coverage` y `sql`

**Por qué**: una action de otro repo se llama con `<owner>/<repo>/<carpeta>@<ref>`. Por eso las
actions están en la raíz del central: `actions-tablero/setup-tablero` se lee solo. En el job
`coverage` de `ci-web.yml` y en el `sql` de `ci.yml` el step es de `tablero`, no de un
reutilizable, así que aquí sí hace falta escribir el repo central entero: `$/` apuntaría a
`tablero`.

**Comando**:

```bash
sed -i -E "s|uses: \./\.github/actions/([a-z-]+).*|uses: $ORG/actions-tablero/\1@$SHA # $TAG|" \
  .github/workflows/ci-web.yml .github/workflows/ci.yml
```

El job `sql` de `ci.yml`:

```yaml
      - uses: <tu-org>/actions-tablero/sql-lint@<sha-de-v1.0.0> # v1.0.0
        with:
          path: api/migrations
          # La migración alinea las columnas con espacios y LT01 las marcaría todas.
          exclude-rules: LT01
```

**Verifica**:

```bash
yq '.jobs.coverage.steps[].uses | select(.)' .github/workflows/ci-web.yml | sed -E 's/@[0-9a-f]{40}/@<sha>/'
# actions/checkout@<sha>
# <tu-org>/actions-tablero/setup-tablero@<sha>
# <tu-org>/actions-tablero/coverage-report@<sha>
yq '.jobs.sql.steps[].uses' .github/workflows/ci.yml | sed -E 's/@[0-9a-f]{40}/@<sha>/'
# actions/checkout@<sha>
# <tu-org>/actions-tablero/sql-lint@<sha>
```

`yq` no enseña el `# v1.0.0`: es un comentario, no parte del valor.

---

## Paso 4: Borrar las copias locales

**Por qué**: si las copias se quedan, conviven dos versiones del CI y nadie sabe cuál es la
buena; la próxima corrección se hará en una y no en la otra. Se borran **en el mismo commit**
que cambia los llamadores: así ningún commit de `main` queda a medias
([teoría 01](../1-teoria/01-un-repo-central-de-ci.md)). `test-actions.yml` también se va: lo
que probaba lo prueba ahora el `ci.yml` del central. Y los filtros `paths` que apuntaban a esas
rutas se quitan: no rompen nada, pero engañan a quien los lee.

> ⚠️ **Vas a borrar las actions y los reutilizables de `tablero`.** El respaldo es doble: están
> en `main` (esta rama no lo toca hasta el merge) y en `actions-tablero`. Si necesitas
> recuperar algo antes del merge: `git restore --source=main --staged --worktree .github/`.
> Después del merge, `git checkout <commit-anterior> -- .github/actions`.

**Comando**:

```bash
git rm -r -q .github/actions .github/workflows/_python.yml .github/workflows/_node.yml \
  .github/workflows/_image.yml .github/workflows/test-actions.yml
git status --short --ignored .github/actions | grep '^!!'
# !! .github/actions/
rm -rf .github/actions
sed -i -E '/^ +- "\.github\/(actions\/[a-z-]+\/\*\*|workflows\/_[a-z]+\.yml)"$/d' \
  .github/workflows/ci-api.yml .github/workflows/ci-web.yml .github/workflows/images.yml
```

`git rm` solo quita lo comiteado: si instalaste dependencias en la Semana 10, el `node_modules/`
ignorado de `coverage-report` deja la carpeta en disco (`!!` es "ignorado") y el check
`no-local-copies` la vería. El `rm -rf` borra solo eso.

**Verifica**:

```bash
find .github -path .github/actions -o -name '_*.yml' -o -name test-actions.yml | wc -l
# 0
yq '.on.push.paths | join(" ")' .github/workflows/ci-web.yml
# web/** .github/workflows/ci-web.yml
cat .github/workflows/{ci-api,ci-web,images}.yml | grep -cE '"\.github/(actions|workflows/_)'
# 0
```

---

## Paso 5: Una sola versión, la del tag

**Por qué**: siete referencias al central con el mismo SHA son una versión; si una se queda
atrás, `tablero` corre dos versiones a la vez y un fallo depende de qué job mires
([teoría 03](../1-teoria/03-versionar-actions.md)). Y el SHA tiene que ser **el commit del
tag** que dice el comentario: un `# v1.0.0` junto a otro SHA es una mentira que nadie detecta a
simple vista.

**Comando**: lista cada pareja SHA + tag distinta y cuántas veces aparece:

```bash
grep -rhoE "$ORG/actions-tablero/[^@ ]+@[0-9a-f]{40} # v[0-9]+\.[0-9]+\.[0-9]+" .github/workflows \
  | sed -E 's/.*@//' | sort | uniq -c
#       7 <sha-de-v1.0.0> # v1.0.0
```

Siete: dos en `images.yml`, tres en `ci-web.yml` (reutilizable, `setup-tablero` y
`coverage-report`), una en `ci-api.yml` y una en `ci.yml`.

**Verifica**: una sola pareja, y el SHA es el que devuelve la API para ese tag:

```bash
ref=$(grep -rhoE "$ORG/actions-tablero/[^@ ]+@[0-9a-f]{40} # v[0-9.]+" .github/workflows | sed -E 's/.*@//' | sort -u)
wc -l <<<"$ref"
# 1
test "$(gh api "repos/$ORG/actions-tablero/commits/${ref##* }" --jq .sha)" = "${ref%% *}" && echo "SHA = commit de ${ref##* }"
# SHA = commit de v1.0.0
```

---

## Paso 6: actionlint y zizmor

**Por qué**: `tablero` ya no tiene ningún `./` ni ningún `$/`, así que no necesita la excepción
de `actionlint.yaml` del central ni los `# zizmor: ignore[self-repository]`. Lo que sí hace
actionlint con un reutilizable remoto es comprobar la sintaxis de la llamada; los inputs del
reutilizable no los ve, porque no descarga el archivo. Eso lo comprueba el run del paso 7.

**Comando**:

```bash
actionlint && zizmor --offline -q .github/; echo "exit $?"
# No findings to report. Good job! (3 suppressed)
# exit 0
```

**Verifica**: ningún `uses:` remoto sin SHA (la orden de `actions-pinned`) y ninguna referencia
local:

```bash
grep -rhE '^\s*-?\s*uses:' .github/workflows --include='*.yml' | grep -vE 'uses: \./|@[0-9a-f]{40} # v' | wc -l
# 0
grep -rlE 'uses: (\./|\$/)' .github/workflows | wc -l
# 0
```

---

## Paso 7: Push, PR y runs en verde

**Por qué**: actionlint no sabe si el reutilizable remoto acepta tus inputs ni si `$/` resuelve
la action desde otro repo: eso solo lo demuestra un run real. El PR ejecuta `ci-api`, `ci-web`,
`images` y `ci` porque sus archivos cambiaron y están en sus propios `paths`; el merge los
vuelve a ejecutar sobre `main`.

**Comando**:

```bash
git add -A .github/workflows
git commit -m "ci: consume actions-tablero $TAG and drop local copies"
git push -u origin ci/central-actions
gh pr create --fill
gh pr checks --watch > /dev/null; echo "exit $?"
# exit 0
gh pr merge --squash --delete-branch
git switch main && git pull --ff-only
sha=$(git rev-parse HEAD)
for w in ci ci-api ci-web; do
  gh run watch "$(gh run list --workflow $w.yml --commit "$sha" --json databaseId --jq '.[0].databaseId')" --exit-status > /dev/null
done
```

Si quieres verlo, abre el log del job `Tests unitarios` de `ci-api`: en `Set up job` GitHub
lista lo que descarga antes de empezar; busca ahí `actions-tablero`. El `$/` de `_python.yml`
se resolvió contra el repo central, no contra `tablero`.

**Verifica**:

```bash
for w in ci ci-api ci-web; do
  printf '%s=%s ' "$w" "$(gh run list --workflow $w.yml --commit "$sha" --json conclusion --jq '.[0].conclusion')"
done; echo
# ci=success ci-api=success ci-web=success
```

---

## ✅ Resultado

- [ ] `ci-api.yml`, `ci-web.yml` e `images.yml` llaman a los reutilizables centrales por SHA
- [ ] Los jobs `coverage` y `sql` usan las actions centrales por SHA
- [ ] `tablero` no tiene `.github/actions/`, `_*.yml` ni `test-actions.yml`
- [ ] Una sola pareja SHA + tag, y el SHA es el commit del tag
- [ ] `actionlint && zizmor --offline -q .github/` sin hallazgos
- [ ] `ci`, `ci-api` y `ci-web` en verde sobre el último commit de `main`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 11
# ✅ ci-api.yml, ci-web.yml e images.yml llaman a los reutilizables de actions-tablero fijados por SHA con el tag en comentario
# ✅ tablero ya no guarda copias locales: ni .github/actions/, ni reutilizables _*.yml, ni test-actions.yml
# ✅ Todas las referencias de tablero al repo central fijan el mismo SHA y el mismo tag
# ✅ ci, ci-api y ci-web terminan en success sobre el último commit de main, ya con el repo central
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `Can't find 'action.yml', 'action.yaml' or 'Dockerfile' under '.../.github/actions/setup-tablero'` | El `_python.yml` de la release sigue con `./` | Práctica 01, paso 2; nueva release (`v1.0.1`) y repite el paso 1 aquí |
| `no-local-copies` en rojo con todo borrado en git | Queda `.github/actions/coverage-report/node_modules/` en disco | `rm -rf .github/actions` (paso 4) |
| `single-central-version` da 2 | Un `sed` corrió con otro `$SHA` o editaste una línea a mano | El `uniq -c` del paso 5 dice qué pareja sobra; `grep -rn` la localiza y la corriges con el `$SHA` del paso 1 |
| `pinned-sha-matches-tag` en rojo | El SHA no es el commit de `v1.0.0` (por ejemplo, el del objeto tag anotado) | Paso 1: el SHA sale de `commits/$TAG` o de `resolve-sha.sh` |
| `ci-web=` vacío en la verificación | El squash no tocó `ci-web.yml` o el run aún no existe | Espera unos segundos; si sigue vacío, `gh workflow run ci-web.yml --ref main` |
| El job llamador falla al leer el reutilizable remoto | `actions-tablero` no es público | `gh repo edit <tu-org>/actions-tablero --visibility public --accept-visibility-change-consequences` |
| `ci-api` en rojo por un input que no existe | El reutilizable central cambió su contrato respecto a la Semana 09 | Compara con `gh api "repos/$ORG/actions-tablero/contents/.github/workflows/_python.yml?ref=$TAG" -H 'Accept: application/vnd.github.raw'` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Repo central y primera release](01-repo-central-y-primera-release.md) | [Políticas de la organización](03-politicas-de-la-organizacion.md) |
