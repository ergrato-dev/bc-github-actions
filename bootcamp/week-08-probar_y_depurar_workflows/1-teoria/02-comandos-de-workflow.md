# Comandos de workflow

> Un step se comunica con el runner escribiendo líneas especiales en su salida. Con ellas
> conviertes un mensaje perdido en el log en una anotación sobre la línea exacta del PR.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Emitir anotaciones `notice`, `warning` y `error` con archivo, línea y título
- Plegar el log en grupos con `::group::` y `::endgroup::`
- Ocultar un valor sensible generado en el job con `::add-mask::`
- Desactivar el procesado de comandos mientras imprimes salida no confiable
- Distinguir los comandos de salida estándar de los archivos de entorno (`$GITHUB_OUTPUT`...)

## 1. Qué problema resuelve

Tu script de validación encuentra un error en `api/src/tablero/main.py`, línea 12, y lo
imprime. Quien abre el run tiene que desplegar el job, el step, buscar la línea entre cien y luego
abrir el archivo a mano. Si el mismo script imprime una línea con un formato concreto, GitHub la
convierte en una **anotación**: aparece arriba del run y sobre la línea 12 en el diff del PR.

Lo mismo con el ruido: un log de 800 líneas de instalación delante del error que importa se
pliega en un grupo. Y un token temporal que tu job genera y no es un secreto del repo se oculta
igual que uno.

## 2. Cómo funciona

El runner lee la salida estándar de cada step línea a línea. Si una línea empieza por `::` y sigue
el formato `::comando parámetros::mensaje`, la interpreta en vez de solo copiarla al log:

```text
::error file=api/src/tablero/main.py,line=12,col=8,title=Import sin usar::os no se usa
```

Tiene tres partes: el **comando** (`error`), los **parámetros** separados por comas
(`file=...,line=12,col=8,title=...`) y, tras el segundo `::`, el **mensaje**.

No hay librería ni API: cualquier lenguaje que escriba en `stdout` puede usarlos. `echo` en
bash, `print` en Python, `console.log` en Node.

### Los comandos que vas a usar

| Comando | Qué hace |
|---|---|
| `::debug::mensaje` | Línea de depuración: solo se ve con `ACTIONS_STEP_DEBUG` activo (archivo 03) |
| `::notice …::mensaje` | Anotación informativa |
| `::warning …::mensaje` | Anotación de aviso, en amarillo |
| `::error …::mensaje` | Anotación de error, en rojo |
| `::group::título` / `::endgroup::` | Pliega las líneas entre ambos bajo un título |
| `::add-mask::valor` | A partir de aquí, el valor sale como `***` en el log |
| `::stop-commands::<token>` / `::<token>::` | Deja de interpretar comandos hasta ver el token |
| `::add-matcher::ruta.json` / `::remove-matcher owner=<owner>::` | Problem matchers (archivo 04) |

Los parámetros de las anotaciones son todos opcionales: `file`, `line`, `endLine`, `col`,
`endColumn` y `title`. Sin `file` la anotación sale en el run pero no en el diff. `file` es una
ruta relativa a la raíz del repo; si el archivo no existe en el commit, la anotación se queda en
el run sin enlazar.

### Una anotación de error no falla el step

`::error::` crea una marca roja pero **no cambia el código de salida**. Si tu script emite tres
errores y termina con 0, el step queda en verde con tres anotaciones rojas encima, lo más confuso
que puedes enseñar. Emite y luego sal con 1.

### Lo que ya no se hace con comandos

`::set-output` y `::save-state` existían para pasar datos entre steps. GitHub los deshabilitó:
cualquiera que controlara un texto impreso en el log (el título de un PR, por ejemplo) podía
inyectar un `::set-output` y cambiar el resultado de otro step. Hoy se escribe en archivos que el
runner prepara para cada step y que nadie más imprime:

| Archivo | Para qué | Lo viste en |
|---|---|---|
| `$GITHUB_OUTPUT` | Outputs del step | Semana 02 |
| `$GITHUB_ENV` | Variables de entorno para los steps siguientes | Semana 02 |
| `$GITHUB_PATH` | Añadir directorios al `PATH` | Semana 02 |
| `$GITHUB_STEP_SUMMARY` | Markdown del resumen del job | Semana 02 |

Del resumen conviene saber dos límites: como mucho **1 MiB por step** y se muestran **20
resúmenes por job**. Para un informe largo, súbelo como artefacto y enlázalo desde el resumen.

## 3. Cómo se usa

### Un workflow de demostración

```yaml
name: commands-demo

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  demo:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Anotaciones con archivo y línea
        run: |
          echo "::notice title=Versión::Python $(python3 --version | cut -d' ' -f2)"
          echo "::warning file=api/pyproject.toml,line=1,title=Revisión pendiente::Revisa las dependencias"

      - name: Agrupar una salida larga
        run: |
          echo "::group::Paquetes del sistema"
          dpkg -l | head -50
          echo "::endgroup::"

      - name: Ocultar un valor generado en el job
        run: |
          session_token=$(openssl rand -hex 16)
          # Se enmascara antes de que cualquier comando pueda imprimirlo.
          echo "::add-mask::$session_token"
          echo "Token de sesión: $session_token"

      - name: Fallar con una anotación
        run: |
          echo "::error file=api/src/tablero/main.py,line=1,title=Validación::Ejemplo de error anotado"
          exit 1
```

En el run verás tres anotaciones arriba (notice, warning, error), un grupo plegado con los
paquetes, `Token de sesión: ***` y el último step en rojo porque sale con 1.

### Desde Python

En `tablero` los scripts de validación están en Python: el formato es el mismo.

```python
# Una anotación por problema; el código de salida decide el color del step.
for path, line, msg in problems:
    print(f"::error file={path},line={line},title=Esquema::{msg}")
raise SystemExit(1 if problems else 0)
```

### `::add-mask::` y sus límites

- Enmascara **desde ese momento**. Lo que ya se imprimió antes sigue visible.
- Los secretos del repo (`secrets.*`) se enmascaran solos; `add-mask` es para lo que **tú
  generas** en el job: un token temporal, una contraseña aleatoria, una URL firmada.
- Es por línea: un valor de varias líneas hay que enmascararlo línea a línea.
- Con `set -x` activo, bash imprime cada comando antes de ejecutarlo, valor incluido: no
  actives trazas antes de enmascarar.

Las credenciales de usar y tirar de este bootcamp valen `cambiame` y no hace falta ocultarlas;
cualquier otro valor sensible, sí.

### Salida no confiable: `::stop-commands::`

Si un step imprime texto que no controlas (el log de una herramienta, el contenido de un archivo
de un PR), una línea que empiece por `::` sería interpretada como comando. `::stop-commands::`
corta la interpretación hasta que imprimes el token que tú elegiste:

```bash
stop_token=$(openssl rand -hex 16)
echo "::stop-commands::$stop_token"
cat informe-de-terceros.txt   # sus "::error::" salen como texto, no como anotación
echo "::$stop_token::"
```

El token es aleatorio por la misma razón que una contraseña: si fuera fijo, el texto no confiable
podría contenerlo y reactivar los comandos.

### El límite de anotaciones

No sirve de nada emitir quinientas. La documentación del toolkit de Actions habla de un tope por
step (10 de cada nivel) y por job (50); lo que pasa de ahí no aparece. Si tu herramienta puede
dar cientos de hallazgos, agrúpalos: una anotación por archivo y el detalle en el resumen.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `::error::` sin `exit 1` | Step verde con anotaciones rojas | Emitir y salir con código distinto de 0 |
| `echo "::set-output name=x::1"` | Deshabilitado: el output no llega | `echo "x=1" >> "$GITHUB_OUTPUT"` |
| `echo "::error::${{ github.event.pull_request.title }}"` en `run:` | Inyección: el título entra en el script | Pásalo por `env:` y usa `"$PR_TITLE"` |
| `add-mask` después de imprimir el valor | Ya está en el log, para siempre | Enmascarar justo al generarlo |
| `cat` de un archivo de un PR sin `stop-commands` | El archivo puede emitir anotaciones o enmascarar texto | Rodearlo con `::stop-commands::` |
| `stop-commands` con un token fijo | El texto no confiable puede incluirlo | Token aleatorio por run |
| Cientos de anotaciones | Pasado el tope dejan de aparecer | Una por archivo y el detalle en el resumen |

## 5. Trucos

- **`title=`** es lo primero que se lee en la lista de anotaciones del run: pon ahí la regla o la
  herramienta (`title=ruff F401`) y en el mensaje el detalle.
- **`endLine`** marca un rango: útil cuando el problema es un bloque entero y no una línea.
- **Un grupo por fase** (`::group::Instalar`, `::group::Tests`) hace que el log de un step largo se
  lea como un índice: el grupo que falla se queda desplegado.
- **`::notice::` con la versión** de cada herramienta al principio del job deja constancia en el
  run sin abrir ningún log.

Verificado con actionlint 1.7.12 y ubuntu-24.04, noviembre 2026.

## 📚 Recursos Adicionales

- [GitHub Docs: Workflow commands for GitHub Actions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands)
- [actions/toolkit: docs/commands.md](https://github.com/actions/toolkit/blob/main/docs/commands.md)
- [GitHub Blog: deprecating save-state and set-output commands](https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/)

## ✅ Checklist de Verificación

- [ ] Sé el formato `::comando parámetros::mensaje`
- [ ] Sé emitir una anotación con archivo, línea y título
- [ ] Sé por qué `::error::` no basta para fallar un step
- [ ] Sé plegar el log con `::group::`
- [ ] Sé cuándo usar `::add-mask::` y desde cuándo protege
- [ ] Sé proteger una salida no confiable con `::stop-commands::` y un token aleatorio
- [ ] Sé qué archivo sustituye a `::set-output` y por qué

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Leer un run que falla](01-leer-un-run-que-falla.md) | [Logs de depuración](03-logs-de-depuracion.md) |
