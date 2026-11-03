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

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Modelo de costes](modelo-de-costes.md) | [Glosario del bootcamp](glosario.md) |
