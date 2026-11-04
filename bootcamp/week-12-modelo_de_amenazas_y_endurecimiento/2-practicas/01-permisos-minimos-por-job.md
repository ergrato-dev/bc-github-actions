# Práctica 01 — Permisos mínimos por job

> Hasta ahora cada workflow de `tablero` daba `contents: read` a todos sus jobs desde la raíz.
> En esta práctica le das la vuelta: la raíz no da nada y cada job pide lo que usa. Un job
> nuevo que no declare permisos no hereda ninguno por accidente.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Leer en el log de un run los permisos que recibió de verdad el `GITHUB_TOKEN` de un job
- `permissions: {}` en la raíz de los 7 workflows de `tablero`
- Un bloque `permissions` en cada job, también en los que llaman a un reutilizable
- Escritura solo en `images` (`packages`) y `nightly` (`actions`)
- Aprobación obligatoria para los workflows de todos los colaboradores externos
- `main` en verde con los permisos nuevos

## 📋 Antes de empezar

`./scripts/check-week.sh 11` está en 17/17 y leíste la
[teoría 02](../1-teoria/02-permisos-del-github-token.md): cómo se calculan los permisos
efectivos y por qué los de un job que llama a un reutilizable son su techo.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
ls .github/workflows/ | wc -l
# 7
```

---

## Paso 1: Leer los permisos efectivos en el log

**Por qué**: el YAML dice lo que pides; el log dice lo que recibió el job después de aplicar el
default de la org, la raíz, el job y el recorte de los forks. El step `Set up job` de cada job
abre un grupo `GITHUB_TOKEN Permissions` con un scope por línea. `Metadata: read` aparece
siempre: es el permiso implícito que tiene todo token. Comparas dos workflows que hoy piden
cosas distintas: `ci` hereda `contents: read` de la raíz y `nightly` declara `actions: write`
en su único job.

**Comando**:

```bash
ci=$(gh run list --workflow ci.yml --branch main --limit 1 --json databaseId --jq '.[0].databaseId')
nightly=$(gh run list --workflow nightly.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run view "$nightly" --log | grep -A6 "GITHUB_TOKEN Permissions"
```

Si `nightly` todavía no tiene runs, lánzalo con `gh workflow run nightly.yml -f target=smoke`
y repite cuando termine.

**Verifica**: de cada log, solo las líneas de scope:

```bash
gh run view "$ci" --log | grep -oE '(Actions|Contents|Metadata): (read|write)' | sort -u
# Contents: read
# Metadata: read
gh run view "$nightly" --log | grep -oE '(Actions|Contents|Metadata): (read|write)' | sort -u
# Actions: write
# Metadata: read
```

Fíjate en lo que **no** sale en `nightly`: `Contents`. Su job declara `actions: write` y, al
declarar un scope, todos los demás quedan en `none`; también los de la raíz.

---

## Paso 2: Raíz vacía en los 7 workflows

**Por qué**: con `contents: read` en la raíz, cualquier job que alguien añada mañana recibe ese
permiso sin pedirlo. Con `permissions: {}` la raíz no da nada: el job que no declare sus
permisos falla en el primer step que use el token, y el fallo se ve en el PR en lugar de
quedar escondido. Los 7 workflows tienen hoy el mismo bloque de tres líneas con el comentario
«lo verás a fondo en la Semana 12»: esta es esa semana.

> ⚠️ **Entre este paso y el siguiente ningún job tiene permisos.** No hagas push hasta el
> paso 7: si lo haces, todo checkout falla. Para deshacer: `git checkout -- .github/workflows`.

**Comando**: sustituye el bloque en los 7 a la vez; `-z` deja que `sed` vea los saltos de
línea:

```bash
sed -i -z 's/# Mínimo privilegio: lo verás a fondo en la Semana 12.\npermissions:\n  contents: read\n/# Raíz vacía: cada job declara solo los permisos que usa.\npermissions: {}\n/' \
  .github/workflows/*.yml
git diff --stat
# 7 files changed, 14 insertions(+), 21 deletions(-)
```

**Verifica**: la orden de `root-permissions-empty`, que no lista ningún archivo:

```bash
for f in .github/workflows/*.yml; do
  [ "$(yq '.permissions | (tag == "!!map" and length == 0)' "$f")" = true ] || echo "$f"
done
# (sin salida)
```

`tag == "!!map"` distingue `{}` de un `permissions:` vacío, que YAML lee como `null`.

---

## Paso 3: Un bloque `permissions` en cada job

**Por qué**: ahora cada job tiene que pedir lo suyo. Casi todos solo leen el código, así que
piden `contents: read`. Los que llaman a un reutilizable (`ci-api` → `_python.yml`, `ci-web` →
`_node.yml`) también: sus permisos son el **techo** del reutilizable, y el checkout que hace
`_python.yml` dentro necesita `contents: read`. Sin él, el run no arranca.

**Comando**: primero la lista de jobs sin bloque, que es tu lista de tareas:

```bash
yq -N '.jobs | to_entries | .[] | select(.value.permissions == null) | filename + ":" + .key' \
  .github/workflows/*.yml | wc -l
# 13
```

`images` (`api` y `web`) y `nightly` no salen: ya declaraban sus permisos. Edita a mano cada uno de los 13. En un job normal el bloque va debajo de
`timeout-minutes`, por ejemplo en `ci.yml`:

```yaml
  runner-info:
    name: Información del runner
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    permissions:
      contents: read
    steps:
      - name: Sistema operativo
        run: cat /etc/os-release
```

En un job que llama a un reutilizable no hay `runs-on`: el bloque va antes de `uses:`, como en
`images.yml`. En `ci-api.yml`:

```yaml
  api:
    name: API
    # Techo del reutilizable: _python.yml solo puede usar lo que este job concede.
    permissions:
      contents: read
    uses: <tu-org>/actions-tablero/.github/workflows/_python.yml@<sha-de-v1.0.0> # v1.0.0
```

Deja el `uses:` con el SHA que ya tenías; solo añades las tres líneas.

**Verifica**: la orden de `jobs-declare-permissions`, que ya no lista nada:

```bash
yq -N '.jobs | to_entries | .[] | select(.value.permissions == null) | filename + ":" + .key' \
  .github/workflows/*.yml
# (sin salida)
actionlint && echo ok
# ok
```

---

## Paso 4: Escritura solo donde hace falta

**Por qué**: un permiso de escritura es lo que un atacante busca cuando consigue ejecutar
código en un job. En `tablero` solo dos jobs previos escriben, y cada uno por un motivo que se
lee en su nombre: `images` publica en GHCR (`packages: write`) y `nightly` crea
`workflow_dispatch` de otros workflows (`actions: write`). Si mañana se compromete `ci` o
`lint-workflows`, su token no puede publicar una imagen ni lanzar nada. `write-all` y
`read-all` dan todos los scopes de golpe: no aparecen en ningún sitio. Las prácticas 02 y 03
añadirán tres escrituras más (`codeql`, `labeler` y `pr-report`), cada una en su propio
workflow.

**Comando**: lista cada scope de escritura con el archivo que lo pide:

```bash
grep -rlE 'permissions: *(write|read)-all' .github/workflows
yq -N '.jobs | to_entries | .[] | .value.permissions // {} | to_entries | .[] | select(.value == "write") | (filename | sub(".*/"; "")) + ":" + .key' \
  .github/workflows/*.yml | sort -u
```

**Verifica**: el `grep` no imprime nada y la lista tiene exactamente dos líneas:

```bash
yq -N '.jobs | to_entries | .[] | .value.permissions // {} | to_entries | .[] | select(.value == "write") | (filename | sub(".*/"; "")) + ":" + .key' \
  .github/workflows/*.yml | sort -u
# images.yml:packages
# nightly.yml:actions
```

Si sale una tercera línea, quítala salvo que sepas decir qué llamada a la API la necesita.

---

## Paso 5: Repaso de `persist-credentials`

**Por qué**: `actions/checkout` guarda por defecto el token en `.git/config` para que un
`git push` posterior funcione. Cualquier step siguiente puede leerlo, y si un
`upload-artifact` sube el workspace, el token viaja dentro del artefacto: es la auditoría
`artipacked` de zizmor. Lo aplicas desde la Semana 01; con los permisos recortados vale la
pena confirmar que ningún checkout se quedó atrás, porque un token de lectura filtrado sigue
siendo un token.

**Comando**:

```bash
yq -N '.jobs[].steps[]? | select(.uses // "" | test("^actions/checkout@")) | .with."persist-credentials"' \
  .github/workflows/*.yml | sort | uniq -c
#       7 false
```

**Verifica**: zizmor sin conexión, que también revisa `excessive-permissions`, no encuentra
nada:

```bash
zizmor --offline -q .github/workflows/
# No findings to report. Good job! (3 suppressed)
```

Los `suppressed` son hallazgos que la persona `regular` no enseña; los verás con
`--persona=auditor` ([teoría 07](../1-teoria/07-analisis-estatico-zizmor-y-codeql.md)).

---

## Paso 6: Aprobación para todos los colaboradores externos

**Por qué**: con el valor por defecto, GitHub pide aprobación solo a quien contribuye por
primera vez. Basta con que un PR inocente sea aceptado para que los siguientes de esa cuenta
ejecuten sus workflows sin que nadie los mire. Con `all_external_contributors`, ningún PR de
un fork ejecuta nada hasta que alguien con escritura pulsa **Approve and run**. No sustituye a
los permisos mínimos: es otra capa, para el caso en que alguno falle.

**Comando**: guarda primero el valor actual, que es el que restaurarías:

```bash
gh api 'repos/{owner}/{repo}/actions/permissions/fork-pr-contributor-approval' --jq .approval_policy
# first_time_contributors
gh api -X PUT 'repos/{owner}/{repo}/actions/permissions/fork-pr-contributor-approval' \
  -f approval_policy=all_external_contributors
```

El `PUT` responde `204` sin cuerpo: no verás salida.

**Verifica**: la orden de `fork-pr-approval`:

```bash
gh api 'repos/{owner}/{repo}/actions/permissions/fork-pr-contributor-approval' --jq .approval_policy
# all_external_contributors
```

---

## Paso 7: Push y `main` en verde

**Por qué**: un recorte de permisos solo está bien hecho si el CI sigue pasando. El commit toca
los 7 workflows, así que el push dispara todos los que tienen filtro de rutas por su propio
archivo: `ci`, `ci-api`, `ci-web`, `lint-workflows`, `images` y `smoke`. Si a un job le falta
un permiso, falla aquí con `Resource not accessible by integration` o con el error de techo
del reutilizable, y sabes exactamente qué job es.

**Comando**:

```bash
git add .github/workflows
git commit -m "ci: drop default token permissions"
git push
sha=$(git rev-parse HEAD)
for w in ci ci-api ci-web lint-workflows images smoke; do
  id=$(gh run list --workflow "$w.yml" --commit "$sha" --limit 1 --json databaseId --jq '.[0].databaseId')
  gh run watch "$id" --exit-status > /dev/null && echo "$w ok"
done
# ci ok
# ci-api ok
# ci-web ok
# lint-workflows ok
# images ok
# smoke ok
```

Si `gh run list` no devuelve nada aún, espera unos segundos: el run tarda en aparecer.

**Verifica**: la orden de `green-on-main`, sin `codeql`, que llega en la práctica 02:

```bash
git fetch -q origin main && sha=$(git rev-parse origin/main)
for w in ci ci-api ci-web lint-workflows; do
  printf '%s=%s ' "$w" "$(gh run list --workflow $w.yml --commit "$sha" --json conclusion --jq '.[0].conclusion')"
done; echo
# ci=success ci-api=success ci-web=success lint-workflows=success
```

Y el log confirma lo que pediste: los jobs de `ci` siguen con `contents: read`, ahora porque
cada uno lo declara.

```bash
id=$(gh run list --workflow ci.yml --commit "$sha" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run view "$id" --log | grep -oE '(Actions|Contents|Metadata): (read|write)' | sort -u
# Contents: read
# Metadata: read
```

---

## ✅ Resultado

- [ ] Sabes leer los permisos efectivos de un job en el grupo `GITHUB_TOKEN Permissions`
- [ ] Los 7 workflows tienen `permissions: {}` en la raíz
- [ ] Los 16 jobs declaran sus permisos, también los que llaman a un reutilizable
- [ ] Solo `images` y `nightly` escriben, y sabes decir por qué cada uno
- [ ] Los 7 checkouts siguen con `persist-credentials: false` y zizmor no encuentra nada
- [ ] Los PRs de cualquier colaborador externo esperan tu aprobación
- [ ] `main` en verde con los permisos nuevos

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 12
# ✅ Todos los workflows de tablero declaran permissions: {} en la raíz
# ✅ Cada job de cada workflow declara sus propios permissions
# ✅ tablero exige aprobación para los workflows de todos los colaboradores externos
```

Las demás comprobaciones siguen en rojo: las cierran las prácticas 02 a 04.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `git diff --stat` del paso 2 dice menos de 7 archivos | El comentario o la sangría de algún bloque no coincide con el patrón | Edita ese workflow a mano y repite la verificación del paso 2 |
| La verificación del paso 2 lista un archivo con `permissions:` | YAML lo lee como `null`, no como mapa vacío | Escribe `permissions: {}` con las llaves |
| `actions/checkout` falla en un job que antes pasaba | El job no declara `contents: read` | Paso 3: añádelo a ese job |
| `The nested job ... is requesting ..., but is only allowed ...` | El job que llama al reutilizable no concede lo que este pide | Paso 3: el bloque va en el job llamador, antes de `uses:` |
| `Resource not accessible by integration` en `nightly` o `images` | Quitaste su permiso de escritura al editar | Paso 4: `actions: write` en `nightly`, `packages: write` en `images` |
| El `PUT` del paso 6 responde 403 o 404 | No eres admin del repo, o `GH_REPO` apunta a otro | `gh repo view --json nameWithOwner,viewerPermission` |
| `gh run view --log` no muestra el grupo de permisos | El run es tan antiguo que su log ya caducó | Usa un run reciente o lanza uno con `gh workflow run` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Análisis estático: zizmor y CodeQL](../1-teoria/07-analisis-estatico-zizmor-y-codeql.md) | [Inyección de scripts](02-inyeccion-de-scripts.md) |
