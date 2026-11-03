# 🌐 Webgrafía — Semana 08

Documentación oficial y artículos de referencia. Las referencias son para consultar, no para leer de
corrido.

## Leer y depurar runs

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Using workflow run logs](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs) | Buscar en el log, ver el log en bruto y descargar el archivo de logs de un run | 2026-11-02 |
| [Enabling debug logging](https://docs.github.com/en/actions/how-tos/monitor-workflows/enable-debug-logging) | `ACTIONS_STEP_DEBUG` y `ACTIONS_RUNNER_DEBUG` como secreto o variable, y qué gana si existen los dos | 2026-11-02 |
| [Troubleshooting workflows](https://docs.github.com/en/actions/how-tos/troubleshoot-workflows) | El punto de entrada oficial para un run que falla, con enlaces a cada técnica | 2026-11-02 |
| [Re-running workflows and jobs](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs) | Reintentar todo, solo lo fallido o un job, con o sin depuración, y por qué usa el mismo commit | 2026-11-02 |
| [`gh run view`](https://cli.github.com/manual/gh_run_view) | `--log`, `--log-failed`, `--job` y `--attempt`, la base de la práctica 01 | 2026-11-02 |
| [`gh run rerun`](https://cli.github.com/manual/gh_run_rerun) | `--failed`, `--job` y `--debug` | 2026-11-02 |
| [REST API: Check runs](https://docs.github.com/en/rest/checks/runs) | El endpoint de anotaciones de un check run, para leerlas como datos | 2026-11-02 |
| [Contexts](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts) | `runner.debug`, para que un `if:` sepa si alguien pidió depuración | 2026-11-02 |
| [Variables reference](https://docs.github.com/en/actions/reference/workflows-and-actions/variables) | `RUNNER_DEBUG` y las variables `GITHUB_*` que también reconstruye act | 2026-11-02 |

## Comandos de workflow y problem matchers

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Workflow commands](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands) | `::error`, `::group`, `::add-mask`, `::stop-commands` y los archivos de entorno que sustituyen a `::set-output` | 2026-11-02 |
| [actions/toolkit: commands.md](https://github.com/actions/toolkit/blob/main/docs/commands.md) | Los mismos comandos vistos desde el toolkit de las actions JavaScript, con `core.debug()` y compañía | 2026-11-02 |
| [actions/toolkit: problem-matchers.md](https://github.com/actions/toolkit/blob/main/docs/problem-matchers.md) | El formato del JSON de un matcher: `owner`, `severity`, `pattern`, grupos y `loop`, y cómo retirarlo | 2026-11-02 |

## actionlint

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [actionlint: checks](https://github.com/rhysd/actionlint/blob/main/docs/checks.md) | Cada comprobación con un ejemplo y su salida. Úsalo cuando no entiendas un error | 2026-11-02 |
| [actionlint: usage](https://github.com/rhysd/actionlint/blob/main/docs/usage.md) | Opciones de la línea de comandos, `-color` y el uso en CI con el problem matcher | 2026-11-02 |
| [actionlint: install](https://github.com/rhysd/actionlint/blob/main/docs/install.md) | Las formas de instalarlo. Tú usas la del tarball de la release con checksum, nunca el script por `curl` | 2026-11-02 |
| [actionlint-matcher.json en v1.7.12](https://github.com/rhysd/actionlint/blob/v1.7.12/.github/actionlint-matcher.json) | El matcher oficial en el tag que fijas: el original contra el que haces `diff` | 2026-11-02 |
| [Release v1.7.12 de actionlint](https://github.com/rhysd/actionlint/releases/tag/v1.7.12) | Los binarios de la versión fijada, cuyo `digest` lees con `gh api` | 2026-11-02 |
| [REST API: Release assets](https://docs.github.com/en/rest/releases/assets) | El campo `digest` de cada archivo de una release, de donde sale el checksum | 2026-11-02 |

## zizmor

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [zizmor](https://docs.zizmor.sh/) | Qué es, cómo instalarlo y el resto de la documentación | 2026-11-02 |
| [zizmor: usage](https://docs.zizmor.sh/usage/) | Personas, `--offline`, formatos de salida, códigos de salida e ignorar hallazgos | 2026-11-02 |
| [zizmor: audits](https://docs.zizmor.sh/audits/) | Una sección por auditoría con el porqué y el arreglo; es el enlace que imprime cada hallazgo | 2026-11-02 |
| [zizmor: configuration](https://docs.zizmor.sh/configuration/) | El archivo `zizmor.yml` para ignorar hallazgos en varios archivos, con su motivo | 2026-11-02 |

## act

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [act user guide](https://nektosact.com/) | La guía oficial de act | 2026-11-02 |
| [act: installation](https://nektosact.com/installation/index.html) | Las formas de instalarlo; quédate con el binario de la release y su checksum | 2026-11-02 |
| [act: usage](https://nektosact.com/usage/index.html) | `-l`, `-j`, `-W`, `-e`, secretos, variables y eventos | 2026-11-02 |
| [act: runners](https://nektosact.com/usage/runners.html) | Cómo `-P` asigna una imagen a cada etiqueta de `runs-on` y por qué las imágenes son incompletas | 2026-11-02 |
| [act: not supported](https://nektosact.com/not_supported.html) | La lista oficial de lo que act no imita: tenla abierta antes de fiarte de un verde local | 2026-11-02 |
| [Release v0.2.94 de act](https://github.com/nektos/act/releases/tag/v0.2.94) | Los binarios de la versión fijada, con su `digest` | 2026-11-02 |
| [catthehacker/docker_images](https://github.com/catthehacker/docker_images) | Las imágenes de runner para act, sus tamaños y sus tags con fecha | 2026-11-02 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
