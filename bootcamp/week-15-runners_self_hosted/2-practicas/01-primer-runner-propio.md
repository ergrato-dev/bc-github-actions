# Práctica 01 — Primer runner propio

> Antes de construir el runner bueno, construyes el ingenuo: uno persistente, registrado con un
> token de registro, que se queda escuchando entre job y job. Lo pruebas con una sonda y ves con
> tus ojos por qué no sirve: el segundo job encuentra lo que dejó el primero.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- La política de la org que solo deja tener runners de repositorio a `tablero`
- La etiqueta `tablero-lab` declarada para actionlint
- Una sonda, `runner-probe.yml`, que dice si el job hereda algo del anterior
- Un runner persistente en un contenedor, con sus etiquetas vistas desde la API
- La prueba de que un runner persistente comparte disco entre jobs, y el runner ya borrado

## 📋 Antes de empezar

Leíste la teoría de la semana, de la [01](../1-teoria/01-por-que-un-runner-propio.md) a la
[07](../1-teoria/07-runner-propio-en-un-repo-publico.md). La capa 14 está en `main` y Docker
corre en tu máquina.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
org=${GH_REPO%%/*}
docker version --format '{{.Server.Version}}' > /dev/null && echo docker-ok
# docker-ok
gh api "repos/$GH_REPO/actions/runners" --jq .total_count
# 0
```

Ese `0` es el punto de partida: `tablero` no tiene ningún runner propio.

---

## Paso 1: Solo `tablero` puede tener runners propios

**Por qué**: en una org Free no puedes crear runner groups adicionales
([teoría 06](../1-teoria/06-runner-groups-y-politicas.md)), pero sí decidir qué repositorios
pueden registrar runners propios. Por defecto pueden **todos**: cualquier repo nuevo de tu org
podría colgar un runner de tu máquina con un workflow que tú no has revisado. Con
`enabled_repositories=selected` y `tablero` como único seleccionado, ese hueco se cierra.

La segunda capa ya la pusiste en la Semana 12: los workflows de un PR de fork esperan a que tú
los apruebes, venga de quien venga. Con un runner propio en un repo público deja de ser una
buena costumbre y pasa a ser obligatorio ([teoría 07](../1-teoria/07-runner-propio-en-un-repo-publico.md)).

Cambiar políticas de la org necesita el scope `admin:org` en tu sesión de `gh`. Si
`gh auth status` no lo lista entre los *Token scopes*, amplíala:

```bash
gh auth refresh -h github.com -s admin:org
```

**Comando**: guarda la política actual (es tu respaldo para deshacer) y cámbiala:

```bash
gh api "orgs/$org/actions/permissions/self-hosted-runners" > ~/self-hosted-policy-backup.json
jq -r .enabled_repositories ~/self-hosted-policy-backup.json
# all
gh api -X PUT "orgs/$org/actions/permissions/self-hosted-runners" -f enabled_repositories=selected
repo_id=$(gh api "repos/$GH_REPO" --jq .id)
gh api -X PUT "orgs/$org/actions/permissions/self-hosted-runners/repositories/$repo_id"
```

Los dos `PUT` responden `204` sin cuerpo: no verás nada. En la UI es *Settings → Actions →
General → Repository-level self-hosted runners → Selected repositories*. Para volver atrás,
`-f enabled_repositories=` con el valor que guardaste en el respaldo.

**Verifica**: las órdenes de `org-self-hosted-selected` y `fork-pr-approval`:

```bash
printf 'enabled=%s repos=%s\n' \
  "$(gh api orgs/{owner}/actions/permissions/self-hosted-runners --jq .enabled_repositories)" \
  "$(gh api orgs/{owner}/actions/permissions/self-hosted-runners/repositories --jq '[.repositories[].name] | join(",")')"
# enabled=selected repos=tablero
gh api repos/{owner}/{repo}/actions/permissions/fork-pr-contributor-approval --jq .approval_policy
# all_external_contributors
```

`{owner}` y `{repo}` los rellena `gh` a partir de `GH_REPO`. Si la segunda da otro valor, vuelve
a ponerlo como en la Semana 12 antes de seguir: sin él, no registres ningún runner.

---

## Paso 2: actionlint conoce `tablero-lab`

**Por qué**: actionlint valida `runs-on` contra la lista de etiquetas de los runners de GitHub.
Una etiqueta propia le parece un error tipográfico, y el job `lint-workflows` de `tablero` se
pondría en rojo en cuanto subas la sonda del paso 3. Se lo dices en `.github/actionlint.yaml`,
que actionlint lee solo, sin flags ([teoría 03](../1-teoria/03-etiquetas-y-runs-on.md)).

**Comando**: crea `.github/actionlint.yaml`:

```yaml
# Etiquetas propias que actionlint debe aceptar en runs-on: las del runner propio de tablero.
self-hosted-runner:
  labels:
    - tablero-lab
```

```bash
git add .github/actionlint.yaml
git commit -m "ci(runner): declare tablero-lab label for actionlint"
```

`self-hosted` no hace falta declararla: actionlint ya la conoce.

**Verifica**:

```bash
yq '."self-hosted-runner".labels | join(",")' .github/actionlint.yaml
# tablero-lab
actionlint && echo lint-ok
# lint-ok
```

---

## Paso 3: La sonda

**Por qué**: necesitas un job que te diga, sin abrir la máquina, si alguien estuvo antes. La
sonda busca un archivo en `$HOME`; si lo encuentra, dice quién lo dejó; después deja el suyo.
Solo se lanza a mano (`workflow_dispatch`), no hace checkout ni toca secretos: lo único que
ejecuta en tu máquina es lo que ves en el YAML. Aun así es un job `self-hosted`, y en la
práctica 04 lo borras para que `lab.yml` sea el único.

**Comando**: escribe `.github/workflows/runner-probe.yml`:

```yaml
# Sonda de la Semana 15: dice si el job encuentra en $HOME lo que dejó el anterior.
# Va en .github/workflows/runner-probe.yml de <tu-org>/tablero y se borra en la práctica 04.
name: runner-probe
on:
  workflow_dispatch:
permissions:
  contents: read
jobs:
  probe:
    runs-on: [self-hosted, tablero-lab]
    timeout-minutes: 5
    steps:
      - name: Buscar lo que dejó el job anterior
        run: |
          marker="$HOME/probe-marker"
          if [ -f "$marker" ]; then
            echo "state=inherited from=$(cat "$marker")"
          else
            echo "state=clean"
          fi
          echo "$RUNNER_NAME-$GITHUB_RUN_ID" > "$marker"
```

```bash
actionlint .github/workflows/runner-probe.yml
git add .github/workflows/runner-probe.yml
git commit -m "ci(runner): add self-hosted runner probe"
git push
```

`runs-on` es una lista: el job necesita un runner que tenga **todas** esas etiquetas.

**Verifica**:

```bash
gh workflow list --json name,state --jq '.[] | select(.name == "runner-probe") | .state'
# active
```

---

## Paso 4: Un runner persistente en un contenedor

**Por qué**: es el registro clásico ([teoría 02](../1-teoria/02-como-funciona-el-runner.md)):
pides un token de registro, que caduca en una hora; `config.sh` lo canjea por credenciales
**permanentes** que guarda en el disco del runner, y `run.sh` se queda escuchando jobs para
siempre. Lo metes en un contenedor de la imagen oficial para no instalar nada en tu máquina y
poder tirarlo entero en el paso 6.

El token va al contenedor por `-e REG_TOKEN`, sin `=valor`: Docker copia la variable de tu shell
y el token no aparece en la línea de órdenes ni en el historial.

**Comando**:

```bash
image=ghcr.io/actions/actions-runner:2.338.2@sha256:6d0b2d80d80f143f77dcb676e50920100bbb547e39e883454d57f45ab8c31300
REG_TOKEN=$(gh api -X POST "repos/$GH_REPO/actions/runners/registration-token" --jq .token)
export REG_TOKEN
docker run -d --name tablero-persistente -e GH_REPO -e REG_TOKEN "$image" \
  bash -c './config.sh --unattended --url "https://github.com/$GH_REPO" --token "$REG_TOKEN" \
    --name tablero-persistente --labels tablero-lab && ./run.sh'
unset REG_TOKEN
docker logs -f tablero-persistente
# ...
# √ Connected to GitHub
# ...
# 2026-11-13 10:00:00Z: Listening for Jobs
```

Sal de `docker logs -f` con Ctrl-C cuando veas *Listening for Jobs*: el contenedor sigue
corriendo en segundo plano.

**Verifica**: el runner visto desde la API:

```bash
gh api "repos/$GH_REPO/actions/runners" --jq '.runners[] | select(.name == "tablero-persistente")
  | "\(.status) ephemeral=\(.ephemeral) labels=\([.labels[].name] | sort | join(","))"'
# online ephemeral=false labels=Linux,X64,self-hosted,tablero-lab
```

Pediste una etiqueta y tiene cuatro: `config.sh` añade siempre `self-hosted`, el sistema y la
arquitectura, salvo que pases `--no-default-labels`. `ephemeral=false`: este runner no se va.

---

## Paso 5: El segundo job hereda lo del primero

**Por qué**: es el problema que justifica el resto de la semana. Un runner persistente ejecuta
un job detrás de otro en la misma máquina, con el mismo usuario y el mismo `$HOME`. Lo que un
job deja (un archivo, una caché envenenada, un proceso en segundo plano) lo encuentra el
siguiente, sea del workflow que sea.

**Comando**: una función que lanza la sonda, espera a que acabe y saca su veredicto del log:

```bash
probe() {
  gh workflow run runner-probe.yml > /dev/null
  sleep 5
  id=$(gh run list --workflow runner-probe.yml --limit 1 --json databaseId --jq '.[0].databaseId')
  gh run watch "$id" --exit-status > /dev/null
  gh run view "$id" --log | grep -oE 'state=(clean|inherited from=[^ ]+)$'
}
probe
# state=clean
probe
# state=inherited from=tablero-persistente-19283746501
```

El `sleep 5` da tiempo a que el run aparezca en la lista antes de buscar su id. El `$` del final
del patrón evita que `grep` encuentre la línea del script, que también sale en el log.

**Verifica**: los dos runs, en verde y en el mismo runner:

```bash
gh run list --workflow runner-probe.yml --limit 2 --json databaseId --jq '.[].databaseId' |
  while read -r id; do
    gh api "repos/$GH_REPO/actions/runs/$id/jobs" --jq '.jobs[0] | "\(.conclusion) \(.runner_name)"'
  done
# success tablero-persistente
# success tablero-persistente
```

---

## Paso 6: Borrar el runner persistente

> ⚠️ **Advertencia**: vas a dar de baja el runner y borrar su contenedor con todo lo que tiene
> dentro. No hay nada que respaldar: las credenciales del runner viven solo en ese contenedor y
> el marcador de la sonda es justo lo que quieres perder. Comprueba antes que borras el que toca.

**Por qué**: un runner persistente es una credencial permanente en tu disco y una máquina que
acumula restos. No lo vas a volver a usar: desde la práctica 02 cada job tendrá su propio runner.
`DELETE` sobre su id lo da de baja en GitHub aunque siga conectado; luego tiras el contenedor.

**Comando**:

```bash
runner_id=$(gh api "repos/$GH_REPO/actions/runners" \
  --jq '.runners[] | select(.name == "tablero-persistente") | .id')
echo "$runner_id"
# 17
gh api -X DELETE "repos/$GH_REPO/actions/runners/$runner_id"
docker rm -f tablero-persistente
# tablero-persistente
```

**Verifica**: ni runners persistentes en la API ni el contenedor en tu máquina:

```bash
gh api "repos/$GH_REPO/actions/runners" --jq '"persistent=\([.runners[] | select(.ephemeral | not)] | length)"'
# persistent=0
docker ps -a --filter name=tablero-persistente --format '{{.Names}}'
# (sin salida)
```

---

## ✅ Resultado

- [ ] La org solo deja registrar runners de repositorio en `tablero`
- [ ] Los PR de fork siguen esperando tu aprobación (`all_external_contributors`)
- [ ] `.github/actionlint.yaml` declara `tablero-lab` y `actionlint` pasa
- [ ] `runner-probe.yml` en `main`, solo con `workflow_dispatch`
- [ ] Viste el segundo job de la sonda heredar el marcador del primero
- [ ] El runner persistente y su contenedor ya no existen

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 15
# ...
# ✅ La org solo permite runners propios de repositorio en tablero
# ✅ tablero exige aprobación para los workflows de todos los contribuidores externos
# ...
```

El resto de comprobaciones sigue en rojo: llegan con las prácticas 02 a 04.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `HTTP 403` o `404` en `orgs/.../self-hosted-runners` | Tu sesión de `gh` no tiene `admin:org` | `gh auth refresh -h github.com -s admin:org` y repite el paso 1 |
| `repos=` vacío en la verificación del paso 1 | Pusiste `selected` pero no añadiste `tablero` | El segundo `PUT`, con el id de `gh api repos/$GH_REPO --jq .id` |
| `label "tablero-lab" is unknown` en actionlint | Falta `.github/actionlint.yaml` o la etiqueta está mal escrita | Paso 2 |
| `config.sh` no llega a *Connected to GitHub* | El token de registro caducó (una hora) o es de otro repo | Pide otro token y repite el paso 4 |
| El runner sale *Disabled* en la UI | La política de la org no incluye `tablero` | Paso 1 |
| La sonda se queda en *Queued* | Ningún runner online tiene `self-hosted` y `tablero-lab` | `docker logs tablero-persistente` y el paso 4 |
| `probe` no imprime nada | El run aún no aparecía y `gh run list` cogió otro | Sube el `sleep` y vuelve a lanzarla |
| `persistent=1` tras el paso 6 | El `DELETE` usó otro id o falló | Lista `{id, name}` de los runners y repite el `DELETE` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Un runner propio en un repo público](../1-teoria/07-runner-propio-en-un-repo-publico.md) | [Runner JIT efímero en Docker](02-runner-jit-efimero-en-docker.md) |
