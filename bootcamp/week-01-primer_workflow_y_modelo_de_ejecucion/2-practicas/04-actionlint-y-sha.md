# Práctica 04 — actionlint y pinning por SHA

> GitHub solo te dice que un workflow está mal después del push. actionlint te lo dice
> antes, en tu máquina. Y cuando usas una action de otro, fijarla por SHA es lo que
> garantiza que mañana ejecutas el mismo código que revisaste hoy.

**Tiempo estimado**: 1,5 h

## 🎯 Qué vas a conseguir

- Pasar actionlint a tus workflows y leer sus errores
- Añadir `actions/checkout` a `hello.yml` y ver por qué `@v7` no basta
- Fijar la action por SHA con `scripts/resolve-sha.sh`, sin credenciales persistidas
- Hacer que tu repo **rechace** cualquier action sin SHA completo
- Quedarte con un hábito: actionlint antes de cada push

## 📋 Antes de empezar

Terminaste la [práctica 03](03-gh-cli-para-actions.md). Tienes `actionlint` 1.7.12 instalado
([`docs/setup-entorno.md`](../../../docs/setup-entorno.md), sección 3) y el bootcamp clonado en
`~/code/bc-github-actions`.

```bash
actionlint -version | head -1
# 1.7.12
cd ~/code/tablero
git status -sb
# ## main...origin/main
```

---

## Paso 1: actionlint sobre hello.yml y sobre un workflow roto

**Por qué**: GitHub valida el YAML cuando ya hiciste push. Si está mal, el run sale en rojo con
`Invalid workflow file` y has gastado un commit en averiguarlo. actionlint conoce la sintaxis de
los workflows: claves válidas de cada sección, nombres de eventos, expresiones `${{ }}`, y además
pasa shellcheck a cada `run:`. Lo que detecta en local nunca llega a GitHub.

**Comando**: primero tu workflow, que debería estar limpio:

```bash
actionlint .github/workflows/hello.yml
echo "exit $?"
# exit 0
```

Sin salida y con código 0: no hay nada que corregir. Ahora siembra tres errores en una copia
**fuera** del repo, para no ensuciar `.github/workflows/`:

```bash
mkdir -p /tmp/lint-demo && cp .github/workflows/hello.yml /tmp/lint-demo/broken.yml
```

Edita `/tmp/lint-demo/broken.yml` y cambia tres cosas:

1. `workflow_dispatch:` por `workflow_dispach:` (falta una `t`)
2. `runs-on:` por `run-on:`
3. En el step *Qué máquina*, añade una línea `uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`
   debajo de `run: uname -a`

```bash
actionlint /tmp/lint-demo/broken.yml
# /tmp/lint-demo/broken.yml:6:3: unknown Webhook event "workflow_dispach". see https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#webhook-events for list of all Webhook event names [events]
# /tmp/lint-demo/broken.yml:13:3: "runs-on" section is missing in job "hello" [syntax-check]
# /tmp/lint-demo/broken.yml:15:5: unexpected key "run-on" for "job" section. expected one of "concurrency", "container", "continue-on-error", "defaults", "env", "environment", "if", "name", "needs", "outputs", "permissions", "runs-on", "secrets", "services", "snapshot", "steps", "strategy", "timeout-minutes", "uses", "with" [syntax-check]
# /tmp/lint-demo/broken.yml:22:9: unexpected key "uses" for step to run shell command. expected one of "continue-on-error", "env", "id", "if", "name", "run", "shell", "timeout-minutes", "working-directory" [syntax-check]
echo "exit $?"
# exit 1
```

(Cada error va seguido de un fragmento del archivo con `^~~~` debajo de la columna exacta; aquí se
omite. Los números de línea dependen de cómo esté tu copia.)

Cuatro mensajes para tres errores: `run-on` produce dos, porque la clave desconocida sobra **y**
falta `runs-on`. El último dice que un step es de un tipo o de otro: o ejecuta un comando
(`run:`) o usa una action (`uses:`), nunca las dos cosas. Cada mensaje acaba con la regla entre
corchetes (`[events]`, `[syntax-check]`): te dice qué parte de la sintaxis rompiste.

**Verifica**:

```bash
actionlint .github/workflows/hello.yml && echo LIMPIO
# LIMPIO
actionlint /tmp/lint-demo/broken.yml > /dev/null; echo "exit $?"
# exit 1
```

---

## Paso 2: actions/checkout por tag, y por qué no basta

**Por qué**: en la práctica 02 viste que el workspace empieza vacío. `actions/checkout` es la
action que descarga tu repo en él. La forma que verás en casi todos los tutoriales es
`actions/checkout@v7`, y funciona, pero `v7` es un **tag de git**: su dueño puede moverlo a otro
commit cuando quiera. Si esa cuenta se compromete, el tag pasa a apuntar a código malicioso y tu
workflow lo ejecuta en el siguiente run, con tu token. Es lo que ocurrió con
`tj-actions/changed-files` en marzo de 2025 (teoría 07).

**Comando**: añade este step como **primero** de `hello.yml`. El comentario `antipatron` marca que
es un ejemplo de lo que no se hace; no hagas push todavía.

```yaml
      - name: Descargar el código
        uses: actions/checkout@v7   # antipatron: tag móvil, se corrige en el paso 3
```

```bash
actionlint .github/workflows/hello.yml; echo "exit $?"
# exit 0
```

actionlint no se queja: `@v7` es sintaxis válida. El pinning no es un error de sintaxis, es una
regla de seguridad, y para comprobarla se usa el mismo `grep` que usa `check-week.sh`: lista toda
`uses:` que no sea local (`./`) ni lleve un SHA de 40 caracteres con el tag en comentario.

**Verifica**:

```bash
grep -hE '^\s*-?\s*uses:' .github/workflows/*.yml | grep -vE 'uses: \./|@[0-9a-f]{40} # v' || true
#         uses: actions/checkout@v7   # antipatron: tag móvil, se corrige en el paso 3
```

Una línea en la salida es una action sin fijar. El objetivo es que este comando no imprima nada.

---

## Paso 3: Fijar por SHA con resolve-sha.sh

**Por qué**: un SHA de commit no se puede mover: identifica un contenido exacto. Pero nunca lo
escribas a mano ni lo copies de otro repo: un SHA copiado puede ser de un fork malicioso que se
hace pasar por el original. `scripts/resolve-sha.sh` le pregunta a la API de GitHub a qué commit
apunta **hoy** el tag del repo oficial, y si el tag es anotado, sigue hasta el commit real. El tag
va en el comentario para que cualquiera (y Dependabot, en la Semana 12) sepa qué versión es.

Con el código en el workspace, `persist-credentials: false` evita que `actions/checkout` deje el
`GITHUB_TOKEN` configurado en git (desde la v6, en un archivo bajo `$RUNNER_TEMP`). Si se queda,
cualquier step posterior del job, incluida una action de terceros, puede usarlo. Solo hace falta guardarlo si el
job hace `git push`, y este no lo hace.

**Comando**:

```bash
~/code/bc-github-actions/scripts/resolve-sha.sh actions/checkout v7.0.1
# uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
```

Sustituye el step del paso 2 por este:

```yaml
      - name: Descargar el código
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
```

```bash
actionlint .github/workflows/hello.yml && git add .github/workflows/hello.yml
git commit -m "ci(hello): checkout pinned by sha"
git push
sleep 5
gh run watch "$(gh run list --workflow hello.yml --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
```

**Verifica**:

```bash
grep -hE '^\s*-?\s*uses:' .github/workflows/*.yml | grep -vE 'uses: \./|@[0-9a-f]{40} # v' || true
# (sin salida)
RUN_ID=$(gh run list --workflow hello.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run view "$RUN_ID" --log | grep 'Qué hay en el workspace' | grep -E 'api|compose.yaml'
# ... compose.yaml
# ... api
```

Ahora `ls -A` del step *Qué hay en el workspace* lista `api`, `web`, `compose.yaml`: el código ya
está en el runner.

---

## Paso 4: Que el repo rechace actions sin SHA

**Por qué**: el `grep` del paso 2 depende de que alguien lo ejecute. GitHub tiene un ajuste que lo
convierte en una regla de la plataforma: con **sha_pinning_required**, un job que use una action
remota sin SHA completo falla al prepararse, antes de ejecutar nada. Protege también de un pull
request que intente colar `@main` en un workflow.

En la UI: **Settings → Actions → General → Actions permissions**, marca *Require actions to be
pinned to a full-length commit SHA* y guarda. Por API, el mismo endpoint que activa Actions
(`enabled=true` es obligatorio en esta llamada; `allowed_actions=all` deja la lista de actions
permitidas como estaba por defecto):

**Comando**:

```bash
gh api -X PUT "repos/{owner}/{repo}/actions/permissions" \
  -F enabled=true -f allowed_actions=all -F sha_pinning_required=true
gh api "repos/{owner}/{repo}/actions/permissions"
# {"enabled":true,"allowed_actions":"all","sha_pinning_required":true}
```

Si la organización ya lo exige para todos sus repos, el repo lo hereda. Pruébalo con `@v7` en una
rama, sin tocar `main`: `workflow_dispatch` con `-r` ejecuta el `hello.yml` de esa rama.

```bash
git switch -c test/unpinned
sed -i 's|actions/checkout@[0-9a-f]\{40\} # v7.0.1|actions/checkout@v7|' .github/workflows/hello.yml
git commit -am "test: unpinned checkout"
git push -u origin test/unpinned
gh workflow run hello.yml -r test/unpinned
sleep 5   # el run tarda unos segundos en aparecer en la lista
id=$(gh run list --workflow hello.yml --branch test/unpinned --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status; echo "exit $?"
# ...
# exit 1
```

Abre ese run en la UI: GitHub lo para antes de ejecutar ningún step tuyo, con un error que dice que
la action tiene que estar fijada a un SHA de commit completo. Según dónde lo detecte, la conclusión
puede salir `failure` o `startup_failure`: las dos significan que el ajuste funciona.

Limpia la rama de prueba. Solo contiene el commit `test: unpinned checkout`; comprueba con
`git log --oneline main..test/unpinned` que no hay nada más antes de borrarla.

```bash
git switch main
git branch -D test/unpinned
git push origin --delete test/unpinned
```

**Verifica**:

```bash
gh api "repos/{owner}/{repo}/actions/permissions" --jq .sha_pinning_required
# true
git branch -a | grep -c unpinned
# 0
```

---

## Paso 5: El hábito: actionlint antes de cada push

**Por qué**: a partir de ahora escribes un workflow nuevo casi cada semana. El ciclo barato es
local: editar, `actionlint`, `grep` de pinning, y solo entonces push. Cada error que actionlint
caza en tu máquina es un run rojo menos en el historial y un commit de "fix typo" menos. En la
Semana 08 lo automatizarás con un workflow que lintea workflows; hasta entonces, es un hábito.

**Comando**: guárdalo como función de tu shell (en `~/.zshrc` o `~/.bashrc`):

```bash
wf_check() {
  actionlint .github/workflows/*.yml || return 1
  local unpinned
  unpinned=$(grep -hE '^\s*-?\s*uses:' .github/workflows/*.yml | grep -vE 'uses: \./|@[0-9a-f]{40} # v' || true)
  [[ -z "$unpinned" ]] || { echo "Actions sin SHA:"; echo "$unpinned"; return 1; }
  echo "workflows OK"
}
```

```bash
source ~/.zshrc   # o ~/.bashrc
cd ~/code/tablero && wf_check && git push
```

**Verifica**:

```bash
wf_check
# workflows OK
gh run list --workflow hello.yml --branch main --limit 1 --json conclusion --jq '.[0].conclusion'
# success
```

---

## ✅ Resultado

- [ ] Sabes leer un error de actionlint: archivo, línea, columna, mensaje y regla
- [ ] `hello.yml` descarga el código con `actions/checkout` fijado por SHA y sin credenciales persistidas
- [ ] Ninguna `uses:` remota de tus workflows queda sin SHA
- [ ] Tu repo rechaza actions sin SHA completo, y lo has comprobado en una rama
- [ ] Pasas `wf_check` antes de cada push

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 01
#   ...
#   ✅ El repo rechaza cualquier action que no esté fijada por SHA completo
#   ✅ Toda uses: remota de tus workflows está fijada por SHA de 40 caracteres con el tag en comentario
#   ...
```

Los checks de `ci.yml` siguen en rojo: son el [proyecto](../3-proyecto/README.md).

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `actionlint: command not found` | No está instalado o `~/.local/bin` no está en el `PATH` | `docs/setup-entorno.md`, secciones 3 y 7 |
| actionlint avisa de `shellcheck reported issue` | Un `run:` tiene un problema de shell (comillas, `ls` parseado...) | Lee el código `SCxxxx` en <https://www.shellcheck.net/wiki/> y corrige el script |
| `resolve-sha.sh` responde `HTTP 404` | El tag no existe (por ejemplo `v7.0` en vez de `v7.0.1`) | `gh release list -R actions/checkout -L 5` y usa un tag de la lista |
| El `grep` de pinning sigue mostrando la línea | Falta el comentario `# v7.0.1` o hay dos espacios antes de `#` | Copia la línea exacta que imprime `resolve-sha.sh` |
| `ls -A` sigue vacío tras el checkout | El step de checkout va después del de `ls` | Ponlo como primer step del job |
| El PUT de permisos responde `409 Conflict` | La organización gestiona ese ajuste | Actívalo en **Settings → Actions → General** de la org |
| El run de `test/unpinned` sale en `success` | El ajuste no quedó guardado o el run es de otra rama | Repite el GET del paso 4 y filtra con `--branch test/unpinned` |
| `git push origin --delete` responde `remote ref does not exist` | Ya la borraste | Nada que hacer: `git branch -a` lo confirma |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [gh CLI para Actions](03-gh-cli-para-actions.md) | [Proyecto: capa 01 de tablero](../3-proyecto/README.md) |
