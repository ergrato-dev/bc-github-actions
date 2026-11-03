# Práctica 01 — Organización y repo tablero

> Un workflow solo se ejecuta desde `.github/workflows/` en la raíz de un repo. Por eso
> no trabajas en un fork del bootcamp: creas tu propia organización y, dentro, el repo
> público `<tu-org>/tablero`. Ahí vivirá el CI/CD que construyes durante las 20 semanas.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Una organización gratuita de GitHub que será tu laboratorio
- El repo público `<tu-org>/tablero` con el código de la app en la raíz
- `check-week.sh` configurado para comprobar tu repo
- El `GITHUB_TOKEN` de solo lectura por defecto, y aprobación obligatoria para los workflows de cualquier colaborador externo

## 📋 Antes de empezar

Tienes que tener instaladas las herramientas de
[`docs/setup-entorno.md`](../../../docs/setup-entorno.md), y `gh` con sesión iniciada y el scope
`workflow`:

```bash
gh auth status
# ✓ Logged in to github.com account <tu-usuario> ...
# - Token scopes: 'gist', 'read:org', 'repo', 'workflow'
```

En esta práctica se supone que clonaste el bootcamp en `~/code/bc-github-actions` y que tu repo
irá en `~/code/tablero`. Si usas otras rutas, cámbialas en todos los comandos.

```bash
ls ~/code/bc-github-actions/app
# README.md  api  compose.yaml  scripts  web
```

---

## Paso 1: Crear la organización gratuita

**Por qué**: en una organización (y no en tu usuario) tienes lo que vas a usar más adelante:
políticas de Actions para todos sus repos, runner groups (Semana 15), un repo central de actions
(Semana 11) y rulesets a nivel de org (Semana 18). El plan Free cuesta 0 € y, con repos públicos,
los minutos de los runners estándar son gratuitos. `gh` no puede crear organizaciones: este paso
se hace en la web.

**Comando**:

1. Abre <https://github.com/account/organizations/new> y elige el plan **Free**.
2. Ponle un nombre corto en minúsculas, por ejemplo `<tu-usuario>-lab`. Este nombre es tu
   `<tu-org>` en todo el bootcamp.
3. Como correo de contacto, el tuyo. Marca que pertenece a tu cuenta personal.
4. Sáltate la invitación de miembros: de momento estás solo tú.

Después, desde la terminal, guarda el nombre en una variable para no repetirlo:

```bash
export ORG=<tu-org>
```

**Verifica**:

```bash
gh api "orgs/$ORG" --jq .login
# <tu-org>
gh api "orgs/$ORG/memberships/$(gh api user --jq .login)" --jq .role
# admin
```

Si sale `admin`, eres propietario de la organización y puedes cambiar sus ajustes de Actions.

---

## Paso 2: Crear el repo público tablero

**Por qué**: el repo tiene que ser **público** por dos motivos. Los minutos de los runners estándar
son gratuitos e ilimitados en repos públicos, y algunas funciones que verás después (environments
con revisores obligatorios, attestations) solo están en el plan Free si el repo es público. La
otra cara es que cualquiera puede ver tus logs y abrirte un pull request: por eso el paso 5 cierra
la puerta antes de escribir el primer workflow.

**Comando**:

```bash
mkdir -p ~/code && cd ~/code
gh repo create "$ORG/tablero" --public --clone \
  --description "tablero: monorepo FastAPI + React con CI/CD en GitHub Actions"
cd tablero
```

`--public` fija la visibilidad y `--clone` lo clona en el directorio actual. El repo nace vacío: no
uses `--add-readme`, porque el primer commit lo haces tú en el paso 3.

**Verifica**:

```bash
gh api "repos/$ORG/tablero" --jq '.visibility + " " + .owner.type'
# public Organization
git remote get-url origin
# https://github.com/<tu-org>/tablero.git
```

Si sale `User` en vez de `Organization`, creaste el repo en tu cuenta personal: bórralo (lee antes el aviso de
🧯 Si algo sale mal) y repite con `"$ORG/tablero"`.

---

## Paso 3: Copiar la app y hacer el primer push

**Por qué**: `app/` del bootcamp es `tablero` completo y en verde: API en FastAPI con uv, web en
React con pnpm, PostgreSQL 17 y Compose. **No trae `.github/`** a propósito: escribir los
workflows es tu trabajo. Se copia el *contenido* de `app/` a la raíz del repo (el `/.` final de
`app/.` copia también los archivos ocultos, como `.gitignore` y `.env.example`), porque los
workflows de las próximas semanas usan rutas como `api/` y `web/`, no `app/api/`.

**Comando**:

```bash
cd ~/code/tablero
cp -r ~/code/bc-github-actions/app/. .
ls -A
# .env.example  .gitignore  README.md  api  compose.yaml  scripts  web
git add .
git commit -m "chore: import tablero app"
git push -u origin main
```

Los mensajes de commit van en inglés y con Conventional Commits, como en el bootcamp.

**Verifica**:

```bash
git ls-tree --name-only origin/main
# .env.example
# .gitignore
# README.md
# api
# compose.yaml
# scripts
# web
test -f api/uv.lock && test -f web/pnpm-lock.yaml && test -f compose.yaml && echo OK
# OK
```

Si ves `app` en la lista, copiaste la carpeta en vez de su contenido. Arréglalo con
`git mv app/* app/.[!.]* . && rmdir app`, haz commit y vuelve a hacer push.

---

## Paso 4: Configurar check-week.sh

**Por qué**: `check-week.sh` corre en tu máquina, dentro del clon del bootcamp, pero comprueba
**tu** repo. Necesita dos datos: `REPO` (para que `gh` hable con `<tu-org>/tablero`) y `APP_DIR`
(dónde está tu clon, porque los comandos de `checks.json` leen tus archivos de workflow). Lo
detalla [`docs/autograding.md`](../../../docs/autograding.md).

**Comando**:

```bash
cat > ~/.bc-github-actions <<EOF
REPO=$ORG/tablero
APP_DIR=$HOME/code/tablero
EOF
cat ~/.bc-github-actions
# REPO=<tu-org>/tablero
# APP_DIR=/home/<tu-usuario>/code/tablero
```

El heredoc va sin comillas (`<<EOF`) para que `$ORG` y `$HOME` se sustituyan al escribir el archivo.

**Verifica**:

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh --doctor
# Herramientas (versiones en docs/stack-versions.md):
#   ✅ gh               gh version 2.103.3 (2026-10-26)
#   ...
# GitHub:
#   ✅ gh auth          scopes: gist, read:org, repo, workflow
#   ✅ REPO             <tu-org>/tablero
#   ✅ APP_DIR          /home/<tu-usuario>/code/tablero
#
# Todo listo.
```

`docker`, `act`, `kind`, `kubectl` y `helm` pueden salir con ⏳ o ❌: se instalan en sus semanas y
no cuentan todavía.

---

## Paso 5: Cerrar los ajustes de Actions del repo

**Por qué**: un repo público recibe pull requests de desconocidos. Hay dos ajustes que conviene
cerrar **antes** de que exista el primer workflow:

- **Permisos por defecto del `GITHUB_TOKEN`: solo lectura.** Cada job recibe un token. Si por
  defecto puede escribir, cualquier step con un fallo (o una action comprometida) puede empujar
  código, crear releases o tocar issues. Con `read`, el token solo lee y cada workflow pide
  explícitamente lo que necesita en `permissions:` (lo verás a fondo en la Semana 12).
  `can_approve_pull_request_reviews=false` impide además que un workflow apruebe pull requests.
- **Aprobación para todo colaborador externo.** Por defecto GitHub solo pide aprobación la primera
  vez que alguien contribuye. Con `all_external_contributors`, el workflow de un pull request
  desde un fork no corre hasta que tú lo apruebas, siempre, aunque esa persona ya haya contribuido
  antes.

En la UI están en **Settings → Actions → General** del repo: la sección *Workflow permissions*
(*Read repository contents and packages permissions*, sin marcar *Allow GitHub Actions to create
and approve pull requests*) y la sección *Approval for running fork pull request workflows from
contributors* (*Require approval for all external contributors*). Aquí lo haces con la API REST,
que deja constancia exacta de lo que cambias:

**Comando**:

```bash
cd ~/code/tablero
gh api -X PUT "repos/{owner}/{repo}/actions/permissions/workflow" \
  -f default_workflow_permissions=read \
  -F can_approve_pull_request_reviews=false
gh api -X PUT "repos/{owner}/{repo}/actions/permissions/fork-pr-contributor-approval" \
  -f approval_policy=all_external_contributors
```

Dentro de tu clon, `gh api` sustituye `{owner}` y `{repo}` por los de `origin`. `-f` envía el valor
como texto y `-F` lo convierte a su tipo: `false` llega como booleano y no como la cadena
`"false"`. Las dos llamadas responden `204 No Content`, así que no imprimen nada.

Si la organización ya fija un valor más restrictivo, el repo lo hereda y la primera llamada puede
responder `409 Conflict`. En ese caso el ajuste ya está cerrado desde la org
(**Settings → Actions → General** de la organización) y el GET siguiente lo confirma.

**Verifica**:

```bash
gh api "repos/{owner}/{repo}/actions/permissions/workflow" --jq .default_workflow_permissions
# read
gh api "repos/{owner}/{repo}/actions/permissions/fork-pr-contributor-approval" --jq .approval_policy
# all_external_contributors
```

---

## ✅ Resultado

- [ ] Tienes una organización gratuita y eres `admin`
- [ ] `<tu-org>/tablero` es público y pertenece a la organización
- [ ] El código de la app está en la raíz del repo, sin carpeta `app/`
- [ ] `~/.bc-github-actions` apunta a tu repo y a tu clon
- [ ] El `GITHUB_TOKEN` es de solo lectura por defecto
- [ ] Los workflows de pull requests de colaboradores externos esperan tu aprobación

Comprueba lo que ya puedes cumplir de la semana:

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 01
# Semana 01 — Primer workflow y modelo de ejecución  [repo: <tu-org>/tablero]
#
#   ✅ El repo tablero es público
#   ✅ El repo tablero pertenece a una organización, no a tu usuario
#   ✅ El código de tablero está en la raíz del repo: api/uv.lock, web/pnpm-lock.yaml y compose.yaml
#   ✅ El GITHUB_TOKEN del repo es de solo lectura por defecto
#   ✅ Los workflows de un pull request de cualquier colaborador externo esperan tu aprobación
#   ❌ hello.yml terminó en success al menos una vez lanzado a mano (workflow_dispatch)
#   ...
```

Lo que queda en rojo lo resuelven las prácticas 02-04 y el proyecto.

## 🧯 Si algo sale mal

> [!WARNING]
> Borrar un repo es irreversible y elimina también sus runs, logs y paquetes. Antes de
> `gh repo delete`, comprueba con `gh repo view <org>/<repo>` que es el repo equivocado y que no
> tiene nada que quieras conservar. `gh` te pide el scope `delete_repo`
> (`gh auth refresh -s delete_repo`) y confirmación escribiendo el nombre.

| Síntoma | Causa | Solución |
|---|---|---|
| `gh api orgs/<tu-org>` responde `404 Not Found` | El nombre no coincide o la org no terminó de crearse | Cópialo de la URL `github.com/<tu-org>` y repite `export ORG=...` |
| `.owner.type` sale `User` | Creaste el repo sin el prefijo de la org | `gh repo delete <tu-usuario>/tablero` (lee el aviso) y repite el paso 2 con `"$ORG/tablero"` |
| `git push` responde `refusing to allow an OAuth App to create or update workflow` | Al token de `gh` le falta el scope `workflow` | `gh auth refresh -s workflow` |
| `git ls-tree` muestra `app` | Copiaste la carpeta y no su contenido | El `git mv` del final del paso 3 |
| `--doctor`: `config` en rojo | `~/.bc-github-actions` no existe o tiene comillas literales | Repite el heredoc del paso 4 y revisa con `cat` |
| `--doctor`: `REPO ... no existe o no tienes acceso` | Error tipográfico en `REPO=` | `gh repo view <tu-org>/tablero` y corrige el archivo |
| El PUT de `workflow` responde `409 Conflict` | La org impone un valor y el repo no puede cambiarlo | Mira el GET: si dice `read`, ya está bien; si dice `write`, cámbialo en los ajustes de la org |
| `gh api` responde `HTTP 404` en `repos/{owner}/{repo}/...` | Estás fuera del clon y `gh` no sabe qué repo es | `cd ~/code/tablero` o exporta `GH_REPO=<tu-org>/tablero` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Actions de terceros y pinning por SHA](../1-teoria/07-actions-de-terceros-y-pinning.md) | [Tu primer workflow](02-primer-workflow.md) |
