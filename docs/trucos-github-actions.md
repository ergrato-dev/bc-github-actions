# 🎩 Trucos de GitHub Actions

Los trucos de la sección `## 🎩 Trucos y atajos` de cada semana, reunidos en un solo sitio para
buscarlos sin saber en qué semana aparecieron. Cada semana añade aquí los suyos al publicarse.

## Semana 01 — [Primer workflow y modelo de ejecución](../bootcamp/week-01-primer_workflow_y_modelo_de_ejecucion/README.md)

- **`gh run watch <id> --exit-status`** sale con error si el run falla. Encadenado
  (`gh run watch "$id" --exit-status && git push origin HEAD:release`) convierte la terminal en una
  puerta: lo siguiente solo ocurre si el CI está en verde.
- **El run de tu commit, no "el último"**: `gh run list --commit "$(git rev-parse HEAD)"` filtra por
  SHA. Con dos pushes seguidos, "el último run" puede ser el del commit anterior.
- **`gh run view <id> --log-failed`** imprime solo los steps que fallaron, con su prefijo de job y
  step. En un log de 3.000 líneas es la diferencia entre leer y buscar.
- **`gh run rerun <id> --debug`** relanza con los logs de depuración del runner activados, sin
  crear los secretos `ACTIONS_STEP_DEBUG` ni `ACTIONS_RUNNER_DEBUG` y solo para ese intento.
- **`gh api repos/{owner}/{repo}/actions/permissions`** te enseña de un vistazo si Actions está
  activado, qué actions se permiten y si se exige SHA (`sha_pinning_required`), tres ajustes que en
  la UI están repartidos por la página de Settings.

## Semana 02 — [Expresiones, contextos y flujo de datos](../bootcamp/week-02-expresiones_contextos_y_flujo_de_datos/README.md)

- **actionlint comprueba los tipos de tus expresiones**: si escribes `steps.compute.outputs.version`
  y el step se llama `comptue`, o `needs.aa` con un job `a`, te lo dice con línea y columna antes
  del push. Es el error más común de esta semana y el más caro de encontrar en un run.
- **`toJSON(needs)` por `env:` y `jq`** te da el resultado de todos los jobs anteriores en un solo
  valor: `jq -r 'to_entries[] | "\(.key) \(.value.result)"' <<<"$RESULTS"`. Añades un job a
  `needs:` y el resumen lo incluye sin tocar el script.
- **yq ya viene en el runner y lee TOML por la extensión**: `yq -oy '.project.version'
  api/pyproject.toml` saca la versión sin instalar nada ni escribir un parser con `grep` y `sed`.
- **`gh variable set -f vars.env`** carga de una vez todas las variables de configuración de un
  archivo dotenv. Con `gh variable list` compruebas qué hay sin abrir Settings.
- **`${GITHUB_SHA::7}`** es una expansión de bash, no una expresión de GitHub: el SHA corto sale
  del shell, que es donde tiene que estar un dato que vas a escribir en `$GITHUB_OUTPUT`.

## Semana 03 — [CI de Python con uv](../bootcamp/week-03-ci_de_python_con_uv/README.md)

- **`uv lock --check` antes del push** da en un segundo el mismo error que `uv sync --locked` te
  daría en el CI tras arrancar un runner. Es el fallo más frecuente de esta semana.
- **`gh cache list --sort size_in_bytes`** te dice qué cachés ocupan tu cupo de 10 GB, y
  `gh cache list --key setup-uv-` filtra las de uv. En la UI tienes que ir a Actions → Caches y
  ordenar a mano.
- **`ruff check --output-format=github`** convierte cada hallazgo en una anotación en la pestaña
  *Files changed* del pull request, en la línea exacta. Sin ese flag, el error solo está en el log.
- **El output `cache-hit` de setup-uv** (`steps.<id>.outputs.cache-hit`) te dice en un step
  siguiente si la caché acertó, sin leer el log de restauración.
- **`uv tree --depth 1`** muestra las dependencias directas con su versión resuelta y su grupo
  (`dev` o no). Es la forma rápida de ver qué cambió en un pull request que toca `uv.lock`.

## Semana 04 — [CI de frontend con pnpm, matrices y artefactos](../bootcamp/week-04-ci_de_frontend_pnpm_matrices_y_artefactos/README.md)

- **`gh run download <id> -n web-dist`** baja un artefacto concreto de un run a tu máquina, ya
  descomprimido. Es la forma más rápida de comprobar qué construyó el CI exactamente.
- **El orden importa: `pnpm/action-setup` antes que `actions/setup-node`.** Con `cache: pnpm`,
  setup-node le pregunta a pnpm dónde está su store; si pnpm aún no existe, el step falla.
- **`name: Tests (Node ${{ matrix.node }})`** pone la versión en el nombre de cada job de la
  matriz. Sin eso, la UI y los checks requeridos muestran `test (24)` y `test (26)`, y cambiar la
  matriz rompe los nombres que las reglas de rama esperan (Semana 18).
- **`pnpm why <paquete>`** te dice qué dependencia trajo un paquete transitivo; es la pregunta que
  te harás cuando un PR de Dependabot toque `pnpm-lock.yaml`.
- **La caducidad de un artefacto se elige al subirlo** (`retention-days`), no después: lo que no
  pongas toma el valor del repo, 90 días por defecto en uno público, y ocupa almacenamiento todo ese
  tiempo.

## Semana 05 — [Service containers y PostgreSQL](../bootcamp/week-05-service_containers_y_postgresql/README.md)

- **`docker logs "$POSTGRES_CONTAINER"`**, con `POSTGRES_CONTAINER: ${{ job.services.postgres.id }}`
  en el `env:` del step y `if: failure()`, pone el log de la base justo debajo del step que falló.
  El runner también lo imprime en *Stop containers*, pero al final del job, lejos del error.
- **`pytest -rs`** lista los tests saltados con su motivo. Los de integración de `tablero` se
  saltan si falta `DATABASE_URL`: `pytest tests/integration` sale entonces con código 5 y
  `1 skipped`, pero un `pytest` sobre todo el proyecto sale en verde sin que nada lo avise.
- **`docker compose up --wait` ya espera y ya falla**: sale con error si un servicio no llega a
  `healthy`. Un bucle de `sleep` y `curl` delante del smoke test sobra.
- **`COMPOSE_PROJECT_NAME`** en el `env:` del job da a la pila un nombre propio. Así `down` borra
  solo lo que levantó ese job, también en un runner propio compartido (Semana 15).
- **`healthy` no es `migrado`**: `pg_isready` dice que PostgreSQL acepta conexiones, no que tu
  esquema exista. Las migraciones son un step aparte, antes de los tests.

## Semana 06 — [Imágenes Docker y GHCR](../bootcamp/week-06-imagenes_docker_y_ghcr/README.md)

- **`docker buildx imagetools inspect ghcr.io/<tu-org>/tablero-api:main`** enseña el índice y sus
  manifiestos sin descargar ni una capa. Ahí ves que la entrada `unknown/unknown` que muestra la UI
  de GHCR no es una plataforma rota: es el manifiesto de la attestation de procedencia.
- **El resumen de build de `build-push-action`** aparece solo en el resumen del run, con la
  duración, las capas cacheadas y un artefacto `.dockerbuild` que abre Docker Desktop. Si no lo
  quieres, `DOCKER_BUILD_SUMMARY: false` en el `env:` del step.
- **`gh api /orgs/<tu-org>/packages/container/tablero-api/versions --jq '.[0].metadata.container.tags'`**
  lista las etiquetas de la última versión publicada. Necesita el scope `read:packages`:
  `gh auth refresh -s read:packages`.
- **El digest también vale en local**: `docker buildx build --metadata-file meta.json` y
  `jq -r '."containerimage.digest"' meta.json` te dan lo mismo que el output `digest` de la action.
- **`mode=max` frente a `mode=min`**: el modo por defecto solo cachea las capas de la imagen final.
  En un multi-stage eso deja fuera el `uv sync` y el `pnpm install` de la etapa de build, que son
  justo las capas que más tardan.

## Semana 07 — [Disparadores, filtros y concurrencia](../bootcamp/week-07-disparadores_filtros_y_concurrencia/README.md)

- **`gh workflow run nightly.yml -f target=ci-web --ref main`** lanza un `workflow_dispatch` con
  sus inputs sin abrir la UI. Con `--json` lee los inputs de la entrada estándar:
  `echo '{"target":"smoke"}' | gh workflow run nightly.yml --json`.
- **`gh run list --event schedule --workflow nightly.yml`** filtra los runs por evento. Es la forma
  rápida de saber si tu cron se ha ejecutado de verdad, y a qué hora, sin bucear en la UI.
- **`gh api repos/{owner}/{repo}/dispatches -f event_type=tablero-ping -F 'client_payload[from]=cli'`**
  dispara un `repository_dispatch` desde tu terminal. `-F` con corchetes construye el objeto
  anidado sin escribir JSON a mano.
- **Un run cancelado por `concurrency` dice por qué**: en sus anotaciones aparece *Canceling since
  a higher priority waiting request for '<grupo>' exists*. Con `gh run view <id> --json jobs --jq
  '.jobs[].conclusion'` ves `cancelled` sin abrir el log.
- **El minuto 0 está saturado**: los cron en punto se retrasan más porque media plataforma programa
  ahí. Un minuto raro (`17 3 * * *`) llega antes y no compite.
- **`gh workflow disable` / `enable`** apagan un workflow sin borrar el archivo. Útil para parar un
  cron mientras investigas por qué falla cada noche.

## Semana 08 — [Probar y depurar workflows](../bootcamp/week-08-probar_y_depurar_workflows/README.md)

- **`gh run view <id> --log-failed`** imprime solo el log de los steps que fallaron. Con
  `gh run view <id> --log | grep -n 'error'` buscas en todo el run sin abrir el navegador.
- **`gh run rerun <id> --failed --debug`** relanza solo los jobs fallidos con los logs de
  depuración activados para ese intento, sin crear ningún secreto ni variable.
- **`act -l`** lista jobs, etapas y eventos de todos tus workflows en un segundo, sin crear
  ningún contenedor: es la forma rápida de ver el grafo de `needs:`.
- **`zizmor --persona=pedantic`** enseña lo que el modo normal suprime (en `tablero`,
  `undocumented-permissions` y la imagen de PostgreSQL sin digest). Útil para revisar, no para
  la puerta del CI.
- **`echo "::remove-matcher owner=actionlint::"`** desactiva un problem matcher a mitad de job:
  así las líneas de otra herramienta con el mismo formato no se convierten en anotaciones falsas.
- **Las anotaciones viven en la API**: `gh api repos/{owner}/{repo}/check-runs/<job-id>/annotations`
  te las da en JSON, con archivo y línea, para un informe o un script.

## Semana 09 — [Workflows reutilizables](../bootcamp/week-09-workflows_reutilizables/README.md)

- **`gh run view <id> --json jobs --jq '.jobs[].name'`** enseña los jobs de un reutilizable con
  su prefijo, `API / Tests unitarios`: así filtras con `grep 'API /'` lo que vino de una llamada
  concreta.
- **`actionlint` valida la llamada local**: si pasas un input que `_python.yml` no declara, u
  olvidas uno obligatorio, falla antes del push. Con una referencia remota (`owner/repo/...@sha`)
  no puede leer el reutilizable y esa comprobación se pierde.
- **`act` ejecuta los reutilizables locales**: `scripts/ci-local.sh ci-api api` corre los tres
  jobs de `_python.yml` en tu Docker y los nombra `API/_python/<job>`.
- **Un input `string` con JSON** es la forma de pasar listas: `node-versions: "[24, 26]"` y, dentro,
  `${{ fromJSON(inputs.node-versions) }}`. `workflow_call` no tiene tipo lista.
- **`zizmor` caza `secrets: inherit`** con la auditoría `secrets-inherit`, sin red y con la
  persona por defecto: la puerta de la Semana 08 ya lo bloquea.

## Semana 10 — [Actions propias: composite, JavaScript y Docker](../bootcamp/week-10-actions_propias/README.md)

- **Lee los inputs reales de cualquier action en su SHA**:
  `gh api 'repos/actions/setup-node/contents/action.yml?ref=<sha>' --jq .content | base64 -d | yq '.inputs | keys'`.
  Es la única fuente fiable: el README puede ir por delante o por detrás del SHA que fijas.
- **actionlint no valida un `action.yml`, pero sí la llamada**: si un workflow pasa `stak:` a
  `./.github/actions/setup-tablero`, avisa con `input "stak" is not defined in action`. El
  `action.yml` en sí lo revisa zizmor (`zizmor --offline .github/`).
- **Un input con guion en una action Docker** llega como `INPUT_EXCLUDE-RULES`, que bash no puede
  leer con `$`: usa `printenv 'INPUT_EXCLUDE-RULES'`, o nombra los inputs con guion bajo.
- **`git diff --exit-code -- dist`** tras `pnpm build` convierte "se me olvidó reconstruir" en un
  job rojo con la ruta exacta del archivo desfasado.
- **Un `%` en un mensaje de `core.setFailed` sale como `%25`** en el log crudo: los comandos de
  workflow codifican `%`, `\r` y `\n`. Si buscas el texto con `grep` en `gh run view --log`,
  busca la forma codificada.

## Semana 11 — [Actions a escala de organización](../bootcamp/week-11-actions_a_escala_de_organizacion/README.md)

- **Comprueba que un SHA fijado es el del tag que dice el comentario**:
  `gh api repos/<tu-org>/actions-tablero/commits/v1.0.0 --jq .sha`. `commits/<tag>` resuelve tags
  ligeros y anotados al commit, sin que tengas que distinguirlos.
- **Lee un archivo de otro repo sin clonarlo ni pasar por base64**:
  `gh api 'repos/<tu-org>/.github/contents/workflow-templates/ci-python.yml' -H 'Accept: application/vnd.github.raw'`.
  Añade `?ref=v1.0.0` a la ruta para leerlo en un tag.
- **`gh release verify v1.0.0 -R <tu-org>/actions-tablero`** comprueba la attestation que GitHub
  firma al publicar una release inmutable: te dice a qué commit resolvió el tag y el digest de cada
  asset.
- **`{owner}` funciona también en rutas de organización**: con `GH_REPO` exportado,
  `gh api orgs/{owner}/actions/permissions` lee la política de tu org sin escribir su nombre.
- **Un reutilizable puede decir qué versión de sí mismo está corriendo**: `job.workflow_sha` y
  `job.workflow_repository` apuntan al archivo del reutilizable, mientras que `github.sha` y
  `github.workflow_sha` siguen siendo los del llamador.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Modelo de costes](modelo-de-costes.md) | [Glosario del bootcamp](glosario.md) |
