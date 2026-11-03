# Práctica 04 — Encadenar workflows

> Un workflow también puede despertar porque alguien de fuera manda un aviso o porque otro
> workflow termina. En esta práctica escribes `chain-lab.yml`, que escucha un
> `repository_dispatch` con nombre propio y el final de `dispatch-lab`, y le añades un step con
> `actions/github-script` que pregunta a la API cómo fue el run que lo despertó.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `chain-lab.yml` en `main`, despertado por `repository_dispatch` de tipo `tablero-ping`
- Un evento mandado desde tu terminal con `gh api` y su `client_payload` leído por `env:`
- Un payload hostil que llega al log como texto
- `workflow_run` sobre `dispatch-lab`, que solo sigue si el run vigilado salió verde
- Un step de `github-script` que lee el run vigilado y sus pasos desde la API, con el id por `env:`

## 📋 Antes de empezar

Terminaste la [práctica 03](03-cron-y-dispatch-con-inputs.md): `dispatch-lab.yml` está en `main`,
activo y sin cron.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
gh workflow list --all --json name,state --jq '.[] | select(.name == "dispatch-lab") | .state'
# active
yq '.on | keys | join(",")' .github/workflows/dispatch-lab.yml
# workflow_dispatch
```

Como en la práctica 03, trabajas en `main`: `repository_dispatch` y `workflow_run` solo leen el
workflow de **la rama por defecto**. Un `chain-lab.yml` que solo existe en una rama no despierta
nunca, y no da ningún error que lo avise
([teoría 05](../1-teoria/05-encadenar-workflows.md#repository_dispatch-un-evento-con-nombre-propio)).

---

## Paso 1: Un workflow que escucha `tablero-ping`

**Por qué**: `repository_dispatch` es un evento con un tipo inventado por ti. Quien lo manda no
necesita saber qué workflows escuchan, y `types:` hace que este solo despierte con `tablero-ping`:
sin `types`, cualquier tipo lo despertaría. El `client_payload` lo escribe quien manda el evento,
así que es dato no confiable y llega al shell por `env:`.

**Comando**: crea `.github/workflows/chain-lab.yml`.

```yaml
name: chain-lab

on:
  repository_dispatch:
    types: [tablero-ping]

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  ping:
    name: Recibir tablero-ping
    if: ${{ github.event_name == 'repository_dispatch' }}
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - name: Leer el client_payload
        env:
          EVENT_TYPE: ${{ github.event.action }}
          FROM: ${{ github.event.client_payload.from }}
        run: echo "recibido=$EVENT_TYPE from=$FROM"
```

El `if:` del job parece sobrar con un solo evento. En el paso 4 llega el segundo, y cada job tiene
que saber a cuál responde.

**Verifica**:

```bash
actionlint .github/workflows/chain-lab.yml; echo "exit $?"
# exit 0
git add .github/workflows/chain-lab.yml
git commit -m "ci: add chain lab listening to tablero-ping"
git push
git log origin/main --oneline -1 -- .github/workflows/chain-lab.yml | wc -l
# 1
```

---

## Paso 2: Mandar el evento desde la terminal

**Por qué**: el evento se manda con `POST /repos/{owner}/{repo}/dispatches`, que pide permiso de
escritura sobre el contenido del repo: tu token de `gh auth` lo tiene; desde un workflow, el job
necesitaría `contents: write`. `-f` manda `event_type` como cadena y `-F` con corchetes construye
el objeto anidado `client_payload` sin escribir JSON a mano. `{owner}/{repo}` lo rellena `gh` con
el repo de la carpeta actual.

**Comando**: la respuesta de un dispatch correcto es un `204` sin cuerpo, así que `gh api` no
imprime nada.

```bash
gh api repos/{owner}/{repo}/dispatches -f event_type=tablero-ping -F 'client_payload[from]=cli'
sleep 10
id=$(gh run list --workflow chain-lab.yml --event repository_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
```

**Verifica**: es la orden del check `repository-dispatch-received`, y el log del job.

```bash
gh run list --event repository_dispatch --status success --json databaseId --jq length
# 1
gh run view "$id" --log | grep -oE 'recibido=[^$ ]+ from=[^$ ]+'
# recibido=tablero-ping from=cli
```

`github.event.action` trae el `event_type`. La expresión de `grep` excluye `$` para no casar con
la línea del script, que el log también enseña.

---

## Paso 3: Un payload hostil

**Por qué**: cualquiera con permiso de escritura, o cualquier sistema con un token del repo, puede
mandar un `tablero-ping` con lo que quiera dentro. Si el workflow pegara
`${{ github.event.client_payload.from }}` dentro de `run:`, el texto se volvería código del shell
antes de ejecutarse. Por `env:` es el valor de una variable. El `client_payload` admite como mucho
10 propiedades de primer nivel; para más datos, anídalos.

**Comando**: las comillas simples evitan que tu terminal ejecute `$(id)` antes de mandarlo.

```bash
gh api repos/{owner}/{repo}/dispatches -f event_type=tablero-ping -F 'client_payload[from]=$(id)'
sleep 10
id=$(gh run list --workflow chain-lab.yml --event repository_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
```

**Verifica**: el texto llegó literal y el shell no ejecutó `id`.

```bash
gh run view "$id" --log | grep -cF 'from=$(id)'
# 1
gh run view "$id" --log | grep -c 'uid='
# 0
```

---

## Paso 4: `workflow_run` sobre `dispatch-lab`

**Por qué**: `workflow_run` despierta a un workflow cuando otro cambia de estado, sin tocar el
YAML del otro ([teoría 05](../1-teoria/05-encadenar-workflows.md#workflow_run-cuando-otro-termina)).
Tres detalles deciden si funciona:

- **`workflows:` lista nombres**, el `name:` del workflow vigilado, no el archivo.
- **`completed` no significa `success`**: también llega cuando el vigilado falla o se cancela. El
  `if:` del job comprueba la conclusión.
- **Corre con los permisos del repo** aunque el run vigilado viniera de un PR ajeno. Aquí no hay
  checkout ni descarga de artefactos, solo metadatos; el patrón seguro completo, con artefactos de
  un fork, lo ves en la Semana 12.

**Comando**: añade el evento al bloque `on:` de `chain-lab.yml`…

```yaml
  workflow_run:
    workflows: [dispatch-lab]
    types: [completed]
```

…y un segundo job al final del archivo:

```yaml
  after-dispatch:
    name: Tras dispatch-lab
    # completed incluye failure y cancelled: solo seguimos si dispatch-lab salió verde.
    if: ${{ github.event_name == 'workflow_run' && github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - name: Metadatos del evento
        env:
          RUN_URL: ${{ github.event.workflow_run.html_url }}
          HEAD_SHA: ${{ github.event.workflow_run.head_sha }}
        run: echo "dispatch-lab verde en $HEAD_SHA, $RUN_URL"
```

**Verifica**:

```bash
actionlint .github/workflows/chain-lab.yml; echo "exit $?"
# exit 0
yq '.on.workflow_run.workflows[0] + " " + .on.workflow_run.types[0]' .github/workflows/chain-lab.yml
# dispatch-lab completed
git add .github/workflows/chain-lab.yml
git commit -m "ci: follow dispatch lab runs with workflow_run"
git push
```

---

## Paso 5: Un verde y un rojo en la cadena

**Por qué**: hay que ver las dos ramas del `if:`. Lanzas `dispatch-lab` dos veces con el input
`outcome` de la práctica 03: una termina en `success`, la otra en `failure`. Las dos despiertan
a `chain-lab`, pero solo la primera pasa el `if:` de `after-dispatch`; en la segunda, sus dos jobs
se saltan y el run queda `skipped`.

**Comando**: un helper corto para esperar al último run de un workflow. `dispatch-lab` con
`outcome=failure` termina en rojo a propósito.

```bash
last() { gh run list --workflow "$1" --limit 1 --json databaseId --jq '.[0].databaseId'; }
gh workflow run dispatch-lab.yml -f outcome=success -f flag=false && sleep 10
gh run watch "$(last dispatch-lab.yml)" > /dev/null; sleep 15
gh run watch "$(last chain-lab.yml)" > /dev/null
gh workflow run dispatch-lab.yml -f outcome=failure && sleep 10
gh run watch "$(last dispatch-lab.yml)" > /dev/null; sleep 15
gh run watch "$(last chain-lab.yml)" > /dev/null
```

**Verifica**: los dos últimos runs de `chain-lab` por `workflow_run`, el más reciente primero.

```bash
gh run list --workflow chain-lab.yml --event workflow_run --limit 2 \
  --json conclusion --jq '[.[].conclusion] | join(",")'
# skipped,success
```

El `skipped` es el run que siguió al rojo: existió, pero su `if:` lo paró. Sin esa comprobación,
`after-dispatch` habría seguido adelante como si `dispatch-lab` hubiera ido bien.

---

## Paso 6: Preguntar a la API con `github-script`

**Por qué**: el evento `workflow_run` trae un resumen del run vigilado, pero no sus jobs ni sus
pasos. `actions/github-script` te da un cliente de la API autenticado con el `GITHUB_TOKEN` del
job ([teoría 08](../1-teoria/08-github-script.md#lo-que-el-script-tiene-a-mano)). Dos reglas de
siempre: el token solo puede lo que diga `permissions:`, así que el job sube `actions: read`; y el
id del run llega por `env:` y el script lo lee con `process.env`. Nada de `${{ }}` dentro de
`script:`: sería código JavaScript que escribe otro
([teoría 08](../1-teoria/08-github-script.md#la-inyección-dentro-de-script)).

**Comando**: en el job `after-dispatch`, añade `permissions` debajo de `timeout-minutes`…

```yaml
    # Sustituye a la raíz: este job no lee código, solo la API de Actions.
    permissions:
      actions: read
```

…y un último step:

```yaml
      - name: Leer el run vigilado desde la API
        uses: actions/github-script@3a2844b7e9c422d3c10d287c895573f7108da1b3 # v9.0.0
        env:
          RUN_ID: ${{ github.event.workflow_run.id }}
        with:
          script: |
            const runId = Number(process.env.RUN_ID);
            const { data: run } = await github.rest.actions.getWorkflowRun({
              ...context.repo,
              run_id: runId,
            });
            const { data } = await github.rest.actions.listJobsForWorkflowRun({
              ...context.repo,
              run_id: runId,
            });
            const steps = data.jobs.flatMap((job) => job.steps ?? []);
            core.info(`leido=${run.name} #${run.run_number} evento=${run.event} conclusion=${run.conclusion}`);
            for (const step of steps) {
              core.info(`paso=${step.conclusion} ${step.name}`);
            }
            await core.summary
              .addHeading(`${run.name} #${run.run_number}`, 3)
              .addTable([
                [{ data: 'Paso', header: true }, { data: 'Conclusión', header: true }],
                ...steps.map((step) => [step.name, step.conclusion ?? '']),
              ])
              .write();
```

```bash
actionlint .github/workflows/chain-lab.yml; echo "exit $?"
# exit 0
git add .github/workflows/chain-lab.yml
git commit -m "ci: read the followed run from the api with github-script"
git push
gh workflow run dispatch-lab.yml -f outcome=success -f flag=false && sleep 10
gh run watch "$(last dispatch-lab.yml)" > /dev/null; sleep 15
id=$(last chain-lab.yml)
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
```

**Verifica**: el script leyó el run de `dispatch-lab` y los dos steps condicionales de la
práctica 03.

```bash
gh run view "$id" --log > /tmp/chain-lab.log
grep -oE 'leido=[^$ ]+ #[0-9]+ evento=[^$ ]+ conclusion=[^$ ]+' /tmp/chain-lab.log
# leido=dispatch-lab #<n> evento=workflow_dispatch conclusion=success
grep -oE 'paso=[a-z]+ Si [a-z.]+' /tmp/chain-lab.log
# paso=success Si github.event.inputs.flag
# paso=skipped Si inputs.flag
yq '.jobs.after-dispatch.steps[] | select((.uses // "") | test("github-script")) | .with.script | test("\$\{\{")' .github/workflows/chain-lab.yml
# false
```

La última orden confirma que el `script:` no tiene ninguna expresión: el id solo está en el `env:`. La tabla con todos
los pasos está en el resumen del run: `gh run view "$id" --web`.

---

## ✅ Resultado

- [ ] `chain-lab.yml` está en `main` y escucha `repository_dispatch` de tipo `tablero-ping`
- [ ] Mandaste el evento con `gh api` y el `client_payload` llegó al shell por `env:`
- [ ] Un `from=$(id)` llegó al log como texto, sin ejecutarse
- [ ] `after-dispatch` corre tras un `dispatch-lab` verde y se salta tras uno rojo
- [ ] `github-script` leyó el run vigilado y sus pasos con `actions: read` solo en su job
- [ ] Ningún `${{ }}` dentro de `run:` ni de `script:`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 07
# ✅ Un workflow tuyo terminó en success disparado por repository_dispatch
```

Lo que queda en rojo es `nightly.yml`: llega con el [proyecto](../3-proyecto/README.md).

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `gh api .../dispatches` responde `404 Not Found` | Tu token de `gh` no tiene permiso de escritura en el repo, o el repo es otro | `gh auth status` y `gh repo view --json nameWithOwner` |
| El dispatch responde `204` pero no aparece ningún run | `chain-lab.yml` no está en `main`, o el `event_type` no coincide con `types` | Paso 1: `git log origin/main -- .github/workflows/chain-lab.yml` |
| `chain-lab` no despierta al terminar `dispatch-lab` | `workflows:` lleva el nombre del archivo en vez del `name:` | `workflows: [dispatch-lab]`, sin `.yml` |
| Tras un `dispatch-lab` rojo, `after-dispatch` corre igual | Falta la comprobación de `conclusion` en el `if:` | Paso 4 |
| `github-script` falla con `Resource not accessible by integration` | El job no tiene `actions: read` | Paso 6 |
| `github-script` falla con `run_id` inválido | `RUN_ID` vacío: el step corre en un run de `repository_dispatch` | El step va en `after-dispatch`, no en `ping` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Cron y dispatch con inputs](03-cron-y-dispatch-con-inputs.md) | [Proyecto: capa 07 de tablero](../3-proyecto/README.md) |
