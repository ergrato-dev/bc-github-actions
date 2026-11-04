# 📖 Glosario — Semana 12

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **Activo** (*asset*): lo que un atacante busca en un pipeline: el `GITHUB_TOKEN`, los
  secretos, la caché, los artefactos, el runner y las releases o imágenes que publicas.
- **Actor** (*actor*): quien puede influir en un run y qué controla: el autor de un PR desde un
  fork, un colaborador con escritura, un comentarista, una dependencia comprometida o el
  mantenedor de una action.
- **Aprobación de workflows de forks** (*fork pull request workflow approval*,
  `approval_policy`): ajuste del repo que hace esperar a un mantenedor antes de correr los
  workflows de un PR externo. Por defecto solo en la primera contribución; `tablero` usa
  `all_external_contributors`.
- **Artefacto envenenado** (*artifact poisoning*): artefacto que escribió un run de menos
  confianza (el código de un PR) y que un run con permisos descarga y usa como código o encima
  del workspace. Se evita con `runner.temp`, sin checkout y validando los datos.
- **Auditoría online** (*online audit*): auditoría de zizmor que consulta la API de GitHub, como
  `impostor-commit` o `known-vulnerable-actions`. Se activa sola si hay `GH_TOKEN` y se apaga con
  `--offline`.

## C

- **`cache-mode`**: clave de la raíz o de un job que decide si se restaura y se guarda caché:
  `read`, `write`, `write-only` o `none`. Por defecto `write` en triggers de confianza y `read` en
  los de baja confianza. actionlint 1.7.12 aún no la admite.
- **Caché envenenada** (*cache poisoning*): entrada de caché preparada por un run de baja
  confianza que restaura después un run de `main` con permisos de escritura o de publicación.
- **Code scanning**: pestaña **Security → Code scanning** donde se guardan las alertas de un
  analizador subidas como SARIF. Una alerta se abre en un commit y se cierra sola cuando un
  análisis posterior deja de verla.
- **CodeQL**: analizador de GitHub que, con el lenguaje `actions`, revisa workflows y `action.yml`
  siguiendo el flujo del dato entre steps. Corre en el workflow `codeql` con
  `security-events: write`.
- **Commit impostor** (*impostor commit*): commit que solo existe en un fork pero se resuelve
  como `owner/repo@<sha>` porque los forks comparten red de objetos. Lo detecta la auditoría
  `impostor-commit` de zizmor.
- **Cooldown**: días que Dependabot espera desde que se publica una versión antes de proponerla
  (`cooldown.default-days`). `tablero` usa 7; sin la clave, 3. Solo afecta a las version updates.

## D

- **Dependabot**: servicio de GitHub que abre PRs con actualizaciones de dependencias según
  `.github/dependabot.yml`. Entiende el pinning por SHA y reescribe el comentario del tag.
- **Disparador peligroso** (*dangerous trigger*, `dangerous-triggers`): auditoría de zizmor que
  marca todo `pull_request_target` y todo `workflow_run`, sin mirar si el uso es seguro.

## E

- **Excepción justificada**: comentario `# zizmor: ignore[<auditoría>] <motivo>` en la línea
  exacta del hallazgo, con una sola auditoría y un motivo que dice qué control lo hace seguro.
  `zizmor --no-ignores` enseña todo lo silenciado.

## F

- **Frontera de confianza** (*trust boundary*): punto donde algo que no controlas entra en un
  contexto con poder. En un workflow hay cuatro: el evento, el checkout, lo que se hereda entre
  runs y las referencias externas.

## G

- **`GITHUB_TOKEN Permissions`**: grupo del paso **Set up job** del log con los permisos que el
  job recibió de verdad, más `Secret source` y `Cache mode`.

## I

- **Inyección de scripts** (*script injection*): texto controlado por el atacante que, al
  expandirse un `${{ }}` dentro de `run:` o `script:` antes del shell, se ejecuta como código. Se
  evita pasando el dato por `env:` y usando `"$VAR"`.

## L

- **Lockfile de workflows** (*workflow lockfile*, `actions.lock`): archivo que registra por cada
  `uses:` el ref, el commit, el `owner_id` y el `repo_id`. Lo generan y verifican
  `gh actions-lock` y `gh actions-lock --verify`. No cubre reutilizables y está documentado para
  GitHub Enterprise Cloud.

## M

- **Modelo de amenazas** (*threat model*): descripción de qué actores pueden influir en el
  pipeline, a través de qué fronteras y hacia qué activos. Convierte cada hallazgo en una casilla.

## P

- **Permisos efectivos**: permisos que recibe un job tras aplicar, por orden, el default de la
  org, la raíz del workflow, el job, el techo del reutilizable y el recorte por fork.
- **Persona** (*persona*): nivel de ruido de zizmor: `regular` (por defecto), `pedantic` o
  `auditor`.
- **`pull_request_target`**: trigger que corre el workflow de la rama por defecto, con secretos y
  con la escritura que declares, aunque el PR venga de un fork. Solo para etiquetar o comentar,
  nunca para construir el PR.
- **Pwn request**: ataque en el que un `pull_request_target` hace checkout del head del PR y
  ejecuta su código con escritura y secretos.

## R

- **Recorte por fork**: en un evento de un PR desde un fork (salvo `pull_request_target`), todo
  `write` del token pasa a `read` y no hay secretos.

## S

- **SARIF** (*Static Analysis Results Interchange Format*): formato de resultados que CodeQL, y
  zizmor con `--format=sarif`, suben a code scanning.
- **Scope**: cada permiso del `GITHUB_TOKEN` (`contents`, `packages`, `pull-requests`…) con sus
  niveles `read`, `write` o `none`. En cuanto declaras uno, los demás pasan a `none`.
- **Security updates** y **version updates**: PRs de Dependabot que corrigen una vulnerabilidad
  conocida y PRs que suben a la última versión según `dependabot.yml`. El cooldown solo retrasa
  las segundas.
- **Suite de consultas** (*query suite*): conjunto de consultas que carga CodeQL. La de por
  defecto solo trae precisión `high` y `very-high`; `security-extended` añade, por ejemplo,
  `actions/code-injection/medium`.

## T

- **Techo de permisos**: los permisos del job que llama a un reutilizable son el máximo que
  pueden recibir sus jobs internos; pedir más es un error de validación. Con `cache-mode` pasa lo
  mismo.
- **Trigger de baja confianza** (*low-trust trigger*): evento que corre en el contexto de la rama
  por defecto pero puede provocarlo alguien de fuera, como `pull_request_target`,
  `issue_comment` o `workflow_run`. Solo lee la caché de la rama por defecto.

## W

- **`workflow_run`**: trigger que se dispara al terminar otro workflow, con secretos y escritura
  aunque el run anterior no los tuviera. `github.event.workflow_run.pull_requests` llega vacío en
  los PR de forks.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Índice del bootcamp](../../README.md) |
