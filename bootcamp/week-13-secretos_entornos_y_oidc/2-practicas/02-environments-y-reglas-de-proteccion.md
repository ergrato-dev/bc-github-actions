# Práctica 02 — Environments y reglas de protección

> Un secreto de environment solo vale lo que valen las reglas del environment. En esta práctica
> cierras las dos puertas que dejaste abiertas: solo `main` despliega, y production espera a que
> una persona lo apruebe. La aprobación la das desde la terminal.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `staging` y `production` que solo aceptan despliegues desde `main`
- `production` con un revisor obligatorio: tú
- El job `production` en `deploy-gate.yml`, detrás de `staging` y con concurrencia sin cancelación
- Un despliegue aprobado por la API y otro, desde una rama, rechazado por las reglas

## 📋 Antes de empezar

Terminaste la [práctica 01](01-secretos-de-repo-environment-y-org.md) y leíste la
[teoría 03](../1-teoria/03-environments-y-reglas-de-proteccion.md).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
git status --short | wc -l
# 0
```

---

## Paso 1: Lo que dejó la práctica 01

**Por qué**: antes de cambiar reglas, mira de dónde partes. Los dos environments existen sin
ninguna regla: `deployment_branch_policy` a `null` significa que **cualquier rama** puede
desplegar en ellos y recibir sus secretos. Y cada run de `deploy-gate` creó un deployment de
GitHub en `staging`, el registro de qué commit llegó a qué environment (lo verás a fondo en la
Semana 17).

**Comando**:

```bash
gh api 'repos/{owner}/{repo}/environments' \
  --jq '.environments[] | [.name, ([.protection_rules[].type] | join(","))] | @tsv'
# production
# staging
gh api 'repos/{owner}/{repo}/environments/staging' --jq '.deployment_branch_policy'
# null
```

**Verifica**: el último deployment de `staging` es el último commit de `main`. Un job con
`environment:` deja un deployment de GitHub; la API de deployments la verás a fondo en la
Semana 17, aquí solo lees el `sha`:

```bash
last=$(gh api 'repos/{owner}/{repo}/deployments?environment=staging&per_page=1' --jq '.[0].sha')
[ "$last" = "$(git rev-parse origin/main)" ] && echo "staging tiene el último commit"
# staging tiene el último commit
```

---

## Paso 2: Solo `main` despliega

**Por qué**: sin esta regla, quien pueda hacer push a una rama puede escribir un workflow con
`environment: production`, lanzarlo desde esa rama y llevarse `DATABASE_PASSWORD`. Con la regla,
el job ni siquiera empieza: el runner no recibe los secretos. Son dos llamadas: el `PUT` activa
las políticas propias (`custom_branch_policies`, que excluye a `protected_branches`) y el `POST`
añade la política `main` de tipo `branch`. Sin el `PUT` previo, el `POST` responde 404.

**Comando**:

```bash
for e in staging production; do
  gh api -X PUT "repos/{owner}/{repo}/environments/$e" --input - > /dev/null \
    <<< '{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}'
  gh api -X POST "repos/{owner}/{repo}/environments/$e/deployment-branch-policies" \
    -f name=main -f type=branch > /dev/null
done
```

**Verifica**: la orden de `environments-protected`:

```bash
for e in staging production; do printf '%s=%s:%s ' "$e" \
  "$(gh api "repos/{owner}/{repo}/environments/$e" --jq '.deployment_branch_policy.custom_branch_policies')" \
  "$(gh api "repos/{owner}/{repo}/environments/$e/deployment-branch-policies" --jq '[.branch_policies[] | .type + "/" + .name] | join(",")')"
done; echo
# staging=true:branch/main production=true:branch/main
```

---

## Paso 3: Un revisor en production

**Por qué**: la rama correcta no basta; un commit malo en `main` también es de `main`. El revisor
obligatorio para el job **antes** de que empiece, y hasta que lo aprueba no le llegan los
secretos de production. Admite hasta seis usuarios o equipos y basta con uno.

`prevent_self_review: true` impide que apruebe quien lanzó el run: es lo correcto en un equipo,
pero trabajas solo y te bloquearía. Lo dejas en `false` y lo anotas como deuda. La UI tiene
además la casilla "Allow administrators to bypass configured protection rules": déjala
desmarcada, o la regla no te protege de ti mismo. El wait timer (de 1 a 43.200 minutos) es otra
regla posible; aquí no lo necesitas.

El `PUT` vuelve a llevar la política de ramas: así el cuerpo describe el environment entero y
no dependes de qué hace la API con un campo que no mandas.

**Comando**: tu id de usuario numérico, no tu login:

```bash
me=$(gh api user --jq .id)
jq -n --argjson id "$me" '{
  reviewers: [{type: "User", id: $id}],
  prevent_self_review: false,
  deployment_branch_policy: {protected_branches: false, custom_branch_policies: true}
}' | gh api -X PUT 'repos/{owner}/{repo}/environments/production' --input - > /dev/null
```

**Verifica**: la orden de `production-reviewers`, y la política de ramas intacta:

```bash
gh api 'repos/{owner}/{repo}/environments/production' \
  --jq '[.protection_rules[] | select(.type == "required_reviewers") | .reviewers | length] | add // 0'
# 1
gh api 'repos/{owner}/{repo}/environments/production/deployment-branch-policies' \
  --jq '[.branch_policies[].name] | join(",")'
# main
```

---

## Paso 4: El job `production` y la concurrencia

**Por qué**: `needs: staging` hace que production solo corra si staging terminó bien: si la
migración rompe en staging, production no llega a pedir aprobación. Es el mismo job con otro
`environment`, y por eso `secrets.DATABASE_PASSWORD` vale otra cosa sin cambiar una letra.

La concurrencia va en la raíz con un grupo fijo, `deploy-gate`: dos runs nunca despliegan a la
vez, venga cada uno de un push o de un `workflow_dispatch`. Y `cancel-in-progress: false`,
porque cortar un despliegue a medias deja el environment en un estado que nadie eligió. El
precio es una cola: mientras un run espera tu aprobación, el siguiente queda en `Pending`, y si
llega un tercero, sustituye al que esperaba.

**Comando**: en `.github/workflows/deploy-gate.yml`, entre `on:` y `permissions:`:

```yaml
# Un despliegue no se corta a medias: el siguiente run espera en cola a que acabe el anterior.
concurrency:
  group: deploy-gate
  cancel-in-progress: false
```

Y, debajo del job `staging`, el job `production` (con tu org y tu SHA, como en staging):

```yaml
  production:
    name: Production
    needs: staging
    runs-on: ubuntu-24.04
    timeout-minutes: 15
    environment: production
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
      - name: Migraciones con la contraseña de production
        working-directory: api
        run: uv run --no-sync python -m tablero.migrate
```

```bash
actionlint && zizmor --offline -q .github/workflows/deploy-gate.yml && echo limpio
# limpio
```

**Verifica**: las órdenes de `gate-environments` y `gate-concurrency`:

```bash
yq '"staging=" + (.jobs.staging.environment | .name // .) + " production=" + (.jobs.production.environment | .name // .) + " needs=" + ([.jobs.production.needs] | flatten | join(","))' \
  .github/workflows/deploy-gate.yml
# staging=staging production=production needs=staging
yq '"group=" + ((.concurrency.group // "") != "" | tostring) + " cancel=" + (.concurrency."cancel-in-progress" // false | tostring)' \
  .github/workflows/deploy-gate.yml
# group=true cancel=false
```

---

## Paso 5: Production espera, y lo apruebas por la API

**Por qué**: cuando staging termina, production queda en `Waiting` y el run entero en estado
`waiting`. La UI enseña el botón "Review deployments"; la API hace lo mismo con
`pending_deployments`: un `GET` lista qué espera y si tú puedes aprobarlo, y un `POST` con el id
**numérico** del environment, `state` y un `comment` obligatorio lo aprueba o lo rechaza. El
comentario queda en el historial del run: escribe por qué apruebas.

**Comando**:

```bash
git add .github/workflows/deploy-gate.yml
git commit -m "ci: add production job behind approval"
git push
sleep 5
run=$(gh run list --workflow deploy-gate.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
pending="repos/{owner}/{repo}/actions/runs/$run/pending_deployments"
until [ "$(gh api "$pending" --jq length)" -gt 0 ]; do sleep 10; done
gh api "$pending" --jq '.[] | "\(.environment.name) puedo-aprobar=\(.current_user_can_approve)"'
# production puedo-aprobar=true
gh run view "$run" --json status --jq .status
# waiting
```

Ahora apruébalo:

```bash
env_id=$(gh api "$pending" --jq '.[0].environment.id')
gh api -X POST "$pending" -F "environment_ids[]=$env_id" \
  -f state=approved -f comment='Ensayo de la práctica 02: migraciones de staging en verde' > /dev/null
gh run watch "$run" --exit-status > /dev/null && echo deploy-gate ok
# deploy-gate ok
```

**Verifica**: los dos jobs en verde, y nada esperando:

```bash
gh run view "$run" --json jobs --jq '.jobs[] | .name + " " + .conclusion'
# Staging success
# Production success
gh api "$pending" --jq length
# 0
```

---

## Paso 6: Una rama no despliega

**Por qué**: comprobar una regla de seguridad es intentar saltártela. `deploy-gate` admite
`workflow_dispatch` desde cualquier rama, así que el workflow sí arranca, pero el environment
`staging` rechaza el job antes de darle un runner. Production ni lo intenta: depende de staging.

**Comando**: una rama sin cambios basta, porque lo que se juzga es la rama, no el código:

```bash
git switch -c test/no-deploy && git push -u origin test/no-deploy && git switch main
gh workflow run deploy-gate.yml --ref test/no-deploy && sleep 5
run=$(gh run list --workflow deploy-gate.yml --branch test/no-deploy --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null || echo "rechazado, como se esperaba"
# rechazado, como se esperaba
gh run view "$run"
```

En las anotaciones del run verás un mensaje como
`Branch "test/no-deploy" is not allowed to deploy to staging due to environment protection rules.`

**Verifica**: el run falló y no hay deployment nuevo con el commit de la rama en `staging` (la
rama apunta al mismo commit que `main`, así que lo compruebas por la rama):

```bash
gh run view "$run" --json conclusion --jq .conclusion
# failure
gh api 'repos/{owner}/{repo}/deployments?environment=staging&ref=test/no-deploy' --jq length
# 0
```

> ⚠️ **Vas a borrar la rama `test/no-deploy`** en local y en GitHub. No tiene commits propios:
> no pierdes nada.

```bash
git push origin --delete test/no-deploy && git branch -D test/no-deploy
git ls-remote --heads origin test/no-deploy | wc -l
# 0
```

---

## ✅ Resultado

- [ ] `staging` y `production` solo aceptan la rama `main`
- [ ] `production` tiene un revisor, y sabes por qué `prevent_self_review` está en `false`
- [ ] `deploy-gate.yml` con `production` detrás de `staging` y concurrencia sin cancelación
- [ ] Aprobaste un despliegue con `pending_deployments` y comentario
- [ ] Un `workflow_dispatch` desde otra rama falló sin tocar ningún environment

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 13
# ✅ deploy-gate.yml tiene un job staging con environment staging y un job production con environment production que necesita a staging
# ✅ deploy-gate.yml declara concurrency en la raíz sin cancel-in-progress
# ✅ Los environments staging y production solo admiten despliegues desde la rama main
# ✅ production exige la aprobación de un revisor antes de ejecutar su job
# ...
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `HTTP 404` en el `POST` de `deployment-branch-policies` | `custom_branch_policies` sigue en `false` | El `PUT` del paso 2 antes del `POST` |
| `HTTP 422` con `already exists` en el `POST` | La política `main` ya estaba | Nada que hacer: la verificación del paso 2 lo confirma |
| `HTTP 422` en el `PUT` de production | `id` no es numérico o el usuario no tiene acceso al repo | `gh api user --jq .id` y `--argjson`, no `--arg` |
| El bucle `until` no termina | Staging falló y production nunca llegó a esperar | `gh run view "$run" --log-failed` |
| `deploy-gate` en `Pending` sin empezar | Otro run del grupo espera aprobación | Apruébalo o recházalo con `state=rejected` |
| No puedes aprobar: `current_user_can_approve` es `false` | `prevent_self_review` en `true`, o no estás en `reviewers` | Paso 3 |
| La rama del paso 6 despliega en staging | La política de ramas no se aplicó a `staging` | Repite el paso 2 y su verificación |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Secretos de repo, environment y org](01-secretos-de-repo-environment-y-org.md) | [El token OIDC y sus claims](03-token-oidc-y-sus-claims.md) |
