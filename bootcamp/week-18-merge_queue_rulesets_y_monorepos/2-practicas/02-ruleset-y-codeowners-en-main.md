# Práctica 02 — Ruleset y CODEOWNERS en main

> Hasta hoy `main` aceptaba cualquier push, incluido un force push que reescribe la historia.
> En esta práctica le pones dueños a las rutas que gobiernan el CI y el despliegue, escribes el
> ruleset de `main` como código, lo aplicas con la API y compruebas que de verdad frena lo que
> dice frenar.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `.github/CODEOWNERS` con dueño para `/.github/` y `/ops/`, sin errores según GitHub
- `ops/github/ruleset-main.yaml`: sin borrado, sin force push, PR obligatorio sin aprobaciones,
  `ci-gate` de GitHub Actions como único check y nadie con bypass
- El ruleset activo sobre `main`, leído desde `rules/branches/main`
- La prueba de que un push directo, un force push y un PR con `ci-gate` en rojo no entran

## 📋 Antes de empezar

Terminaste la [práctica 01](01-un-solo-check-para-un-monorepo.md): `ci-gate` ya corrió en verde
en `tablero`, así que GitHub lo conoce como check. Leíste las teorías
[01](../1-teoria/01-de-ramas-protegidas-a-rulesets.md),
[02](../1-teoria/02-las-reglas-de-un-ruleset.md) y
[06](../1-teoria/06-codeowners-y-revision-en-equipo.md).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
S=~/code/bc-github-actions/bootcamp/week-18-merge_queue_rulesets_y_monorepos/3-proyecto/starter
gh api 'repos/{owner}/{repo}/rulesets' --jq length
# 0
git switch -c ruleset-main
```

Si el `length` no da `0`, tienes un ruleset de una prueba anterior: míralo con
`gh api 'repos/{owner}/{repo}/rulesets'` antes de seguir, porque los rulesets se suman.

---

## Paso 1: CODEOWNERS para `.github/` y `ops/`

**Por qué**: `.github/` decide qué corre y con qué permisos; `ops/` guarda el ruleset que estás
a punto de escribir. Un cambio ahí cambia cómo se protege `tablero`, así que tiene dueño. Hoy
trabajas solo y el ruleset no exige la aprobación del dueño, pero GitHub ya pedirá su revisión en
cada PR que toque esas rutas, y un equipo solo tendría que activar `require_code_owner_review`
([teoría 06](../1-teoria/06-codeowners-y-revision-en-equipo.md#la-revisión-de-un-equipo)). Dos
detalles muerden: el dueño necesita permiso de escritura en el repo, y una línea inválida se
ignora sin avisar en el PR. Por eso se pregunta a la API.

**Comando**: copia el starter y rellena el **TODO 10** con tu usuario de GitHub:

```bash
cp "$S/.github/CODEOWNERS" .github/CODEOWNERS
```

Las dos líneas que añades, debajo de los comentarios de cabecera:

```text
/.github/ @<tu-usuario>
/ops/ @<tu-usuario>
```

La barra inicial ancla el patrón a la raíz del repo: `/ops/` no casa con `api/ops/`.

```bash
git add .github/CODEOWNERS
git commit -m "chore: add CODEOWNERS for .github and ops"
git push -u origin ruleset-main
```

**Verifica**: la orden de `codeowners` y la de `codeowners-valid`, esta contra tu rama, porque
todavía no está en `main`:

```bash
grep -E '^/' .github/CODEOWNERS
# /.github/ @<tu-usuario>
# /ops/ @<tu-usuario>
gh api 'repos/{owner}/{repo}/codeowners/errors?ref=ruleset-main' --jq '.errors | length'
# 0
```

Si da más de `0`, lee el motivo de cada línea con
`--jq '.errors[] | "\(.line): \(.kind) \(.message)"'`. Lo habitual es un usuario mal escrito.

---

## Paso 2: El ruleset como código

**Por qué**: un ruleset hecho a golpe de clic no tiene historia ni revisión. En
`ops/github/ruleset-main.yaml` se lee, se revisa en un PR (con su dueño, por el paso 1) y se
aplica con un comando. Cada regla frena un riesgo
([teoría 02](../1-teoria/02-las-reglas-de-un-ruleset.md)): `deletion` impide borrar `main`,
`non_fast_forward` impide reescribirla, `pull_request` obliga a pasar por PR y
`required_status_checks` exige `ci-gate`. Tres decisiones son tuyas en los TODO:

- **Nadie se lo salta** (TODO 11). El starter trae el rol admin (`RepositoryRole` con id `5`)
  como bypass, que es justo tu rol. Con él, el ruleset solo frenaría a los demás. Si un día
  `ci-gate` se rompe, se arregla con otro PR.
- **0 aprobaciones** (TODO 12). GitHub no te deja aprobar tu propio PR: con `1` no podrías
  fusionar nada. La revisión de un equipo está en la teoría 06.
- **`ci-gate` de GitHub Actions** (TODO 13). `integration_id` ata el check a la app que lo
  emite: un status llamado `ci-gate` publicado por otra integración con permiso de escritura en
  statuses no cuenta.

**Comando**: copia el starter y comprueba el id de la app de GitHub Actions:

```bash
mkdir -p ops/github
cp "$S/ops/github/ruleset-main.yaml" ops/github/
gh api apps/github-actions --jq '"\(.id) \(.slug)"'
# 15368 github-actions
```

Rellena los **TODO 11, 12 y 13**. Las tres partes quedan así:

```yaml
# Nadie se salta el ruleset, tampoco el admin: si ci-gate se rompe, se arregla con otro PR.
bypass_actors: []
```

```yaml
      # Trabajas solo y no puedes aprobar tus PR. En un equipo: 1, con code owners y last push.
      required_approving_review_count: 0
```

```yaml
      required_status_checks:
        # 15368 es GitHub Actions: un status con el mismo nombre desde otra app no cuenta.
        - context: ci-gate
          integration_id: 15368
```

Deja el **TODO 14** (la merge queue) para la práctica 03: antes, `ci.yml` tiene que escuchar
`merge_group`.

Abre el PR y fusiónalo: es el último que entra sin ruleset.

```bash
git add ops/github/ruleset-main.yaml
git commit -m "chore: add main ruleset as code"
git push
gh pr create --title "chore: add main ruleset and CODEOWNERS" --body "Capa 18, práctica 02."
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch > /dev/null; gh pr merge "$pr" --squash --delete-branch
git switch main && git pull --ff-only
```

**Verifica**: ya en `main`, lo que el ruleset dice, leído como lo leerá la API:

```bash
yq -o=json ops/github/ruleset-main.yaml | jq -r '"bypass=\(.bypass_actors | length) rules=\([.rules[].type] | join(",")) approvals=\(.rules[] | select(.type == "pull_request") | .parameters.required_approving_review_count) checks=\([.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks[] | "\(.context)@\(.integration_id)"] | join(","))"'
# bypass=0 rules=deletion,non_fast_forward,pull_request,required_status_checks approvals=0 checks=ci-gate@15368
```

---

## Paso 3: Aplicar el ruleset

**Por qué**: el archivo no protege nada hasta que la API lo crea. La primera vez es un `POST`;
devuelve el `id` con el que harás los `PUT` de después. Un segundo `POST` no actualiza: crea
otro ruleset con el mismo nombre, y los dos se suman. Lo que se aplica de verdad a `main` no se
lee en el ruleset, sino en `rules/branches/main`: la suma de todos los rulesets activos.

> ⚠️ **Desde aquí, `main` solo cambia por PR con `ci-gate` en verde, también para ti.** No hay
> nada que respaldar: el ruleset no toca el contenido de la rama. La salida de emergencia, si
> algo lo deja bloqueado, es desactivarlo (eres admin del repo, y editar un ruleset no es un
> push):
> `gh api -X PUT "repos/{owner}/{repo}/rulesets/<id>" -f enforcement=disabled`.

**Comando**:

```bash
yq -o=json ops/github/ruleset-main.yaml \
  | gh api -X POST 'repos/{owner}/{repo}/rulesets' --input - --jq .id
# <id-del-ruleset>
```

**Verifica**: las reglas que tiene `main` ahora, con el ruleset del que viene cada una:

```bash
gh api 'repos/{owner}/{repo}/rules/branches/main' --jq '.[] | "\(.type) ← \(.ruleset_source_type) \(.ruleset_id)"' | sort
# deletion ← Repository <id-del-ruleset>
# non_fast_forward ← Repository <id-del-ruleset>
# pull_request ← Repository <id-del-ruleset>
# required_status_checks ← Repository <id-del-ruleset>
gh api 'repos/{owner}/{repo}/rules/branches/main' \
  --jq '.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[] | "\(.context)@\(.integration_id)"'
# ci-gate@15368
```

En la UI lo ves en **Settings → Rules → Rulesets**: cualquiera con lectura en el repo puede
verlo, también quien abre un PR desde un fork.

---

## Paso 4: Un push directo y un force push, rechazados

**Por qué**: una regla que no has visto fallar es una regla que crees que funciona. El push
directo choca con `pull_request`; el force push, además, con `non_fast_forward`. Los dos los
rechaza el servidor, no tu cliente: `git` no sabe nada del ruleset hasta que GitHub responde.

> ⚠️ **Advertencia**: el force push de este paso intenta quitarle a `main` su último commit. Si
> el ruleset no estuviera activo, lo conseguiría. Antes guardas la punta de `main` en un tag
> local; si `main-intacto` no sale, la restauras con
> `git push --force origin backup/main-s18:refs/heads/main` (solo funcionará precisamente
> porque el ruleset no está activo) y vuelves al paso 3.

**Comando**: primero el respaldo y el push directo de un commit vacío:

```bash
git tag -f backup/main-s18 origin/main
before=$(git rev-parse origin/main)
git commit --allow-empty -m "chore: direct push test"
git push origin main 2> push.log; echo "exit=$?"
# exit=1
grep -i 'rule' push.log | head -3
# remote: ... (líneas que citan las reglas del repositorio y refs/heads/main)
```

El texto exacto lo decide GitHub y puede cambiar; lo que importa es que menciona las reglas del
repositorio y que `git` termina con error. Descarta el commit vacío, que solo existe en tu clon:

```bash
git reset --hard origin/main
```

Ahora el force push, que intenta mover `main` un commit atrás:

```bash
git push --force origin "$before~1:refs/heads/main" 2> push.log; echo "exit=$?"
# exit=1
grep -ci 'rule' push.log
# <un número mayor que 0>
rm push.log
```

**Verifica**: `main` en GitHub sigue exactamente donde estaba:

```bash
git fetch -q origin
[[ $(git ls-remote origin refs/heads/main | cut -f1) == "$before" ]] && echo main-intacto
# main-intacto
git status -sb | head -1
# ## main...origin/main
```

---

## Paso 5: Un PR con `ci-gate` en rojo no se fusiona

**Por qué**: el PR es el único camino, y `ci-gate` es su guardián. Lo compruebas con un test que
falla a propósito: `ci-api` falla, `ci-gate` lo ve en `needs` y falla también, y el ruleset no
deja fusionar. `--required` en `gh pr checks` filtra los checks que exige el ruleset: es la vista
de lo que bloquea, no de todo lo que corrió.

**Comando**:

```bash
git switch -c test/red-gate
cat > api/tests/unit/test_gate.py <<'EOF'
"""Falla a propósito: comprueba que ci-gate bloquea el PR."""


def test_gate_blocks_red_pr():
    assert 1 == 2, "rojo a propósito"
EOF
git add api/tests/unit/test_gate.py
git commit -m "test(api): fail on purpose to check ci-gate"
git push -u origin test/red-gate
gh pr create --title "test(api): fail on purpose" --body "Comprueba que ci-gate bloquea. No se fusiona."
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch --required > /dev/null; echo "exit=$?"
# exit=1
```

**Verifica**: el check obligatorio en rojo, el merge rechazado y el PR bloqueado:

```bash
gh pr checks "$pr" --required
# ci-gate	fail	<duración>	https://github.com/<tu-org>/tablero/actions/runs/<run-id>/job/<job-id>
gh pr merge "$pr" --squash; echo "exit=$?"
# <gh explica que el PR no cumple los requisitos de la rama>
# exit=1
gh pr view "$pr" --json state,mergeStateStatus --jq '"\(.state) \(.mergeStateStatus)"'
# OPEN BLOCKED
```

Ni tú, que eres admin, puedes fusionarlo: `bypass_actors` está vacío. Cierra el PR:

```bash
gh pr close "$pr" --delete-branch
git switch main && git branch -D test/red-gate
```

---

## ✅ Resultado

- [ ] `.github/CODEOWNERS` asigna `/.github/` y `/ops/` a tu usuario, y la API no le ve errores
- [ ] `ops/github/ruleset-main.yaml` en `main`, con bypass vacío, 0 aprobaciones y `ci-gate@15368`
- [ ] El ruleset activo: `rules/branches/main` devuelve sus cuatro reglas
- [ ] Un push directo y un force push a `main` rechazados, y `main` intacta
- [ ] Un PR con `ci-gate` en rojo, bloqueado y cerrado sin fusionar

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 18
# ...
#   ✅ CODEOWNERS asigna dueño a /.github/ y a /ops/
#   ❌ ops/github/ruleset-main.yaml protege la rama por defecto sin excepciones: ...
# ...
```

Se suman `codeowners` y `codeowners-valid`: diez en verde. `ruleset-file` y `ruleset-active`
siguen en rojo hasta que la práctica 03 añada la regla `merge_queue`.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `HTTP 422` en el `POST` del ruleset | Un parámetro con el valor o el tipo equivocado | El mensaje dice cuál; compara con la teoría 02 |
| `codeowners/errors` devuelve errores | Usuario mal escrito o sin escritura en el repo | Corrige la línea; el dueño necesita escritura |
| El push directo entra | Ruleset en `disabled`, o con tu rol en `bypass_actors` | `gh api 'repos/{owner}/{repo}/rulesets/<id>' --jq '.enforcement, .bypass_actors'` |
| `gh pr checks --required` sale vacío | El ruleset no está activo o el check no se llama `ci-gate` | Paso 3; el `name:` del job tiene que ser `ci-gate` |
| El PR espera un `ci-gate` que nunca llega | `integration_id` distinto de `15368` | Corrige el YAML y aplícalo con `PUT` (práctica 03, paso 2) |
| Dos rulesets llamados `main` | Repetiste el `POST` | Borra el duplicado: `gh api -X DELETE 'repos/{owner}/{repo}/rulesets/<id-duplicado>'` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Un solo check para un monorepo](01-un-solo-check-para-un-monorepo.md) | [Merge queue](03-merge-queue.md) |
