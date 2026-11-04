# Práctica 01 — Repo central y primera release

> Las tres actions de la Semana 10 y los tres reutilizables de la Semana 09 viven dentro de
> `tablero`, y ningún otro repo de tu organización puede usarlos sin copiarlos. En esta práctica
> los sacas a `<tu-org>/actions-tablero`, les das un CI propio y publicas `v1.0.0` como release
> inmutable.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `<tu-org>/actions-tablero`, público, con `setup-tablero/`, `coverage-report/` y `sql-lint/` en
  la raíz y `_python.yml`, `_node.yml` e `_image.yml` en `.github/workflows/`
- Los reutilizables preparando cada job con `$/setup-tablero` en lugar de `./`
- Un `ci.yml` del repo central en verde: actionlint, zizmor, tests de `coverage-report` y humo
  de `sql-lint`
- La release `v1.0.0`, inmutable, y el SHA de commit al que apunta su tag

## 📋 Antes de empezar

Terminaste la Semana 10: `main` de `tablero` tiene `.github/actions/` con las tres actions y los
reutilizables `_*.yml`, todo en verde.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
ls .github/actions/
# coverage-report  setup-tablero  sql-lint
ls .github/workflows/_*.yml
# .github/workflows/_image.yml  .github/workflows/_node.yml  .github/workflows/_python.yml
```

En esta práctica `tablero` no cambia: solo lo lees. Lo cambias en la práctica 02.

---

## Paso 1: Crear el repo central y mover las piezas

**Por qué**: el repo central es público para que cualquier repo de la org (y el autograding)
pueda leerlo sin credenciales extra. Las actions van en la **raíz**, no en `.github/actions/`:
así se llaman `<tu-org>/actions-tablero/setup-tablero@<sha>`, sin una ruta interna que nadie
recuerda ([teoría 01](../1-teoria/01-un-repo-central-de-ci.md)). Copias con `git archive` y no
con `cp -r` porque `git archive` solo trae lo comiteado: el `node_modules/` que tienes en local
dentro de `coverage-report/` se queda fuera. Un commit por pieza, para que el historial diga de
dónde viene cada una.

**Comando**:

```bash
gh repo create <tu-org>/actions-tablero --public --add-readme \
  --description "Actions y workflows reutilizables de CI de la organización"
gh repo clone <tu-org>/actions-tablero ~/code/actions-tablero
cd ~/code/actions-tablero
T=~/code/tablero

for a in setup-tablero coverage-report sql-lint; do
  git -C "$T" archive HEAD:.github/actions "$a" | tar -x
  git add "$a" && git commit -m "feat($a): move action from tablero"
done

mkdir -p .github/workflows
git -C "$T" archive HEAD:.github/workflows _python.yml _node.yml _image.yml | tar -x -C .github/workflows
git add .github/workflows && git commit -m "feat(workflows): move reusable workflows from tablero"
```

**Verifica**:

```bash
find . -name action.yml -not -path './.git/*' | sort
# ./coverage-report/action.yml
# ./setup-tablero/action.yml
# ./sql-lint/action.yml
ls .github/workflows/
# _image.yml  _node.yml  _python.yml
git log --oneline | wc -l   # README inicial, tres actions y los reutilizables
# 5
```

---

## Paso 2: De `./` a `$/` en los reutilizables

**Por qué**: es el problema central de la semana. Cuando `tablero` llame a `_python.yml` del
repo central, el job corre en el workspace de **`tablero`**: `uses: ./.github/actions/setup-tablero`
busca la action en el checkout del llamador, donde ya no existe. `$/setup-tablero` se resuelve
contra el repo y el commit **del archivo que corre**, sin checkout
([teoría 02](../1-teoria/02-referencias-dentro-del-repo-central.md); verificado con el
changelog de GitHub del 2026-07-30, noviembre de 2026). Además, con `$/` desaparece el
comentario `# zizmor: ignore[self-repository]` de la Semana 10: era justo lo que zizmor pedía.

**Comando**: una sustitución que cambia la línea entera, comentario incluido:

```bash
sed -i -E 's|uses: \./\.github/actions/([a-z-]+).*|uses: $/\1|' \
  .github/workflows/_python.yml .github/workflows/_node.yml
git diff --stat
#  .github/workflows/_node.yml   | 6 +++---
#  .github/workflows/_python.yml | 6 +++---
#  2 files changed, 6 insertions(+), 6 deletions(-)
```

`_image.yml` no se toca: no usa `setup-tablero`. Cada job queda así:

```yaml
      - uses: $/setup-tablero
        with:
          stack: python
          working-directory: ${{ inputs.working-directory }}
```

```bash
git commit -am "refactor(workflows): reference setup-tablero with self-repository syntax"
```

**Verifica**: la misma cuenta que hace `checks.json` sobre la release (tres `$/` y ningún `./`
por archivo), y el error que actionlint 1.7.12 da con la sintaxis nueva:

```bash
for f in _python _node; do
  printf '%s=%s/%s ' "$f" "$(grep -c 'uses: \$/setup-tablero' .github/workflows/$f.yml)" \
    "$(grep -c 'uses: \./' .github/workflows/$f.yml)"
done; echo
# _python=3/0 _node=3/0
actionlint 2>&1 | grep -c 'invalid format'
# 6
```

---

## Paso 3: Que actionlint acepte `$/`

**Por qué**: actionlint 1.7.12 todavía no conoce `$/` (issue `rhysd/actionlint#711`) y da por
cada uso `specifying action "$/setup-tablero" in invalid format because ref is missing`. No
quitas actionlint: le dices que ignore **ese mensaje y solo ese**, en
`.github/actionlint.yaml`, que actionlint encuentra solo. Si ignoraras la regla `action`
entera, un `uses: actions/checkout@v7` sin SHA pasaría sin aviso.

**Comando**: copia el starter (trae también el `ci.yml` y el `README.md` que completas en los
pasos 4 y 6) y el matcher de anotaciones de `tablero`:

```bash
S=~/code/bc-github-actions/bootcamp/week-11-actions_a_escala_de_organizacion/3-proyecto/starter
cp -r "$S"/actions-tablero/. .
cp ~/code/tablero/.github/actionlint-matcher.json .github/
grep -rnE 'TODO [0-9]' . --exclude-dir=.git | wc -l
# 6
```

El patrón `TODO [0-9]` cuenta solo los huecos numerados del starter: el `dist/` de
`coverage-report` trae comentarios `TODO` de sus dependencias que no son tuyos.

Completa el `TODO 1` de `.github/actionlint.yaml`:

```yaml
# actionlint 1.7.12 todavía no entiende la referencia "self-repository" ($/), que GitHub
# admite desde julio de 2026 (rhysd/actionlint#711). Se ignora solo ese mensaje.
paths:
  .github/workflows/**/*.yml:
    ignore:
      - 'specifying action "\$/[^"]+" in invalid format'
```

La entrada de `ignore` es una expresión regular: `\$` escapa el dólar y `[^"]+` admite
cualquier action de este repo (`setup-tablero`, `sql-lint`) sin abrir nada más.

```bash
git add .github/actionlint.yaml .github/actionlint-matcher.json
git commit -m "ci: ignore actionlint self-repository false positive"
```

**Verifica**:

```bash
actionlint; echo "exit $?"
# exit 0
actionlint -verbose 2>&1 | grep -c '^verbose: Filtered'
# 2
```

Dos líneas `Filtered`: una por archivo con errores ignorados (`_python.yml` y `_node.yml`).

---

## Paso 4: El CI del repo central, en verde

**Por qué**: los consumidores fijan el SHA de una release, así que una release solo se
publica sobre un commit cuyo CI terminó en verde. En `tablero` lo hacía `test-actions.yml`;
aquí ese trabajo es del `ci.yml` central. Tres huecos: zizmor sobre **todo** el repo (los
`action.yml` ya no están bajo `.github/`), y `coverage-report` y `sql-lint` probados con `$/`,
igual que los usarán los reutilizables.

**Comando**: en `.github/workflows/ci.yml`, el `TODO 2` es el `run` del step de zizmor:

```yaml
      - name: zizmor
        # Todo el repo: los workflows y también los action.yml de cada action.
        run: zizmor --offline --format=github .
```

El `TODO 3`, en el job `coverage-report`, después del checkout:

```yaml
      - uses: $/setup-tablero
        with:
          stack: node
          working-directory: coverage-report
```

El `TODO 4`, en el job `sql-lint`, después del checkout:

```yaml
      - id: lint
        uses: $/sql-lint
        with:
          path: sql-lint/tests
      - name: La action revisó el archivo de prueba
        env:
          FILES: ${{ steps.lint.outputs.files }}
        run: test "$FILES" = "1"
```

El output llega al shell por `env:` (regla 4) y el step falla si `sql-lint` no encontró
exactamente el archivo de prueba. Créalo con un SQL que sqlfluff 4.5.0 da por limpio:

```bash
mkdir -p sql-lint/tests
printf 'SELECT\n    id,\n    title\nFROM tasks\nWHERE done = FALSE;\n' > sql-lint/tests/ok.sql
actionlint && zizmor --offline -q .; echo "exit $?"
# No findings to report. Good job! (3 suppressed)
# exit 0
git add .github/workflows/ci.yml sql-lint/tests
git commit -m "ci: add central ci with linters, coverage-report tests and sql-lint smoke test"
git push
gh run watch "$(gh run list --workflow ci.yml --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')" --exit-status > /dev/null
```

Los tres `suppressed` son hallazgos que zizmor solo enseña con una persona más estricta
(`--persona=pedantic`); con la de por defecto no cuentan como fallo.

**Verifica**:

```bash
gh run list --workflow ci.yml --commit "$(git rev-parse HEAD)" --json conclusion --jq '.[0].conclusion'
# success
yq '.jobs | keys | join(" ")' .github/workflows/ci.yml
# actionlint zizmor coverage-report sql-lint
```

---

## Paso 5: Inmutabilidad y release `v1.0.0`

**Por qué**: un tag se puede mover; el de una release inmutable, no. Con la inmutabilidad
activada, al **publicar** la release su tag queda bloqueado en el commit, no se puede borrar ni
mover y GitHub firma una attestation con el tag y el SHA
([teoría 04](../1-teoria/04-releases-inmutables.md)). No es retroactiva: actívala **antes** de
publicar. La creas como borrador, la revisas y solo entonces la publicas. `--target` lleva el
SHA del commit en verde y no `main`: si `main` avanzara entre el borrador y la publicación, el
tag acabaría en otro commit.

**Comando**: activa la inmutabilidad en **Settings → General → Releases → Enable release
immutability**, o por API:

```bash
gh api -X PUT repos/<tu-org>/actions-tablero/immutable-releases
gh api repos/<tu-org>/actions-tablero/immutable-releases --jq .enabled
# true
```

> ⚠️ **Lo que publiques ya no tiene vuelta atrás.** A partir del `gh release edit` de abajo,
> `v1.0.0` queda fijo en ese commit. Si te equivocas, no lo arreglas: publicas `v1.0.1`. Y si
> borras la release, el nombre `v1.0.0` no se puede volver a usar. Revisa la salida de
> `gh release view` antes de publicar.

```bash
sha=$(git rev-parse HEAD)
gh release create v1.0.0 --draft --target "$sha" --title "v1.0.0" --notes "$(cat <<'EOF'
Primera versión del repo central de CI de la organización.

- setup-tablero (composite, Semana 10): prepara uv o pnpm con caché
- coverage-report (JavaScript, Semana 10): resumen de cobertura con mínimo
- sql-lint (Docker, Semana 10): sqlfluff con anotaciones en el diff
- _python.yml, _node.yml, _image.yml (reutilizables, Semana 09), ahora con $/setup-tablero
EOF
)"
gh release view v1.0.0 --json tagName,isDraft,isImmutable,targetCommitish
gh release edit v1.0.0 --draft=false
```

**Verifica**: la release que leen los consumidores, y la attestation que firma GitHub:

```bash
gh api repos/<tu-org>/actions-tablero/releases/latest \
  --jq '"\(.tag_name) immutable=\(.immutable) draft=\(.draft)"'
# v1.0.0 immutable=true draft=false
gh release verify v1.0.0 2>&1 | head -3
# Resolved tag v1.0.0 to sha1:<sha-de-v1.0.0>
# Loaded attestation from GitHub API
# ✓ Release v1.0.0 verified!
gh release verify v1.0.0 2>&1 | grep -q "$sha" && echo "la attestation apunta al commit en verde"
# la attestation apunta al commit en verde
```

---

## Paso 6: Del tag al SHA que fijarán los consumidores

**Por qué**: `tablero` no fijará `v1.0.0` sino el **commit** al que apunta. Ese SHA se
resuelve, nunca se copia de la web ni de la UI: con un tag anotado, el SHA del objeto tag no
es el del commit, y fijarlo deja el check `pinned-sha-matches-tag` en rojo
([teoría 03](../1-teoria/03-versionar-actions.md)). `resolve-sha.sh` distingue los dos casos
desde la Semana 01.

**Comando**:

```bash
~/code/bc-github-actions/scripts/resolve-sha.sh <tu-org>/actions-tablero v1.0.0
# uses: <tu-org>/actions-tablero@<sha-de-v1.0.0> # v1.0.0
SHA=$(gh api repos/<tu-org>/actions-tablero/commits/v1.0.0 --jq .sha)
```

Con ese SHA completa los `TODO 5` y `TODO 6` del `README.md`: una fila por pieza con su línea
`uses:` lista para copiar (`<tu-org>/actions-tablero/setup-tablero@<sha-de-v1.0.0> # v1.0.0`,
`<tu-org>/actions-tablero/.github/workflows/_python.yml@<sha-de-v1.0.0> # v1.0.0`...) y tu
política de versiones. Este commit va **después** del tag: no entra en `v1.0.0`, y no hace
falta, porque el README no se ejecuta.

```bash
git add README.md && git commit -m "docs: add catalog and versioning policy" && git push
```

**Verifica**: los tres caminos dan el mismo commit, y el repo central ya no tiene huecos:

```bash
test "$SHA" = "$sha" && echo "tag, release y commit en verde coinciden"
# tag, release y commit en verde coinciden
grep -rnE 'TODO [0-9]' . --exclude-dir=.git | wc -l
# 0
```

---

## ✅ Resultado

- [ ] `<tu-org>/actions-tablero` es público, con las tres actions en la raíz y los tres reutilizables
- [ ] `_python.yml` y `_node.yml` usan `$/setup-tablero` en sus seis jobs y ningún `./`
- [ ] `actionlint` ignora solo el mensaje de `$/`, y `ci.yml` está en verde
- [ ] `v1.0.0` está publicada, es inmutable y `gh release verify` la da por buena
- [ ] Tienes el SHA del commit de `v1.0.0` en `$SHA`

Los checks del repo central pasan ya; los de `tablero` llegan con la práctica 02:

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 11
# ✅ La última release de actions-tablero es una v1.x.y publicada (no borrador) e inmutable
# ✅ El ci.yml de actions-tablero terminó en success sobre el commit de su última release
# ✅ En la última release, _python.yml y _node.yml preparan cada job con $/setup-tablero y ninguno usa ./
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `coverage-report/node_modules` aparece en `git status` | Lo copiaste con `cp -r` | Bórralo y repite el paso 1 con `git archive`; el `.gitignore` de la action lo ignora igualmente |
| actionlint sigue dando `invalid format` | La regex no casa: comillas dobles en el YAML o sin `\$` | Comillas simples y `\$`, como en el paso 3 |
| `exit 0` en actionlint pero también con un `@v7` sin SHA | Ignoraste la regla `action` entera | Ignora solo el mensaje `specifying action "\$/...` |
| `sql-lint (humo)` falla en `test "$FILES" = "1"` | `path` relativo a otra carpeta o `ok.sql` sin comitear | `path: sql-lint/tests` y `git add sql-lint/tests` |
| `coverage-report (tests y dist)` falla en `git diff --exit-code -- dist` | El `dist/` comiteado no es el de `src/` | `pnpm install && pnpm build` en `coverage-report/`, comitea `dist/` |
| Un job con `$/` falla al resolver la action | Runner anterior a 2.336.0 o GHES: `$/` es solo de github.com | En los runners alojados no debería pasar; revisa la versión en el log de "Set up job" |
| `immutable=false` en la release | Activaste la inmutabilidad después de publicar | Actívala y publica `v1.0.1` sobre un commit en verde |
| `gh release verify` no encuentra attestation | La release sigue en borrador | `gh release edit v1.0.0 --draft=false` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Rulesets que exigen workflows](../1-teoria/07-rulesets-que-exigen-workflows.md) | [Consumir el repo central](02-consumir-el-repo-central.md) |
