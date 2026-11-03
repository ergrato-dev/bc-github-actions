# Práctica 03 — Cron y dispatch con inputs

> Hasta ahora tus workflows arrancaban porque alguien empujaba código. En esta práctica escribes
> `dispatch-lab.yml`, un workflow que se lanza a mano con un input de cada tipo, lo disparas desde
> `gh` de dos maneras, ves en el log por qué `inputs` y `github.event.inputs` no son lo mismo y le
> añades un cron real que luego apagas.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `dispatch-lab.yml` en `main` con inputs `string`, `boolean`, `choice` y `number`, leídos por `env:`
- Un run lanzado con `gh workflow run -f` y otro con `--json` por la entrada estándar
- La diferencia entre `inputs.flag` (booleano) y `github.event.inputs.flag` (cadena), en el log y en
  dos `if:`
- Un texto hostil en el input `note` que llega al log como texto y nada más
- Un `schedule` cada 15 minutos comprobado con `gh run list --event schedule`, desactivado con
  `gh workflow disable` y retirado del YAML

## 📋 Antes de empezar

Terminaste la [práctica 02](02-concurrencia-y-timeouts.md): el PR está fusionado y `main` tiene
los filtros, la concurrencia y los techos.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
yq '.concurrency.group' .github/workflows/ci-api.yml
# ${{ github.workflow }}-${{ github.ref }}
```

Esta práctica y la siguiente trabajan directamente en `main`, sin PR. El motivo es el mismo en las
dos: el botón de `workflow_dispatch`, el cron y los eventos de la práctica 04 leen el workflow de
**la rama por defecto** ([teoría 04](../1-teoria/04-workflow-dispatch-e-inputs.md#quién-puede-pulsar-el-botón)).

---

## Paso 1: Un workflow con un input de cada tipo

**Por qué**: cada tipo de input se ve distinto en la UI y llega distinto a las expresiones
([teoría 04](../1-teoria/04-workflow-dispatch-e-inputs.md#los-cinco-tipos)). `note` es texto libre
y lo escribe quien lanza el run, así que es dato no confiable: entra al shell por `env:`, igual que
los demás, aunque `choice` y `number` los valide GitHub. El quinto tipo, `environment`, despliega
la lista de environments del repo; `tablero` todavía no tiene ninguno y los environments se
estudian en la Semana 13, así que se queda fuera.

**Comando**: crea `.github/workflows/dispatch-lab.yml`.

```yaml
name: dispatch-lab

on:
  workflow_dispatch:
    inputs:
      note:
        description: Texto libre que aparece en el log
        type: string
        required: false
        default: sin nota
      flag:
        description: Casilla para comparar inputs con github.event.inputs
        type: boolean
        default: false
      outcome:
        description: Cómo termina el run
        type: choice
        options: [success, failure]
        default: success
      count:
        description: Cuántas repeticiones imprime
        type: number
        default: 1

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  show:
    name: Inputs en el log
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - name: Inputs por env
        env:
          EVENT: ${{ github.event_name }}
          NOTE: ${{ inputs.note }}
          OUTCOME: ${{ inputs.outcome }}
          COUNT: ${{ inputs.count }}
          FLAG_TYPED: ${{ toJSON(inputs.flag) }}
          FLAG_RAW: ${{ toJSON(github.event.inputs.flag) }}
        run: |
          echo "evento=$EVENT outcome=$OUTCOME count=$COUNT"
          echo "nota: $NOTE"
          echo "tipado=$FLAG_TYPED texto=$FLAG_RAW"
          # En un run de schedule los inputs llegan vacíos: count vale 1.
          for i in $(seq 1 "${COUNT:-1}"); do echo "repetición $i"; done

      - name: Si github.event.inputs.flag
        if: ${{ github.event.inputs.flag }}
        run: echo "Corre aunque la casilla esté desmarcada"

      - name: Si inputs.flag
        if: ${{ inputs.flag }}
        run: echo "Corre solo con la casilla marcada"

      - name: Terminar según outcome
        env:
          OUTCOME: ${{ inputs.outcome }}
        run: |
          if [[ "$OUTCOME" == "failure" ]]; then
            echo "::error::Fallo pedido con outcome=failure"
            exit 1
          fi
```

`toJSON` enseña el tipo en el log: un booleano sale `false`; una cadena, `"false"` con comillas.

**Verifica**: los cuatro tipos y, tras el push, que solo despierta `ci`: el commit toca un archivo
que no está en los `paths` de nadie.

```bash
actionlint .github/workflows/dispatch-lab.yml; echo "exit $?"
# exit 0
yq '[.on.workflow_dispatch.inputs[].type] | join(",")' .github/workflows/dispatch-lab.yml
# string,boolean,choice,number
git add .github/workflows/dispatch-lab.yml
git commit -m "ci: add dispatch lab with one input of each type"
git push
sleep 15
gh run list --commit "$(git rev-parse HEAD)" --json workflowName --jq '[.[].workflowName] | join(",")'
# ci
```

---

## Paso 2: Lanzarlo con `-f`, y con un texto hostil

**Por qué**: `gh workflow run` llama al endpoint de `workflow_dispatch`
([teoría 04](../1-teoria/04-workflow-dispatch-e-inputs.md#desde-gh)). `-f clave=valor` manda cada
input como cadena y GitHub la convierte al tipo declarado. La nota de este run imita lo que
escribiría un atacante: si llegara pegada dentro del script, `$(whoami)` se ejecutaría. Por
`env:` es el valor de una variable y el shell no lo interpreta.

**Comando**: sin `--ref`, el run usa la rama por defecto. Las comillas simples evitan que tu
propia terminal expanda `$(whoami)`.

```bash
gh workflow run dispatch-lab.yml -f note='$(whoami); echo inyectado' -f flag=false -f outcome=success -f count=3
sleep 10
id=$(gh run list --workflow dispatch-lab.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
```

**Verifica**: los valores, tal como los imprimió el job.

```bash
gh run view "$id" --log > /tmp/dispatch-lab.log
grep -oE 'evento=[^$ ]+ outcome=[^$ ]+ count=[^$ ]+' /tmp/dispatch-lab.log
# evento=workflow_dispatch outcome=success count=3
grep -cE 'repetición [0-9]' /tmp/dispatch-lab.log
# 3
grep -cF 'nota: $(whoami); echo inyectado' /tmp/dispatch-lab.log
# 1
```

La nota salió literal: el shell no ejecutó `whoami` ni el `echo` que venía detrás. Las
expresiones de `grep` excluyen `$` para no casar con las líneas del propio script, que el log
también enseña.

---

## Paso 3: `inputs.flag` frente a `github.event.inputs.flag`

**Por qué**: `inputs.flag` es un booleano real; `github.event.inputs.flag` es la misma casilla
convertida en cadena. En un `if:`, cualquier cadena no vacía es verdadera, así que `'false'` deja
pasar un step que debía saltarse
([teoría 04](../1-teoria/04-workflow-dispatch-e-inputs.md#inputs-frente-a-githubeventinputs)). El
run del paso 2 se lanzó con `flag=false`: ahí se ve.

**Comando**:

```bash
grep -oE 'tipado=[^$ ]+ texto=[^$ ]+' /tmp/dispatch-lab.log
# tipado=false texto="false"
```

**Verifica**: los dos steps condicionales del mismo run.

```bash
gh run view "$id" --json jobs \
  --jq '.jobs[0].steps[] | select(.name | startswith("Si ")) | "\(.conclusion)\t\(.name)"'
# success	Si github.event.inputs.flag
# skipped	Si inputs.flag
```

El primero corrió con la casilla desmarcada. Es el fallo que verás en workflows antiguos que
nacieron cuando solo existía `github.event.inputs`: usa siempre `inputs`.

---

## Paso 4: Lanzarlo con `--json`, y un valor fuera de la lista

**Por qué**: con muchos inputs, `--json` lee un objeto de la entrada estándar y te ahorra una
ristra de `-f`. Y un `choice` no es una sugerencia: GitHub rechaza la petición si el valor no está
en `options`, antes de crear ningún run.

**Comando**: el mismo workflow con la casilla marcada.

```bash
echo '{"note":"desde stdin","flag":"true","outcome":"success","count":"1"}' \
  | gh workflow run dispatch-lab.yml --json
sleep 10
id=$(gh run list --workflow dispatch-lab.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
```

**Verifica**: con `flag` verdadero corren los dos steps, y `outcome=maybe` no crea run.

```bash
gh run view "$id" --json jobs \
  --jq '[.jobs[0].steps[] | select(.name | startswith("Si ")) | .conclusion] | join(",")'
# success,success
gh workflow run dispatch-lab.yml -f outcome=maybe; echo "exit $?"
# (un error HTTP 422 que nombra el input outcome)
# exit 1
```

---

## Paso 5: Un cron cada 15 minutos

**Por qué**: `schedule` dispara el workflow sin que nadie haga nada, siempre sobre el último
commit de la rama por defecto y en UTC
([teoría 03](../1-teoria/03-schedule-y-cron.md#las-reglas-de-github)). Un cron cada 15 minutos te
deja verlo en una sesión de trabajo; en un proyecto real sería un desperdicio, y por eso el paso 6
lo retira. Los minutos 7, 22, 37 y 52 esquivan el minuto 0, el más saturado de la plataforma.

**Comando**: añade `schedule` al bloque `on:` de `dispatch-lab.yml`, después de
`workflow_dispatch`.

```yaml
  schedule:
    # Solo para la práctica: el paso 6 lo retira.
    - cron: "7,22,37,52 * * * *"
```

```bash
actionlint .github/workflows/dispatch-lab.yml; echo "exit $?"
# exit 0
git add .github/workflows/dispatch-lab.yml
git commit -m "ci: run dispatch lab every 15 minutes"
git push
```

GitHub puede tardar en registrar un cron nuevo, y los runs programados se retrasan cuando hay
carga. Sigue con la teoría o con el proyecto y vuelve en media hora.

**Verifica**: al menos un run con evento `schedule`, en verde.

```bash
gh run list --workflow dispatch-lab.yml --event schedule --limit 3 \
  --json createdAt,conclusion --jq '.[] | "\(.createdAt)\t\(.conclusion)"'
# 2026-11-02T10:24:51Z	success
```

Fíjate en la hora: casi nunca es el minuto exacto que pediste. En el log, la línea de
`evento=schedule` trae `count=` vacío y `tipado=null`: en un run programado no hay inputs.

---

## Paso 6: Apagar el cron

**Por qué**: hay dos formas de parar un cron. `gh workflow disable` apaga el workflow entero sin
tocar el archivo: útil mientras investigas por qué falla cada noche, pero también bloquea los
lanzamientos a mano, y la práctica 04 los necesita. Así que lo pruebas, lo vuelves a encender y
retiras el `schedule` del YAML, que es la solución permanente.

**Comando**:

```bash
gh workflow disable dispatch-lab.yml
gh workflow list --all --json name,state --jq '.[] | select(.name == "dispatch-lab") | .state'
# disabled_manually
gh workflow enable dispatch-lab.yml
```

Borra el bloque `schedule:` de `dispatch-lab.yml`, con su comentario, y súbelo:

```bash
actionlint .github/workflows/dispatch-lab.yml; echo "exit $?"
# exit 0
git add .github/workflows/dispatch-lab.yml
git commit -m "ci: drop lab schedule from dispatch lab"
git push
```

**Verifica**: activo, sin cron y lanzable.

```bash
gh workflow list --all --json name,state --jq '.[] | select(.name == "dispatch-lab") | .state'
# active
yq '.on | has("schedule")' .github/workflows/dispatch-lab.yml
# false
```

Si algún run programado había quedado en cola antes del último push, puede aparecer uno más
después: es el último.

---

## ✅ Resultado

- [ ] `dispatch-lab.yml` está en `main` con inputs `string`, `boolean`, `choice` y `number`
- [ ] Todos los inputs llegan al shell por `env:`; ninguno se interpola en `run:`
- [ ] Lanzaste el workflow con `-f` y con `--json`, y viste que un `choice` inválido no crea run
- [ ] El texto `$(whoami)` llegó al log como texto
- [ ] Viste `tipado=false texto="false"` y el step que corre con la casilla desmarcada
- [ ] Viste al menos un run de `schedule`, desactivaste el workflow y retiraste el cron

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 07
# ✅ Todos tus workflows pasan actionlint
# ✅ Toda uses: remota de tus workflows está fijada por SHA de 40 caracteres con el tag en comentario
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `gh workflow run` dice `could not find any workflows named dispatch-lab.yml` | El archivo no está en `main`, o el push no ha llegado | `git log origin/main --oneline -1 -- .github/workflows/dispatch-lab.yml` |
| `Workflow does not have 'workflow_dispatch' trigger` | `workflow_dispatch:` mal indentado bajo `on:` | Repasa el paso 1 con `yq '.on \| keys'` |
| `gh run list` devuelve el run de antes | El run nuevo aún no existía cuando lo buscaste | Sube el `sleep` a 20 segundos |
| `tipado` sale `"false"` con comillas | Leíste `github.event.inputs.flag` en las dos variables | `FLAG_TYPED` lee `inputs.flag` |
| Ningún run de `schedule` tras una hora | El cron no está en `main`, o tiene un error que actionlint marca | `yq '.on.schedule' .github/workflows/dispatch-lab.yml` sobre `main` |
| `gh workflow run` falla con `workflow is disabled` | Quedó desactivado en el paso 6 | `gh workflow enable dispatch-lab.yml` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Concurrencia y timeouts](02-concurrencia-y-timeouts.md) | [Encadenar workflows](04-encadenar-workflows.md) |
