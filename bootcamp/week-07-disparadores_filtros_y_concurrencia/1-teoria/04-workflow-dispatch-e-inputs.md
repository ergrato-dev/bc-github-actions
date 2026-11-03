# workflow_dispatch e inputs

> `workflow_dispatch` es el botón "Run workflow". Con inputs tipados se convierte en un formulario:
> eliges rama, marcas casillas y GitHub valida los valores antes de crear el run. Y el mismo botón
> se pulsa desde `gh` y desde la API.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Declarar inputs de los cinco tipos: `boolean`, `choice`, `number`, `environment` y `string`
- Explicar por qué `inputs.x` y `github.event.inputs.x` no son lo mismo
- Lanzar un workflow desde la UI, desde `gh workflow run` y desde la API
- Pasar inputs a un step sin abrir una vía de inyección
- Conocer los límites: 25 inputs y 65.535 caracteres de payload

## 1. Qué problema resuelve

Desde la Semana 01 tus workflows llevan `workflow_dispatch:` a secas: un botón para relanzar sin
commit. Útil, pero rígido. Hay tareas que necesitan una decisión en el momento:

- Relanzar **solo** el CI de la web, no todo.
- Hacer un ensayo en seco antes del proceso real.
- Repetir un test inestable N veces para cazarlo.

Sin inputs, cada variante sería un workflow distinto, o una variable que alguien edita en
Settings antes de pulsar el botón. Con inputs, la variante se elige al lanzar y queda registrada en
el run.

## 2. Cómo funciona

### Los cinco tipos

```yaml
  workflow_dispatch:
    inputs:
      target:
        description: Qué parte relanzar
        type: choice
        options: [all, ci-api, ci-web, smoke]
        default: all
      dry_run:
        description: Ensayo sin efectos
        type: boolean
        default: true
      repeat:
        description: Veces que repetir los tests
        type: number
        default: 1
      note:
        description: Motivo del lanzamiento
        type: string
        required: false
```

| Tipo | En la UI | Valor en `inputs` | Nota |
|---|---|---|---|
| `string` | Caja de texto | Cadena | El tipo por defecto si no declaras `type` |
| `boolean` | Casilla | `true` / `false` de verdad | |
| `number` | Caja numérica | Número | |
| `choice` | Desplegable | Cadena, una de `options` | GitHub rechaza un valor fuera de la lista |
| `environment` | Desplegable de environments del repo | Cadena | Los environments llegan en la Semana 13 |

Cada input admite `description`, `required`, `default` y `type`; `choice` además exige `options`.
Hay dos límites: **25 inputs** como máximo, y el payload completo del evento no puede pasar de
**65.535 caracteres**.

### `inputs` frente a `github.event.inputs`

Los valores llegan por dos caminos y no son iguales:

| Expresión | `dry_run` desmarcado | Tipo |
|---|---|---|
| `inputs.dry_run` | `false` | Booleano real |
| `github.event.inputs.dry_run` | `'false'` | **Cadena** |

La diferencia muerde en los `if:`. Una cadena no vacía es verdadera en una expresión, así que:

```yaml
    if: ${{ github.event.inputs.dry_run }}   # 'false' es una cadena no vacía: SIEMPRE verdadero
    if: ${{ inputs.dry_run }}                # false real: se salta cuando debe
```

Usa siempre `inputs`. Además, `inputs` existe en todos los eventos del workflow: en un run de
`push` o de `schedule` está vacío, y una expresión como `inputs.target || 'all'` te da el valor por
defecto.

### Quién puede pulsar el botón

- Solo personas con **permiso de escritura** en el repo.
- El workflow tiene que estar **en la rama por defecto** para que el botón aparezca en la UI.
  Después puedes elegir otra rama: el run usa el YAML de esa rama.
- Los filtros de `push` y `pull_request` no afectan a `workflow_dispatch`: si está declarado, corre.

## 3. Cómo se usa

### Un workflow con inputs y su uso seguro

```yaml
name: dispatch-demo

on:
  workflow_dispatch:
    inputs:
      target:
        description: Qué parte relanzar
        type: choice
        options: [all, ci-api, ci-web, smoke]
        default: all
      dry_run:
        description: Ensayo sin efectos
        type: boolean
        default: true
      note:
        description: Motivo del lanzamiento
        type: string
        required: false

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  show:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - name: Ensayo
        if: ${{ inputs.dry_run }}
        env:
          TARGET: ${{ inputs.target }}
          NOTE: ${{ inputs.note }}
        run: |
          echo "Relanzaría: $TARGET"
          echo "Motivo: $NOTE"
```

`note` es texto libre: quien lanza el workflow puede escribir `"; rm -rf ~; echo "`. Por eso llega
al shell por `env:`, como cualquier dato que no controla el workflow. `target` es un `choice` y
GitHub lo valida, pero la regla es la misma para todos: nada de `${{ inputs.* }}` dentro de
`run:`.

### Desde `gh`

```bash
gh workflow run dispatch-demo.yml --ref main -f target=ci-web -f dry_run=false -f note="cazar test"
gh run list --workflow dispatch-demo.yml --limit 1 --json event,status --jq '.[0]'
# {"event":"workflow_dispatch","status":"queued"}
```

- **`-f clave=valor`** pasa un input como cadena; GitHub lo convierte al tipo declarado.
- **`--ref`** elige la rama. Sin él, la rama por defecto.
- **`--json`** lee los inputs como JSON de la entrada estándar, cómodo cuando son muchos:

```bash
echo '{"target":"smoke","dry_run":"true"}' | gh workflow run dispatch-demo.yml --json
```

Si te olvidas de los inputs, `gh workflow run dispatch-demo.yml` sin `-f` en una terminal
interactiva te los pregunta uno a uno.

### Desde la API

`gh workflow run` llama por debajo a este endpoint, que es el que usarás desde `github-script` en
el archivo 08:

```bash
gh api repos/{owner}/{repo}/actions/workflows/dispatch-demo.yml/dispatches \
  -f ref=main -f 'inputs[target]=ci-api' -f 'inputs[dry_run]=true'
```

El run aparece segundos después en `gh run list`. `{owner}/{repo}` lo rellena
`gh` con el repo de la carpeta actual o de `GH_REPO`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `if: github.event.inputs.flag` | `'false'` es verdadero: el step corre siempre | `if: inputs.flag` |
| `run: echo ${{ inputs.note }}` | Inyección: el texto del input se vuelve código del shell | `env: NOTE: ${{ inputs.note }}` y `"$NOTE"` |
| `string` para un valor de una lista cerrada | Una errata llega al workflow y falla tarde | `choice` con `options` |
| Leer inputs sin defecto en un workflow que también tiene cron | En el run programado están vacíos | `inputs.x \|\| 'defecto'` |
| Un workflow por cada variante | Copias que se desincronizan | Un workflow con inputs |
| Probar el botón desde una rama sin fusionar el YAML | El botón no aparece | Fusiona primero a la rama por defecto |

## 5. Trucos

- **`gh workflow run x.yml` sin `-f`** en una terminal interactiva te pregunta cada input con su
  descripción y sus opciones: la forma de no equivocarte de nombre.
- **`gh run list --event workflow_dispatch`** separa los runs que lanzó alguien a mano de los de
  `push` y `schedule` del mismo workflow.
- **`run-name:`** con `inputs.target` pone el input en el título del run en la lista de Actions:
  `run-name: Nightly (${{ inputs.target || 'all' }})`.

Verificado con actionlint 1.7.12 y ubuntu-24.04, noviembre 2026.

## 📚 Recursos Adicionales

- [GitHub Docs: `on.workflow_dispatch.inputs`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onworkflow_dispatchinputs)
- [GitHub Docs: Manually running a workflow](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
- [GitHub REST API: Create a workflow dispatch event](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event)
- [`gh workflow run`](https://cli.github.com/manual/gh_workflow_run)

## ✅ Checklist de Verificación

- [ ] Sé declarar un input de cada uno de los cinco tipos
- [ ] Sé por qué uso `inputs` y no `github.event.inputs`
- [ ] Sé por qué un input llega al shell por `env:`
- [ ] Sé lanzar un workflow con `gh workflow run`, `-f`, `--ref` y `--json`
- [ ] Sé qué endpoint de la API crea un `workflow_dispatch`
- [ ] Sé qué valor tiene `inputs` en un run de `schedule`

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Schedule y cron](03-schedule-y-cron.md) | [Encadenar workflows](05-encadenar-workflows.md) |
