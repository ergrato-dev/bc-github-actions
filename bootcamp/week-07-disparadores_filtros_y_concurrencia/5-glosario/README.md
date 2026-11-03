# 📖 Glosario — Semana 07

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **`always()`**: función de estado que hace que un step o un job corra tras un fallo **y** tras
  una cancelación. Un job con `if: always()` no se cancela; úsala solo para limpieza corta.

## C

- **`cancel-in-progress`**: clave de `concurrency` que decide qué pasa con el run en curso cuando
  llega otro al mismo grupo. Con `true` se cancela; con `false` termina. En `tablero` vale
  `${{ github.event_name == 'pull_request' }}`.
- **Cancelación** (*cancellation*): corte de un run, pedido a mano o por `concurrency`. GitHub
  reevalúa los `if:`, manda `SIGINT` al step en curso, `SIGTERM` a los 7,5 s y lo mata 2,5 s
  después.
- **Cancelación forzada** (*force cancel*): `gh run cancel --force`. Corta también los jobs y
  steps que siguen corriendo con `always()`.
- **`cancelled()`**: función de estado verdadera solo si el run se canceló. Sirve para anotar que
  se cortó.
- **`choice`**: tipo de input de `workflow_dispatch` que muestra un desplegable con `options`.
  GitHub rechaza un valor fuera de la lista con un HTTP 422.
- **`client_payload`**: objeto JSON libre que viaja con un `repository_dispatch` y llega como
  `github.event.client_payload`. Es dato no confiable: entra al shell por `env:`.
- **Concurrencia** (*concurrency*): control de cuántos runs o jobs de un mismo grupo corren a la
  vez. Se declara con `concurrency:` en la raíz del workflow o dentro de un job.
- **Cron**: expresión de cinco campos (minuto, hora, día del mes, mes, día de la semana) que fija
  cuándo corre un `schedule`. En UTC salvo que declares `timezone`.

## D

- **Diff de dos puntos** (*two-dot diff*): `before..after`, lo que cambia un `push` respecto al
  commit anterior de la rama. Es lo que mira `paths` en `push`.
- **Diff de tres puntos** (*three-dot diff*): `base...head`, todo lo que un PR cambia respecto a la
  base de fusión. Es lo que mira `paths` en `pull_request`.
- **Dispatch**: lanzar un workflow por API en lugar de por un cambio en el repo:
  `workflow_dispatch` nombra el workflow, `repository_dispatch` manda un evento con nombre.

## E

- **`event_type`**: nombre que inventas para un `repository_dispatch`, como `tablero-ping`. Se
  filtra con `types:` y llega como `github.event.action`.

## F

- **Filtro de ramas** (*branch filter*): `branches`, `branches-ignore` y `tags` en un evento. Con
  patrones glob y negación `!`, el último patrón que casa gana.
- **Filtro de rutas** (*path filter*): `paths` o `paths-ignore` en un evento. Si no casa ningún
  archivo del diff, no se crea ningún run.

## G

- **`github-script`**: action que ejecuta JavaScript con un cliente autenticado (`github`), el
  `context` del run y `core`. Lo que escribes en `script:` es código: los datos entran por `env:`.
- **Grupo de concurrencia** (*concurrency group*): la cadena de `concurrency.group`. Todos los runs
  que calculan la misma cadena comparten grupo, aunque sean de workflows distintos. En `tablero`,
  `${{ github.workflow }}-${{ github.ref }}`.

## I

- **Inactividad** (*inactivity*): en un repo público, 60 días sin actividad desactivan los
  workflows programados. El workflow sigue ahí; el cron, no.
- **Input tipado** (*typed input*): input de `workflow_dispatch` con `type`: `string`, `boolean`,
  `choice`, `number` o `environment`. `inputs.x` respeta el tipo; `github.event.inputs.x` es
  siempre una cadena.

## J

- **Job puerta** (*gate job*): job que corre siempre y decide qué partes del CI eran necesarias,
  para que un filtro de rutas no deje un check obligatorio esperando. Llega en la Semana 18.

## P

- **Pendiente** (*pending*): run que espera en un grupo de concurrencia porque otro está en curso.
  Solo cabe uno: el pendiente nuevo sustituye y cancela al anterior.

## Q

- **`queue`**: clave de `concurrency` que, con `max`, convierte el pendiente único en una fila de
  hasta 100 runs. Está en la documentación, pero actionlint 1.7.12 la rechaza.

## R

- **`repository_dispatch`**: evento con nombre propio que se manda con
  `POST /repos/{owner}/{repo}/dispatches`. Corre en la rama por defecto y, creado con el
  `GITHUB_TOKEN`, sí dispara workflows.
- **`result-encoding`**: input de `github-script` que decide cómo sale el valor devuelto: `json`
  por defecto, `string` para una cadena sin comillas.

## S

- **`schedule`**: evento que lanza un workflow según una o varias expresiones cron. Solo lee el
  YAML de la rama por defecto, con un intervalo mínimo de 5 minutos y sin puntualidad garantizada.
- **`SIGINT` / `SIGTERM`**: señales que recibe el step en curso al cancelar. Un `trap` que limpie
  en menos de diez segundos llega a terminar.

## T

- **Timeout** (`timeout-minutes`): techo de minutos de un job (360 por defecto) o de un step. Al
  vencer, el job se cancela o el step falla.
- **`timezone`**: clave de una entrada de `schedule` con un nombre IANA, como `Europe/Madrid`. Con
  ella GitHub sigue los cambios de horario por ti.

## W

- **`workflow_dispatch`**: evento que lanza un workflow a mano, desde la UI, `gh workflow run` o la
  API, con hasta 25 inputs. Creado con el `GITHUB_TOKEN`, sí dispara workflows.
- **`workflow_run`**: evento que GitHub emite cuando otro workflow, nombrado por su `name:`, se
  pide, empieza o termina. `completed` no es `success`: comprueba `conclusion`. Encadena como mucho
  tres niveles.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Semana 08 — Probar y depurar workflows](../../week-08-probar_y_depurar_workflows/README.md) |
