# Autograding

`scripts/check-week.sh` te dice qué te falta antes de entregar. No sabe nada de ninguna
semana en concreto: lee `bootcamp/week-NN-*/checks.json` y ejecuta cada comando **dentro de tu
copia local de `<tu-org>/tablero`**, con `gh` apuntando a ese repo.

Comprueba dos sitios a la vez:

- **Lo local**: tus archivos de workflow, tu Docker y, desde la Semana 16, tu clúster kind.
- **Lo remoto**: tus ejecuciones en GitHub, los settings de tu repo y de tu organización.

---

## Configuración (una vez, en la Semana 01)

Crea `~/.bc-github-actions` con dos variables:

```bash
cat > ~/.bc-github-actions <<'EOF'
REPO=<tu-org>/tablero
APP_DIR=~/code/tablero
EOF
```

- `REPO`: el repo público que creas en la Semana 01.
- `APP_DIR`: dónde lo clonaste.

Las variables de entorno `REPO` y `APP_DIR` tienen prioridad sobre el archivo, por si quieres
verificar otro clon: `APP_DIR=/tmp/otro ./scripts/check-week.sh 05`.

---

## Uso

```bash
./scripts/check-week.sh --doctor   # comprueba herramientas, gh y tu repo
./scripts/check-week.sh 05         # comprueba la Semana 05
```

Salida:

```
Semana 05 — Service containers y PostgreSQL  [repo: <tu-org>/tablero]

  ✅ ci-api.yml pasa actionlint
  ✅ El job integration de ci-api.yml levanta PostgreSQL 17 como service container con healthcheck
  ❌ ci-api.yml terminó en success sobre el último commit de main
     pista: 2-practicas/02-postgresql-como-service.md, paso 6

  11/12 comprobaciones superadas.
```

Sale con 0 si pasan todas y con 1 si falla alguna. **Cada pista dice en qué práctica y en qué paso
se arregla**: si una pista no lleva ahí, es un fallo del material y merece un issue.

---

## Qué hace antes de cada comando

1. Hace `cd "$APP_DIR"`: las rutas del `cmd` son relativas a la raíz de tu repo
   (`.github/workflows/ci-api.yml`).
2. Exporta `GH_REPO="$REPO"`. `GH_REPO` es una variable nativa de `gh`: todo `gh run`,
   `gh workflow` y `gh api repos/{owner}/{repo}/...` habla con tu repo sin escribir su nombre.
3. Si el `checks.json` declara `"context"`, crea un kubeconfig temporal que solo contiene ese
   contexto. Un `kubectl` a secas nunca toca otro clúster.

---

## Formato de `checks.json`

Un archivo por semana, en la raíz de la carpeta de la semana.

```json
{
  "week": "05",
  "title": "Service containers y PostgreSQL",
  "checks": [
    {
      "id": "integration-postgres-17",
      "description": "El job integration de ci-api.yml levanta PostgreSQL 17 como service container con healthcheck",
      "cmd": "yq '.jobs.integration.services.postgres | .image + \" \" + (.options // \"\")' .github/workflows/ci-api.yml",
      "assert": "stdout~^postgres:17\\.[0-9]+-alpine .*--health-cmd",
      "hint": "2-practicas/02-postgresql-como-service.md, paso 2"
    },
    {
      "id": "ci-api-verde-en-main",
      "description": "ci-api.yml terminó en success sobre el último commit de main",
      "cmd": "git fetch -q origin main && gh run list --workflow ci-api.yml --commit \"$(git rev-parse origin/main)\" --json conclusion --jq '.[0].conclusion'",
      "assert": "stdout~^success$",
      "hint": "2-practicas/02-postgresql-como-service.md, paso 6"
    }
  ]
}
```

Campo opcional de primer nivel: `"context": "kind-gha"` en las semanas con clúster (S16-20).

### Campos

| Campo | Obligatorio | Qué es |
|---|:--:|---|
| `id` | sí | Identificador estable en kebab-case. **Nunca se renombra** |
| `description` | sí | Qué se comprueba, en una línea. **Se copia literal** a `3-proyecto/README.md` |
| `cmd` | sí | Comando bash que se ejecuta en la raíz de tu repo. `gh` ya apunta a tu repo: nunca escribas `--repo` |
| `assert` | sí | Qué tiene que cumplirse. Ver la tabla siguiente |
| `hint` | sí | Archivo y paso donde se arregla |

### Aserciones

| `assert` | Se cumple si |
|---|---|
| `exit0` | el comando sale con código 0 |
| `exit!=0` | el comando sale distinto de 0 |
| `exit=N` | el comando sale exactamente con el código `N` |
| `stdout~RE` | la salida casa con la expresión regular extendida `RE` |
| `stdout!~RE` | la salida **no** casa con `RE` |

---

## Las cuatro familias de comprobación

| Familia | Herramienta | Ejemplo de `cmd` | `assert` |
|---|---|---|---|
| Estática del archivo | `yq` (mikefarah v4) | `yq '.permissions.contents' .github/workflows/ci.yml` | `stdout~^read$` |
| | `actionlint` | `actionlint .github/workflows/ci-api.yml` | `exit0` |
| | `zizmor` | `zizmor --offline .github/workflows/` | `exit0` |
| | `grep` | `grep -hE '^\s*-?\s*uses:' .github/workflows/*.yml \| grep -vE 'uses: \./\|@[0-9a-f]{40} # v' \|\| true` | `stdout!~.` |
| Ejecución remota | `gh run list --commit` | `gh run list --workflow ci.yml --commit "$(git rev-parse origin/main)" --json conclusion --jq '.[0].conclusion'` | `stdout~^success$` |
| Configuración remota | `gh api` | `gh api repos/{owner}/{repo}/environments --jq '[.environments[].name] \| sort \| join(",")'` | `stdout~^production,staging$` |
| Local | `docker`, `kubectl` | `kubectl get deploy tablero-api -n tablero -o jsonpath='{.status.availableReplicas}'` | `stdout~^[1-9]` |

## Reglas

- Se escribe **antes** que el contenido: define qué es entregable y qué tienen que enseñar las
  prácticas.
- Entre 6 y 18 comprobaciones, creciendo con la complejidad de la semana.
- Una comprobación, un hecho. Nada de encadenar dos cosas con `&&` dentro del `cmd` salvo que
  sean un único requisito (el `git fetch` que precede a `gh run list` lo es).
- **Una ejecución remota se comprueba sobre el SHA de `origin/main`**, nunca "la última": un
  verde de hace tres commits no demuestra nada sobre el código actual.
- Sin efectos duraderos: un `cmd` nunca lanza un workflow, crea un release, borra una caché ni
  modifica un setting. Solo lee.
- Preferir `--json` + `--jq` a parsear columnas: las columnas de `gh` cambian, los campos JSON no.
- **Cero lógica bash por semana en `check-week.sh`.** Si una comprobación necesita código
  imperativo, el entregable no es verificable y va a rúbrica manual.

## Comprobaciones superadas por capas posteriores

`check-week.sh NN` valida la capa NN tal como se entrega. Una capa posterior puede cambiar a
propósito lo que una anterior fijó, y entonces el check antiguo pasa a rojo. Es lo esperado:
lo que cuenta es la semana en curso.

| Check | Semana | Lo pone en rojo | Por qué |
|---|:--:|:--:|---|
| `writes-only-where-needed` | 12 | 13 | `deploy-gate.yml` pide `id-token: write` para OIDC |
| `writes-only-where-needed` | 13 | 14 | `release.yml` y `dependency-review.yml` escriben |
| `dependabot-ecosystems` | 12 | 14 | Se añade el ecosistema `docker` en `/api` y `/web` |
| `dependabot-docker` | 14 | 15 | Se añade `/ops/runner` al ecosistema `docker` para vigilar la imagen del runner |
| `lab-runs-on` | 15 | 16 | `lab.yml` pasa de `[self-hosted, tablero-lab]` a `tablero-runners` (ARC) |
| `self-hosted-only-in-lab` | 15 | 16 | `runs-on: tablero-runners` ya no contiene `self-hosted`; la S16 lo comprueba con `own-runners-only-in-lab` |
| `lab-green-on-own-runner` | 15 | 16 | El run lo ejecuta un runner `tablero-runners-…` de ARC, no uno `tablero-lab-…` |
| `gate-environments`, `gate-concurrency`, `gate-env-secret`, `gate-verifier` y `green-on-main` | 13 | 17 | `deploy-gate.yml` se borra: `deploy.yml` despliega de verdad y el apiserver de kind hace de verificador OIDC |
| `id-token-scoped` | 13 | 17 | Los jobs con `id-token: write` pasan a ser `staging` y `production` de `deploy.yml` |
| `writes-only-where-needed` | 13 y 14 | 17 | `deploy.yml` pide `id-token: write` y el job `deploy` de `release.yml`, `actions: write` |
| `own-runners-only-in-lab` | 16 | 17 | `deploy.yml` también usa `tablero-runners`; la S17 lo comprueba con `own-runners-dispatch-only` |
| `org-default-token-read` | 11 | 14 | release-please necesita `can_approve_pull_request_reviews=true`; la Semana 18 cierra el riesgo con revisión obligatoria |

## Permisos de `gh` por semana

| Semanas | Scopes del token de `gh` | Por qué |
|---|---|---|
| 01-20 | `repo`, `workflow` | Leer runs y subir `.github/workflows/` |
| 11, 15, 18 | además `admin:org` | Leer políticas de actions, runner groups y rulesets de organización |

`./scripts/check-week.sh --doctor` te dice qué scopes tienes. Para añadir uno:
`gh auth refresh -s admin:org`.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Preparar el entorno](setup-entorno.md) | [Proyecto hilo conductor: tablero](proyecto-hilo-conductor.md) |
