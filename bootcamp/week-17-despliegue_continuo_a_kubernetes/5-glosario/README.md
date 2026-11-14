# 📖 Glosario — Semana 17

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **`AuthenticationConfiguration`**: objeto `apiserver.config.k8s.io/v1` con el que el apiserver
  acepta tokens JWT de un emisor externo. El de `tablero` confía en
  `https://token.actions.githubusercontent.com` con audiencia `kind-gha`. Lo carga por el flag
  `--authentication-config` y lo recarga solo al cambiar el archivo.
- **Audiencia propia** (*audience*): el `aud` que el job pide para su token OIDC y el apiserver
  exige. `kind-gha` evita que un token pedido para otro consumidor valga en el clúster.

## C

- **CA del clúster** (*cluster CA*): certificado con el que Helm comprueba que habla con el
  apiserver de verdad. Es público: sirve para verificar al servidor, no para presentarse ante él.
- **CEL** (*Common Expression Language*): lenguaje de expresiones pequeño, sin bucles ni efectos,
  que Kubernetes usa para reglas declarativas. En `authentication-config.yaml`, `claims` es el
  payload del token.
- **`claimMappings`**: parte de `AuthenticationConfiguration` que calcula el usuario de Kubernetes a
  partir de los claims. `tablero` usa `'github:' + claims.environment`.
- **`claimValidationRules`**: expresiones CEL que tienen que dar `true` para aceptar un token, cada
  una con su `message`. Las de `tablero` comprueban `repository_id`, `ref`, `job_workflow_ref` y
  `environment`.
- **client-go**: librería cliente de Kubernetes que llevan Helm y `kubectl`. Ejecuta el plugin
  `exec`, guarda el token en memoria y vuelve a llamarlo cuando caduca.

## D

- **`--deny-self-hosted-runners`**: opción de `gh attestation verify` que rechaza una imagen
  construida en un runner propio, aunque la firme el workflow esperado.
- **Deployment de GitHub** (*deployment*): registro que crea un job con `environment:`, con el
  commit, el environment y una serie de estados (`in_progress`, `success`, `failure`...). Se ve en
  la portada del repo, en la página de environments y en `repos/{owner}/{repo}/deployments`.
- **Deployment de Kubernetes**: objeto que declara qué pods quieres (imagen, réplicas, probes) y
  cómo pasar de una versión a otra. Crea un ReplicaSet por versión.
- **Despliegue continuo** (*continuous deployment*): cada cambio que pasa las puertas se despliega
  sin que una persona ejecute nada. En `tablero`, desde esta semana: la release lanza
  `deploy.yml`.

## E

- **Entrega continua** (*continuous delivery*): cada cambio en `main` **podría** desplegarse, pero
  una persona decide cuándo. Las dos se abrevian CD.
- **`ExecCredential`**: objeto JSON `client.authentication.k8s.io/v1` que un plugin `exec`
  imprime: `status.token` y `status.expirationTimestamp`.
- **`expirationTimestamp`**: caducidad que el plugin declara. `github-token.sh` la pone a 4
  minutos, uno antes de que caduque de verdad el token de GitHub.

## H

- **`helm.sh/resource-policy: keep`**: anotación que impide a Helm borrar un objeto aunque una
  revisión ya no lo incluya o desinstales la release. La lleva el PVC `db-data`.
- **Historial de Helm** (*history*): lista de revisiones de una release con su estado y su
  descripción (`helm history`). Guarda 10 por defecto (`--history-max`).

## J

- **`job_workflow_ref`**: claim del token OIDC con el archivo de workflow y la ref donde corrió el
  job: `<tu-org>/tablero/.github/workflows/deploy.yml@refs/heads/main`.

## K

- **`kube-root-ca.crt`**: ConfigMap que Kubernetes publica en cada namespace con el CA del
  clúster. El runner lo monta en `/etc/kube-ca` sin necesitar token de ServiceAccount.
- **Kubeconfig**: archivo que dice a Helm y `kubectl` a qué servidor hablar, con qué CA y con qué
  credencial. El de `ops/deploy/kubeconfig.yaml` no lleva ninguna: la pide el plugin `exec`.

## N

- **Namespace**: espacio con nombre dentro del clúster donde viven los objetos. `tablero` tiene
  uno por environment, y es la frontera de los Roles y de Pod Security.

## P

- **Plugin `exec`** (*exec credential plugin*): programa que client-go ejecuta para obtener una
  credencial. `github-token.sh` es uno, como `aws eks get-token` o `gke-gcloud-auth-plugin`.
- **Pod Security Admission**: controlador de admisión de Kubernetes que aplica los Pod Security
  Standards según una etiqueta del namespace, en modo `enforce`, `audit` o `warn`.
- **Pod Security `restricted`**: el nivel más estricto de los Pod Security Standards. Exige
  `allowPrivilegeEscalation: false`, `drop: [ALL]`, `runAsNonRoot: true` y
  `seccompProfile: RuntimeDefault`. Con `enforce`, un pod que no lo cumple no se crea.
- **Promoción** (*promotion*): mover el mismo artefacto, identificado por su digest, de un
  entorno al siguiente en lugar de reconstruirlo o volver a resolver su tag.
- **PVC** (*PersistentVolumeClaim*): petición de almacenamiento que sobrevive a los pods. La de
  PostgreSQL guarda los datos y la contraseña con la que se inicializó la base.

## R

- **Readiness** (*readiness probe*): comprobación que dice cuándo un pod puede recibir tráfico.
  Mientras no está Ready, el Service no le manda peticiones y el rollout no avanza.
- **Release de Helm**: una instalación con nombre de un chart en un namespace (`tablero` en
  `tablero-staging`). No es la release de GitHub.
- **ReplicaSet**: objeto que mantiene un número de pods iguales. El Deployment crea uno nuevo en
  cada versión y apaga el anterior.
- **`repository_id`**: claim con el id numérico del repo, que no se reutiliza aunque borres o
  renombres el repo. En el token de GitHub va como texto.
- **Revisión de Helm** (*revision*): cada `install`, `upgrade` o `rollback` de una release crea
  una revisión numerada con su estado: `deployed`, `superseded` o `failed`.
- **Role / RoleBinding**: permisos de RBAC dentro de un namespace y su asignación a un sujeto.
  `tablero` da un Role `deployer` al usuario `github:<environment>` en su propio namespace.
- **Rollback de Helm**: nueva revisión con los objetos de una anterior (`helm rollback`). No
  deshace migraciones ni datos escritos.
- **`--rollback-on-failure`**: opción de Helm 4 (antes `--atomic`) que vuelve a la última revisión
  buena si el upgrade no queda listo en `--timeout`. En el primer install, desinstala.
- **Rollout**: paso de los pods de una versión a la siguiente que hace un Deployment.
  `kubectl rollout status` lo sigue.
- **`run-name`**: título de cada run de un workflow. Con `deploy ${{ inputs.version }}`, la lista
  de runs es el historial de despliegues.

## S

- **Service**: nombre y dirección estables delante de un grupo de pods, con DNS dentro del
  clúster: `web.tablero-staging.svc.cluster.local`.
- **Smoke test**: prueba mínima tras desplegar que comprueba que la app responde de punta a
  punta. Si falla, `deploy.yml` hace `helm rollback`.

## U

- **Usuario de Kubernetes** (*user*): nombre que el apiserver asigna a quien presenta una
  credencial válida. No es un objeto: `github:staging` existe mientras alguien presente un token
  que se mapee a ese nombre.

## W

- **`--wait`** en Helm 4: estrategia de espera. `hookOnly` (sin el flag) solo espera a los
  hooks; `watcher` espera a que los recursos estén listos; `legacy` imita a Helm 3.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Semana 18 — Merge queue, rulesets y monorepos](../../week-18-merge_queue_rulesets_y_monorepos/README.md) |
