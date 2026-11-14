# Helm, lo justo

> ARC son decenas de objetos de Kubernetes. Helm los empaqueta en un chart, los rellena con tus
> values y los instala como una release que puedes repetir, inspeccionar y borrar de una vez.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Distinguir chart, values y release, y decir qué pones tú en cada uno
- Instalar un chart desde un registro OCI sin añadir repositorios
- Explicar por qué `helm upgrade --install` es la forma idempotente de instalar
- Fijar la versión del chart y saber qué pasa si no lo haces
- Saber qué no hace Helm con los CRD y por qué importa al actualizar ARC
- Ver lo que de verdad tiene aplicado el clúster, no lo que dice tu repo

## 1. Qué problema resuelve

Instalar ARC a mano sería escribir y aplicar en orden cuatro CRD, un deployment, varias service
accounts, roles y role bindings, y después tu scale set con su secret. Y repetirlo igual en cada
actualización. Helm convierte eso en un comando: el autor de ARC escribe las plantillas una vez,
tú le das los valores que cambian (tu repo, tu nombre, tu imagen) y Helm genera y aplica el
resto.

## 2. Cómo funciona

### Tres palabras

| Palabra | Qué es | En ARC |
|---|---|---|
| **Chart** | Un paquete versionado de plantillas de Kubernetes más un `values.yaml` con valores por defecto | `gha-runner-scale-set-controller` y `gha-runner-scale-set` |
| **Values** | Los valores con los que se rellenan las plantillas | Tu `ops/arc/values.yaml` |
| **Release** | Una instalación concreta de un chart, con nombre, en un namespace | `arc` en `arc-systems` y `tablero-runners` en `arc-runners` |

Un mismo chart se puede instalar varias veces con nombres distintos: cada release es
independiente. Helm guarda en el propio clúster el historial de cada release, con sus values y
su número de revisión.

### De dónde salen los values

Helm parte del `values.yaml` del chart y le superpone, en orden, lo que tú le pases:

1. Los valores por defecto del chart
2. Cada archivo de `-f` (o `--values`), en el orden en que los escribas
3. Cada `--set clave=valor`

Lo que no sobrescribes se queda con el valor por defecto del autor. Y ese valor por defecto no
siempre es el que quieres: el chart del scale set de ARC 0.15.1 trae como imagen del runner
`ghcr.io/actions/actions-runner:latest`. Si no la cambias en tus values, tus runners corren una
imagen que cambia sin avisar. El archivo 07 la fija por digest.

### Charts en un registro OCI

Los charts de ARC se publican como artefactos OCI en GHCR, igual que una imagen. No hay que
añadir ningún repositorio con `helm repo add`: el chart se nombra por su URL completa.

| Chart | URL |
|---|---|
| Controller | `oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller` |
| Scale set | `oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set` |

Sin `--version`, Helm toma la última versión publicada. Con `--version 0.15.1`, siempre la misma.
Controller y scale set salen de la misma release de ARC y se instalan **con la misma versión**:
`install.sh` la guarda en una sola variable para que no puedan separarse.

### `upgrade --install`: un comando para instalar y actualizar

`helm install` falla si la release ya existe, y `helm upgrade` falla si no existe.
`helm upgrade --install` hace lo que haga falta: instala la primera vez y actualiza las
siguientes. Eso hace `install.sh` idempotente: lo lanzas tras cada cambio en `values.yaml` y el
clúster acaba igual que tu repo.

Las opciones que usa `tablero`:

| Opción | Para qué |
|---|---|
| `--kube-context kind-gha` | El clúster del laboratorio y ningún otro |
| `--namespace arc-systems` | Dónde vive la release |
| `--create-namespace` | Crea el namespace si no existe |
| `--version "$ARC_VERSION"` | La versión fijada del chart |
| `-f values.yaml` | Tus values, versionados en el repo |
| `--wait` | No termina hasta que los objetos estén listos: un error sale aquí, no más tarde |

### Lo que Helm no hace: actualizar CRD

El chart del controller lleva los CRD de ARC en su carpeta `crds/`. Helm los instala la primera
vez, pero **no los actualiza** en un `upgrade`. La documentación de GitHub lo dice sin rodeos:
como Helm no actualiza ni borra CRD, no se puede actualizar ARC solo con Helm cuando cambian. El
procedimiento es desinstalar los scale sets, desinstalar el controller, borrar los CRD de
`actions.github.com` si han cambiado y volver a instalar. En el laboratorio eso es barato: un
clúster desechable y un `install.sh`.

### `helm template` necesita un clúster

`helm template` genera los YAML sin aplicarlos y suele servir para revisar un chart sin clúster.
Con el chart del scale set no funciona: al generar el role binding, la plantilla busca el
controller en el clúster y, si no está, falla:

```text
No gha-rs-controller deployment found using label (app.kubernetes.io/part-of=gha-rs-controller)
```

Por eso el orden es fijo: primero el controller, después el scale set.

_Verificado con ARC 0.15.1, Helm v4.3.2 y kind v0.33.0, noviembre de 2026._

## 3. Cómo se usa

### Instalar Helm con checksum

Helm se instala como cualquier binario del bootcamp: la release fijada y su checksum, nunca un
script remoto por tubería.

```bash
curl -fsSLO https://get.helm.sh/helm-v4.3.2-linux-amd64.tar.gz
curl -fsSLO https://get.helm.sh/helm-v4.3.2-linux-amd64.tar.gz.sha256sum
sha256sum -c helm-v4.3.2-linux-amd64.tar.gz.sha256sum
# helm-v4.3.2-linux-amd64.tar.gz: OK
```

### La forma que tiene `install.sh`

```bash
ARC_VERSION=0.15.1
CHARTS=oci://ghcr.io/actions/actions-runner-controller-charts

helm upgrade --install arc --kube-context kind-gha \
  --namespace arc-systems --create-namespace \
  --version "$ARC_VERSION" "$CHARTS/gha-runner-scale-set-controller" --wait
```

El scale set sigue el mismo patrón con su propio nombre, su namespace y `-f values.yaml`. La
práctica 02 instala el controller; la 03, el scale set.

### Consultar lo instalado

```bash
helm list -A --kube-context kind-gha
# NAME              NAMESPACE     ... CHART                                   APP VERSION
# arc               arc-systems   ... gha-runner-scale-set-controller-0.15.1  0.15.1
# tablero-runners   arc-runners   ... gha-runner-scale-set-0.15.1             0.15.1
```

| Comando | Qué te dice |
|---|---|
| `helm show values <chart> --version 0.15.1` | Todas las opciones del chart, comentadas, en esa versión |
| `helm get values tablero-runners -n arc-runners` | Los values de la última instalación |
| `helm get manifest tablero-runners -n arc-runners` | Los YAML que Helm aplicó de verdad |
| `helm history tablero-runners -n arc-runners` | Las revisiones de la release |
| `helm uninstall tablero-runners -n arc-runners` | Borra la release y sus objetos |

### Desinstalar en orden

Se desmonta al revés de como se monta: primero el scale set, después el controller. Si borras
antes el controller, nadie queda para limpiar los runners y el registro del scale set en GitHub.

```bash
helm uninstall tablero-runners --kube-context kind-gha -n arc-runners --wait
helm uninstall arc --kube-context kind-gha -n arc-systems --wait
```

En el laboratorio también puedes borrar el clúster entero con `./scripts/lab-down.sh`, pero
entonces nadie le dice a GitHub que el scale set ya no existe: desinstálalo antes con Helm.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Instalar sin `--version` | Cada instalación puede traer una versión distinta, y el controller y el scale set se separan | `--version "$ARC_VERSION"` en los dos |
| `curl ... \| bash` para instalar Helm | Ejecutas lo que sirva ese servidor en ese momento | Release fijada y `sha256sum -c` |
| `--set githubConfigSecret.github_token=...` | La credencial queda en el historial del shell y en los values de la release | Un secret creado aparte y referenciado por nombre |
| Credenciales en `values.yaml` | El archivo está en el repo: la credencial también | Solo el nombre del secret |
| Dejar la imagen por defecto del chart | Es `:latest`: cambia sin aviso | Imagen fijada por tag y digest en tus values |
| `kubectl edit` sobre objetos de una release | El siguiente `upgrade` deshace tu cambio sin decírtelo | Cambiar `values.yaml` y volver a lanzar `install.sh` |

## 5. Trucos

- **Las opciones sin clonar el repo de ARC**: `helm show values` sobre la URL OCI con
  `--version` imprime el `values.yaml` comentado de esa versión exacta. Es la referencia que
  manda, por encima de cualquier tutorial.
- **Deriva entre repo y clúster**: compara `helm get values tablero-runners -n arc-runners` con
  `ops/arc/values.yaml`. Si difieren, alguien no relanzó `install.sh`.
- **Lo que Helm añadió por su cuenta**: `helm get manifest` enseña los objetos que nunca
  escribiste, como la service account sin permisos del runner.

## 📚 Recursos Adicionales

- [Helm: Installing Helm](https://helm.sh/docs/intro/install/)
- [Helm: Using Helm](https://helm.sh/docs/intro/using_helm/)
- [Helm: Use OCI-based registries](https://helm.sh/docs/topics/registries/)
- [Helm: Custom Resource Definitions](https://helm.sh/docs/chart_best_practices/custom_resource_definitions/)
- [GitHub Docs: Deploying runner scale sets with ARC](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller/deploy-runner-scale-sets)

## ✅ Checklist de Verificación

- [ ] Sé distinguir chart, values y release
- [ ] Sé en qué orden se superponen los values y qué pasa con lo que no sobrescribo
- [ ] Sé instalar un chart OCI fijando su versión
- [ ] Sé por qué controller y scale set van con la misma versión
- [ ] Sé por qué `helm upgrade --install` hace idempotente `install.sh`
- [ ] Sé qué no hace Helm con los CRD y qué implica para actualizar ARC
- [ ] Sé ver los values y los manifiestos que tiene aplicados el clúster

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Kubernetes, lo justo](01-kubernetes-lo-justo.md) | [Arquitectura de ARC](03-arquitectura-de-arc.md) |
