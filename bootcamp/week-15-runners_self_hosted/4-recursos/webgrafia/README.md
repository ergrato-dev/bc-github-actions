# 🌐 Webgrafía — Semana 15

Documentación oficial primero, luego los informes de ataques reales que explican por qué la semana
insiste tanto en JIT, contenedores desechables y aprobación de forks. La documentación de GitHub
cambia de ruta a menudo: si un enlace falla, busca el título en docs.github.com.

### GitHub: runners propios

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Self-hosted runners](https://docs.github.com/en/actions/concepts/runners/self-hosted-runners) | El concepto: qué gestionas tú, qué gestiona GitHub y por qué solo se recomiendan en repos privados (teoría 01) | 2026-11-13 |
| [Self-hosted runners reference](https://docs.github.com/en/actions/reference/runners/self-hosted-runners) | Los límites de la semana: cola de 24 horas, plazo de 63 días para actualizar, borrado a los 14 días o al día si es efímero | 2026-11-13 |
| [Adding self-hosted runners](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners) | El registro a mano con `config.sh` y token de registro que haces una sola vez en la práctica 01 | 2026-11-13 |
| [Using self-hosted runners in a workflow](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/use-in-a-workflow) | Cómo casa `runs-on` con las etiquetas, las etiquetas por defecto y la forma con `group` (teoría 03) | 2026-11-13 |
| [Managing access to self-hosted runners using groups](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/manage-access) | Grupos, repos públicos y `selected_workflows`: lo que harías con un plan Team (teoría 06) | 2026-11-13 |
| [Runner groups](https://docs.github.com/en/actions/concepts/runners/runner-groups) | Qué es el grupo por defecto y qué controla un grupo, antes de leer la guía anterior | 2026-11-13 |
| [Removing self-hosted runners](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/remove-runners) | Las formas de dar de baja un runner, incluida la que usas al parar el bucle | 2026-11-13 |
| [Monitoring and troubleshooting self-hosted runners](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/monitor-and-troubleshoot) | Los logs de `_diag`, el estado del runner y qué mirar cuando un job no arranca | 2026-11-13 |
| [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use) | La sección de runners propios: repos públicos, JIT y por qué reutilizar la máquina expone información (teorías 04 y 07) | 2026-11-13 |
| [Approving workflow runs from forks](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/approve-runs-from-forks) | Qué revisar antes de aprobar el workflow de un PR de fork, la capa que cierra la puerta en un repo público | 2026-11-13 |

### GitHub: API

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [REST API: Self-hosted runners](https://docs.github.com/en/rest/actions/self-hosted-runners) | `generate-jitconfig`, `registration-token`, la lista de runners y el `DELETE`: todas las llamadas de `jit-runner.sh` y de las prácticas | 2026-11-13 |
| [REST API: Self-hosted runner groups](https://docs.github.com/en/rest/actions/self-hosted-runner-groups) | `visibility`, `allows_public_repositories` y `selected_workflows`, campo por campo | 2026-11-13 |
| [REST API: GitHub Actions permissions](https://docs.github.com/en/rest/actions/permissions) | La política `self-hosted-runners` de la org y la aprobación de PR de forks del repo, las dos que comprueba el autograding | 2026-11-13 |

### El runner y su imagen

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [actions/runner releases](https://github.com/actions/runner/releases) | Cada versión nueva del runner: el reloj de los 63 días empieza aquí, y Dependabot te la trae como PR | 2026-11-13 |
| [Paquete actions-runner en GHCR](https://github.com/actions/runner/pkgs/container/actions-runner) | Los tags de la imagen oficial de la que parte `ops/runner/Dockerfile` | 2026-11-13 |

### Docker

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Docker Engine security](https://docs.docker.com/engine/security/) | La sección del demonio explica por qué dar acceso al socket es dar root en el host (teoría 05) | 2026-11-13 |
| [Running containers](https://docs.docker.com/engine/containers/run/) | Privilegios en tiempo de ejecución, `--cap-drop` y `--security-opt`: las opciones de la práctica 03 | 2026-11-13 |
| [docker container run](https://docs.docker.com/reference/cli/docker/container/run/) | La referencia de cada flag de `jit-runner.sh`: `--rm`, `--pids-limit`, `--memory`, `--cpus` | 2026-11-13 |
| [Resource constraints](https://docs.docker.com/engine/containers/resource_constraints/) | Qué pasa cuando un job llega al techo de memoria o CPU, para elegir límites con sentido | 2026-11-13 |
| [Rootless mode](https://docs.docker.com/engine/security/rootless/) | Un paso más allá de la semana: un demonio que no es root, para reducir lo que vale el socket si alguna vez se filtra | 2026-11-13 |

### Ataques reales

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Self-Hosted GitHub Runners Are Backdoors](https://www.praetorian.com/blog/self-hosted-github-runners-are-backdoors/) — Praetorian | Cómo un runner persistente en un repo público se convierte en un acceso permanente a la red de la víctima | 2026-11-13 |
| [Playing with Fire: How We Executed a Critical Supply Chain Attack on PyTorch](https://johnstawinski.com/2024/01/11/playing-with-fire-how-we-executed-a-critical-supply-chain-attack-on-pytorch/) — John Stawinski | El caso completo: un PR de fork, un runner propio sin aprobación y lo que se puede robar desde él | 2026-11-13 |
| [One Supply Chain Attack to Rule Them All](https://adnanthekhan.com/2023/12/20/one-supply-chain-attack-to-rule-them-all/) — Adnan Khan | El mismo patrón contra los runners de la propia imagen de GitHub: por qué `first_time_contributors` no basta | 2026-11-13 |

### Siguiente paso

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Actions Runner Controller](https://docs.github.com/en/actions/concepts/runners/actions-runner-controller) | Lo que hace `jit-runner.sh` a mano, hecho por un controlador en Kubernetes: la Semana 16 | 2026-11-13 |
| [actionlint: configuration](https://github.com/rhysd/actionlint/blob/main/docs/config.md) | El formato de `.github/actionlint.yaml` y su clave `self-hosted-runner` | 2026-11-13 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
