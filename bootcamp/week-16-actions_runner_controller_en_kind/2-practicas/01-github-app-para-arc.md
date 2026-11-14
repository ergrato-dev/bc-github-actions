# Práctica 01 — Una GitHub App para ARC

> ARC necesita una credencial para registrar runners en `tablero`. Un token personal alcanzaría
> todo lo que tú alcanzas y no caducaría nunca. Una GitHub App de la org, instalada solo en
> `tablero` y con dos permisos, alcanza lo justo. Su clave privada es lo más valioso de la semana:
> vive en tu máquina, fuera del repo, y llega al clúster como un secret de Kubernetes.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Una GitHub App de `<tu-org>` sin webhook, con Administration (lectura y escritura) y Metadata
  (lectura) sobre repositorios, y nada más
- La App instalada en `tablero` y en ningún otro repo
- Su clave privada en `~/.config/tablero-arc/app.pem`, con permisos `600` y fuera de cualquier repo
- El clúster `kind-gha` arriba y el secret `tablero-arc-app` en el namespace `arc-runners`, con
  las tres claves que ARC espera

## 📋 Antes de empezar

Tienes `check-week.sh 15` en verde y leíste la
[teoría 04](../1-teoria/04-autenticar-arc-con-una-github-app.md). Necesitas ser propietario de la
org para crear una App en ella.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
gh api "orgs/${GH_REPO%%/*}" --jq .login
# <tu-org>
```

---

## Paso 1: Crear la App en la org

**Por qué**: la App es de la organización, no tuya. Si mañana dejas el proyecto, la credencial no
se va contigo ni se queda viva a tu nombre. Los permisos se eligen uno a uno: el scale set de
`tablero` es de **repositorio** (igual que el runner de la Semana 15), y para registrar runners
en un repo la documentación pide **Administration: Read and write** y **Metadata: Read-only**.
Nada de la org: un permiso de organización le daría alcance sobre todos los repos.

ARC no recibe eventos: habla con GitHub por conexiones salientes. Un webhook activo sería una URL
a la que GitHub enviaría datos sin que nadie los necesite.

**Comando**: en GitHub, abre los **Settings de la org** → **Developer settings** →
**GitHub Apps** → **New GitHub App**, y rellena solo esto:

| Campo | Valor | Por qué |
|---|---|---|
| GitHub App name | `<tu-org>-tablero-arc` | El nombre es único en todo GitHub: con el de tu org delante no choca |
| Homepage URL | `https://github.com/<tu-org>/tablero` | Es obligatorio; no se usa para nada más |
| Webhook → Active | **Desmarcado** | ARC no usa webhooks |
| Repository permissions → Administration | Read and write | Registrar y borrar los runners del repo |
| Repository permissions → Metadata | Read-only | GitHub lo exige junto a cualquier permiso de repo |
| Organization permissions | Todos en *No access* | El scale set no es de la org |
| Where can this GitHub App be installed? | Only on this account | Nadie de fuera de tu org puede instalarla |

Deja el resto como viene y crea la App. GitHub te lleva a su página de configuración: la última
parte de la URL es el **slug** de la App y en la página ves su **client ID**.

**Verifica**: pide a la API la ficha de la App por su slug:

```bash
APP_SLUG=<slug-de-tu-app>
gh api "apps/$APP_SLUG" --jq '{owner: .owner.login, permissions, events}'
# {"owner":"<tu-org>","permissions":{"administration":"write","metadata":"read"},"events":[]}
```

`events` vacío confirma que la App no se suscribe a nada. Si en `permissions` sale algo más,
vuelve a la página de la App y quítalo antes de instalarla.

---

## Paso 2: Instalarla solo en `tablero`

**Por qué**: Administration es un permiso fuerte: da acceso a la configuración del repo, sus
runners incluidos. Lo que acota ese poder es **dónde** está instalada la App. Instalada solo en
`tablero`, el token que ARC genera con ella no sirve en ningún otro repo de la org.

La instalación tiene su propio número, el **installation ID**. ARC lo necesita junto al client ID
para pedir tokens de instalación, que caducan en una hora y se renuevan solos.

**Comando**: en la página de la App, entra en **Install App**, elige tu org y, en la pantalla de
repositorios, marca **Only select repositories** con `tablero` como único repo. Tras instalarla,
la URL de la instalación termina en el installation ID:

```text
https://github.com/organizations/<tu-org>/settings/installations/<ID>
```

Guarda los dos identificadores en un archivo de entorno fuera del repo. No son secretos, pero
así no tienes que buscarlos en cada terminal:

```bash
mkdir -p ~/.config/tablero-arc
chmod 700 ~/.config/tablero-arc
cat > ~/.config/tablero-arc/app.env <<'EOF'
# Datos de la GitHub App de ARC. Los lee ops/arc/install.sh; la clave es solo una ruta.
export APP_CLIENT_ID=<client-id>
export APP_INSTALLATION_ID=<installation-id>
export APP_PRIVATE_KEY_FILE="$HOME/.config/tablero-arc/app.pem"
EOF
```

Edita el archivo y pon tus dos valores en lugar de los marcadores.

**Verifica**: no queda ningún marcador y el installation ID es un número:

```bash
grep -c '<' ~/.config/tablero-arc/app.env
# 0
source ~/.config/tablero-arc/app.env
[[ $APP_INSTALLATION_ID =~ ^[0-9]+$ && -n $APP_CLIENT_ID ]] && echo ids-ok
# ids-ok
```

En la página de la instalación, la sección de acceso a repositorios tiene que enseñar `tablero`
y solo `tablero`. La rúbrica lo revisa a mano.

---

## Paso 3: La clave privada, fuera del repo

**Por qué**: con el client ID, el installation ID y la clave privada, cualquiera puede pedir
tokens con Administration sobre `tablero`. Los dos ID están en URLs; la clave es lo único que lo
impide. GitHub no la guarda: la descargas una vez y desde ese momento es responsabilidad tuya.

Va a `~/.config/tablero-arc/`, no a una carpeta del repo con `.gitignore`: basta un `git add -f`
o una herramienta que no respete `.gitignore` para que acabe en un commit de un repo público.

**Comando**: en la página de la App, en la sección de claves privadas, genera una clave. El
navegador descarga un archivo `<nombre-de-la-app>.<fecha>.private-key.pem`. Muévelo (en WSL2 tu
carpeta de descargas está en `/mnt/c/Users/<tu-usuario>/Downloads`):

```bash
mv ~/Downloads/<tu-org>-tablero-arc.*.private-key.pem ~/.config/tablero-arc/app.pem
chmod 600 ~/.config/tablero-arc/app.pem
```

No hagas `cat` de la clave para "ver si está bien": quedaría en tu terminal, en su historial de
desplazamiento y en cualquier grabación de pantalla. `openssl` la valida sin imprimirla.

> ⚠️ **Advertencia — regenerar la clave**: si pierdes el `.pem` o sospechas que se filtró, genera
> otra en la misma sección y **después** borra la vieja en GitHub. Borrar una clave invalida al
> instante los tokens que ARC pida con ella: si ARC ya la usa (desde la práctica 03), primero
> relanzas `install.sh` con la nueva y luego borras la vieja, nunca al revés.

**Verifica**: la orden de `no-private-key-in-repo`, más los permisos y la validez del archivo:

```bash
stat -c '%a' ~/.config/tablero-arc/app.pem
# 600
openssl pkey -in ~/.config/tablero-arc/app.pem -noout && echo pem-ok
# pem-ok
git grep -lE -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' || echo sin-claves
# sin-claves
git log --all -p | grep -cE -- '-----BEGIN [A-Z ]*PRIVATE KEY-----'
# 0
```

La última orden revisa todo el historial: una clave borrada en un commit posterior sigue en el
anterior, y en un repo público eso es igual que publicarla.

---

## Paso 4: El clúster y el secret de la App

**Por qué**: el chart de ARC no lee la clave de tu disco: lee un **secret de Kubernetes** por su
nombre. Lo creas en `arc-runners`, el namespace de los runners, porque es allí donde lo busca el
scale set; el controller vivirá aparte, en `arc-systems`
([teoría 03](../1-teoria/03-arquitectura-de-arc.md)).

Las tres claves del secret tienen nombres fijos. `github_app_id` acepta el client ID: lo dice el
`values.yaml` del chart 0.15.1. El secret se construye en memoria con `--dry-run=client -o yaml`
y `apply` lo crea o lo actualiza, así que puedes repetirlo. La clave entra con `--from-file`: no
pasa por la línea de órdenes ni por el historial del shell.

**Comando**: levanta el clúster del laboratorio:

```bash
~/code/bc-github-actions/scripts/lab-up.sh
# NAME                STATUS   ROLES           AGE   VERSION
# gha-control-plane   Ready    control-plane   ...
# gha-worker          Ready    <none>          ...
#
# Laboratorio listo: contexto kind-gha
```

Si `gha-worker` no llega a `Ready`, no sigas: la
[práctica 02, antes de empezar](02-arc-con-helm.md#-antes-de-empezar) explica el límite de
inotify que lo provoca. Después crea el namespace y el secret:

```bash
source ~/.config/tablero-arc/app.env
kubectl --context kind-gha create namespace arc-runners --dry-run=client -o yaml \
  | kubectl --context kind-gha apply -f -
kubectl --context kind-gha create secret generic tablero-arc-app --namespace arc-runners \
  --from-literal=github_app_id="$APP_CLIENT_ID" \
  --from-literal=github_app_installation_id="$APP_INSTALLATION_ID" \
  --from-file=github_app_private_key="$APP_PRIVATE_KEY_FILE" \
  --dry-run=client -o yaml | kubectl --context kind-gha apply -f -
```

En la práctica 03 estas mismas órdenes pasan a `ops/arc/install.sh`. Hoy las lanzas a mano para
ver qué hace cada una.

**Verifica**: la orden de `arc-secret-in-kind`, que lista las claves sin imprimir sus valores:

```bash
kubectl --context kind-gha get secret tablero-arc-app -n arc-runners -o json | jq -r '.data | keys | join(",")'
# github_app_id,github_app_installation_id,github_app_private_key
kubectl --context kind-gha get secret tablero-arc-app -n arc-runners -o jsonpath='{.type}{"\n"}'
# Opaque
```

Si en la lista apareciera `github_token`, el secret llevaría un token personal: el check lo marca
en rojo precisamente para eso.

El secret vive en el clúster, no en el repo: si borras el clúster con `lab-down.sh`, desaparece
con él. `install.sh` lo vuelve a crear desde `app.env` y el `.pem`.

---

## ✅ Resultado

- [ ] La App `<tu-org>-tablero-arc` existe, sin webhook y con Administration y Metadata
- [ ] Está instalada solo en `tablero`
- [ ] `~/.config/tablero-arc/app.env` tiene el client ID, el installation ID y la ruta de la clave
- [ ] `~/.config/tablero-arc/app.pem` tiene permisos `600` y `openssl` la acepta
- [ ] Ningún archivo ni commit de `tablero` contiene una clave privada
- [ ] El secret `tablero-arc-app` de `arc-runners` tiene sus tres claves

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 16
# ...
# ✅ Ningún archivo de tablero contiene una clave privada
# ...
# ✅ El secret tablero-arc-app de arc-runners guarda la GitHub App y ningún token personal
# ...
```

El resto de comprobaciones siguen en rojo: las cierran las prácticas 02 a 04.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El nombre de la App ya está en uso | Los nombres de App son únicos en todo GitHub | Añade un sufijo: `<tu-org>-tablero-arc-lab` |
| `gh api apps/<slug>` devuelve `HTTP 404` | Slug mal copiado, o la App es de tu cuenta personal y no de la org | Copia el slug de la URL de la App; si está en tu cuenta, créala de nuevo desde los Settings de la org |
| `permissions` enseña más permisos de los dos | Se marcó algo de más al crearla | Quítalo en la página de la App y acepta el cambio en la instalación |
| `openssl pkey` da `Could not read key` | El archivo no es el `.pem` descargado, o quedó a medias | Genera otra clave (lee la advertencia del paso 3) y vuelve a moverla |
| `git grep` encuentra un `.pem` en `tablero` | La clave se copió dentro del repo | Sácala a `~/.config/tablero-arc/`; si llegó a un commit, rota la clave: el historial ya la publicó |
| `gha-worker` se queda en `NotReady` | Límite de inotify del host | [Práctica 02, antes de empezar](02-arc-con-helm.md#-antes-de-empezar) |
| `context was not found for specified context: kind-gha` | El clúster no está levantado |  `~/code/bc-github-actions/scripts/lab-up.sh` |
| `El clúster gha es anterior a la Semana 17` | El `lab-up.sh` actual monta la configuración OIDC y tu clúster se creó antes | Recréalo: `~/code/bc-github-actions/scripts/lab-down.sh && ~/code/bc-github-actions/scripts/lab-up.sh` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Endurecer el pod del runner](../1-teoria/07-endurecer-el-pod-del-runner.md) | [ARC con Helm](02-arc-con-helm.md) |
