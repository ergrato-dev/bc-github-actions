# 📖 Glosario — Semana 08

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **act**: herramienta que ejecuta workflows en tu Docker, un contenedor por job, imitando un
  runner. Sirve para probar la lógica de los steps; ignora `permissions`, `concurrency`,
  `timeout-minutes` y `environment:`, y no crea anotaciones. En `tablero`, la 0.2.94.
- **actionlint**: linter de workflows. Comprueba sintaxis, expresiones, contextos, `needs:` y, con
  shellcheck, los scripts de `run:`. No ejecuta nada. En `tablero`, la 1.7.12, instalada con
  checksum.
- **Anotación** (*annotation*): mensaje con nivel (`notice`, `warning`, `error`) que aparece en la
  página del run y, con archivo y línea, sobre esa línea del PR. La crean el runner, un comando de
  workflow o un problem matcher. Se lee también por la API del check run.
- **Auditoría** (*audit*): cada comprobación de zizmor, como `template-injection`, `artipacked` o
  `unpinned-uses`. Unas son offline y otras consultan la API de GitHub (auditorías online).

## C

- **Checksum**: huella SHA-256 de un archivo. Se compara con `sha256sum -c` contra el campo
  `digest` que la release publica antes de descomprimir nada.
- **Código de salida** (*exit code*): número con el que termina un proceso. Lo único que decide si
  un step queda en verde (0) o en rojo (cualquier otro). zizmor termina con 14 si hay un hallazgo
  de severidad alta.
- **Comando de workflow** (*workflow command*): línea de la forma `::comando parámetros::mensaje`
  que un step imprime y el runner interpreta: `::error`, `::group`, `::add-mask`, `::debug`,
  `::add-matcher`, `::stop-commands`.
- **Confianza** (*confidence*): cuán seguro está zizmor de que un hallazgo es real: `low`,
  `medium` o `high`. Independiente de la severidad.

## D

- **Dry run** (`--dryrun`, `-n`): modo de act que no crea contenedores pero sí clona las actions.
  Para ver solo el plan, `act -l` es más rápido.

## F

- **Falso verde**: step o run en `success` que no comprobó lo que debía, como `pytest | tee` sin
  `pipefail`. El peor fallo, porque nadie lee el log de un verde.

## H

- **Hallazgo** (*finding*): problema que encuentra una auditoría de zizmor, con archivo, línea,
  severidad, confianza y un enlace a su documentación.

## I

- **Ignorar un hallazgo** (*ignore*): aceptar un riesgo con `# zizmor: ignore[<auditoría>]` como
  comentario de YAML, o en `zizmor.yml`, siempre con una línea que diga por qué. Dentro de un
  `run: |` de varias líneas el comentario es parte del script y no cuenta.
- **Imagen de runner** (*runner image*): imagen Docker que hace de runner en act, asignada a una
  etiqueta de `runs-on` con `-P`. Las de `catthehacker/ubuntu` son incompletas a propósito; se
  fija el tag con fecha, como `act-24.04-20260815`.

## L

- **Log de depuración** (*step debug logs*): líneas `##[debug]` en el log de cada step, activadas
  con `ACTIONS_STEP_DEBUG` o con `gh run rerun --debug`. Enseñan cómo se evaluó cada `if:` y
  expresión.
- **Log de diagnóstico del runner** (*runner diagnostic logs*): logs del proceso runner y del
  worker, activados con `ACTIONS_RUNNER_DEBUG`, en la carpeta `runner-diagnostic-logs` del archivo
  de logs del run.
- **Log en bruto** (*raw logs*): el log de un job como texto plano con marca de tiempo por línea,
  sin plegar.

## M

- **Máscara** (*mask*): sustitución de un valor por `***` en el log. Los `secrets.*` se
  enmascaran solos; lo que genera el job, con `::add-mask::`, desde ese momento y línea a línea.

## O

- **`--offline`**: flag de zizmor que desactiva todo lo que necesita red. La puerta del CI no
  necesita token y da el mismo resultado para el mismo commit.

## P

- **Persona** (*persona*): perfil de zizmor que decide qué hallazgos enseña: `regular` para la
  puerta del CI, `pedantic` para revisar a fondo y `auditor` para código ajeno.
- **Pipefail**: opción de bash que hace fallar una tubería si falla cualquiera de sus comandos. La
  activa `shell: bash`; sin `shell:`, el step corre con `bash -e` sin ella.
- **Problem matcher**: JSON con una regex que el runner aplica a cada línea de salida de los steps
  siguientes del job para convertirla en anotación. Se registra con `::add-matcher::` después del
  checkout y se retira con `::remove-matcher owner=<owner>::`.
- **Puerta** (*gate*): workflow que debe fallar para impedir que algo llegue a `main`. En
  `tablero`, `lint-workflows.yml`. Una puerta que nunca se vio en rojo no está probada.

## R

- **`runner.debug`**: contexto que vale `'1'` cuando la depuración está activa. En los scripts, la
  variable `RUNNER_DEBUG`.

## S

- **SARIF**: formato estándar de salida de los analizadores estáticos, el que leen las
  herramientas de code scanning. zizmor lo emite con `--format=sarif`.
- **Severidad** (*severity*): cuánto daño haría un hallazgo si es real: `informational`, `low`,
  `medium` o `high`.
- **`stop-commands`**: comando de workflow que apaga la interpretación de comandos hasta que se
  imprime un token aleatorio. Protege al leer texto no confiable.
- **Suprimido** (*suppressed*): hallazgo que la persona activa no enseña. Aparece contado en el
  resumen de zizmor; `--persona=pedantic` lo saca.

## T

- **`template-injection`**: auditoría de zizmor que detecta `${{ }}` con datos controlables dentro
  de `run:`. Ve `${{ inputs.* }}`, que actionlint 1.7.12 no marca.

## Z

- **zizmor**: analizador estático de seguridad para workflows y actions. Lee el YAML, no lo
  ejecuta. En `tablero`, la 1.31.1, instalada con `uv tool install`.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Semana 09 — Workflows reutilizables](../../week-09-workflows_reutilizables/README.md) |
