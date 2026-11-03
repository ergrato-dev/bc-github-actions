# Contextos

> Un workflow necesita saber qué lo disparó, en qué rama, en qué máquina corre y qué hicieron los
> pasos anteriores. Los contextos son los objetos donde GitHub te da toda esa información.

## 🎯 Objetivos

- Saber qué contextos existen y qué información guarda cada uno
- Leer la tabla de disponibilidad para saber qué contexto puedes usar en cada clave del workflow
- Distinguir un contexto (`github.sha`) de una variable de entorno por defecto (`$GITHUB_SHA`) y
  elegir bien entre los dos
- Volcar un contexto al log para depurar sin filtrar el token ni ningún secreto

## 1. Qué problema resuelve

El `hello.yml` de la Semana 01 imprimía `$GITHUB_ACTOR` y `$GITHUB_SHA`, dos variables de entorno
que el runner crea en cada job. Sirven mientras el código ya corre en la máquina. Pero muchas
decisiones se toman **antes**:

- ¿Este job tiene que correr, o solo en `push` a `main`?
- ¿Qué nombre se le muestra en la UI?
- ¿En qué runner se ejecuta?

Cuando GitHub decide esas cosas todavía no hay runner, así que tampoco hay variables de entorno.
Hace falta información que GitHub tenga en el servidor desde el principio: eso son los
**contextos**.

Un contexto es un objeto con propiedades, como un JSON. Se lee dentro de una expresión `${{ }}`:

```yaml
${{ github.event_name }}      # push, pull_request, workflow_dispatch...
${{ github.ref_name }}        # main, mi-rama...
${{ runner.os }}              # Linux, Windows o macOS
```

## 2. Cómo funciona

### Los contextos que existen

| Contexto | Qué contiene | Lo usas desde |
|---|---|---|
| `github` | El run y el evento que lo disparó: `event_name`, `ref`, `sha`, `actor`, `repository`, `run_id`, `event` (el payload completo)... | Esta semana |
| `env` | Las variables definidas con `env:` en el workflow, el job o el step | Esta semana |
| `vars` | Las variables de configuración del repo, la organización o un environment | Esta semana |
| `job` | El job en curso: `status` (`success`, `failure` o `cancelled`) | Esta semana |
| `steps` | Los steps anteriores del job que tienen `id`: `outputs`, `outcome`, `conclusion` | Esta semana |
| `runner` | La máquina: `os`, `arch`, `temp`, `name` | Esta semana |
| `needs` | Los jobs de los que depende este: `outputs` y `result` | Esta semana |
| `secrets` | Los secretos disponibles para el run | Semana 06 y 13 |
| `strategy` y `matrix` | La matriz del job | Semana 04 |
| `inputs` | Los inputs de un `workflow_dispatch` o de un workflow reutilizable | Semanas 07 y 09 |
| `jobs` | Los outputs de los jobs de un workflow reutilizable | Semana 09 |

Algunas propiedades que vas a usar esta semana:

| Propiedad | Ejemplo de valor |
|---|---|
| `github.event_name` | `push` |
| `github.ref` | `refs/heads/main` |
| `github.ref_name` | `main` |
| `github.sha` | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `github.repository` | `<tu-org>/tablero` |
| `github.run_number` | `14` |
| `runner.os` | `Linux` |
| `runner.arch` | `X64` |
| `runner.temp` | Un directorio temporal que se vacía al empezar y al acabar el job |

### No todo contexto existe en todas partes

Cada clave del workflow se evalúa en un momento distinto, y en cada momento GitHub sabe cosas
distintas. Cuando decide si un job corre (`jobs.<id>.if`), el job todavía no tiene runner, así que
`runner` no existe. Tampoco existe `steps`, porque ningún step ha corrido aún.

Versión resumida de la tabla oficial de disponibilidad (verificado con la referencia de contextos
de docs.github.com y ubuntu-24.04, noviembre de 2026):

| Clave | Contextos disponibles | Funciones especiales |
|---|---|---|
| `env` del workflow | `github`, `secrets`, `inputs`, `vars` | — |
| `jobs.<id>.if` | `github`, `needs`, `vars`, `inputs` | Funciones de estado |
| `jobs.<id>.runs-on`, `jobs.<id>.name` | `github`, `needs`, `strategy`, `matrix`, `vars`, `inputs` | — |
| `jobs.<id>.outputs` | Lo anterior más `job`, `runner`, `env`, `steps`, `secrets` | — |
| Claves de un step (`if`, `env`, `name`, `run`, `with`...) | Casi todos: también `job`, `runner`, `env`, `steps`, `secrets` | `hashFiles()`, y en `if` las funciones de estado |

Dos consecuencias que sorprenden la primera vez:

- **`env` no está disponible en el `if` de un job.** `if: env.DEPLOY == 'true'` a nivel de job no
  funciona. Usa `vars` o `github`.
- **`hashFiles()` solo funciona en las claves de un step**, porque necesita los archivos del
  workspace, y esos solo existen en el runner.

Si usas un contexto donde no está disponible, actionlint te avisa antes del push.

### Contexto frente a variable de entorno por defecto

Casi todo `github.*` tiene una variable de entorno equivalente en el runner:

| Contexto | Variable de entorno | Quién la resuelve |
|---|---|---|
| `${{ github.sha }}` | `$GITHUB_SHA` | GitHub, antes de mandar el job / el shell, en el runner |
| `${{ github.ref_name }}` | `$GITHUB_REF_NAME` | Igual |
| `${{ runner.os }}` | `$RUNNER_OS` | Igual |

Las variables de entorno por defecto solo existen **dentro del runner**. Los contextos se pueden
usar casi en cualquier punto del workflow, incluso antes de que el job llegue al runner. La regla
práctica:

- **En un `if:`, un `name:`, un `runs-on:` o un `with:`**, usa el contexto: es lo único que hay.
- **Dentro de un `run:`**, usa la variable de entorno. El shell la lee cuando la necesita, y el
  contenido nunca se convierte en código. La teoría 02 explica por qué esto importa.

## 3. Cómo se usa

Un workflow de exploración que vuelca contextos al log, pasándolos siempre por `env:`:

```yaml
name: contexts-demo

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  show:
    runs-on: ubuntu-24.04
    steps:
      - name: Qué disparó el run
        env:
          EVENT: ${{ github.event_name }}
          REF: ${{ github.ref_name }}
          SHA: ${{ github.sha }}
          ACTOR: ${{ github.actor }}
        run: echo "$EVENT en $REF ($SHA), lanzado por $ACTOR"

      - name: El runner entero
        env:
          RUNNER_CONTEXT: ${{ toJSON(runner) }}
        run: echo "$RUNNER_CONTEXT"

      - name: Una variable de configuración
        env:
          PROJECT: ${{ vars.PROJECT_NAME }}
        run: echo "Proyecto ${PROJECT:-sin definir}"
```

`toJSON()` convierte un objeto en texto JSON. Es la forma de ver qué tiene un contexto sin adivinar.

### Variables de configuración: `vars`

Las variables de configuración guardan valores **no secretos** fuera del YAML: un nombre de
proyecto, una URL, una región. Se crean en el repo (o en la organización) y se leen con
`vars.NOMBRE`:

```bash
gh variable set PROJECT_NAME --body tablero
gh variable list
# PROJECT_NAME  tablero  ...
```

Si la variable no existe, `vars.PROJECT_NAME` vale una cadena vacía: el workflow no falla. Por eso
el ejemplo de arriba usa `${PROJECT:-sin definir}`. Para valores sensibles, los secretos: Semana 13.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `toJSON(github)` entero al log | El contexto `github` incluye `github.token`. GitHub lo enmascara en el log, pero el enmascarado no es una garantía completa, y el payload del evento trae datos que no controlas | Vuelca solo las propiedades que necesitas |
| `toJSON(secrets)` en cualquier sitio | Pone todos los secretos del repo a disposición de un step. Penalización grave en la rúbrica | Pasa a cada step solo el secreto que usa (Semana 13) |
| `if: env.X == 'true'` a nivel de job | `env` no existe cuando se evalúa el `if` del job: la condición nunca hace lo que esperas | `vars.X`, o el `if` a nivel de step |
| `${{ github.sha }}` dentro de `run:` | Funciona, pero acostumbra a interpolar dentro del shell. Con un campo del evento, eso es inyección | `$GITHUB_SHA`, o el valor por `env:` |
| Guardar una URL o un nombre en el YAML de cinco workflows | Cambiarlo obliga a tocar los cinco | Una variable de configuración en el repo u organización |

## 5. Trucos

- **El payload completo del evento ya está en el runner**: `cat "$GITHUB_EVENT_PATH"`. Es el mismo
  JSON que `github.event`, y con `jq` lo exploras sin pasar nada por expresiones:
  `jq '.repository.full_name' "$GITHUB_EVENT_PATH"`.
- **`runner.temp` se vacía al empezar y al terminar cada job.** Es el sitio para archivos de
  trabajo que no quieres que acaben en un artefacto ni en el workspace.
- **`github.ref_name` frente a `github.ref`**: `ref` trae el prefijo (`refs/heads/main`,
  `refs/tags/v1.0.0`) y `ref_name` solo el nombre. Para comparar con una rama, `ref` evita
  confundir una rama `v1.0.0` con un tag del mismo nombre.

## 📚 Recursos Adicionales

- [Contexts reference](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts):
  todas las propiedades y la tabla de disponibilidad completa
- [Variables reference](https://docs.github.com/en/actions/reference/workflows-and-actions/variables):
  variables de entorno por defecto y variables de configuración

## ✅ Checklist de Verificación

- [ ] Sé qué contexto uso para el evento, para la máquina y para los steps anteriores
- [ ] Sé por qué `runner` y `steps` no existen en el `if` de un job
- [ ] Sé por qué `env` no sirve en el `if` de un job y qué uso en su lugar
- [ ] Dentro de `run:` leo variables de entorno o valores pasados por `env:`, no `${{ }}`
- [ ] Nunca vuelco `toJSON(github)` entero ni `toJSON(secrets)`
- [ ] Sé crear una variable de configuración con `gh variable set` y leerla con `vars.`

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Semana 02](../README.md) | [Expresiones y funciones](02-expresiones-y-funciones.md) |
