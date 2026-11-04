# Práctica 02 — Inyección de scripts

> Leer que `${{ }}` dentro de un `run:` es inyección convence a medias. Verlo convence del
> todo: en esta práctica abres un PR cuyo título ejecuta un comando en tu runner, lo detectas
> con zizmor, lo corriges con `env:` y dejas a CodeQL vigilando los workflows de `main`.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Un workflow vulnerable a propósito en la rama `lab/injection`, que nunca llega a `main`
- Un PR cuyo título inofensivo demuestra en el log que se ejecutó como código
- zizmor y actionlint señalando la línea exacta
- La corrección con `env:`, comprobada con la misma orden que usa `check-week.sh`
- `codeql.yml` en `main` y code scanning sin alertas abiertas
- El PR cerrado sin fusionar y la rama borrada

## 📋 Antes de empezar

Terminaste la [práctica 01](01-permisos-minimos-por-job.md) y leíste la
[teoría 03](../1-teoria/03-inyeccion-de-scripts.md): por qué la expresión se expande antes de
que el shell vea el script.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
git status --short | wc -l
# 0
```

> ⚠️ **El workflow de esta práctica es vulnerable a propósito.** Vive solo en la rama
> `lab/injection` y en un PR que **nunca se fusiona**. Lleva `permissions: {}` y corre con
> `pull_request`, así que aunque la inyección funcione el job no tiene token útil ni secretos.
> El título que usas imprime un número y nada más. Al final cierras el PR y borras la rama.

---

## Paso 1: La rama de laboratorio con el workflow vulnerable

**Por qué**: necesitas un sitio donde la inyección ocurra de verdad sin poner nada en riesgo.
Una rama propia con un PR hacia `main` dispara `pull_request` con el workflow de la rama, que
es justo el caso de un PR de cualquiera. El step mete el título del PR en el script con
`${{ }}`: el error que la teoría describe, tal cual.

**Comando**: crea la rama y escribe a mano `.github/workflows/injection-lab.yml`:

```bash
git switch -c lab/injection
```

```yaml
# Laboratorio de la práctica 02: vulnerable a propósito. Vive solo en lab/injection.
name: injection-lab
on:
  pull_request:
# Aunque la inyección funcione, el token no tiene ningún scope.
permissions: {}
jobs:
  greet:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    permissions: {}
    steps:
      - name: Saludar
        run: echo "Gracias por el PR ${{ github.event.pull_request.title }}"
```

```bash
git add .github/workflows/injection-lab.yml
git commit -m "test: add vulnerable injection lab workflow"
git push -u origin lab/injection
```

**Verifica**: el workflow está en la rama y no en `main`:

```bash
git ls-tree -r --name-only origin/lab/injection .github/workflows | grep -c injection-lab
# 1
git ls-tree -r --name-only origin/main .github/workflows | grep -c injection-lab
# 0
```

---

## Paso 2: El PR con el título que ataca

**Por qué**: el título de un PR lo escribe quien lo abre, sin ninguna validación. Con
`x"; echo "PWNED-$((6*7))`, la primera comilla cierra la cadena de tu `echo`, el `;` empieza
un comando nuevo y `$((6*7))` es aritmética que solo evalúa un shell. Si en el log aparece
`PWNED-42`, el título se ejecutó. Las **comillas simples** en tu terminal son importantes: con
dobles, tu propio shell calcularía el 42 antes de enviar el título y la prueba no valdría.

**Comando**:

```bash
gh pr create --base main --head lab/injection \
  --title 'x"; echo "PWNED-$((6*7))' \
  --body "Laboratorio de la práctica 02. No se fusiona."
pr=$(gh pr view lab/injection --json number --jq .number)
```

**Verifica**: el título llegó a GitHub literal, con el `$((6*7))` sin calcular:

```bash
gh pr view "$pr" --json title --jq .title
# x"; echo "PWNED-$((6*7))
```

---

## Paso 3: `PWNED-42` en el log

**Por qué**: es la prueba de que el título cruzó de dato a código. El log de cada step empieza
con el script que recibió el shell, después de expandir las expresiones: ahí ves el título
pegado dentro del `echo`. Debajo, la salida: el 42 solo puede salir de un shell que evaluó
`$((6*7))`.

**Comando**:

```bash
id=$(gh run list --commit "$(git rev-parse HEAD)" --json databaseId,workflowName \
  --jq '[.[] | select(.workflowName == "injection-lab")][0].databaseId')
gh run watch "$id" > /dev/null
gh run view "$id" --log | grep -m1 -oE 'echo "Gracias.*'
# echo "Gracias por el PR x"; echo "PWNED-$((6*7))"
```

Dos comandos donde tu YAML escribió uno.

**Verifica**: la salida del segundo comando:

```bash
gh run view "$id" --log | grep -oE 'PWNED-[0-9]+' | sort -u
# PWNED-42
```

Un atacante real no imprimiría nada: leería el token, llamaría a la API o descargaría un
script. Aquí el token no tiene ningún scope y `pull_request` no entrega secretos: el daño queda
contenido por la práctica 01, no por suerte.

---

## Paso 4: zizmor y actionlint lo ven antes de ejecutarlo

**Por qué**: no hace falta abrir un PR para descubrirlo. La auditoría `template-injection` de
zizmor marca toda expresión con datos del atacante dentro de un `run:`, y actionlint hace la
misma comprobación (`[expression]`). Los dos corren en `lint-workflows`, así que el PR ya tiene
un check en rojo que lo avisa.

**Comando**:

```bash
zizmor --offline .github/workflows/injection-lab.yml
# error[template-injection]: code injection via template expansion
#   --> .github/workflows/injection-lab.yml:14:42
# ...
actionlint .github/workflows/injection-lab.yml
# .github/workflows/injection-lab.yml:14:42: "github.event.pull_request.title" is potentially untrusted. ...
```

La línea y la columna apuntan al `${{` de tu step; si tu archivo tiene otra cabecera, cambian.

**Verifica**: el hallazgo de zizmor y el check del PR:

```bash
zizmor --offline -q .github/workflows/injection-lab.yml 2>&1 | grep -E '^error\['
# error[template-injection]: code injection via template expansion
gh run list --workflow lint-workflows.yml --branch lab/injection --limit 1 --json conclusion --jq '.[0].conclusion'
# failure
```

---

## Paso 5: Corregir con `env:`

**Por qué**: con `env:` la expresión se expande en el **valor** de una variable de entorno, no
en el texto del script. El shell recibe siempre el mismo script, `echo "Gracias por el PR
$PR_TITLE"`, y expande `"$PR_TITLE"` como un único argumento sin volver a interpretarlo. Las
comillas dobles alrededor de la variable también cuentan: sin ellas no se ejecutan comandos,
pero el valor se parte en palabras y se expanden comodines.

**Comando**: cambia el step de `injection-lab.yml` por este:

```yaml
      - name: Saludar
        env:
          PR_TITLE: ${{ github.event.pull_request.title }}
        run: echo "Gracias por el PR $PR_TITLE"
```

```bash
git commit -am "fix: pass the pr title through env"
git push
id=$(gh run list --commit "$(git rev-parse HEAD)" --json databaseId,workflowName \
  --jq '[.[] | select(.workflowName == "injection-lab")][0].databaseId')
gh run watch "$id" > /dev/null
gh run view "$id" --log | grep -cE 'PWNED-[0-9]+'
# 0
```

El título se imprime tal cual, con el `$((6*7))` sin evaluar.

**Verifica**: la orden de `no-expressions-in-run` sobre todos los workflows de la rama, que son
los de `main` más el de laboratorio:

```bash
yq '.jobs[].steps[]? | (.run // "") + (.with.script // "")' .github/workflows/*.yml | grep -E '\$\{\{' || true
# (sin salida)
zizmor --offline -q .github/workflows/injection-lab.yml
# No findings to report. Good job! (2 suppressed)
```

---

## Paso 6: CodeQL sobre los workflows de `main`

**Por qué**: zizmor y actionlint miran cada línea; CodeQL sigue el dato de un step a otro (de
un `github.event.*` a un output, de ahí a un `env:`, de ahí a un `run:`) y guarda las alertas
con su historia en **Security → Code scanning**. El job sube un SARIF, y eso es lo único que
escribe: `security-events: write`. El workflow va a `main`, no a la rama de laboratorio.

**Comando**: vuelve a `main` y escribe a mano `.github/workflows/codeql.yml`:

```bash
git switch main
```

```yaml
name: codeql
on:
  push:
    branches: [main]
  pull_request:
  # Semanal: recoge consultas nuevas aunque nadie toque los workflows.
  schedule:
    - cron: "17 6 * * 1"
  workflow_dispatch:
permissions: {}
jobs:
  analyze:
    name: CodeQL de workflows
    runs-on: ubuntu-24.04
    timeout-minutes: 15
    permissions:
      contents: read
      # Sube el SARIF a la pestaña Security → Code scanning.
      security-events: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: github/codeql-action/init@9b3254085494b55a0f7c4c2b3d2d52cc712ce370 # v4.39.1
        with:
          languages: actions
      - uses: github/codeql-action/analyze@9b3254085494b55a0f7c4c2b3d2d52cc712ce370 # v4.39.1
        with:
          category: /language:actions
```

```bash
actionlint && zizmor --offline -q .github/workflows/codeql.yml
# No findings to report. Good job! (2 suppressed)
git add .github/workflows/codeql.yml
git commit -m "ci: add codeql for workflows"
git push
id=$(gh run list --workflow codeql.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null && echo codeql ok
# codeql ok
```

**Verifica**: la orden de `codeql-workflow`:

```bash
yq '[.jobs[] | select(.permissions."security-events" == "write") | .steps[] | select(.uses // "" | test("^github/codeql-action/(init|analyze)@"))] | "languages=" + ([.[] | select(.with.languages) | .with.languages] | join(",")) + " steps=" + (length | tostring)' \
  .github/workflows/codeql.yml
# languages=actions steps=2
```

---

## Paso 7: Code scanning limpio y el laboratorio cerrado

**Por qué**: un análisis que nadie consulta no protege. La API de code scanning devuelve las
alertas de la rama por defecto; `0` significa que CodeQL analizó `main` y no encontró nada.
¿Habría avisado del PR de laboratorio? Con la suite por defecto, no: con `pull_request` la
inyección cae en `actions/code-injection/medium`, de precisión media, y la suite por defecto
solo carga consultas de precisión alta o muy alta. Con `pull_request_target` sería
`actions/code-injection/critical` y sí saldría. Por eso zizmor y actionlint son la barrera de
cada PR, y CodeQL la segunda opinión ([teoría 07](../1-teoria/07-analisis-estatico-zizmor-y-codeql.md)).

**Comando**: el último análisis de CodeQL y la consulta que habría visto el laboratorio:

```bash
gh api 'repos/{owner}/{repo}/code-scanning/analyses?tool_name=CodeQL' --jq '.[0] | "\(.ref) \(.results_count)"'
# refs/heads/main 0
gh api repos/github/codeql/contents/actions/ql/src/Security/CWE-094/CodeInjectionMedium.ql \
  --jq .content | base64 -d | grep -E '@(id|precision)'
#  * @precision medium
#  * @id actions/code-injection/medium
```

> ⚠️ **Cierra el PR sin fusionarlo.** `--delete-branch` borra la rama en local y en GitHub; el
> workflow vulnerable desaparece con ella. Si quisieras repetir la práctica, este archivo tiene
> todo el contenido para volver a escribirlo.

```bash
gh pr close "$pr" --delete-branch --comment "Laboratorio de la práctica 02: no se fusiona."
```

**Verifica**: la orden de `code-scanning-clean`, el PR cerrado sin fusionar y la rama borrada:

```bash
gh api 'repos/{owner}/{repo}/code-scanning/alerts?state=open&tool_name=CodeQL&per_page=100' --jq length
# 0
gh pr view "$pr" --json state,mergedAt --jq '"\(.state) merged=\(.mergedAt != null)"'
# CLOSED merged=false
git ls-remote --heads origin lab/injection | wc -l
# 0
```

---

## ✅ Resultado

- [ ] Viste `PWNED-42` en el log y sabes explicar de dónde sale el 42
- [ ] zizmor (`template-injection`) y actionlint (`[expression]`) señalan la misma línea
- [ ] Con `env:` el título se imprime literal y ningún `run:` contiene `${{ }}`
- [ ] `codeql.yml` en `main`, con `security-events: write` solo en su job
- [ ] Code scanning con análisis y sin alertas abiertas
- [ ] Sabes por qué CodeQL por defecto no habría marcado el laboratorio
- [ ] El PR de laboratorio cerrado sin fusionar y `lab/injection` borrada

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 12
# ✅ Ningún run ni script de github-script contiene una expresión ${{ }}: todo dato llega por env
# ✅ codeql.yml analiza el lenguaje actions con init y analyze en un job con security-events: write
# ✅ Code scanning tiene análisis de CodeQL y ninguna alerta abierta
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El título del PR dice `PWNED-42` en lugar de `PWNED-$((6*7))` | Lo escribiste entre comillas dobles y tu shell calculó el 42 | `gh pr edit "$pr" --title 'x"; echo "PWNED-$((6*7))'` y un commit vacío (`git commit --allow-empty -m "test: rerun"`) para relanzar |
| No aparece ningún run de `injection-lab` | El archivo no está en `.github/workflows/` o el PR no apunta a `main` | Paso 1: `git ls-tree` de la rama; `gh pr view "$pr" --json baseRefName` |
| El log no tiene `PWNED-42` en el paso 3 | El step ya usaba `env:` | Es la versión corregida: vuelve al YAML del paso 1 |
| `PWNED-42` sigue saliendo tras el paso 5 | Miras el run anterior, o el `run:` aún tiene la expresión | Toma el último run de la rama y repite la verificación del paso 5 |
| `codeql` falla al subir resultados | Falta `security-events: write` en el job | Paso 6 |
| La API de alertas responde 404 `no analysis found` | `codeql` aún no ha terminado en `main` | Espera al run del paso 6 |
| `gh` te pide el scope `admin:repo_hook` | Aviso engañoso ante un 403 | Con `repo` basta si eres dueño; revisa que `GH_REPO` apunta a tu `tablero` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Permisos mínimos por job](01-permisos-minimos-por-job.md) | [pull_request_target y workflow_run](03-pull-request-target-y-workflow-run.md) |
