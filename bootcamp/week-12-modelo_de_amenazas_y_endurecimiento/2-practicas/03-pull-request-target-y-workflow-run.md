# Práctica 03 — pull_request_target y workflow_run

> Etiquetar un PR y comentarle el tamaño de `web/dist` son tareas de escritura. Con
> `pull_request`, un PR de un fork recibe un token de solo lectura y las dos fallan. En esta
> práctica las resuelves con los dos triggers privilegiados, sin que el código del PR toque
> nunca un token con escritura.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `labeler.yml` etiquetando cada PR por rutas con `pull_request_target`, sin checkout
- `ci-web` dejando el informe de `dist` y el número del PR en el artefacto `dist-report`
- `pr-report.yml` comentando ese informe desde `workflow_run`, con el artefacto como datos
- Un PR de prueba etiquetado y comentado, cerrado sin fusionar

## 📋 Antes de empezar

Terminaste la [práctica 02](02-inyeccion-de-scripts.md) y leíste la
[teoría 04](../1-teoria/04-pull-request-target-y-workflow-run.md): «pwn request» y patrón seguro.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
git status --short | wc -l
# 0
```

---

## Paso 1: Por qué no basta con `pull_request`, y las etiquetas

**Por qué**: en un `pull_request` desde un fork, todo `write` del token pasa a `read`, y
`labeler` necesita `pull-requests: write`. Desde una rama tuya funcionaría, y por eso el fallo
solo aparece el día que llega el primer PR de fuera. `pull_request_target` corre el workflow
**de `main`**, con escritura, y le da al PR solo su número y su lista de archivos. Es seguro
mientras no haga checkout del PR ni ejecute nada suyo. Antes creas las etiquetas, con el color y
la descripción que eliges tú.

**Comando**: `--force` actualiza la etiqueta si ya existía:

```bash
gh label create api --color 2088ff --description "Cambios en api/" --force
gh label create web --color 79c0ff --description "Cambios en web/" --force
gh label create ci --color d2a8ff --description "Cambios en .github/" --force
```

**Verifica**:

```bash
gh label list --json name --jq '[.[].name | select(. == "api" or . == "web" or . == "ci")] | sort | join(" ")'
# api ci web
```

---

## Paso 2: `labeler.yml` y su configuración en `main`

**Por qué**: `actions/labeler` lee `.github/labeler.yml` por la API desde la rama base y
compara sus globs con los archivos que cambia el PR. No necesita el código: por eso el job no
hace checkout, y el único permiso de escritura es `pull-requests`. zizmor marca todo
`pull_request_target` como `dangerous-triggers`; la excepción va en la línea del trigger, con
un motivo que se pueda comprobar leyendo el archivo.

**Comando**: escribe a mano `.github/labeler.yml`:

```yaml
# Etiquetas por ruta para labeler.yml. Se lee de la rama base, nunca del PR.
api:
  - changed-files:
      - any-glob-to-any-file: api/**
web:
  - changed-files:
      - any-glob-to-any-file: web/**
ci:
  - changed-files:
      - any-glob-to-any-file: .github/**
```

Y `.github/workflows/labeler.yml`:

```yaml
name: labeler
on:
  # Corre con el workflow y la configuración de la rama base: el PR solo aporta la lista
  # de archivos cambiados. No hace checkout ni ejecuta nada del PR.
  pull_request_target: # zizmor: ignore[dangerous-triggers] sin checkout del PR, solo etiqueta
    types: [opened, synchronize, reopened]
permissions: {}
jobs:
  label:
    name: Etiquetar por ruta
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/labeler@bf12e9b00b37c5c0ca2b87b79b2daf7891dbda13 # v7.0.0
```

```bash
actionlint && zizmor --offline -q .github/workflows/labeler.yml
git add .github/labeler.yml .github/workflows/labeler.yml
git commit -m "ci: label pull requests by path"
git push
```

**Verifica**: la orden de `labeler-safe`:

```bash
yq '"trigger=" + (.on | keys | join(",")) + " checkout=" + ([.jobs[].steps[] | select(.uses // "" | test("^actions/checkout@"))] | length | tostring) + " labeler=" + ([.jobs[].steps[] | select(.uses // "" | test("^actions/labeler@[0-9a-f]{40}$"))] | length | tostring)' \
  .github/workflows/labeler.yml
# trigger=pull_request_target checkout=0 labeler=1
```

---

## Paso 3: Un PR de prueba, etiquetado

**Por qué**: `labeler.yml` ya está en `main`, que es de donde lo lee `pull_request_target`. Un
PR que toque `web/` tiene que recibir la etiqueta `web` y ninguna otra. Este PR te sirve
también para los pasos 4 a 6: `ci-web` corre en él y `pr-report` lo comentará.

**Comando**:

```bash
git switch -c test/pr-report
echo "<!-- prueba de pr-report -->" >> web/index.html
git commit -am "test(web): trigger pr-report" && git push -u origin test/pr-report
gh pr create --fill
pr=$(gh pr view test/pr-report --json number --jq .number)
id=$(gh run list --workflow labeler.yml --event pull_request_target --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null && echo labeler ok
# labeler ok
```

**Verifica**: la etiqueta en el PR y la orden de `labeler-labeled`:

```bash
gh pr view "$pr" --json labels --jq '[.labels[].name] | join(" ")'
# web
gh pr list --state all --limit 50 --json labels --jq '[.[].labels[].name | select(. == "api" or . == "web" or . == "ci")] | length'
# 1
```

---

## Paso 4: `ci-web` deja el informe en un artefacto

**Por qué**: `ci-web` es quien construye `dist`, y en un PR corre el código del PR con un token
sin escritura. No puede comentar, y no debe poder. Lo que sí puede es dejar el informe y el
número del PR en un artefacto: el número va por `env:`, como todo dato del evento
([práctica 02](02-inyeccion-de-scripts.md)). En un `push` el step del número no corre y el
artefacto solo lleva `report.md`.

**Comando**: vuelve a `main` (`git switch main`) y, en el job `dist-report` de
`.github/workflows/ci-web.yml`, deja así los steps que siguen a la descarga de `dist`:

```yaml
      - name: Tamaño de cada archivo
        run: |
          mkdir -p report
          {
            echo "## web/dist"
            echo
            echo '```'
            du -ah dist | sort -h
            echo '```'
          } > report/report.md
          cat report/report.md >> "$GITHUB_STEP_SUMMARY"
      - name: Número del PR para pr-report
        if: github.event_name == 'pull_request'
        env:
          PR_NUMBER: ${{ github.event.pull_request.number }}
        run: echo "$PR_NUMBER" > report/pr-number
      # pr-report.yml lo descarga desde workflow_run para comentar en el PR.
      - uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: dist-report
          path: report/
          retention-days: 1
```

```bash
actionlint
git commit -am "ci(web): upload dist report artifact"
git push
id=$(gh run list --workflow ci-web.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null && echo ci-web ok
# ci-web ok
```

**Verifica**: el artefacto del run de `main`, sin `pr-number` porque vino de un `push`:

```bash
d=$(mktemp -d)
gh run download "$id" -n dist-report -D "$d" && ls "$d"
# report.md
```

---

## Paso 5: `pr-report.yml`, el workflow con permiso para comentar

**Por qué**: `workflow_run` corre cuando termina `ci-web`, con el workflow de `main` y un
token con escritura, aunque el run de `ci-web` viniera de un fork. Por eso es la otra mitad
del patrón, y por eso lleva cuatro defensas: el **guardia `if:`** solo deja pasar runs de
`pull_request` en `success`; **sin checkout**, nada del PR llega al runner salvo el artefacto;
**`run-id`** lo descarga del run de `ci-web` y **`runner.temp`** lo deja fuera del workspace; y
el **número se valida** con `^[0-9]+$`, porque lo escribió código del PR.

El número viaja en el artefacto porque `github.event.workflow_run.pull_requests` llega vacío
cuando el PR viene de un fork.

**Comando**: escribe a mano `.github/workflows/pr-report.yml`:

```yaml
name: pr-report
on:
  # ci-web corre el código del PR sin permisos; este workflow corre después, con permiso
  # para comentar, y solo trata el artefacto como datos.
  workflow_run: # zizmor: ignore[dangerous-triggers] sin checkout, el artefacto se valida
    workflows: [ci-web]
    types: [completed]
permissions: {}
jobs:
  comment:
    name: Comentar el informe de dist
    if: github.event.workflow_run.event == 'pull_request' && github.event.workflow_run.conclusion == 'success'
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    permissions:
      # Leer artefactos de otro run es leer de Actions.
      actions: read
      pull-requests: write
    steps:
      - uses: actions/download-artifact@9000827ccba6bdab643e8b6fd33ac0654aef8333 # v8.0.2
        with:
          name: dist-report
          path: ${{ runner.temp }}/dist-report
          run-id: ${{ github.event.workflow_run.id }}
          github-token: ${{ github.token }}
      - name: Comentar en el PR
        env:
          GH_TOKEN: ${{ github.token }}
          GH_REPO: ${{ github.repository }}
          REPORT_DIR: ${{ runner.temp }}/dist-report
        run: |
          # El artefacto lo escribió código del PR: el número se valida antes de usarlo.
          pr=$(head -c 10 "$REPORT_DIR/pr-number")
          if ! [[ "$pr" =~ ^[0-9]+$ ]]; then
            echo "::error::pr-number no es un número"
            exit 1
          fi
          gh pr comment "$pr" --body-file "$REPORT_DIR/report.md"
```

`GH_REPO` hace falta porque no hay checkout: sin un repo local, `gh` no sabe a cuál hablar.

```bash
actionlint && zizmor --offline -q .github/workflows/pr-report.yml
git add .github/workflows/pr-report.yml
git commit -m "ci: comment dist report on pull requests"
git push
```

**Verifica**: la orden de `pr-report-safe`, y la de `writes-only-where-needed`, que ya tiene
las cinco escrituras de la semana:

```bash
yq '"from=" + (.on.workflow_run.workflows | join(",")) + " guard=" + ([.jobs[] | select(.if // "" | test("workflow_run.event == .pull_request."))] | length | tostring) + " checkout=" + ([.jobs[].steps[] | select(.uses // "" | test("^actions/checkout@"))] | length | tostring) + " run-id=" + ([.jobs[].steps[] | select(.with."run-id" // "" | test("workflow_run.id"))] | length | tostring)' \
  .github/workflows/pr-report.yml
# from=ci-web guard=1 checkout=0 run-id=1
yq -N '.jobs | to_entries | .[] | .value.permissions // {} | to_entries | .[] | select(.value == "write") | (filename | sub(".*/"; "")) + ":" + .key' \
  .github/workflows/*.yml | sort -u | tr '\n' ' '; echo
# codeql.yml:security-events images.yml:packages labeler.yml:pull-requests nightly.yml:actions pr-report.yml:pull-requests
```

---

## Paso 6: El comentario del bot en el PR

**Por qué**: `pr-report` corre la versión de `main`, que ya lo tiene, pero necesita un run de
`ci-web` que venga de un `pull_request`. Un push nuevo a la rama del PR lo dispara, y ese run
usa el `ci-web.yml` de `main` con el job `dist-report` nuevo, porque un `pull_request` corre
sobre la fusión de la rama con `main`.

**Comando**:

```bash
git switch test/pr-report
echo "<!-- segunda pasada -->" >> web/index.html
git commit -am "test(web): rerun ci-web for pr-report" && git push
id=$(gh run list --workflow ci-web.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null && echo ci-web ok
# ci-web ok
```

`pr-report` arranca cuando `ci-web` termina; dale unos segundos:

```bash
id=$(gh run list --workflow pr-report.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null
gh run view "$id" --json event,conclusion --jq '"\(.event) \(.conclusion)"'
# workflow_run success
```

**Verifica**: el comentario en el PR y la orden de `pr-report-commented`:

```bash
gh api "repos/{owner}/{repo}/issues/$pr/comments" \
  --jq '.[] | select(.user.login == "github-actions[bot]") | .body | split("\n")[0]'
# ## web/dist
gh api 'repos/{owner}/{repo}/issues/comments?sort=created&direction=desc&per_page=100' \
  --jq '[.[] | select(.user.login == "github-actions[bot]" and (.body | test("web/dist")))] | length'
# 1
```

---

## Paso 7: Cerrar el PR de prueba

**Por qué**: el PR ya dejó la etiqueta y el comentario que comprueba `check-week.sh`, que
cuenta también los PRs cerrados. Fusionarlo solo metería dos comentarios HTML en `web/`.

> ⚠️ **Cierra el PR sin fusionarlo.** `--delete-branch` borra `test/pr-report` en local y en
> GitHub; la etiqueta y el comentario se quedan en el PR cerrado.

**Comando**:

```bash
git switch main
gh pr close "$pr" --delete-branch
```

**Verifica**: PR cerrado sin fusionar, rama borrada y la evidencia intacta:

```bash
gh pr view "$pr" --json state,mergedAt,labels --jq '"\(.state) merged=\(.mergedAt != null) labels=\([.labels[].name] | join(","))"'
# CLOSED merged=false labels=web
git ls-remote --heads origin test/pr-report | wc -l
# 0
```

---

## ✅ Resultado

- [ ] `labeler.yml` sin checkout y con la excepción de zizmor justificada; un PR etiquetado `web`
- [ ] `ci-web` sube `dist-report` con `report.md` y, en un PR, `pr-number`
- [ ] `pr-report.yml` con guardia, sin checkout, con `run-id`, `runner.temp` y número validado
- [ ] El bot comentó el informe de `web/dist` y el PR de prueba está cerrado sin fusionar

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 12
# ✅ labeler.yml se dispara con pull_request_target, no hace checkout y usa actions/labeler fijada por SHA
# ...
# ✅ pr-report.yml se dispara al terminar ci-web, solo actúa si el run vino de un pull_request, no hace checkout y descarga el artefacto de ese run
# ✅ github-actions[bot] ha comentado el informe de web/dist en un pull request de tablero
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `labeler` no corre en el PR | `labeler.yml` no estaba en `main` cuando abriste el PR | Paso 2 primero; después un push nuevo a la rama del PR |
| `error[dangerous-triggers]` en zizmor | Falta el comentario de excepción, o no está en la línea del trigger | Va en la misma línea que `pull_request_target:` o `workflow_run:` |
| `pr-report` termina en `skipped` | El run de `ci-web` vino de un `push` o falló | Es lo esperado: solo actúa sobre `pull_request` en `success` |
| `Unable to download artifact(s): Artifact not found for name: dist-report` | Falta `run-id`, o el run de `ci-web` es anterior al paso 4 | Paso 5: `run-id` y `github-token`; paso 6: push nuevo al PR |
| `pr-report` falla con `pr-number no es un número` | El run de `ci-web` no escribió el número | El step lleva `if: github.event_name == 'pull_request'`; revisa el paso 4 |
| `gh pr comment` responde `Resource not accessible by integration` | Falta `pull-requests: write` en el job | Paso 5 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Inyección de scripts](02-inyeccion-de-scripts.md) | [Dependabot y zizmor online](04-dependabot-y-zizmor-online.md) |
