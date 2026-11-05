# Práctica 01 — Secretos de repo, environment y org

> Un secreto con el mismo nombre puede existir en tres niveles a la vez, y el job recibe solo
> uno. En esta práctica compruebas cuál gana sin imprimir ningún valor, ves qué tapa el runner y
> qué no, y empiezas `deploy-gate.yml` con una contraseña que solo conoce su environment.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Los environments `staging` y `production` creados, todavía sin reglas
- La precedencia environment > repo > org comprobada con un workflow temporal
- `DATABASE_PASSWORD` distinta en cada environment y ninguna a nivel de repo
- La primera versión de `deploy-gate.yml`, con PostgreSQL migrado con la contraseña de staging

## 📋 Antes de empezar

Leíste la [teoría 01](../1-teoria/01-secretos-de-repo-environment-y-org.md) y la
[teoría 02](../1-teoria/02-enmascarado-y-fugas-de-secretos.md), y `check-week.sh 12` está en
verde.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
git status --short | wc -l
# 0
```

---

## Paso 1: Los dos environments, vacíos

**Por qué**: un job con `environment: staging` crea el environment al vuelo si no existe, sin
ninguna regla. Prefieres crearlos tú, saber que existen antes de cargarles secretos y añadir
las reglas en la [práctica 02](02-environments-y-reglas-de-proteccion.md). Un `PUT` sin cuerpo
crea el environment, y si ya existe no le cambia nada.

**Comando**:

```bash
for e in staging production; do
  gh api -X PUT "repos/{owner}/{repo}/environments/$e" > /dev/null
done
```

**Verifica**:

```bash
gh api 'repos/{owner}/{repo}/environments' --jq '[.environments[].name] | sort | join(" ")'
# production staging
```

---

## Paso 2: Laboratorio de precedencia sin imprimir valores

**Por qué**: "el nivel más bajo gana" se olvida a la primera; verlo no. Creas `SHADOW_DEMO` en
el repo y en `staging` con valores que **no son secretos** (`nivel-repo` y `nivel-staging`) y un
workflow temporal con dos jobs: uno sin environment y otro en `staging`. Cada job compara el
valor en el shell y solo escribe qué nivel ganó.

De paso mides el enmascarado: el runner tapa el valor y también su base64 (registra esa
codificación junto al secreto), pero no conoce el valor al revés. Ese `rev` es el ejemplo de lo
que la [teoría 02](../1-teoria/02-enmascarado-y-fugas-de-secretos.md) llama valor derivado: con
un secreto real sería una fuga.

**Comando** (`--body` vale con valores de prueba; con uno real, nunca: paso 3):

```bash
gh secret set SHADOW_DEMO --body nivel-repo
gh secret set SHADOW_DEMO --env staging --body nivel-staging
```

Escribe a mano `.github/workflows/secrets-lab.yml`:

```yaml
# Temporal: compara qué valor de SHADOW_DEMO recibe cada job sin imprimirlo. Se borra en el paso 6.
name: secrets-lab
on:
  workflow_dispatch:
permissions: {}
jobs:
  without-environment:
    name: Sin environment
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - name: Qué nivel gana
        env:
          SHADOW_DEMO: ${{ secrets.SHADOW_DEMO }}
        run: |
          case "$SHADOW_DEMO" in
            nivel-staging) gana=environment ;;
            nivel-repo) gana=repo ;;
            nivel-org) gana=org ;;
            *) gana=ninguno ;;
          esac
          echo "gana=$gana"
          # Con un valor real, estas dos líneas son una fuga: aquí solo miden qué tapa el runner.
          echo "base64=$(printf '%s' "$SHADOW_DEMO" | base64)"
          echo "reves=$(printf '%s' "$SHADOW_DEMO" | rev)"

  with-environment:
    name: Con environment staging
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    environment: staging
    steps:
      - name: Qué nivel gana
        env:
          SHADOW_DEMO: ${{ secrets.SHADOW_DEMO }}
        run: |
          case "$SHADOW_DEMO" in
            nivel-staging) gana=environment ;;
            nivel-repo) gana=repo ;;
            nivel-org) gana=org ;;
            *) gana=ninguno ;;
          esac
          echo "gana=$gana"
          echo "base64=$(printf '%s' "$SHADOW_DEMO" | base64)"
          echo "reves=$(printf '%s' "$SHADOW_DEMO" | rev)"
```

`workflow_dispatch` exige el archivo en la rama por defecto: primero el push. Después, `lab`
lanza el laboratorio y filtra del log las tres líneas de cada job, no las del script:

```bash
actionlint
git add .github/workflows/secrets-lab.yml
git commit -m "ci: add temporary secrets lab"
git push
lab() {
  gh workflow run secrets-lab.yml --ref main && sleep 5
  local id
  id=$(gh run list --workflow secrets-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
  gh run watch "$id" --exit-status > /dev/null
  gh run view "$id" --log |
    awk -F'\t' 'match($3, /(gana|base64|reves)=[^ $]+$/) { print $1 ": " substr($3, RSTART) }'
}
lab
```

**Verifica**: el orden de los jobs puede variar; lo que cuenta es cada línea:

```bash
# Con environment staging: gana=environment
# Con environment staging: base64=***
# Con environment staging: reves=gnigats-levin
# Sin environment: gana=repo
# Sin environment: base64=***
# Sin environment: reves=oper-levin
```

`staging` gana al repo en su job, y el otro job ni lo ve. Y `oper-levin` al revés es
`nivel-repo`: el runner solo tapa las formas que conoce.

---

## Paso 3: `DATABASE_PASSWORD`, una por environment

**Por qué**: si la contraseña de production fuera un secreto de repo, cualquier job de
cualquier workflow la recibiría al pedirla, incluido uno de una rama. Como secreto de
environment solo llega al job que declara ese environment, y en production, después de la
aprobación. `openssl rand -hex 24` da 48 caracteres hexadecimales: nada que rompa una URL de
conexión. Va por stdin: no queda en `~/.zsh_history` ni pasa por tu pantalla. Nadie, ni tú,
conoce el valor, y no hace falta.

**Comando**: dos generaciones, dos valores distintos:

```bash
openssl rand -hex 24 | gh secret set DATABASE_PASSWORD --env staging
openssl rand -hex 24 | gh secret set DATABASE_PASSWORD --env production
```

**Verifica**: la orden de `env-secrets`:

```bash
printf 'repo=%s staging=%s production=%s\n' \
  "$(gh secret list --json name --jq '[.[] | select(.name == "DATABASE_PASSWORD")] | length')" \
  "$(gh secret list --env staging --json name --jq '[.[] | select(.name == "DATABASE_PASSWORD")] | length')" \
  "$(gh secret list --env production --json name --jq '[.[] | select(.name == "DATABASE_PASSWORD")] | length')"
# repo=0 staging=1 production=1
```

---

## Paso 4: Un secreto de org que solo ve `tablero`

**Por qué**: un secreto de org evita copiar el mismo valor en diez repos, pero su visibilidad
por defecto en `gh secret set --org` es `private`: solo repos privados. `tablero` es público, así
que no lo recibiría y el job vería una cadena vacía sin ningún error. `selected` con la lista
exacta de repos es lo correcto. Lo creas con el mismo nombre para ver el tercer nivel: mientras
exista el de repo, el de org pierde.

Listar y crear secretos de org pide el scope `admin:org` en tu sesión de `gh`.

**Comando**:

```bash
gh auth refresh -h github.com -s admin:org
gh secret set SHADOW_DEMO --org <tu-org> --visibility selected --repos tablero --body nivel-org
gh secret list --org <tu-org> --json name,visibility,numSelectedRepos \
  --jq '.[] | select(.name == "SHADOW_DEMO") | "\(.visibility) \(.numSelectedRepos)"'
# selected 1
lab | grep 'Sin environment: gana'
# Sin environment: gana=repo
```

> ⚠️ **Vas a borrar el secreto de repo `SHADOW_DEMO`.** Su valor es `nivel-repo` y no protege
> nada; no hay nada que respaldar. Comprueba el nombre antes de pulsar Enter.

```bash
gh secret delete SHADOW_DEMO
lab | grep 'gana'
```

**Verifica**: sin el de repo llega el de org; `staging` sigue ganando en su job:

```bash
# Con environment staging: gana=environment
# Sin environment: gana=org
```

---

## Paso 5: `deploy-gate.yml`, primera versión

**Por qué**: es el workflow que crece toda la semana. Esta versión tiene solo el job `staging`:
declara `environment: staging` y por eso `secrets.DATABASE_PASSWORD` es el de staging. El secreto
se usa en dos sitios que no son `run:`: el `env` del service container, que PostgreSQL lee al
arrancar, y `DATABASE_URL` en el `env` del job, que las migraciones leen como variable de
entorno. Ningún `${{ }}` dentro de un `run:`: el secreto llega al proceso, no al texto del
script ([regla 4](../../../docs/reglas-de-seguridad-de-workflows.md)).

`defaults.run.shell: bash` no es redundante: con shell explícito el runner ejecuta
`bash --noprofile --norc -eo pipefail {0}` y no `bash -e {0}`. Ese `pipefail` importa en la
práctica 04, cuando el token viaje por un pipe.

**Comando**: escribe a mano `.github/workflows/deploy-gate.yml`, con tu org y el SHA de tu `v1.0.0`:

```yaml
# Ensayo de despliegue: cada environment migra una base con su propia contraseña y demuestra con
# OIDC quién es. En la Semana 17 este workflow pasa a desplegar de verdad.
name: deploy-gate
on:
  push:
    branches: [main]
  workflow_dispatch:
permissions: {}
defaults:
  run:
    # Con shell explícito el runner añade pipefail: si curl falla, el pipe del token falla.
    shell: bash
jobs:
  staging:
    name: Staging
    runs-on: ubuntu-24.04
    timeout-minutes: 15
    environment: staging
    permissions:
      contents: read
    services:
      postgres:
        image: postgres:17.11-alpine
        env:
          POSTGRES_USER: tablero
          POSTGRES_PASSWORD: ${{ secrets.DATABASE_PASSWORD }}
          POSTGRES_DB: tablero
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U tablero -d tablero"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10
    env:
      DATABASE_URL: postgresql://tablero:${{ secrets.DATABASE_PASSWORD }}@localhost:5432/tablero
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: <tu-org>/actions-tablero/setup-tablero@<sha-de-v1.0.0> # v1.0.0
        with:
          stack: python
          working-directory: api
      - name: Migraciones con la contraseña de staging
        working-directory: api
        run: uv run --no-sync python -m tablero.migrate
```

```bash
actionlint && zizmor --offline -q .github/workflows/deploy-gate.yml
git add .github/workflows/deploy-gate.yml
git commit -m "ci: add deploy gate with staging environment"
git push
sleep 5
id=$(gh run list --workflow deploy-gate.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null && echo deploy-gate ok
# deploy-gate ok
```

**Verifica**: el secreto llega al servicio, y ningún `run:` de ningún workflow contiene una
expresión (la orden de `no-expressions-in-run` no imprime nada):

```bash
yq '.jobs.staging.services.postgres.env.POSTGRES_PASSWORD' .github/workflows/deploy-gate.yml
# ${{ secrets.DATABASE_PASSWORD }}
yq '.jobs[].steps[]? | (.run // "") + (.with.script // "")' .github/workflows/*.yml | grep -cE '\$\{\{'
# 0
```

---

## Paso 6: Limpiar el laboratorio

**Por qué**: `SHADOW_DEMO` no protege nada, pero un secreto que nadie usa es ruido que el
siguiente no se atreve a borrar, y `secrets-lab.yml` sigue pudiendo lanzarse. La
[rúbrica](../rubrica-evaluacion.md) comprueba que no queda nada. Un secreto de org real que
conserves, con visibilidad `selected`.

> ⚠️ **Vas a borrar dos secretos y un workflow.** Solo los de prueba: revisa que el nombre es
> `SHADOW_DEMO`. El workflow sigue en el historial de Git si alguna vez lo quieres recuperar.

**Comando**:

```bash
gh secret delete SHADOW_DEMO --env staging
gh secret delete SHADOW_DEMO --org <tu-org>
git rm .github/workflows/secrets-lab.yml
git commit -m "ci: remove temporary secrets lab"
git push
```

**Verifica**: ningún `SHADOW_DEMO` en los tres niveles ni el workflow en `main`:

```bash
q='[.[] | select(.name == "SHADOW_DEMO")] | length'
echo "$(gh secret list --json name --jq "$q") $(gh secret list --env staging --json name --jq "$q") $(gh secret list --org <tu-org> --json name --jq "$q")"
# 0 0 0
git ls-tree --name-only origin/main .github/workflows/ | grep -c secrets-lab
# 0
```

---

## ✅ Resultado

- [ ] `staging` y `production` existen
- [ ] Comprobaste que environment gana a repo y repo gana a org, sin imprimir ningún valor
- [ ] Viste que el runner tapa el valor y su base64, pero no el valor al revés
- [ ] `DATABASE_PASSWORD` en cada environment, generada con `openssl rand` y cargada por stdin
- [ ] `deploy-gate.yml` con el job `staging` en verde
- [ ] Sin rastro de `SHADOW_DEMO` ni de `secrets-lab.yml`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 13
# ✅ Los dos jobs de deploy-gate.yml dan a PostgreSQL el secreto DATABASE_PASSWORD de su environment
# ✅ Ningún run ni script de github-script contiene una expresión ${{ }}: secretos, variables y datos llegan por env
# ✅ DATABASE_PASSWORD existe como secreto de staging y de production, y no como secreto del repositorio
# ...  (el resto sigue en rojo hasta las prácticas siguientes)
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `could not find any workflows named secrets-lab.yml` | El archivo aún no está en `main` | Paso 2: el push antes de `lab` |
| `Sin environment: gana=ninguno` tras el paso 4 | El secreto de org se creó con visibilidad `private` | `gh secret set ... --visibility selected --repos tablero` |
| `gh secret list --org` responde `HTTP 403` | La sesión de `gh` no tiene `admin:org` | `gh auth refresh -h github.com -s admin:org` |
| `lab` no imprime nada | Copiaste mal el patrón de `awk` o el run falló | `gh run view <id> --log-failed` y revisa el patrón |
| `password authentication failed for user "tablero"` en `deploy-gate` | Falta `DATABASE_PASSWORD` en `staging` | Paso 3 y `gh run rerun <id>` |
| `Unable to resolve action <tu-org>/actions-tablero...` | Dejaste el placeholder o el SHA no es el de tu `v1.0.0` | Copia el `uses:` que ya usas: `grep -rh 'actions-tablero/setup-tablero@' .github/workflows \| sort -u` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Política de confianza y sub personalizado](../1-teoria/06-politica-de-confianza-y-sub-personalizado.md) | [Environments y reglas de protección](02-environments-y-reglas-de-proteccion.md) |
