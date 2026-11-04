# 📖 Glosario — Semana 09

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **Anidamiento** (*nesting*): un reutilizable que a su vez llama a otro. Hasta 10 niveles: el
  llamador de nivel superior más nueve reutilizables encadenados. Cada nivel solo puede mantener
  o bajar los permisos que recibe y vuelve a pasar los secretos que el siguiente necesite.

## C

- **`cache-mode`**: clave del job que llama que limita el acceso del reutilizable a la caché:
  `read`, `write`, `write-only` o `none`. Evita que un reutilizable con código poco fiable envenene
  la caché de `main`. `tablero` no la usa: actionlint 1.7.12 la rechaza.
- **Contrato** (*interface*): lo que un reutilizable declara en `on.workflow_call`: inputs con su
  tipo, secretos y outputs. actionlint valida cada llamada local contra él antes del push.

## E

- **`env` que no cruza**: las variables de `env:` del llamador no llegan al reutilizable ni al
  revés. Lo que cruza la frontera viaja por input, output o `vars.*`.

## I

- **Input** (*input*): parámetro de un reutilizable, declarado en `on.workflow_call.inputs` con
  `type` (`string`, `number` o `boolean`), `required`, `default` y `description`. Se lee con el
  contexto `inputs` y llega al shell siempre por `env:`.
- **Interbloqueo de `concurrency`**: llamador y llamado con el mismo `group` y
  `cancel-in-progress: true`. Como los dos evalúan `github.workflow` con el valor del llamador, el
  reutilizable cancela a su propio llamador. En `tablero`, `concurrency` vive solo en los
  llamadores.

## J

- **Job que llama** (*caller job*): job con `uses:` en lugar de `runs-on` y `steps`. Solo admite
  `name`, `uses`, `with`, `secrets`, `needs`, `if`, `strategy`, `permissions`, `concurrency` y
  `cache-mode`; su `name:` es el prefijo de los jobs del reutilizable en la UI (`API / ...`).

## L

- **Llamado**: ver *workflow reutilizable*.
- **Llamador** (*caller workflow*): el workflow que usa un reutilizable. Decide cuándo corre
  (eventos, `paths`, `concurrency`), con qué inputs y secretos y con qué techo de permisos.
- **Lista JSON**: forma de pasar una lista a un reutilizable, que no tiene tipo lista. Un input
  `string` como `"[24, 26]"` que el reutilizable convierte con `fromJSON`.

## M

- **Matriz de llamadas**: `strategy.matrix` en un job que llama; el reutilizable corre una vez por
  combinación, pero el llamador solo ve un output por nombre, el del último que terminó bien.

## O

- **Output de un reutilizable** (*output*): valor declarado en `on.workflow_call.outputs.<id>.value`
  a partir de `jobs.<job>.outputs`. El llamador lo lee como `needs.<job-que-llama>.outputs.<id>`.

## P

- **Plantilla de workflow** (*workflow template*): archivo que se copia para arrancar un repo. A
  diferencia de un reutilizable, cada copia diverge y un cambio no llega a nadie (Semana 11).

## R

- **Referencia local** (`./`): `uses: ./.github/workflows/_python.yml`. Lee el reutilizable del
  mismo commit que el llamador, así un PR prueba su propio cambio. Es la que usa `tablero`.
- **Referencia remota** (`owner/repo/.github/workflows/<archivo>@<ref>`): llamada a un
  reutilizable de otro repo. El `@ref` es obligatorio y, en este bootcamp, un SHA de 40 caracteres
  con el tag en comentario.
- **Reutilizable único** (*unique reusable workflow*): cada archivo distinto que usa un workflow de
  nivel superior, anidados incluidos. Máximo 50; llamar dos veces al mismo cuenta uno.

## S

- **`secrets: inherit`**: en el job que llama, pasa todos los secretos del llamador al llamado
  directo, solo dentro de la misma organización o enterprise. Prohibido en `tablero`; zizmor lo
  marca con la auditoría `secrets-inherit`.
- **Secreto declarado**: secreto que el reutilizable lista en `on.workflow_call.secrets`, con
  `required`, y que el llamador pasa de forma explícita en `secrets:`. El `GITHUB_TOKEN` llega sin
  declararlo.
- **Self-repository** (`$/`): sintaxis `uses: $/.github/workflows/<archivo>` para el mismo repo y
  commit, sin depender del sistema de archivos del runner. Disponible en github.com desde julio de
  2026; actionlint 1.7.12 aún no la admite (issue #711), así que `tablero` ignora la auditoría
  `self-repository` de zizmor con el motivo escrito.

## T

- **Techo de permisos**: el `permissions:` de raíz de un reutilizable. Es lo máximo que puede usar
  y lo que necesita: si el job que llama concede menos, la llamada no valida y el run no crea jobs.

## W

- **Workflow reutilizable** (*reusable workflow*): workflow con `on: workflow_call` que otro
  workflow llama desde un job. Empaqueta jobs completos, con su runner, servicios y matrices, y sus
  jobs corren dentro del run del llamador. Tiene que estar directamente en `.github/workflows/`.
- **`workflow_call`**: el evento que convierte un workflow en reutilizable. Dentro del llamado no
  se ve: el contexto `github` es el del llamador, `github.workflow` y `github.event_name`
  incluidos.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Semana 10 — Actions propias: composite, JavaScript y Docker](../../week-10-actions_propias/README.md) |
