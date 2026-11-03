# Variables de entorno, vars y defaults

> Un workflow necesita valores fijos (el nombre del proyecto, la carpeta de la API) y valores que
> pone GitHub (el commit, el evento). Este archivo enseña dónde vive cada uno y cuál gana cuando
> dos se llaman igual.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Declarar variables de entorno con `env:` a nivel de workflow, de job y de step, y predecir cuál
  gana
- Usar las variables por defecto `GITHUB_*` y `RUNNER_*` sin redefinirlas
- Crear variables de configuración con `gh variable set` y leerlas con el contexto `vars`
- Fijar con `defaults.run` el shell y la carpeta de todos los `run` de un workflow o de un job
- Explicar por qué este bootcamp escribe `shell: bash` aunque bash ya sea el shell por defecto

---

## 1. Qué problema resuelve

Sin variables, cada valor se repite en cada step: el nombre `tablero` en diez sitios, la carpeta
`api` en cada `cd`. Cuando cambia, cambias diez líneas y te dejas una.

Hay tres tipos de valor y cada uno tiene su sitio:

| Tipo de valor | Ejemplo | Dónde vive |
|---|---|---|
| Fijo y propio de este workflow | La carpeta `api` | `env:` en el YAML |
| Lo pone GitHub en cada ejecución | El SHA del commit, el nombre del evento | Variables por defecto `GITHUB_*` |
| Configuración del repo u org, la misma para varios workflows | El nombre del proyecto | Variables de configuración: `vars.` |

Ninguno de los tres es para secretos: un valor de `env:` o de `vars` se ve en el YAML, en la
UI de Settings o en el log. Los secretos tienen su propio mecanismo (Semana 13).

---

## 2. Cómo funciona

### 2.1 `env:` en tres niveles

`env:` se puede poner en la raíz del workflow, dentro de un job o dentro de un step. GitHub usa
**la más específica**: una variable de step gana a la de job mientras dura ese step, y una de job
gana a la de workflow.

```yaml
name: env-levels

on: workflow_dispatch

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

env:
  STAGE: workflow

jobs:
  show:
    runs-on: ubuntu-24.04
    env:
      STAGE: job
    steps:
      - name: Gana el job
        run: echo "STAGE=$STAGE"
      - name: Gana el step
        env:
          STAGE: step
        run: echo "STAGE=$STAGE"
```

El primer step imprime `STAGE=job` y el segundo `STAGE=step`. La variable de workflow no se ve
en ninguno, porque el job la tapa.

Dentro de `run:` lees la variable como cualquier variable de bash: `$STAGE`. El valor se lo pasa
el runner al proceso; no lo escribe GitHub dentro del script.

### 2.2 Variables por defecto

El runner define en todo job un grupo de variables `GITHUB_*` y `RUNNER_*`. Las que más vas a
usar:

| Variable | Qué contiene |
|---|---|
| `CI` | Siempre `true`. Sirve para que un script sepa que corre en CI |
| `GITHUB_EVENT_NAME` | El evento que disparó el run: `push`, `pull_request`… |
| `GITHUB_SHA` | El commit del run. Depende del evento (Semana 01, teoría 05) |
| `GITHUB_REF` / `GITHUB_REF_NAME` | La ref completa (`refs/heads/main`) y su nombre corto (`main`) |
| `GITHUB_REPOSITORY` | `owner/repo` |
| `GITHUB_ACTOR` | Quién o qué lanzó el run |
| `GITHUB_RUN_ID` / `GITHUB_RUN_NUMBER` | Identificador único y contador por workflow. No cambian al relanzar |
| `GITHUB_RUN_ATTEMPT` | Empieza en 1 y sube en cada re-run |
| `GITHUB_WORKSPACE` | Carpeta de trabajo por defecto y destino del checkout |
| `GITHUB_EVENT_PATH` | Ruta del JSON completo del evento en el runner |
| `RUNNER_OS` / `RUNNER_ARCH` | `Linux` y `X64` en `ubuntu-24.04` |
| `RUNNER_TEMP` | Carpeta temporal, vacía al empezar y al terminar cada job |

**No puedes sobrescribir** las `GITHUB_*` ni las `RUNNER_*`: si declaras `GITHUB_SHA` en `env:`,
el runner mantiene la suya. `CI` sí se puede sobrescribir hoy, pero GitHub no lo garantiza
(verificado con la documentación de variables y ubuntu-24.04, noviembre de 2026).

### 2.3 Variables de configuración: `vars`

Una **variable de configuración** se guarda en GitHub, no en el YAML: en la organización, en el
repo o en un environment (Semana 13). Todos los workflows del repo la leen con el contexto
`vars`:

```bash
gh variable set PROJECT_NAME --body tablero   # nivel repo, en el repo de tu carpeta actual
gh variable list
# PROJECT_NAME  tablero  ...
```

Reglas que conviene conocer (verificado con la documentación de variables, noviembre de 2026):

- **Nombres**: letras, números y `_`; sin espacios, sin empezar por número ni por `GITHUB_`. No
  distinguen mayúsculas al leerlos.
- **Precedencia**: si el mismo nombre existe en varios niveles, gana el más bajo. Environment gana
  a repo y repo gana a organización.
- **Límites**: 1.000 variables por organización, 500 por repo y 100 por environment; 48 KB por
  variable.
- **Sin valor**: `${{ vars.NO_EXISTE }}` devuelve una cadena vacía, sin error. Un nombre mal
  escrito no rompe el run: rompe el resultado.

### 2.4 `defaults.run`

`defaults.run` fija `shell` y `working-directory` para todos los `run` de un workflow (en la raíz)
o de un job (dentro del job). Como con `env`, gana el más específico: el `defaults` del job tapa
al del workflow, y un `shell:` o `working-directory:` escrito en el step tapa a los dos.

En el `defaults` de la raíz no se pueden usar expresiones ni contextos: los valores son literales.

### 2.5 bash, y bash "de verdad"

En Linux, un `run` sin `shell` se ejecuta con `bash -e {0}`. Con `shell: bash` explícito el
comando cambia a `bash --noprofile --norc -eo pipefail {0}` (verificado con la referencia de
sintaxis y ubuntu-24.04, noviembre de 2026). La diferencia que importa es **`pipefail`**:

```bash
false | true
echo "sigo vivo"
```

- Con `bash -e`: el código de una tubería es el del último comando. `true` sale con 0, el step
  sigue e imprime `sigo vivo`.
- Con `-o pipefail`: la tubería sale con el código del primero que falla. El step falla en la
  primera línea.

Un `curl ... | jq` cuyo `curl` falla deja de pasar en silencio. Por eso este bootcamp pone
`shell: bash` en `defaults.run`, una vez, en vez de repetirlo en cada step.

---

## 3. Cómo se usa

Un workflow que junta las cuatro piezas: una variable de configuración, `env:` de workflow,
`defaults.run` y una variable por defecto.

```yaml
name: env-demo

on: workflow_dispatch

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

env:
  PROJECT: ${{ vars.PROJECT_NAME }}

defaults:
  run:
    shell: bash
    working-directory: api

jobs:
  info:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: Dónde estoy y qué proyecto es
        run: |
          echo "Proyecto: ${PROJECT:-sin PROJECT_NAME}"
          echo "Carpeta: $PWD"
          echo "Run ${GITHUB_RUN_NUMBER}, intento ${GITHUB_RUN_ATTEMPT}, en ${RUNNER_OS}/${RUNNER_ARCH}"
```

Fíjate en tres decisiones:

- `vars.PROJECT_NAME` se convierte en `env` una vez, en la raíz. Los steps leen `$PROJECT`, no la
  expresión.
- `${PROJECT:-sin PROJECT_NAME}` cubre el caso de la variable sin crear: `vars` devuelve vacío y
  el log lo dice en vez de imprimir una línea en blanco.
- `working-directory: api` exige que la carpeta exista. Sin el checkout, el step falla con
  `No such file or directory` antes de ejecutar nada.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Guardar un token o una contraseña en `env:` o en `vars` | Se ve en el YAML, en Settings y en el log | Un secreto (Semana 13) |
| Redefinir `GITHUB_SHA` o `GITHUB_REF` en `env:` | El runner ignora tu valor y el script lee algo distinto de lo que crees | Usa otro nombre: `BUILD_SHA` |
| Repetir `cd api &&` en cada step | Un step nuevo sin el `cd` corre en la raíz y falla lejos de la causa | `defaults.run.working-directory` |
| Confiar en el shell por defecto con tuberías | `curl ... \| jq` pasa aunque `curl` falle | `defaults.run.shell: bash` |
| Leer `vars.X` en diez steps | Diez sitios que cambiar si cambia el nombre | Pásalo a `env:` una vez |
| Usar `vars` para algo que depende del commit | `vars` es igual para todos los runs | Calcúlalo en un step (teoría 05) |

---

## 5. Trucos

- **`env | sort`** en un step te enseña todo el entorno del job: las `GITHUB_*`, las `RUNNER_*` y
  tus `env:`. Es la forma más rápida de comprobar qué nivel ganó.
- **`gh variable list --json name,value,updatedAt`** te da las variables del repo en JSON; con
  `-o <tu-org>` ves las de la organización.
- **`gh variable set -f vars.env`** carga varias variables desde un archivo `.env`. Útil para
  rehacer la configuración de un repo de pruebas en un comando.
- **`GITHUB_RUN_ATTEMPT`** en un nombre de archivo o en un log te dice de qué intento salió algo
  cuando relanzas un run.

---

## 📚 Recursos Adicionales

- [Variables reference](https://docs.github.com/en/actions/reference/workflows-and-actions/variables)
- [Workflow syntax: `env` y `defaults`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
- [Contexts: `vars` y `env`](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts)
- `gh variable --help`

---

## ✅ Checklist de Verificación

- [ ] Sé qué `env:` gana entre workflow, job y step
- [ ] Sé que las `GITHUB_*` y `RUNNER_*` no se pueden sobrescribir
- [ ] Creé una variable con `gh variable set` y sé qué devuelve `vars` si no existe
- [ ] Sé la precedencia de `vars` entre organización, repo y environment
- [ ] Sé qué cambia entre `bash -e {0}` y `shell: bash`
- [ ] Uso `defaults.run` para el shell y la carpeta en vez de repetirlos

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Condiciones y funciones de estado](03-condiciones-y-funciones-de-estado.md) | [Datos entre steps](05-datos-entre-steps.md) |
