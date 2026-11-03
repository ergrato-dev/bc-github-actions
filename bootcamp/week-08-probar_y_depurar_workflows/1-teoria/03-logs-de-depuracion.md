# Logs de depuración

> Cuando el log normal no basta, GitHub puede contarte mucho más sin que cambies una línea del
> workflow: qué evaluó en cada expresión, qué hizo cada action por dentro y qué pasó en el runner.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué añade `ACTIONS_STEP_DEBUG` y qué añade `ACTIONS_RUNNER_DEBUG`
- Activarlos para un único reintento con `gh run rerun --debug`, sin crear nada
- Activarlos para todo el repo con un secreto o una variable, y saber cuál gana
- Hacer que tus propios scripts den más detalle solo cuando la depuración está activa
- Saber qué riesgos tiene dejar la depuración encendida

## 1. Qué problema resuelve

El step `Install dependencies` falla con `exit code 2` y el log dice poco. ¿Qué valor tomó la
expresión del `if:`? ¿Qué clave de caché buscó `setup-uv` y por qué no la encontró? ¿Qué hizo el
runner antes de lanzar el step? Nada de eso aparece en el log normal.

La tentación es llenar el workflow de `echo` y `set -x`, hacer push, mirar, quitarlos y volver a
hacer push. Tres commits de ruido en el historial y otro run por cada prueba. GitHub ya tiene
esa información; solo la oculta por defecto.

## 2. Cómo funciona

Hay dos niveles independientes:

| Interruptor | Qué añade | Dónde lo ves |
|---|---|---|
| `ACTIONS_STEP_DEBUG=true` | Líneas `##[debug]` en el log de cada step: evaluación de expresiones, detalles internos de las actions, tus mensajes `::debug::` | En el propio log, en otro color |
| `ACTIONS_RUNNER_DEBUG=true` | Logs de diagnóstico del runner: el log del proceso runner y del worker que ejecuta el job | En el archivo de logs del run, carpeta `runner-diagnostic-logs` |

`ACTIONS_STEP_DEBUG` es el que casi siempre quieres: responde "qué hizo el workflow". El de runner
responde "qué hizo la máquina": útil cuando un job se queda colgado, no arranca o el runner pierde
la conexión. En runners alojados por GitHub lo vas a necesitar poco; con runners propios (Semana
15) mucho más.

### Tres formas de encenderlos

1. **Un reintento con depuración.** Cualquiera que pueda ejecutar el workflow puede relanzar un
   run con los dos niveles activos para ese intento: desde la UI (casilla **Enable debug
   logging** del diálogo de re-run) o con `gh run rerun <id> --debug`. No crea nada en el repo y
   no afecta a otros runs.
2. **Una variable del repo** `ACTIONS_STEP_DEBUG` o `ACTIONS_RUNNER_DEBUG` con valor `true`:
   todos los runs a partir de ahora.
3. **Un secreto del repo** con el mismo nombre y valor: igual que la variable. Si existen los
   dos con el mismo nombre, **gana el secreto**.

### Cómo sabe tu workflow que está en modo depuración

Cuando la depuración está activa, el runner lo expone de dos maneras:

- El contexto `runner.debug` vale `'1'`. Úsalo en expresiones (`if:`, `with:`).
- La variable de entorno `RUNNER_DEBUG` vale `1` dentro de los steps. Úsala en scripts.

Con eso tus herramientas pueden subir su nivel de detalle solo cuando alguien lo pidió.

## 3. Cómo se usa

### Lo normal: un reintento con `--debug`

```bash
id=$(gh run list --workflow ci-api.yml --status failure --limit 1 --json databaseId --jq '.[0].databaseId')

# Solo los jobs fallidos (y los que dependen de ellos), con depuración
gh run rerun "$id" --failed --debug
gh run watch "$id"

# El log del intento nuevo, solo las líneas de depuración
gh run view "$id" --log-failed | grep -F '##[debug]' | head -40
```

Lo que verás en las líneas `##[debug]` depende de cada action, pero hay patrones que se repiten:

- `Evaluating condition for step: '...'` y el resultado de la expresión del `if:`.
- `Evaluating: ...` con cada paso de una expresión y su valor intermedio.
- Detalles internos de las actions JavaScript que usan `core.debug()`: rutas, claves de caché,
  URLs consultadas.

El reintento usa el mismo commit y el mismo YAML. Si el fallo era intermitente puede salir verde:
eso ya es un dato.

### Para todo el repo, durante un rato

Si estás persiguiendo un fallo que no sabes reproducir, enciéndelo con una variable y apágalo al
terminar:

```bash
gh variable set ACTIONS_STEP_DEBUG --body true
# ... los runs siguientes llevan depuración ...
gh variable delete ACTIONS_STEP_DEBUG
```

Prefiere la variable al secreto: se ve en `gh variable list` y en la configuración del repo, así
que nadie se olvida de que está encendida. El secreto no enseña su valor.

### Tus scripts, más habladores bajo demanda

```yaml
name: debug-aware

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  check:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Validar con más detalle si se pide depuración
        run: |
          # RUNNER_DEBUG solo existe cuando la depuración está activa.
          if [[ "${RUNNER_DEBUG:-}" == "1" ]]; then
            set -x
          fi
          echo "::debug::Directorio de trabajo: $PWD"
          ls -la

      - name: Volcado del contexto runner, solo en depuración
        if: runner.debug == '1'
        env:
          RUNNER_CONTEXT: ${{ toJSON(runner) }}
        run: echo "$RUNNER_CONTEXT"
```

Fíjate en tres cosas:

- `::debug::` no necesita condición: el runner ya lo oculta si la depuración está apagada.
- `set -x` sí la necesita: bash no sabe nada de Actions y lo imprimiría siempre.
- El contexto `runner` llega al shell por `env:`, no interpolado en el `run:`. Nunca vuelques
  `secrets` así: `toJSON(secrets)` está prohibido en todo el bootcamp.

### Qué hay en `runner-diagnostic-logs`

Con `ACTIONS_RUNNER_DEBUG`, el archivo de logs del run (**Download log archive**) trae una carpeta
`runner-diagnostic-logs` con, por cada job, el log del proceso **runner** (el que habla con GitHub
y recibe el job) y el del **worker** (el que ejecuta los steps). Ahí aparecen las fases que el log
normal no enseña: preparar el directorio de trabajo, descargar las actions, arrancar los
contenedores de servicio (Semana 05) y limpiar al final.

### Lo que la depuración no cambia

- **No cambia el comportamiento.** Los mismos steps, con el mismo YAML y el mismo commit. Si el
  run de depuración sale verde y el normal rojo, lo que tienes es un fallo intermitente.
- **No desenmascara secretos.** Los valores de `secrets.*` y los de `::add-mask::` siguen saliendo
  como `***` en las líneas `##[debug]`.
- **No es privado.** En un repo público como `tablero`, cualquiera puede leer los logs de sus
  runs, también los de depuración. Lo que tus scripts impriman "solo en depuración" lo lee el
  mundo: rutas internas, URLs, versiones. Nada que no imprimirías en un log normal.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Llenar el YAML de `echo` y `set -x` para depurar | Commits de ruido y un run por prueba | `gh run rerun --debug` |
| Dejar `ACTIONS_STEP_DEBUG` encendido para siempre | Logs enormes, más lentos de leer, y más datos internos a la vista de quien lea el run | Encenderlo para un reintento o un rato |
| Usar un secreto para activarlo "por si acaso" | No se ve el valor: nadie recuerda que está activo | Variable visible, o `--debug` |
| `set -x` sin condición | Imprime cada comando siempre, a veces con valores sensibles | Condicionarlo a `RUNNER_DEBUG` |
| `echo "${{ toJSON(github) }}"` dentro de `run:` | Interpola datos no confiables en el script | Pasarlo por `env:` y solo en depuración |
| Volcar `toJSON(secrets)` para "ver qué hay" | Prohibido: es la forma más rápida de filtrar un secreto | Comprobar si existe sin imprimirlo |

## 5. Trucos

- **`gh run rerun "$id" --job <job-id> --debug`** relanza con depuración un único job (y sus
  dependencias) de un run que ya terminó, aunque haya salido verde: útil para ver por qué una
  caché no se reutiliza.
- **`grep -F '##[debug]Evaluating condition'`** sobre el log te dice el resultado de cada `if:`
  sin leer nada más.
- **`core.debug()` en tus actions JavaScript** (Semana 10) y `::debug::` en tus scripts son
  gratis: no ensucian el log normal y están ahí el día que hacen falta.
- **Mira los permisos del token** al principio de cada job, en el grupo `GITHUB_TOKEN
  Permissions` del step **Set up job**: no hace falta depuración para verlos.

Verificado con gh 2.103 y ubuntu-24.04, noviembre 2026.

## 📚 Recursos Adicionales

- [GitHub Docs: Enabling debug logging](https://docs.github.com/en/actions/how-tos/monitor-workflows/enable-debug-logging)
- [GitHub Docs: Re-running workflows and jobs](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs)
- [GitHub Docs: contexto `runner`](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#runner-context)
- [GitHub CLI: `gh run rerun`](https://cli.github.com/manual/gh_run_rerun)

## ✅ Checklist de Verificación

- [ ] Sé qué añade cada interruptor y dónde aparece
- [ ] Sé relanzar un run con depuración sin crear nada en el repo
- [ ] Sé activarlo con una variable y por qué la prefiero al secreto
- [ ] Sé qué gana si hay secreto y variable con el mismo nombre
- [ ] Sé condicionar `set -x` a `RUNNER_DEBUG` y un step a `runner.debug`
- [ ] Sé qué contiene `runner-diagnostic-logs`

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Comandos de workflow](02-comandos-de-workflow.md) | [Problem matchers y actionlint en CI](04-problem-matchers-y-actionlint-en-ci.md) |
