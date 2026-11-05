# Práctica 04 — Verificador OIDC y deploy-gate

> Una nube no confía en un token porque llegue: comprueba la firma, el emisor, la audiencia, la
> caducidad y el `sub`, y solo entonces da credenciales. `oidc-verifier` hace eso mismo dentro de
> `tablero`. En esta práctica lo pruebas, lo conectas a los dos jobs de `deploy-gate` e intentas
> engañarlo.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `tools/oidc-verifier/` en `tablero`, con sus 16 tests en verde
- `ci-tools.yml`, que lo prueba con el `_python.yml` de tu repo central
- Los dos jobs de `deploy-gate.yml` pasando su token al verificador por un pipe
- Un intento de suplantación rechazado, y la capa 13 entera en verde

## 📋 Antes de empezar

Terminaste la [práctica 03](03-token-oidc-y-sus-claims.md): `OIDC_SUB` existe en los dos
environments y `oidc-claims.yml` ya no está.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
gh run list --workflow deploy-gate.yml --status waiting --json databaseId --jq '.[].databaseId' |
  xargs -r -n1 gh run cancel
git status --short | wc -l
# 0
```

---

## Paso 1: El verificador, en local

**Por qué**: el verificador decide quién despliega, así que es el código que más tiene que estar
probado del repo. Lee el token por stdin, nunca como argumento (un argumento se ve en `ps` y en
el historial), busca en las claves públicas del emisor la del `kid` de la cabecera, admite solo
`RS256` y exige `aud`, `iss`, `exp`, el `sub` exacto y los claims que le pidas. Sus tests firman
tokens con una clave propia y una JWKS de prueba: no necesitan red ni GitHub.

**Comando**: copia el verificador y añade sus cachés a `.gitignore`:

```bash
cp -r ~/code/bc-github-actions/app/tools .
cat >> .gitignore <<'EOF'
tools/oidc-verifier/.venv/
tools/oidc-verifier/.coverage
tools/oidc-verifier/.pytest_cache/
tools/oidc-verifier/.ruff_cache/
EOF
(cd tools/oidc-verifier && uv sync --locked && uv run --no-sync pytest tests/unit -q) | grep -oE '[0-9]+ passed'
# 16 passed
```

**Verifica**: la orden de `verifier-present`, y que Git no ve el entorno virtual:

```bash
test -f tools/oidc-verifier/pyproject.toml && test -f tools/oidc-verifier/uv.lock && test -f tools/oidc-verifier/src/oidc_verifier/core.py && echo presente
# presente
git status --short --untracked-files=all | grep -c '\.venv/'
# 0
```

---

## Paso 2: `ci-tools.yml` con el reutilizable del repo central

**Por qué**: el verificador es Python con uv, como `api/`, y el `_python.yml` de tu repo central
ya sabe instalarlo, pasar lint y tests y exigir cobertura. Solo cambian tres inputs:
`working-directory`, `package` (el que mide la cobertura) e `integration: false`, porque el
verificador no tiene base de datos. Y Dependabot tiene que vigilar su `uv.lock`: PyJWT y
cryptography son las dependencias que validan identidades.

**Comando**: escribe a mano `.github/workflows/ci-tools.yml`, con tu org y tu SHA:

```yaml
# Prueba las herramientas de tools/ con el reutilizable de Python del repo central.
name: ci-tools
on:
  push:
    branches: [main]
    paths:
      - "tools/**"
      - ".github/workflows/ci-tools.yml"
  pull_request:
    paths:
      - "tools/**"
      - ".github/workflows/ci-tools.yml"
  workflow_dispatch:
# Un run por workflow y ref: en un PR, el push nuevo cancela el run anterior;
# en main cada commit termina su run.
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
permissions: {}
jobs:
  oidc-verifier:
    name: oidc-verifier
    uses: <tu-org>/actions-tablero/.github/workflows/_python.yml@<sha-de-v1.0.0> # v1.0.0
    with:
      working-directory: tools/oidc-verifier
      package: oidc_verifier
      integration: false
    permissions:
      contents: read
```

En `.github/dependabot.yml`, la entrada de `uv` pasa de `directory` a `directories`:

```yaml
  - package-ecosystem: uv
    directories:
      - /api
      - /tools/oidc-verifier
```

```bash
actionlint
git add .gitignore tools .github/workflows/ci-tools.yml .github/dependabot.yml
git commit -m "ci: test oidc verifier with central python workflow"
git push
sleep 5
id=$(gh run list --workflow ci-tools.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null && echo ci-tools ok
# ci-tools ok
```

**Verifica**: la orden de `ci-tools-reusable` y los directorios de Dependabot:

```bash
yq '.jobs[] | select(.uses // "" | test("/actions-tablero/.github/workflows/_python.yml@[0-9a-f]{40}$")) | .with."working-directory" + " integration=" + (.with.integration | tostring)' \
  .github/workflows/ci-tools.yml
# tools/oidc-verifier integration=false
yq '.updates[] | select(."package-ecosystem" == "uv") | .directories | join(",")' .github/dependabot.yml
# /api,/tools/oidc-verifier
```

---

## Paso 3: El token, de `curl` al verificador sin tocar el disco

**Por qué**: el token pasa de `curl` a `jq` y de `jq` a la entrada del verificador por un pipe.
No queda en una variable, ni en un archivo, ni en el log. El runner no lo enmascara, porque no
lo conoce: lo único que lo protege es no escribirlo nunca.

Cada pieza tiene su motivo. `AUDIENCE` es una sola variable para pedir el token y para
comprobarlo, y así no pueden divergir. `EXPECTED_SUB` llega por `env:` desde `vars.OIDC_SUB`, la
de su environment. `--claim runner_environment=github-hosted` rechaza un token de un runner
propio (Semana 15) y `--claim ref=refs/heads/main` repite la regla del environment dentro de la
verificación. `curl -f` y el `pipefail` del shell explícito hacen que un fallo de la petición
tumbe el step. La tabla de claims va al resumen del job.

**Comando**: en `.github/workflows/deploy-gate.yml`, después de las migraciones de `staging`:

```yaml
      - name: Token OIDC verificado como lo haría la nube
        working-directory: tools/oidc-verifier
        env:
          AUDIENCE: tablero-verifier
          EXPECTED_SUB: ${{ vars.OIDC_SUB }}
        run: |
          uv sync --locked
          curl -sSf -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
              "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=$AUDIENCE" |
            jq -r .value |
            uv run --no-sync oidc-verifier --audience "$AUDIENCE" --sub "$EXPECTED_SUB" \
              --claim runner_environment=github-hosted --claim ref=refs/heads/main \
              >> "$GITHUB_STEP_SUMMARY"
```

Y el mismo step, idéntico, después de las migraciones de `production`: `vars.OIDC_SUB` ya vale
el `sub` de production en ese job.

```bash
actionlint
git commit -am "ci: verify oidc token in deploy gate"
git push
sleep 5
run=$(gh run list --workflow deploy-gate.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
pending="repos/{owner}/{repo}/actions/runs/$run/pending_deployments"
until [ "$(gh api "$pending" --jq length)" -gt 0 ]; do sleep 10; done
env_id=$(gh api "$pending" --jq '.[0].environment.id')
gh api -X POST "$pending" -F "environment_ids[]=$env_id" \
  -f state=approved -f comment='Staging verificado por OIDC' > /dev/null
gh run watch "$run" --exit-status > /dev/null && echo deploy-gate ok
# deploy-gate ok
```

La tabla de claims de cada job está en el resumen del run: `gh run view "$run" --web`.

**Verifica**: la orden de `gate-verifier` y los dos jobs en verde:

```bash
yq '[.jobs[].steps[] | select((.run // "" | test("ACTIONS_ID_TOKEN_REQUEST_URL")) and (.run | test("\|\s*uv run --no-sync oidc-verifier")) and (.env.EXPECTED_SUB // "" | test("vars\.OIDC_SUB")))] | length' \
  .github/workflows/deploy-gate.yml
# 2
gh run view "$run" --json jobs --jq '.jobs[] | .name + " " + .conclusion'
# Staging success
# Production success
```

---

## Paso 4: Intenta engañarlo

**Por qué**: un control que nunca has visto fallar no sabes si funciona. Tres intentos:

1. **Otro environment**: pones en `staging` el `sub` de production, como haría quien quisiera
   que un token de staging valiera para production. El token de staging dice
   `environment:staging` y la comparación exacta lo rechaza.
2. **Otra clave**: un token con el mismo `kid` firmado por otra clave, o con un `kid` que el
   emisor no publica. Fabricar eso contra GitHub no está a tu alcance; los tests lo hacen.
3. **Otro workflow**: lo viste en la práctica 03. El token de `oidc-claims.yml` en `staging`
   decía `oidc-claims.yml` en su `sub`, y ningún `OIDC_SUB` lo acepta.

> ⚠️ **Vas a sobrescribir `OIDC_SUB` de `staging`.** Primero guardas el valor actual en
> `backup`; al final del paso lo restauras. No cierres la terminal entre medias: si la pierdes,
> el mensaje de rechazo trae el `sub` firmado.

**Comando**:

```bash
q='.[] | select(.name == "OIDC_SUB") | .value'
backup=$(gh variable list --env staging --json name,value --jq "$q")
gh variable set OIDC_SUB --env staging --body "$(gh variable list --env production --json name,value --jq "$q")"
gh workflow run deploy-gate.yml --ref main && sleep 5
run=$(gh run list --workflow deploy-gate.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null || gh run view "$run" --log-failed | grep -oE 'rechazado: .*'
# rechazado: sub 'repo:...:environment:staging:job_workflow_ref:.../deploy-gate.yml@refs/heads/main' no es el esperado 'repo:...:environment:production:job_workflow_ref:.../deploy-gate.yml@refs/heads/main'
gh variable set OIDC_SUB --env staging --body "$backup"
(cd tools/oidc-verifier && uv run --no-sync pytest tests/unit -q -k "another_key or unknown_kid") | grep -oE '[0-9]+ passed'
# 2 passed
```

Production no llegó a pedir aprobación: con staging en rojo, `needs` lo salta.

**Verifica**: el run falló y `OIDC_SUB` vuelve a estar bien (la orden de `oidc-sub-vars`):

```bash
gh run view "$run" --json conclusion --jq .conclusion
# failure
for e in staging production; do v=$(gh variable list --env "$e" --json name,value --jq '.[] | select(.name == "OIDC_SUB") | .value'); grep -qE "^repo:[^:]+/tablero[^:]*:environment:$e:job_workflow_ref:[^:]+/tablero/\.github/workflows/deploy-gate\.yml@refs/heads/main$" <<<"$v" && printf '%s=ok ' "$e" || printf '%s=mal ' "$e"; done; echo
# staging=ok production=ok
```

---

## Paso 5: actionlint y zizmor con las auditorías online

**Por qué**: la Semana 12 dejó los workflows sin hallazgos y esta semana añadió dos más, un
environment, `id-token: write` y secretos. Las auditorías online de zizmor consultan la API de
GitHub (por ejemplo, que cada SHA fijado sea de verdad del repo que dice); por eso llevan tu
token. Y ningún `run:` puede tener una expresión, tampoco ahora que hay `vars`.

**Comando**:

```bash
actionlint && GH_TOKEN=$(gh auth token) zizmor -q .github/ && echo limpio
# limpio
```

**Verifica**: la orden de `no-expressions-in-run` no encuentra ninguna expresión:

```bash
yq '.jobs[].steps[]? | (.run // "") + (.with.script // "")' .github/workflows/*.yml | grep -cE '\$\{\{'
# 0
```

---

## Paso 6: La capa entera en verde sobre el último commit

**Por qué**: `green-on-main` mira el run más reciente de cada workflow sobre el último commit de
`main`. Para `deploy-gate` es el del paso 4, en rojo. Y `ci-tools` no corrió con el commit del
paso 3, que no tocaba `tools/`. Los lanzas los dos a mano sobre `main` y apruebas production.

**Comando**:

```bash
gh workflow run ci-tools.yml --ref main
gh workflow run deploy-gate.yml --ref main && sleep 5
tools=$(gh run list --workflow ci-tools.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')
run=$(gh run list --workflow deploy-gate.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')
pending="repos/{owner}/{repo}/actions/runs/$run/pending_deployments"
until [ "$(gh api "$pending" --jq length)" -gt 0 ]; do sleep 10; done
env_id=$(gh api "$pending" --jq '.[0].environment.id')
gh api -X POST "$pending" -F "environment_ids[]=$env_id" \
  -f state=approved -f comment='Capa 13: staging verificado por OIDC' > /dev/null
gh run watch "$run" --exit-status > /dev/null && gh run watch "$tools" --exit-status > /dev/null && echo capa ok
# capa ok
```

**Verifica**: la orden de `green-on-main`:

```bash
git fetch -q origin main && sha=$(git rev-parse origin/main) && for w in ci-tools deploy-gate; do printf '%s=%s ' "$w" "$(gh run list --workflow $w.yml --commit "$sha" --json conclusion --jq '.[0].conclusion')"; done; echo
# ci-tools=success deploy-gate=success
```

---

## ✅ Resultado

- [ ] `tools/oidc-verifier/` en `tablero`, con 16 tests en verde y sus cachés ignoradas
- [ ] `ci-tools.yml` llama al `_python.yml` del repo central sin integración
- [ ] Dependabot vigila `/tools/oidc-verifier`
- [ ] Los dos jobs de `deploy-gate` verifican su token, que nunca se escribe en ningún sitio
- [ ] Viste el rechazo de un `sub` ajeno y restauraste `OIDC_SUB`
- [ ] actionlint y zizmor online limpios; `ci-tools` y `deploy-gate` en verde sobre `main`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 13
# Semana 13 — Secretos, entornos y OIDC  [repo: <tu-org>/tablero]
# ...
# 17/17 comprobaciones superadas.
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `rechazado: sub '...' no es el esperado ''` | `OIDC_SUB` no existe en ese environment | Práctica 03, paso 6; el mensaje trae el `sub` firmado |
| `rechazado: sub '...' no es el esperado '...'` en el paso 3 | `OIDC_SUB` se sacó de otro workflow o de otro environment | Compara las dos cadenas y corrige la variable |
| `rechazado: token inválido: Audience doesn't match` | La audiencia pedida y la de `--audience` no son la misma | Una sola variable `AUDIENCE` para las dos |
| `rechazado: no llegó ningún token por stdin` | `jq` no encontró `.value` | Revisa la URL: `&audience=`, no `?audience=` |
| `curl: (6) Could not resolve host: &audience=tablero-verifier` | Falta `id-token: write` en el job | Práctica 03, paso 2 |
| `ci-tools` falla por cobertura | Copiaste el verificador sin sus tests | `cp -r` de `app/tools` entero |
| zizmor online responde con un error de autenticación | `GH_TOKEN` vacío | `gh auth status` y `GH_TOKEN=$(gh auth token)` delante |
| `green-on-main` dice `deploy-gate=failure` | El último run del commit es el del paso 4 | Paso 6 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [El token OIDC y sus claims](03-token-oidc-y-sus-claims.md) | [Proyecto: capa 13 de tablero](../3-proyecto/README.md) |
