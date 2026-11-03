# Práctica 03 — Outputs entre steps y jobs

> Cada step es un proceso nuevo y cada job una máquina nueva. Lo que calculas en uno no llega solo
> al siguiente: hay que declararlo. Esta práctica recorre los cuatro canales (`$GITHUB_OUTPUT`,
> `$GITHUB_ENV`, `$GITHUB_PATH` y los `outputs:` de job) y comprueba lo que no cruza.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `data-flow.yml`, un workflow de dos jobs que se lanza a mano
- Un output de step con `$GITHUB_OUTPUT`, incluido un valor de varias líneas
- Una variable de entorno y un directorio del `PATH` que llegan a los steps siguientes
- Un output de job leído desde otro job con `needs.<job>.outputs`
- Ver con tus ojos lo que **no** pasa de un job a otro

## 📋 Antes de empezar

Terminaste la [práctica 02](02-condiciones-y-estado.md).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
```

---

## Paso 1: Un output de step

**Por qué**: un step publica un dato añadiendo una línea `nombre=valor` al archivo cuya ruta está
en `$GITHUB_OUTPUT`. Al terminar el step, el runner lee ese archivo y el valor queda en
`steps.<id>.outputs.<nombre>`. Sin `id:` el step no tiene nombre en el contexto y su output es
inalcanzable. El antiguo `echo "::set-output ..."` está retirado: imprimía el dato en el log, donde
cualquier texto podía inyectar outputs falsos (teoría 05).

**Comando**: crea `.github/workflows/data-flow.yml`:

```yaml
name: data-flow

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  produce:
    name: Productor
    runs-on: ubuntu-24.04
    steps:
      - name: Identificador del build
        id: ids
        run: echo "build-id=${GITHUB_RUN_NUMBER}-${GITHUB_SHA::7}" >> "$GITHUB_OUTPUT"

      - name: Leerlo en el mismo job
        env:
          BUILD_ID: ${{ steps.ids.outputs.build-id }}
        run: echo "build $BUILD_ID"
```

`${GITHUB_SHA::7}` es expansión de bash: los 7 primeros caracteres de la variable. La hace el
shell en el runner, no GitHub.

**Verifica**:

```bash
actionlint .github/workflows/data-flow.yml
# (sin salida: no hay errores)
yq '.jobs.produce.steps[0].id' .github/workflows/data-flow.yml
# ids
```

---

## Paso 2: Un valor de varias líneas

**Por qué**: `nombre=valor` termina en el salto de línea, así que un valor multilínea necesita otra
sintaxis: `nombre<<DELIMITADOR`, las líneas del valor y el `DELIMITADOR` solo en su línea. La
documentación avisa: el delimitador **no puede aparecer** en una línea del valor, o el valor se
corta ahí y el resto se lee como outputs nuevos. Un delimitador aleatorio lo hace imposible.

**Comando**: añade al final de los steps de `produce`:

```yaml
      - name: Notas de varias líneas
        id: notes
        run: |
          delimiter="EOF_$(openssl rand -hex 8)"
          {
            echo "changelog<<${delimiter}"
            echo "- api: endpoint /api/health"
            echo "- web: lista de tareas"
            echo "${delimiter}"
          } >> "$GITHUB_OUTPUT"

      - name: Leer las notas
        env:
          CHANGELOG: ${{ steps.notes.outputs.changelog }}
        run: printf '%s\n' "$CHANGELOG"
```

Las llaves `{ ... } >> archivo` abren el archivo una vez para todas las líneas: más corto que
repetir `>> "$GITHUB_OUTPUT"` en cada `echo`.

**Verifica**:

```bash
actionlint .github/workflows/data-flow.yml
# (sin salida: no hay errores)
yq '[.jobs.produce.steps[].id // "-"] | join(",")' .github/workflows/data-flow.yml
# ids,-,notes,-
```

---

## Paso 3: Variables de entorno y PATH para los steps siguientes

**Por qué**: `$GITHUB_ENV` funciona igual que `$GITHUB_OUTPUT`, pero lo que escribes se convierte
en una variable de entorno de **los steps siguientes** del mismo job; el step que la escribe no la
ve. `$GITHUB_PATH` añade un directorio delante del `PATH`, también desde el step siguiente. Es
como un instalador deja una herramienta disponible para el resto del job.

**Comando**: añade al final de los steps de `produce`:

```yaml
      - name: Escribir entorno y PATH
        run: |
          echo "STAGE=produce" >> "$GITHUB_ENV"
          mkdir -p "$RUNNER_TEMP/bin"
          printf '#!/usr/bin/env bash\necho "hola desde greet"\n' > "$RUNNER_TEMP/bin/greet"
          chmod +x "$RUNNER_TEMP/bin/greet"
          echo "$RUNNER_TEMP/bin" >> "$GITHUB_PATH"
          echo "en este mismo step STAGE='${STAGE:-}'"

      - name: Usarlos en el step siguiente
        run: |
          echo "STAGE=$STAGE"
          greet
```

`$RUNNER_TEMP` es un directorio temporal del runner que se vacía al terminar el job.

**Verifica**:

```bash
yq '.jobs.produce.steps[] | select(.name == "Escribir entorno y PATH") | .run' \
  .github/workflows/data-flow.yml | grep -c 'GITHUB_ENV\|GITHUB_PATH'
# 2
```

---

## Paso 4: Outputs de job y needs

**Por qué**: el contexto `steps` muere con su job. Para que otro job reciba un dato, el job que lo
produce lo declara en `outputs:` y el que lo consume declara `needs:` y lo lee con
`needs.<job>.outputs.<nombre>`. `needs:` hace dos cosas a la vez: ordena (el consumidor espera) y
da acceso a los outputs. Según la documentación, los outputs de job se evalúan en el runner al
terminar el job, y caben como mucho 1 MB por job y 50 MB por run.

**Comando**: añade `outputs:` al job `produce`, entre `runs-on:` y `steps:`:

```yaml
    outputs:
      build-id: ${{ steps.ids.outputs.build-id }}
      changelog: ${{ steps.notes.outputs.changelog }}
```

Y un segundo job al final de `jobs:`:

```yaml
  consume:
    name: Consumidor
    needs: produce
    runs-on: ubuntu-24.04
    steps:
      - name: Outputs del productor
        env:
          BUILD_ID: ${{ needs.produce.outputs.build-id }}
          CHANGELOG: ${{ needs.produce.outputs.changelog }}
        run: |
          echo "build $BUILD_ID"
          printf '%s\n' "$CHANGELOG"
```

```bash
git add .github/workflows/data-flow.yml
git commit -m "ci: add data-flow workflow"
git push
gh workflow run data-flow.yml
sleep 5
RUN_ID=$(gh run list --workflow data-flow.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
gh run view "$RUN_ID" --log | grep -E 'Consumidor.*(build|- api|- web)'
# Consumidor  Outputs del productor  ...  build <número>-<sha corto>
# Consumidor  Outputs del productor  ...  - api: endpoint /api/health
# Consumidor  Outputs del productor  ...  - web: lista de tareas
```

**Verifica**:

```bash
gh run list --workflow data-flow.yml --event workflow_dispatch --status success \
  --json databaseId --jq length
# 1
```

---

## Paso 5: Lo que no cruza entre jobs

**Por qué**: `consume` corre en otra máquina. No tiene el `STAGE` de `$GITHUB_ENV`, ni el `greet`
de `$RUNNER_TEMP`, ni el contexto `steps` de `produce`. Solo recibe lo que `produce` declaró en
`outputs:`. Comprobarlo una vez evita horas buscando por qué "la variable está vacía".

Hay un caso más que no puedes ver todavía porque no usas secretos hasta la Semana 13: según la
documentación, un output de job que contiene un secreto se redacta en el runner y **no llega** a
GitHub, así que el job consumidor lo recibe vacío. Un secreto nunca viaja como output.

**Comando**: añade este step al final de `consume`:

```yaml
      - name: Lo que no cruza
        env:
          PRODUCER_STEPS: ${{ toJSON(steps) }}
        run: |
          echo "STAGE='${STAGE:-}'"
          command -v greet || echo "greet no existe en esta máquina"
          echo "steps en este job: $PRODUCER_STEPS"
```

```bash
git commit -am "ci(data-flow): show what does not cross jobs"
git push
gh workflow run data-flow.yml
sleep 5
RUN_ID=$(gh run list --workflow data-flow.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
```

**Verifica**:

```bash
gh run view "$RUN_ID" --log | grep -E "STAGE=|greet no existe|steps en este job"
# Productor   Usarlos en el step siguiente  ...  STAGE=produce
# Consumidor  Lo que no cruza  ...  STAGE=''
# Consumidor  Lo que no cruza  ...  greet no existe en esta máquina
# Consumidor  Lo que no cruza  ...  steps en este job: {}
```

`steps` sale `{}`: el único step anterior de `consume` no tiene `id:`, y los de `produce` nunca
estuvieron en este job.

---

## ✅ Resultado

- [ ] `data-flow.yml` está en `main` y terminó en `success` lanzado a mano
- [ ] Sabes escribir un output de step, también de varias líneas con delimitador aleatorio
- [ ] Sabes que `$GITHUB_ENV` y `$GITHUB_PATH` valen desde el step **siguiente**
- [ ] Has pasado dos valores de un job a otro con `outputs:` y `needs:`
- [ ] Has comprobado que ni el entorno, ni el `PATH`, ni `steps` cruzan entre jobs

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 02
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El output llega vacío al step siguiente | El step que lo escribe no tiene `id:`, o lo lees con otro `id` | `steps.<id>.outputs.<nombre>` tiene que coincidir letra a letra |
| `build ` sin valor en `consume` | Falta `outputs:` en `produce` o `needs: produce` en `consume` | Revisa el paso 4: hacen falta los dos |
| Solo llega la primera línea del changelog | Usaste `changelog=` en lugar de `changelog<<delimitador` | Sintaxis del paso 2 |
| `Unable to process file command 'output'` | El delimitador de cierre no está solo en su línea | `echo "${delimiter}"` sin espacios ni texto al lado |
| `greet: command not found` en el step siguiente | `$GITHUB_PATH` recibió la ruta antes de crear el directorio, o con otra ruta | Escribe en `$GITHUB_PATH` la misma ruta donde dejaste el script |
| actionlint: `property "notes" is not defined` | Lees `steps.notes` antes del step con `id: notes` | `steps` solo ve los steps anteriores |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Condiciones y estado](02-condiciones-y-estado.md) | [Un pipeline con grafo](04-pipeline-con-grafo.md) |
