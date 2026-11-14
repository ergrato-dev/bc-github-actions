# 📖 Glosario — Semana 18

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **`allowed_merge_methods`**: parámetro de la regla `pull_request` con los métodos de fusión
  permitidos, en minúsculas (`merge`, `squash`, `rebase`). `tablero` solo permite `squash`.
- **Aprobación de workflows** (*approval-required*): estado en el que se crean los runs de
  `pull_request` de un PR que `GITHUB_TOKEN` abre o actualiza. No corren hasta que alguien con
  escritura pulsa "Approve workflows to run". Por eso el PR de release lo abre una App.
- **Área** (de un monorepo): parte de `tablero` con su propio CI: `api`, `web`, `tools`, `smoke` y
  `workflows`. `scripts/changed-areas.sh` dice cuáles cambian y `ci.yml` corre solo esas.

## B

- **Base del diff**: commit contra el que `changes` compara `HEAD`. En un PR,
  `pull_request.base.sha`; en la cola, `merge_group.base_sha`; en un push, `event.before`. Si no
  hay base válida, se prueba todo.
- **Bypass** (*bypass actors*): lista de actores (rol, equipo, App, usuario) que pueden saltarse un
  ruleset. En `tablero` está vacía: tampoco el admin se lo salta.

## C

- **`can_approve_pull_request_reviews`**: el ajuste "Allow GitHub Actions to create and approve
  pull requests" en la API. Deja que `GITHUB_TOKEN` cree y apruebe PR; la API lo describe como un
  riesgo. Vuelve a `false` en la org y en el repo esta semana.
- **Check obligatorio** (*required status check*): check que tiene que terminar en `success`,
  `skipped` o `neutral` sobre el commit para poder fusionar. En `tablero`, solo `ci-gate`.
- **`check_response_timeout_minutes`**: minutos que la cola espera a que un check obligatorio
  conteste antes de darlo por fallido y sacar el PR (1-360; 30 en `tablero`).
- **CODEOWNERS**: archivo que asigna dueños a rutas del repo. Se busca en `.github/`, la raíz y
  `docs/`, en ese orden; gana el último patrón que casa.
- **Conflicto semántico** (*semantic conflict*): dos cambios que se fusionan sin conflicto de
  texto pero juntos no funcionan. Es lo que la merge queue detecta y una rama al día no.
- **`create-github-app-token`**: action oficial (`actions/create-github-app-token`) que cambia la
  clave privada de una App por un token de instalación, con los permisos que pide el step, y lo
  revoca al terminar el job.

## D

- **`deletion`**: regla de ruleset que impide borrar la rama salvo a quien tenga bypass.
- **`~DEFAULT_BRANCH`**: valor de `conditions.ref_name.include` que apunta a la rama por defecto,
  sea cual sea su nombre.
- **Dueño de código** (*code owner*): usuario o equipo que CODEOWNERS asigna a una ruta. GitHub le
  pide revisión en cada PR que la toque y necesita permiso de escritura en el repo.

## E

- **`enforcement`**: estado de un ruleset: `active` (se aplica), `disabled` (no) o `evaluate`
  (solo registra; solo en Enterprise).
- **Expected**: lo que muestra un PR cuando un check obligatorio no ha llegado. Pasa si el
  workflow se saltó por un filtro `paths`, de ramas o por el mensaje del commit.

## G

- **GH013**: código de error con el que el servidor rechaza un push que viola las reglas de un
  ruleset (`Repository rule violations found`).
- **`gh-readonly-queue/<rama>/…`**: ramas temporales que crea la merge queue con cada grupo. Sus
  runs de `merge_group` las llevan como `headBranch`.
- **GitHub Actions (app, id 15368)**: la integración que emite los checks de los jobs de Actions.
  Es el `integration_id` de `ci-gate` en el ruleset.
- **Grupo de la cola** (*merge group*): los cambios de uno o más PR de la cola, aplicados sobre
  `main` y los grupos que van delante, que se prueban juntos.
- **`grouping_strategy`**: cómo decide la cola si un grupo pasa. `ALLGREEN`: cada grupo tiene que
  pasar sus checks. `HEADGREEN`: basta con el commit de cabeza del grupo.

## I

- **`integration_id`**: id de la App que tiene que emitir un check obligatorio. Sin él, cualquiera
  que pueda escribir estados de commit podría publicar un `ci-gate` verde.

## J

- **Job puerta** (*gate job*): un job que corre siempre (`if: always()`), depende de todos los
  demás y falla si alguno no terminó en `success` o `skipped`. En `tablero`, `ci-gate`.

## M

- **Merge queue** (cola de fusión): regla de ruleset que hace que los PR no se fusionen
  directamente, sino que entren en una cola que los prueba sobre el `main` real antes de fusionar.
- **`merge_group`**: evento con el que la cola pide los checks de un grupo (tipo
  `checks_requested`). Todo workflow de un check obligatorio tiene que escucharlo.
- **`merge_method`**: método con el que la cola fusiona, en mayúsculas (`MERGE`, `SQUASH`,
  `REBASE`), a diferencia de `allowed_merge_methods`.
- **Monorepo**: un repositorio con varias partes que se construyen y prueban por separado. El
  reto de CI es correr solo lo que cambia sin dejar checks pendientes.

## N

- **`non_fast_forward`**: regla de ruleset que impide el force push a la rama.

## P

- **`pull_request`** (regla): exige que todo cambio llegue por PR. Sus parámetros fijan
  aprobaciones, revisión de dueños, último push aprobado y hilos resueltos.

## R

- **`require_code_owner_review`**: parámetro de la regla `pull_request` que exige la aprobación de
  un dueño de código. Es configuración de equipo: trabajando solo no puedes aprobar tu propio PR.
- **`require_last_push_approval`**: exige que el último push lo apruebe alguien distinto de quien
  lo hizo.
- **Ruleset**: conjunto de reglas con nombre que se aplica a ramas o tags. Varios rulesets se
  suman y gana la versión más restrictiva de cada regla; cualquiera con lectura los ve.
- **Ruleset de organización**: ruleset definido en la org que aplica a varios repos. Pide GitHub
  Team o Enterprise; una org Free solo tiene rulesets de repositorio.
- **`rules/branches/{branch}`**: endpoint que devuelve las reglas activas sobre una rama, sumadas
  de todos los rulesets, con el `ruleset_id` de cada una.

## S

- **Saltado** (*skipped*): conclusión de un job cuyo `if:` dio `false`. Cuenta como éxito para un
  check obligatorio: por eso el check no puede ser un job de área.
- **`strict_required_status_checks_policy`**: exige que la rama del PR esté al día con la base
  antes de fusionar. Con la merge queue vale `false`: la cola ya prueba sobre el `main` real.

## T

- **Token de instalación** (*installation access token*): token de una GitHub App para los repos
  donde está instalada, con los permisos que se piden y una hora de vida como mucho. Firma como la
  App, así que sus PR disparan workflows con normalidad.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Índice del bootcamp](../../README.md) |
