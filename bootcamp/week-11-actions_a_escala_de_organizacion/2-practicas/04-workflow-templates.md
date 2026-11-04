# Práctica 04 — Workflow templates

> Un repo nuevo de tu organización todavía empieza con `.github/workflows/` vacío, y quien lo
> crea tiene que saber que existe `actions-tablero`, qué SHA fijar y qué reglas cumplir. En esta
> práctica publicas una plantilla de organización que hace todo eso en un clic.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- El repo `<tu-org>/.github`, público
- La plantilla `ci-python` con su `.properties.json`, que llama al `_python.yml` central por SHA
- La comprobación de que el workflow que recibe un repo nuevo pasa actionlint y zizmor
- Una forma de saber si la plantilla se ha quedado atrás respecto a `tablero`

## 📋 Antes de empezar

Terminaste las prácticas [01](01-repo-central-y-primera-release.md) y
[02](02-consumir-el-repo-central.md): `actions-tablero` tiene `v1.0.0` y `tablero` la usa.

```bash
ORG=<tu-org>
SHA=$(gh api "repos/$ORG/actions-tablero/commits/v1.0.0" --jq .sha)
[[ $SHA =~ ^[0-9a-f]{40}$ ]] && echo "SHA válido"
# SHA válido
gh api "repos/$ORG/.github" --silent 2>/dev/null || echo "todavía no existe"
# todavía no existe
```

Es lo esperado: el repo `.github` todavía no existe. Si ya lo tienes (por ejemplo, con
archivos de comunidad), no lo crees de nuevo: salta al paso 2 con un `gh repo clone`.

---

## Paso 1: El repo `.github` de la organización

**Por qué**: GitHub busca las plantillas de una org en un repo con un nombre fijo, `.github`,
dentro de una carpeta `workflow-templates/` **en su raíz**, no dentro de `.github/`
([teoría 05](../1-teoria/05-workflow-templates.md)). En el plan Free, las plantillas de un
`.github` público las ven los repos públicos de la org; si lo haces privado, no aparecen. Lo
clonas en `~/code/org-dot-github` para no tener en `~/code` una carpeta oculta llamada
`.github` que se confunda con la de cualquier repo.

**Comando**:

```bash
gh repo create "$ORG/.github" --public --add-readme \
  --description "Plantillas de workflow y archivos comunes de la organización"
gh repo clone "$ORG/.github" ~/code/org-dot-github
cd ~/code/org-dot-github
```

**Verifica**: la orden de `dot-github-public`:

```bash
gh api "repos/$ORG/.github" --jq .visibility
# public
```

---

## Paso 2: La plantilla y sus metadatos

**Por qué**: cada plantilla son dos archivos con el mismo nombre: el `.yml`, que es lo que se
copia al repo que la adopta, y el `.properties.json`, que es lo que GitHub enseña al elegirla
(`name` y `description` son obligatorias). Tres decisiones:

- **`$default-branch`** en lugar de `main`: GitHub lo sustituye por la rama por defecto del repo
  que adopta la plantilla, se llame como se llame.
- **Un llamador fino**: la plantilla se copia una vez y después no se actualiza. Si llevara los
  steps dentro, cada repo se quedaría con su copia congelada. Así lo que cambia vive en el
  `_python.yml` central y la plantilla solo decide cuándo corre y con qué inputs.
- **Sin `filePatterns`**: filtraría por archivos de la **raíz** del repo, y en `tablero` el
  `pyproject.toml` está en `api/`; un monorepo así no vería la plantilla.

**Comando**: copia el starter y completa los `TODO 7`, `8` y `9`:

```bash
S=~/code/bc-github-actions/bootcamp/week-11-actions_a_escala_de_organizacion/3-proyecto/starter
cp -r "$S"/org-dot-github/workflow-templates .
grep -rnoE 'TODO [0-9]' workflow-templates | sort -t: -k3
# workflow-templates/ci-python.yml:8:TODO 7
# workflow-templates/ci-python.yml:24:TODO 8
# workflow-templates/ci-python.properties.json:2:TODO 9
# workflow-templates/ci-python.properties.json:3:TODO 9
```

`workflow-templates/ci-python.yml` queda así (tu SHA es el de `echo "$SHA"`):

```yaml
# Plantilla de workflow de la organización: CI de un proyecto Python con uv. Se copia a
# <tu-org>/.github como workflow-templates/ci-python.yml. Todo el trabajo lo hace el
# reutilizable central; este archivo solo decide cuándo corre y con qué inputs.
name: ci-python

on:
  push:
    branches: [$default-branch]
  pull_request:
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

permissions:
  contents: read

jobs:
  python:
    name: Python
    uses: <tu-org>/actions-tablero/.github/workflows/_python.yml@<sha-de-v1.0.0> # v1.0.0
    with:
      # Quien adopte la plantilla cambia estos dos valores a los de su proyecto.
      working-directory: .
      package: app
      integration: false
```

`integration: false` porque un repo nuevo no tiene `tests/integration` ni migraciones: con
`true` nacería en rojo. Y `workflow-templates/ci-python.properties.json`:

```json
{
  "name": "CI de Python con uv",
  "description": "Lint con ruff, tests y cobertura usando el reutilizable _python.yml de actions-tablero v1.0.0",
  "categories": ["Python"]
}
```

La `description` cita la versión: quien elige la plantilla sabe qué va a fijar sin abrirla.

**Verifica**: en local, las mismas cuentas que `template-calls-central` y `template-metadata`:

```bash
printf 'default-branch=%s central=%s\n' "$(grep -cF '$default-branch' workflow-templates/ci-python.yml)" \
  "$(grep -cE "uses: $ORG/actions-tablero/\.github/workflows/_python\.yml@$SHA # v" workflow-templates/ci-python.yml)"
# default-branch=1 central=1
jq -r '[.name, .description] | map(select(length > 0 and (test("TODO") | not))) | length' \
  workflow-templates/ci-python.properties.json
# 2
grep -rnE 'TODO [0-9]' workflow-templates | wc -l
# 0
```

El `grep` de `central` usa tu `$SHA`: si escribiste otro a mano, sale `central=0`.

---

## Paso 3: Lo que recibe un repo nuevo

**Por qué**: la plantilla no se ejecuta nunca en `.github`; lo que se ejecuta es la copia que
GitHub crea en el repo que la adopta, con `$default-branch` ya sustituido. Lo compruebas antes
de publicarla: si la copia no pasa actionlint y zizmor, todos los repos que la adopten nacen
con el mismo fallo. Sin `.github/workflows/` en el repo `.github`, nada se dispara al hacer
push aquí.

**Comando**: reproduce la copia en una carpeta temporal y pásale los linters:

```bash
d=$(mktemp -d) && git -C "$d" init -q && mkdir -p "$d/.github/workflows"
sed 's/\$default-branch/main/' workflow-templates/ci-python.yml > "$d/.github/workflows/ci-python.yml"
(cd "$d" && actionlint && zizmor --offline -q .github/); echo "exit $?"
# No findings to report. Good job!
# exit 0
```

`git init` hace falta porque actionlint busca `.github/workflows/` desde la raíz de un repo git.
Si está todo bien, publícala:

```bash
git add workflow-templates
git commit -m "feat(workflow-templates): add ci-python template calling actions-tablero v1.0.0"
git push
```

**Verifica**: lo que lee el autograding, desde la API y no desde tu disco:

```bash
c=$(gh api "repos/$ORG/.github/contents/workflow-templates/ci-python.yml" -H "Accept: application/vnd.github.raw")
printf 'default-branch=%s central=%s\n' "$(grep -cF '$default-branch' <<<"$c")" \
  "$(grep -cE "uses: $ORG/actions-tablero/\.github/workflows/_python\.yml@[0-9a-f]{40} # v" <<<"$c")"
# default-branch=1 central=1
gh api "repos/$ORG/.github/contents/workflow-templates/ci-python.properties.json" \
  -H "Accept: application/vnd.github.raw" | jq -r .name
# CI de Python con uv
```

Para verla como la verá otro, abre la pestaña Actions de un repo público de la org y pulsa
**New workflow**: la plantilla aparece en una sección de tu organización con el `name` y la
`description` del `.properties.json`. El aspecto exacto de esa pantalla cambia con el tiempo.
No la uses en `tablero`: ya tiene su propio `ci-api.yml`.

```bash
gh browse -R "$ORG/tablero" --actions -n
# https://github.com/<tu-org>/tablero/actions
```

---

## Paso 4: Que la plantilla no se quede atrás

**Por qué**: cuando publiques `v1.1.0` de `actions-tablero`, `tablero` subirá con un commit que
cambia sus SHA. La plantilla **no**: es otro repo y nadie la toca si no lo haces tú. Los repos
que ya la adoptaron tampoco cambian (tienen su copia y suben con su propio commit), pero los
repos nuevos arrancarían en una versión vieja. La comprobación es comparar el SHA de la plantilla
con el que fija `tablero`.

**Comando**: guarda la comprobación como función de shell; la repetirás en cada subida de
versión:

```bash
template_lag() {
  local t p
  t=$(gh api "repos/$ORG/.github/contents/workflow-templates/ci-python.yml" -H "Accept: application/vnd.github.raw" \
    | grep -oE "actions-tablero/[^@ ]+@[0-9a-f]{40} # v[0-9.]+" | sed -E 's/.*@//')
  p=$(grep -rhoE "$ORG/actions-tablero/[^@ ]+@[0-9a-f]{40} # v[0-9.]+" ~/code/tablero/.github/workflows | sed -E 's/.*@//' | sort -u)
  if [[ "$t" == "$p" ]]; then echo "plantilla al día: ${t##* }"; else echo "plantilla en ${t##* }, tablero en ${p##* }"; fi
}
```

Cuando toque subir, el cambio en la plantilla es un `sed` del SHA viejo al nuevo, en
`ci-python.yml` y en la versión que cita la `description` del `.properties.json`.

**Verifica**:

```bash
template_lag
# plantilla al día: v1.0.0
```

---

## ✅ Resultado

- [ ] `<tu-org>/.github` existe y es público
- [ ] `workflow-templates/ci-python.yml` filtra por `$default-branch` y llama al `_python.yml` central por SHA
- [ ] `ci-python.properties.json` tiene `name` y `description` propios, sin `TODO`
- [ ] La copia que recibiría un repo nuevo pasa actionlint y zizmor
- [ ] Viste la plantilla en Actions → New workflow de un repo de la org
- [ ] `template_lag` dice que la plantilla está al día

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 11
# ✅ El repo .github de la organización existe y es público
# ✅ workflow-templates/ci-python.properties.json tiene name y description propios, sin TODO
# ✅ La plantilla ci-python.yml filtra por $default-branch y llama al _python.yml central fijado por SHA
#
# 17/17 comprobaciones superadas.
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| La plantilla no aparece en New workflow | `.github` es privado, o la carpeta está en `.github/workflow-templates/` | Paso 1 (público) y `workflow-templates/` en la raíz del repo |
| No aparece aunque el repo es público | Falta el `.properties.json`, o no se llama igual que el `.yml` | `ci-python.yml` + `ci-python.properties.json`, mismo nombre base |
| `jq: error ... parse error` en el paso 2 | JSON inválido: una coma de más tras `categories` | Quita la coma final; `jq . workflow-templates/ci-python.properties.json` lo valida |
| `central=0` en el paso 2 | El SHA no es el de tu `v1.0.0` o falta `# v1.0.0` | Copia el que da `echo "$SHA"` y deja el comentario |
| `default-branch=0` | Escribiste `main` o `"$default-branch"` entre comillas dobles en el shell | En el YAML, `branches: [$default-branch]`, tal cual |
| actionlint falla en el paso 3 con `no project was found in any parent directories` | Falta el `git init` de la carpeta temporal | Repite el bloque entero del paso 3 |
| Un repo que adoptó la plantilla nace en rojo en `Tests unitarios` | Sus `working-directory` y `package` siguen siendo `.` y `app` | Es lo que dice el comentario de la plantilla: hay que cambiarlos al adoptarla |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Políticas de la organización](03-politicas-de-la-organizacion.md) | [Proyecto: capa 11 de tablero](../3-proyecto/README.md) |
