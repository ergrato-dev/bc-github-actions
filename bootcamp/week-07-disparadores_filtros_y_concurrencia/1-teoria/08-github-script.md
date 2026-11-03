# github-script

> Cuando un workflow necesita hablar con la API de GitHub (lanzar otro workflow, comentar un PR,
> leer runs), `actions/github-script` te da un cliente ya autenticado dentro de un step. Es
> JavaScript en el YAML, y tiene la misma trampa de inyección que `run:`.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué objetos recibe un script: `github`, `context`, `core` y compañía
- Llamar a la API con `github.rest.*` y el `GITHUB_TOKEN` del job
- Devolver un valor con `result` y elegir entre `result-encoding: json` y `string`
- Reintentar las llamadas que fallan por la red con `retries`
- Pasar datos no confiables a un script sin inyección

## 1. Qué problema resuelve

`nightly.yml` tiene que lanzar `ci-api`, `ci-web` y `smoke` con `workflow_dispatch` (archivo 05).
Con lo que ya sabes, lo harías en `run:`:

```bash
gh workflow run ci-api.yml --ref main
```

Funciona, y para una llamada suelta es lo más simple. Pero en cuanto hay lógica (elegir qué lanzar
según un input, recorrer una lista, leer la respuesta de la API, decidir si fallar), el shell se
llena de `jq`, comillas y códigos de salida. `github-script` cambia el shell por JavaScript con:

- un cliente de la API (`github`) ya autenticado con el token del job,
- el contexto del evento ya parseado (`context`),
- las funciones del toolkit de Actions (`core`) para logs, outputs, resumen y fallos.

## 2. Cómo funciona

### La action

```yaml
      - uses: actions/github-script@3a2844b7e9c422d3c10d287c895573f7108da1b3 # v9.0.0
        with:
          script: |
            core.info(`Evento: ${context.eventName}`);
```

`script` es el cuerpo de una función `async`: puedes usar `await` y `return` directamente. Corre
con el runtime `node24` de la action.

### Lo que el script tiene a mano

| Objeto | Qué es | Ejemplo |
|---|---|---|
| `github` | Cliente Octokit autenticado | `await github.rest.actions.listWorkflowRuns({...})` |
| `context` | El evento y el repo | `context.repo.owner`, `context.repo.repo`, `context.eventName`, `context.sha` |
| `core` | Toolkit de Actions | `core.info`, `core.setOutput`, `core.setFailed`, `core.summary` |
| `glob`, `io`, `exec` | Archivos, rutas y procesos | `await exec.exec('git', ['status'])` |
| `require` | Módulos de Node y del workspace | `require('fs')` |
| `getOctokit` | Crear otro cliente con otro token | Inyectado en v9 |

Dos cambios de la v9 que rompen scripts copiados de ejemplos viejos: `require('@actions/github')`
ya **no funciona**, y `getOctokit` llega **inyectado**. Si escribes `const getOctokit = ...`, el
script falla por declarar dos veces el mismo nombre.

### Los inputs de la action

| Input | Por defecto | Para qué |
|---|---|---|
| `script` | (obligatorio) | El código |
| `github-token` | `github.token` | Otro token si el del job no basta |
| `result-encoding` | `json` | Cómo se codifica el `return` en el output `result` |
| `retries` | `0` | Reintentos de las llamadas a la API que fallan |
| `retry-exempt-status-codes` | `400,401,403,404,422` | Códigos que no se reintentan nunca |
| `debug` | Activo si el log de depuración del run lo está | Log de cada petición |
| `user-agent`, `previews`, `base-url` | | Casos especiales: GHES, previews de la API |

### El token y sus permisos

El cliente `github` usa el `GITHUB_TOKEN` del job, así que puede lo que diga `permissions:`. Para
lanzar workflows, `actions: write`; para comentar un PR, `pull-requests: write`. Igual que en la
Semana 06 con `packages: write`, el permiso se sube **solo en el job** que lo necesita.

### `result` y `result-encoding`

Lo que devuelve el script con `return` acaba en `steps.<id>.outputs.result`:

| `return` | `result-encoding: json` | `result-encoding: string` |
|---|---|---|
| `'ci-api'` | `"ci-api"`, con comillas | `ci-api` |
| `['a', 'b']` | `["a","b"]` | `a,b` |

Para pasar una cadena a otro step, `string`. Para una lista u objeto que otro step lee con
`fromJSON`, deja `json`.

## 3. Cómo se usa

### Lanzar workflows según un input

```yaml
name: script-demo

on:
  workflow_dispatch:
    inputs:
      target:
        description: Qué workflow relanzar sobre main
        type: choice
        options: [all, ci-api, ci-web, smoke]
        default: all

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  dispatch:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    # Crear un workflow_dispatch es escribir en Actions: solo este job lo puede hacer.
    permissions:
      actions: write
    steps:
      - name: Disparar los workflows elegidos
        id: fire
        uses: actions/github-script@3a2844b7e9c422d3c10d287c895573f7108da1b3 # v9.0.0
        env:
          TARGET: ${{ inputs.target || 'all' }}
        with:
          retries: 3
          result-encoding: string
          script: |
            const all = ['ci-api', 'ci-web', 'smoke'];
            const target = process.env.TARGET;
            const selected = target === 'all' ? all : all.filter((name) => name === target);
            if (selected.length === 0) {
              core.setFailed(`target desconocido: ${target}`);
              return '';
            }
            for (const name of selected) {
              await github.rest.actions.createWorkflowDispatch({
                owner: context.repo.owner,
                repo: context.repo.repo,
                workflow_id: `${name}.yml`,
                ref: 'main',
              });
            }
            return selected.join(',');

      - name: Resumen
        env:
          FIRED: ${{ steps.fire.outputs.result }}
        run: echo "Lanzados sobre main $FIRED" >> "$GITHUB_STEP_SUMMARY"
```

- **`TARGET` por `env:` con defecto**: el input entra como variable de entorno y el script la lee
  con `process.env.TARGET`. El `|| 'all'` cubre los eventos sin inputs, como el `schedule`.
- **La validación dentro del script**: aunque `choice` ya limita los valores en la UI, el script
  no confía y falla con `core.setFailed` ante uno desconocido.
- **`retries: 3`**: un 502 puntual de la API no tumba el nocturno. Los 4xx como un 403 por falta de
  permiso no se reintentan: reintentar no los arregla.
- **`result-encoding: string`**: el siguiente step recibe `ci-api,ci-web,smoke` sin comillas.

## 4. Antipatrones

### La inyección dentro de `script:`

`script:` es código. Si interpolas una expresión dentro, GitHub sustituye el texto **antes** de
que Node lo lea, exactamente igual que en un `run:`:

```yaml
      # ❌ El texto del input se pega dentro del código JavaScript.
      - uses: actions/github-script@3a2844b7e9c422d3c10d287c895573f7108da1b3 # v9.0.0
        with:
          script: |
            const note = '${{ inputs.note }}';
            core.info(note);
```

Con `note` igual a `'; await github.rest.repos.delete(context.repo); '`, el script que corre es:

```javascript
const note = ''; await github.rest.repos.delete(context.repo); '';
```

El atacante no inyecta texto, inyecta **código con el token del job**. Y el riesgo crece con
`${{ github.event.* }}`: el título de un PR, el cuerpo de una issue o el nombre de una rama los
escribe cualquiera. Un script que haga `'${{ github.event.issue.title }}'` ejecuta lo que un
desconocido escriba en un título.

La solución es la misma de siempre: el dato entra por `env:` y el código lo lee como dato.

```yaml
      # ✅ El input es el valor de una variable de entorno; el código no cambia.
      - uses: actions/github-script@3a2844b7e9c422d3c10d287c895573f7108da1b3 # v9.0.0
        env:
          NOTE: ${{ inputs.note }}
        with:
          script: |
            const note = process.env.NOTE;
            core.info(note);
```

Ahora `${{ inputs.note }}` se sustituye en un valor de YAML, no en código. Escriba lo que escriba,
`process.env.NOTE` es una cadena y nada más.

### El resto

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `${{ inputs.* }}` o `${{ github.event.* }}` dentro de `script:` | Inyección de JavaScript con el token del job | `env:` y `process.env.X` |
| `actions: write` en la raíz del workflow | Todos los jobs pueden lanzar workflows | El permiso solo en el job que lo usa |
| `require('@actions/github')` en v9 | El script falla | Usa `github` o el `getOctokit` inyectado |
| `const getOctokit = ...` | Declaración duplicada | Usa el inyectado |
| `result-encoding` por defecto para una cadena | El siguiente step recibe la cadena con comillas | `result-encoding: string` |
| `github-script` para una sola llamada sin lógica | JavaScript donde bastaba `gh` | `gh` en un `run:` con `GH_TOKEN` |

## 5. Trucos

- **`github.paginate(github.rest.actions.listWorkflowRuns, {...})`** recorre todas las páginas y
  te devuelve la lista completa. Sin él, la API te da 30 resultados y te olvidas del resto.
- **`core.summary`** escribe Markdown en el resumen del run con encadenado:
  `await core.summary.addHeading('Hecho', 3).addList(items).write()`. Es lo que usa
  `nightly.yml`.
- **`debug: true`** imprime cada petición y respuesta. Cuando una llamada da 404, te enseña la URL
  exacta que se pidió.

Verificado con actions/github-script@v9.0.0 y ubuntu-24.04, noviembre 2026.

## 📚 Recursos Adicionales

- [actions/github-script en el SHA fijado](https://github.com/actions/github-script/tree/3a2844b7e9c422d3c10d287c895573f7108da1b3)
- [GitHub Docs: Script injections](https://docs.github.com/en/actions/concepts/security/script-injections)
- [Octokit REST: métodos de `github.rest`](https://octokit.github.io/rest.js/)

## ✅ Checklist de Verificación

- [ ] Sé qué objetos recibe el script y para qué sirve cada uno
- [ ] Sé qué permiso pide cada llamada y dónde se declara
- [ ] Sé cuándo usar `result-encoding: string`
- [ ] Sé qué reintenta `retries` y qué no
- [ ] Sé por qué un `${{ }}` dentro de `script:` es inyección
- [ ] Paso todo dato no confiable por `env:` y lo leo con `process.env`
- [ ] Sé los dos cambios de la v9 que rompen scripts viejos

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Timeouts y cancelación](07-timeouts-y-cancelacion.md) | [Filtros de ramas y rutas](../2-practicas/01-filtros-de-ramas-y-rutas.md) |
