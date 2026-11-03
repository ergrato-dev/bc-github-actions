# Práctica 04 — Artefactos entre jobs

> Cada job empieza en una máquina vacía. Si un job construye `web/dist` y otro lo necesita, o lo
> construye otra vez o lo recibe como artefacto. Aquí lo subes, lo descargas en otro job sin
> checkout, lo inspeccionas desde tu terminal, chocas con la inmutabilidad y borras uno a mano.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `artifact-lab.yml`, con un job que construye y sube `web/dist` y otro que lo descarga
- `upload-artifact` con caducidad corta y fallo si no hay nada que subir
- Descargar un artefacto con `gh run download` y listarlo con la API
- Ver por qué un artefacto es inmutable y qué hace de verdad `overwrite: true`
- Borrar un artefacto de tu repo antes de que caduque

## 📋 Antes de empezar

Terminaste la [práctica 03](03-matrices.md): `matrix-lab.yml` terminó en verde.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
```

Como en la práctica 03, cada paso con run usa una función de tu terminal:

```bash
lab_run() {
  gh workflow run artifact-lab.yml
  sleep 5   # el run tarda unos segundos en aparecer en la lista
  id=$(gh run list --workflow artifact-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
  gh run watch "$id" --exit-status; echo "exit $?"
}
```

El artefacto se llama `web-bundle`. No uses `web-dist`: ese nombre es el del proyecto, y la
comprobación `web-dist-artifact` solo debe contar los que sube `ci-web.yml`.

---

## Paso 1: Construir y subir web/dist

**Por qué**: `upload-artifact` guarda archivos del job en el almacenamiento de Actions, ligados al
run. Tres inputs deciden si te sirve o te engaña. `path` es relativo a la raíz del repo, no a
`defaults.run`: es `web/dist`. `if-no-files-found` vale `warn` por defecto: si el build no deja
nada, el step sale verde y el siguiente job falla sin pista; con `error` falla aquí mismo con
`No files were found with the provided path: web/dist. No artifacts will be uploaded.`
`retention-days` lo hace caducar pronto: un bundle de laboratorio no necesita 90 días ocupando
almacenamiento. Inputs leídos del `action.yml` de la v7.0.2 en su SHA.

**Comando**: crea `.github/workflows/artifact-lab.yml`.

```yaml
name: artifact-lab

on:
  workflow_dispatch:

# Mínimo privilegio: el token solo lee. Lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  bundle:
    name: Construir y subir web/dist
    runs-on: ubuntu-24.04
    # Solo este job: inspect no hace checkout y no tiene web/.
    defaults:
      run:
        shell: bash
        working-directory: web
    outputs:
      artifact-id: ${{ steps.upload.outputs.artifact-id }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413 # v6.1.0
        with:
          package_json_file: web/package.json
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version: "26"
          cache: pnpm
          cache-dependency-path: web/pnpm-lock.yaml
      - run: pnpm install --frozen-lockfile
      - run: pnpm build
      - id: upload
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: web-bundle
          # Relativo a la raíz del repo: los steps uses no ven defaults.run.
          path: web/dist
          if-no-files-found: error
          retention-days: 3
```

Fíjate en dónde va `defaults`: dentro del job, no en la raíz. En la práctica 02 iba en la raíz
porque el único job tenía `web/`. Aquí el job del paso 2 no hace checkout, y un
`working-directory` que no existe hace fallar sus `run:` antes de empezar.

**Verifica**:

```bash
actionlint .github/workflows/artifact-lab.yml; echo "exit $?"
# exit 0
yq '.jobs.bundle.steps[-1].with | [.path, ."if-no-files-found", ."retention-days"] | join(",")' \
  .github/workflows/artifact-lab.yml
# web/dist,error,3
```

---

## Paso 2: Descargarlo en otro job, sin checkout

**Por qué**: el segundo job no necesita el código ni pnpm: solo lo que produjo el primero.
`download-artifact` con `name` extrae ese artefacto **directamente** en `path`, sin un
subdirectorio con su nombre. Y comprueba el digest: con `digest-mismatch: error` (el valor por
defecto en la v8.0.2) falla si lo que llega no es lo que se subió. Esa es la garantía que no da
una caché (teoría 06). El id del artefacto llega por `needs` y pasa al shell por `env:`.

**Comando**: añade el job al final de `jobs:`.

```yaml
  inspect:
    name: Inspeccionar el bundle
    needs: bundle
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/download-artifact@9000827ccba6bdab643e8b6fd33ac0654aef8333 # v8.0.2
        with:
          name: web-bundle
          path: site
      - name: Qué ha llegado
        env:
          ARTIFACT_ID: ${{ needs.bundle.outputs.artifact-id }}
        run: |
          echo "artefacto ${ARTIFACT_ID}"
          find site -type f | sort
          du -sh site
          test -f site/index.html
```

```bash
actionlint .github/workflows/artifact-lab.yml
git add .github/workflows/artifact-lab.yml
git commit -m "ci(lab): add artifact-lab workflow"
git push
lab_run
# ...
# exit 0
```

**Verifica**:

```bash
gh run view "$id" --log | grep -E 'site/|artefacto [0-9]'
# Inspeccionar el bundle  Qué ha llegado  ... artefacto <id>
# Inspeccionar el bundle  Qué ha llegado  ... site/assets/index-B_X_rmRw.js
# Inspeccionar el bundle  Qué ha llegado  ... site/index.html
```

`index.html` está en `site/`, no en `site/web-bundle/` ni en `site/web/dist/`: con un directorio,
el artefacto guarda lo que hay **dentro**, y un solo artefacto se extrae en `path` tal cual. El
nombre del `.js` lleva un hash del contenido: si tu `src/` es otro, será otro.

---

## Paso 3: Descargarlo en tu máquina y verlo con la API

**Por qué**: un artefacto no sirve solo entre jobs. Cuando un build de CI hace algo raro, lo
primero es bajar **exactamente** lo que produjo el runner y mirarlo en local, en lugar de
reconstruir y esperar que salga igual. `gh run download` lo hace con el id del run: sin él, busca
en todos los runs del repo, y la ayuda de `gh` avisa de que así no sabes cuál bajas. La API da lo
que la UI de Actions enseña a medias: tamaño en bytes, caducidad exacta y el id para borrarlo.

**Comando**:

```bash
gh run download "$id" -n web-bundle -D /tmp/web-bundle-local
ls /tmp/web-bundle-local
gh api 'repos/{owner}/{repo}/actions/artifacts?name=web-bundle' \
  --jq '.artifacts[] | [.id, .size_in_bytes, .created_at, .expires_at] | @tsv'
```

`{owner}/{repo}` no es un hueco que rellenas tú: `gh api` lo sustituye por el repo del directorio
en el que estás.

**Verifica**:

```bash
ls /tmp/web-bundle-local
# assets  index.html
diff -r /tmp/web-bundle-local ~/code/tablero/web/dist && echo "idéntico a tu build local"
# idéntico a tu build local
gh api 'repos/{owner}/{repo}/actions/artifacts?name=web-bundle' --jq .total_count
# 1
```

`diff` debería salir limpio si tu `web/dist` local viene del mismo commit y del mismo lockfile
(práctica 01, paso 3). Si no lo tienes, `pnpm build` en `web/` y repite; si aun así difiere,
acabas de encontrar justo lo que este paso busca: el runner no construye lo mismo que tu máquina. En la salida de la API,
`expires_at` es tres días después de `created_at`: es tu `retention-days`.

---

## Paso 4: Subir dos veces el mismo nombre

**Por qué**: desde la v4 de las actions de artefactos, un artefacto es **inmutable**: no se le
añaden archivos y no puede haber dos con el mismo nombre en un run. Es lo que rompe una matriz
que sube `coverage` desde cada combinación. Aquí lo provocas con dos `upload-artifact` seguidos
y después ves qué hace `overwrite: true`, que no es "añadir", sino "borrar y volver a subir".

**Comando**: añade este step al final de `bundle`, después del `upload`.

```yaml
      - name: Segunda subida con el mismo nombre
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: web-bundle
          path: web/dist
          if-no-files-found: error
          retention-days: 3
```

```bash
actionlint .github/workflows/artifact-lab.yml
git commit -am "ci(lab): upload web-bundle twice on purpose"
git push
lab_run
# ...
# exit 1
gh run view "$id" --log-failed | grep -m1 -o 'Failed request: (409) Conflict.*'
# Failed request: (409) Conflict: ...
```

El texto que sigue a `Conflict:` lo pone el servidor; el principio lo construye el cliente de la
action (`Received non-retryable error: Failed request: (<código>) <estado>`), en su `dist/` en ese
SHA. `actionlint` no lo detecta: dos steps con el mismo `name:` de artefacto son YAML válido.

Ahora añade `overwrite: true` al `with:` del segundo step y relanza:

```bash
git commit -am "ci(lab): overwrite the second upload"
git push
lab_run
# ...
# exit 0
gh run view "$id" --log | grep -o "Artifact 'web-bundle' (ID: [0-9]*) deleted"
# Artifact 'web-bundle' (ID: <id>) deleted
```

**Verifica**:

```bash
gh api "repos/{owner}/{repo}/actions/runs/$id/artifacts" --jq '.artifacts[] | [.id, .name] | @tsv'
# <otro id>	web-bundle
```

Un solo artefacto, y su id **no** es el del log: el segundo step borró el primero y subió otro.
El output `artifact-id` del step `upload`, que `inspect` imprime, apunta ya a un artefacto
borrado. Por eso `overwrite` sirve para re-ejecuciones, no para compartir un artefacto entre
jobs. Quita el segundo step entero y deja el workflow como en el paso 2:

```bash
git commit -am "ci(lab): drop the duplicated upload"
git push
yq '[.jobs.bundle.steps[].uses // "" | select(test("upload-artifact"))] | length' \
  .github/workflows/artifact-lab.yml
# 1
```

---

## Paso 5: Borrar un artefacto antes de que caduque

**Por qué**: un artefacto ocupa almacenamiento hasta que caduca, y en un repo privado cuenta
contra la cuota de la cuenta. A veces quieres quitarlo ya: subiste algo que no debía salir del
runner, o necesitas espacio. La API lo borra por id. No hay papelera: borrado es borrado.

> ⚠️ **Antes de borrar**: `DELETE` no se puede deshacer y no pide confirmación. Hazlo solo en tu
> `<tu-org>/tablero`, y solo sobre un `web-bundle` de este laboratorio, nunca sobre un `web-dist`
> del proyecto: la comprobación `web-dist-artifact` lo necesita. Si quieres conservar el
> contenido, descárgalo antes como en el paso 3; ese es tu respaldo.

**Comando**: elige el `web-bundle` más antiguo, revisa qué es y bórralo.

```bash
aid=$(gh api 'repos/{owner}/{repo}/actions/artifacts?name=web-bundle' \
  --jq '.artifacts | sort_by(.created_at) | .[0].id')
gh api "repos/{owner}/{repo}/actions/artifacts/$aid" --jq '[.id, .name, .created_at] | @tsv'
# <id>	web-bundle	...
gh run download "$(gh api "repos/{owner}/{repo}/actions/artifacts/$aid" --jq .workflow_run.id)" \
  -n web-bundle -D "/tmp/backup-$aid"
gh api -X DELETE "repos/{owner}/{repo}/actions/artifacts/$aid"
```

El `DELETE` no imprime nada si va bien: la API responde `204 No Content`.

**Verifica**:

```bash
gh api "repos/{owner}/{repo}/actions/artifacts/$aid"; echo "exit $?"
# gh: Not Found (HTTP 404)
# exit 1
ls "/tmp/backup-$aid"
# assets  index.html
```

El artefacto ya no existe, en la API ni en la página del run, aunque el run sigue ahí. Al revés no
pasa: borrar un run borra todos sus artefactos.

---

## ✅ Resultado

- [ ] `artifact-lab.yml` está en `main` y solo se lanza a mano
- [ ] `bundle` sube `web/dist` con `if-no-files-found: error` y `retention-days: 3`
- [ ] `inspect` recibe el bundle sin checkout y encuentra `site/index.html`
- [ ] Has descargado un artefacto con `gh run download` y lo has visto con la API
- [ ] Has visto el `409 Conflict` de dos subidas con el mismo nombre y qué hace `overwrite`
- [ ] Has borrado un `web-bundle` por la API, con su respaldo delante

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 04
```

Esta práctica no añade comprobaciones: `web-dist-artifact` y las de `ci-web.yml` llegan con el
proyecto, que reutiliza todo lo de hoy con los nombres que exige `checks.json`.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `No files were found with the provided path: dist` | `path` relativo a `web/` en lugar de a la raíz | Paso 1: `path: web/dist` |
| Los `run:` de `inspect` fallan antes de ejecutar nada | Pusiste `defaults.run.working-directory: web` en la raíz y `inspect` no tiene `web/` | Paso 1: `defaults` dentro de `bundle` |
| `test -f site/index.html` falla y existe `site/web-bundle/` | Quitaste `name` y `download-artifact` bajó todos los artefactos, uno por directorio | Paso 2: `name: web-bundle` |
| `gh run download` dice `no artifact matches any of the names or patterns provided` | El id del run no es el de un run de `artifact-lab`, o el artefacto caducó o lo borraste | `gh api "repos/{owner}/{repo}/actions/runs/$id/artifacts"` |
| El run del paso 4 sale verde sin `overwrite` | El segundo step tiene otro `name` | Los dos `name:` tienen que ser `web-bundle` |
| `gh api -X DELETE` da `HTTP 404` | El id no existe o es de otro repo | Comprueba que estás en `~/code/tablero` y repite el `aid=...` |
| `gh api -X DELETE` da `HTTP 403` | Tu sesión de `gh` no tiene permiso de escritura en el repo | `gh auth status`; necesitas el alcance `repo` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Matrices](03-matrices.md) | [Proyecto: capa 04 de tablero](../3-proyecto/README.md) |
