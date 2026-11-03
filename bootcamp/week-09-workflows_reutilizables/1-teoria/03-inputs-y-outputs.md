# Inputs y outputs

> Los inputs son los parámetros del reutilizable y los outputs, su valor de retorno. Con tipos,
> obligatorios y valores por defecto, el llamador solo escribe lo que cambia; con outputs, recibe
> de vuelta lo que necesita, como el nombre de un artefacto o el digest de una imagen.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Declarar inputs de tipo `string`, `number` y `boolean`, con `required` o `default`
- Pasar una lista a un reutilizable como JSON y convertirla en matriz con `fromJSON`
- Llevar un valor de un step del reutilizable hasta un job del llamador
- Predecir qué output recibe el llamador cuando la llamada corre en matriz
- Usar un input en un `run:` sin abrir una inyección

## 1. Qué problema resuelve

Un reutilizable sin parámetros es una copia con otro nombre. `_python.yml` tiene que servir para
`api/` hoy y para un `worker/` mañana, con su paquete, su cobertura mínima y con o sin tests de
integración. `_node.yml` tiene que probar las versiones de Node que pida cada llamador. Y el
llamador necesita datos de vuelta: `ci-web` descarga el artefacto que dejó el build y `images`
publica en el resumen los digests de las dos imágenes.

Sin un contrato explícito, cada uno de esos datos acabaría *hardcoded* en el reutilizable o
adivinado por el llamador, que es justo el acoplamiento que querías quitar.

## 2. Cómo funciona

### Declarar inputs

```yaml
on:
  workflow_call:
    inputs:
      working-directory:
        description: Carpeta del proyecto, la que contiene pyproject.toml y uv.lock
        type: string
        required: true
      coverage-min:
        description: Cobertura mínima de los tests unitarios, en porcentaje
        type: number
        default: 60
      integration:
        description: Ejecutar tests/integration contra un PostgreSQL 17 de servicio
        type: boolean
        default: true
```

| Campo | Qué hace |
|---|---|
| `type` | Obligatorio: `string`, `number` o `boolean`. No hay más |
| `required` | Si es `true`, el llamador tiene que pasarlo en `with:` |
| `default` | El valor cuando el llamador no lo pasa. Con `required: true` no tiene sentido |
| `description` | Documentación para quien llama; actionlint no la exige, tus compañeros sí |

El valor que pasa el llamador tiene que coincidir con el tipo declarado. Dentro del reutilizable
lo lees con el contexto `inputs`: `inputs.coverage-min` es un número y `inputs.integration` un
booleano, así que `if: ${{ inputs.integration }}` funciona sin comparar con `'true'`.

### No hay tipo lista

`workflow_call` no tiene `type: list` ni `type: array`. Si un reutilizable necesita una lista, la
recibe como `string` con JSON dentro y la convierte con `fromJSON`:

```yaml
node-versions:
  description: Versiones de Node de la matriz de tests, como lista JSON
  type: string
  default: "[24, 26]"
```

Las comillas importan: `node-versions: "[24, 26]"` es un string; `node-versions: [24, 26]` es una
secuencia YAML y actionlint la rechaza (`expected scalar node for string value but found
sequence node`).

### Devolver outputs

Un valor viaja en cuatro saltos, y cada salto se declara:

1. Un step lo escribe en `$GITHUB_OUTPUT` (o una action lo expone en `steps.<id>.outputs`).
2. El job del reutilizable lo publica en `jobs.<job>.outputs`.
3. El reutilizable lo publica en `on.workflow_call.outputs.<id>.value`.
4. El llamador lo lee como `needs.<job-que-llama>.outputs.<id>`.

```yaml
# _image.yml, en on.workflow_call: salto 3
outputs:
  digest:
    description: Digest de la imagen construida
    value: ${{ jobs.build.outputs.digest }}
```

```yaml
# _image.yml, en el job build: salto 2, desde el step con id build (salto 1)
build:
  outputs:
    digest: ${{ steps.build.outputs.digest }}
```

Es la misma cadena step → job → `needs` de la Semana 02, con un salto más: el del workflow. Si
te saltas el 3, el llamador no ve nada aunque el job lo tenga.

### El output de una matriz de llamadas

El job que llama admite `strategy.matrix`. Entonces el reutilizable corre una vez por
combinación, pero el llamador sigue teniendo **un solo** `needs.<job>.outputs.<id>`: el del
último reutilizable que terminó bien. Si ese dejó el output como cadena vacía, se usa el del
anterior que tenga valor. No hay forma de pedir "el digest de la combinación `web`".

## 3. Cómo se usa

### Una lista para la matriz de `_node.yml`

El job `test` de `_node.yml` saca su matriz del input:

```yaml
test:
  name: Tests (Node ${{ matrix.node }})
  runs-on: ubuntu-24.04
  timeout-minutes: 10
  strategy:
    fail-fast: false
    matrix:
      node: ${{ fromJSON(inputs.node-versions) }}
```

Y el job `build` devuelve el nombre del artefacto, que el workflow publica como output. `ci-web`
lo usa sin repetir el literal `web-dist` en dos sitios:

```yaml
name: ci-web

on:
  pull_request:
    paths:
      - "web/**"
      - ".github/workflows/ci-web.yml"
      - ".github/workflows/_node.yml"

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  web:
    name: Web
    uses: ./.github/workflows/_node.yml # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
    with:
      working-directory: web
      node-versions: "[24, 26]"
      artifact-name: web-dist

  dist-report:
    name: Informe de dist
    needs: web
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - uses: actions/download-artifact@9000827ccba6bdab643e8b6fd33ac0654aef8333 # v8.0.2
        with:
          name: ${{ needs.web.outputs.artifact-name }}
          path: dist
      - name: Tamaño de cada archivo
        run: du -ah dist | sort -h >> "$GITHUB_STEP_SUMMARY"
```

`needs.web` funciona igual que con un job normal: `dist-report` espera a que terminen **todos**
los jobs del reutilizable (lint, los dos tests y build) y solo entonces lee el output.

### Inputs dentro de `run:`, siempre por `env:`

Un input es un dato que escribe otro workflow, y en la Semana 11 ese workflow puede estar en otro
repo. Dentro de `run:` se trata como cualquier dato no confiable (regla 4 de seguridad):

```yaml
- name: pytest con cobertura
  env:
    PACKAGE: ${{ inputs.package }}
    COVERAGE_MIN: ${{ inputs.coverage-min }}
  run: uv run --no-sync pytest tests/unit --cov="$PACKAGE" --cov-fail-under="$COVERAGE_MIN"
```

En `with:`, `defaults.run.working-directory` o `if:` la expresión no pasa por el shell y se
puede usar directamente.

### Por qué `images` no usa una matriz de llamadas

Esto compila y construye las dos imágenes:

```yaml
name: images-matrix

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  image:
    name: Imagen
    strategy:
      matrix:
        component: [api, web]
    permissions:
      contents: read
      packages: write
    uses: ./.github/workflows/_image.yml # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
    with:
      component: ${{ matrix.component }}
    secrets:
      registry-password: ${{ secrets.GITHUB_TOKEN }}

  summary:
    name: Digest
    needs: image
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - name: Un solo digest, el de la última imagen que terminó bien
        env:
          DIGEST: ${{ needs.image.outputs.digest }}
        run: echo "$DIGEST" >> "$GITHUB_STEP_SUMMARY"
```

Pero `summary` recibe un digest, no dos, y cuál depende de qué imagen termine antes. Por eso
`images.yml` llama a `_image.yml` desde **dos jobs**, `api` y `web`, y lee
`needs.api.outputs.digest` y `needs.web.outputs.digest` por separado.

### actionlint comprueba el contrato

Con una referencia `./`, actionlint lee `_python.yml` y valida cada `with:`. Sobre un `ci-api.yml`
que olvida `package`, pasa la cobertura como texto e inventa un input:

```text
ci-api.yml:8:11: input "package" is required by "./.github/workflows/_python.yml" reusable workflow [workflow-call]
ci-api.yml:11:21: input "coverage-min" is typed as number by reusable workflow "./.github/workflows/_python.yml". string value cannot be assigned [expression]
ci-api.yml:13:7: input "bogus" is not defined in "./.github/workflows/_python.yml" reusable workflow. defined inputs are "coverage-min", "integration", "package", "working-directory" [workflow-call]
```

También valida los outputs: `needs.mat.outputs.nope` sobre una llamada a `_image.yml` da
`property "nope" is not defined in object type {digest: string}`. Verificado con actionlint
1.7.12 y ubuntu-24.04, noviembre 2026.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `${{ inputs.package }}` dentro de `run:` | El valor se pega en el script antes de que bash lo lea: inyección | `env: PACKAGE: ${{ inputs.package }}` y `"$PACKAGE"` |
| `node-versions: [24, 26]` sin comillas | Es una secuencia YAML, no un string: la llamada no valida | `node-versions: "[24, 26]"` |
| `type: string` para un número o un sí/no | Comparaciones como `inputs.integration == 'true'` y errores de tipo que nadie ve | `number` y `boolean` |
| Input obligatorio con valor razonable para todos | Cada llamador repite lo mismo | `default:` y que solo lo escriba quien lo cambia |
| Output declarado en el job pero no en `workflow_call.outputs` | El llamador lee una cadena vacía sin error en GitHub | Los cuatro saltos, y actionlint con `./` |
| Matriz de llamadas cuando necesitas un output por combinación | Solo llega el último que terminó bien | Un job que llama por combinación |

## 5. Trucos

- **`toJSON(inputs)` en un step de depuración** enseña todos los inputs tal como los recibe el
  reutilizable, defaults incluidos. Pásalo por `env:` y haz `echo "$INPUTS"`; los inputs nunca
  llevan secretos (esos van por `secrets:`, archivo 04).
- **El `default` es documentación**: `default: "[24, 26]"` le dice al llamador qué formato espera
  el input mejor que cualquier `description`.
- **Un output puede ser el propio input** (`artifact-name: ${{ inputs.artifact-name }}` en el job
  `build`): parece redundante, pero ata el dato al job que lo produjo. Si mañana el nombre lleva
  el SHA, el llamador no cambia.
- **`yq '.on.workflow_call.inputs | to_entries | map(.key + ":" + .value.type)'`** sobre un
  reutilizable te da su firma en una línea; es lo que comprueba `checks.json` en `_python.yml`.

## 📚 Recursos Adicionales

- [GitHub Docs: Reusing workflow configurations, inputs y outputs](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations)
- [GitHub Docs: Workflow syntax, `on.workflow_call.inputs`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onworkflow_callinputs)
- [GitHub Docs: Expressions, `fromJSON`](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions#fromjson)

## ✅ Checklist de Verificación

- [ ] Sé declarar inputs `string`, `number` y `boolean`, con `required` o `default`
- [ ] Sé pasar una lista como string JSON y convertirla con `fromJSON`
- [ ] Sé los cuatro saltos de un output: step, job, workflow y `needs`
- [ ] Sé qué output recibe el llamador de una matriz de llamadas
- [ ] Sé por qué `images.yml` usa dos jobs y no una matriz
- [ ] Sé llevar un input a `run:` por `env:`

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Llamar a un reutilizable](02-llamar-a-un-reutilizable.md) | [Secretos en reutilizables](04-secretos-en-reutilizables.md) |
