# 🌐 Webgrafía — Semana 17

Documentación oficial primero: GitHub para environments, deployments y OIDC; luego Kubernetes,
Helm y kind para lo que la semana enseña "lo justo". La documentación de GitHub cambia de ruta a
menudo: si un enlace falla, busca el título en docs.github.com.

### GitHub: environments, deployments y disparadores

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Deployments and environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments) | La referencia de las reglas de protección, los secretos de environment y el deployment que crea cada job con `environment:` (teoría 01) | 2026-11-14 |
| [Managing environments for deployment](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments) | Cómo configurar revisores obligatorios y ramas permitidas, lo que el primer criterio de calidad te pide comprobar con la API | 2026-11-14 |
| [REST API endpoints for deployments](https://docs.github.com/en/rest/deployments/deployments) | El listado por `environment` y `sha` que usan la práctica 04 y el check `deploy-green-for-release` | 2026-11-14 |
| [REST API endpoints for deployment statuses](https://docs.github.com/en/rest/deployments/statuses) | Los estados de un deployment y cuál es el último: el `success` que lee la comprobación | 2026-11-14 |
| [REST API endpoints for workflow runs](https://docs.github.com/en/rest/actions/workflow-runs) | `pending_deployments` para aprobar desde la terminal y `approvals` para leer quién aprobó y con qué comentario | 2026-11-14 |
| [Manually running a workflow](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow) | `workflow_dispatch` con inputs, desde la UI y desde `gh`: el único disparador de `deploy.yml` | 2026-11-14 |
| [GITHUB_TOKEN](https://docs.github.com/en/actions/concepts/security/github_token) | Por qué los eventos que provoca `GITHUB_TOKEN` no disparan workflows, salvo `workflow_dispatch` y `repository_dispatch` | 2026-11-14 |
| [Concurrency](https://docs.github.com/en/actions/concepts/workflows-and-actions/concurrency) | Grupos, el único pendiente por grupo y `cancel-in-progress`: el fondo de la teoría 07 | 2026-11-14 |
| [Control the concurrency of workflows and jobs](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency) | La sintaxis de `concurrency` a nivel de job, que es donde la pone `deploy.yml` | 2026-11-14 |
| [OpenID Connect](https://docs.github.com/en/actions/concepts/security/openid-connect) | Cómo un job consigue un token firmado por GitHub y por qué la confianza la decide el consumidor, aquí el apiserver | 2026-11-14 |
| [OpenID Connect reference](https://docs.github.com/en/actions/reference/security/oidc) | Cada claim del token: `repository_id`, `ref`, `job_workflow_ref` y `environment`, los cuatro que comprueban tus reglas CEL | 2026-11-14 |
| [gh attestation verify](https://cli.github.com/manual/gh_attestation_verify) | Las opciones de `verify`: `--signer-workflow`, `--deny-self-hosted-runners` y `--format json` | 2026-11-14 |
| [gh workflow run](https://cli.github.com/manual/gh_workflow_run) | `--ref` y `-f`, las dos piezas del job `deploy` de `release.yml` | 2026-11-14 |

### Kubernetes: autenticación, RBAC y Pod Security

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Authenticating](https://kubernetes.io/docs/reference/access-authn-authz/authentication/) | La configuración estructurada con `claimValidationRules` y `claimMappings`, y los plugins de credenciales de client-go que usa `github-token.sh` (teorías 04 y 06) | 2026-11-14 |
| [kube-apiserver Configuration (v1)](https://kubernetes.io/docs/reference/config-api/apiserver-config.v1/) | La referencia campo a campo de `AuthenticationConfiguration` `apiserver.config.k8s.io/v1` | 2026-11-14 |
| [Common Expression Language in Kubernetes](https://kubernetes.io/docs/reference/using-api/cel/) | Qué es CEL en Kubernetes, qué puede y qué no puede hacer una expresión | 2026-11-14 |
| [CEL](https://cel.dev/) | El sitio del lenguaje: sintaxis de `has()`, `in` y la concatenación de cadenas de tus reglas | 2026-11-14 |
| [Authorization](https://kubernetes.io/docs/reference/access-authn-authz/authorization/) | Dónde entra RBAC después de autenticar, y cómo funciona `kubectl auth can-i` | 2026-11-14 |
| [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) | `Role`, `RoleBinding`, sus diferencias con los de clúster y los sujetos de tipo `User` (teoría 05) | 2026-11-14 |
| [Role Based Access Control Good Practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/) | Por qué ni comodines ni `secrets` de más ni permisos de clúster: los riesgos que evitan los Roles de `tablero` | 2026-11-14 |
| [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) | Lo que exige `restricted`, control a control, comparado con `baseline` y `privileged` | 2026-11-14 |
| [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/) | Las etiquetas del namespace y los modos `enforce`, `audit` y `warn` | 2026-11-14 |
| [Accessing the Kubernetes API from a Pod](https://kubernetes.io/docs/tasks/run-application/access-api-from-pod/) | `kubernetes.default.svc` y el `ca.crt`: lo que el runner usa sin el token de ServiceAccount (teoría 06) | 2026-11-14 |
| [aws eks get-token](https://docs.aws.amazon.com/cli/latest/reference/eks/get-token.html) | El plugin `exec` de una nube que `github-token.sh` imita: identidad del momento convertida en token para el clúster | 2026-11-14 |

### Kubernetes: lo que despliega el chart

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) | Rollout, ReplicaSets y `strategy`, incluido el `Recreate` del Deployment `db` (teoría 02) | 2026-11-14 |
| [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/) | Las readiness probes de `db`, `api` y `web`, que deciden cuándo Helm da el despliegue por bueno | 2026-11-14 |
| [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) | Por qué el smoke test llega a `web.<namespace>.svc.cluster.local` desde el pod del runner | 2026-11-14 |
| [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) | Qué protege de verdad un Secret, y por qué el `Role` que puede leerlos se limita a un namespace | 2026-11-14 |

### Helm y kind

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [helm upgrade](https://helm.sh/docs/helm/helm_upgrade/) | `--install`, `--rollback-on-failure`, `--wait`, `--timeout`, `--description` y `--set-string`, todos los que usa `deploy.yml` | 2026-11-14 |
| [helm rollback](https://helm.sh/docs/helm/helm_rollback/) | Volver a la revisión anterior o a una concreta: el step tras el smoke test y la práctica 02 paso 5 | 2026-11-14 |
| [helm history](https://helm.sh/docs/helm/helm_history/) | El historial de revisiones con su estado y descripción, la base del check `rollback-drill` | 2026-11-14 |
| [Installing Helm](https://helm.sh/docs/intro/install/) | Los binarios de la release y su checksum, la forma que `deploy.yml` usa en vez de `curl \| bash` | 2026-11-14 |
| [Chart Development Tips and Tricks](https://helm.sh/docs/howto/charts_tips_and_tricks/) | `helm.sh/resource-policy: keep` y `required`, las dos defensas del chart de `tablero` (teoría 03) | 2026-11-14 |
| [kind: Configuration](https://kind.sigs.k8s.io/docs/user/configuration/) | `extraMounts` y `kubeadmConfigPatches`, con los que `lab/kind-config.yaml` pasa la configuración OIDC al apiserver | 2026-11-14 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
