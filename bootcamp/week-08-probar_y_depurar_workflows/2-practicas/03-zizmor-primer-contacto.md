# Práctica 03 — zizmor: primer contacto

> actionlint te dice si un workflow está bien escrito; zizmor, si es seguro. En esta práctica lo
> pasas por todos tus workflows, provocas un hallazgo que actionlint deja pasar, lo corriges como
> manda la regla 4, dejas el repo sin hallazgos y añades zizmor como segundo job de la puerta.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- zizmor en local, en modo `regular` y `pedantic`, y la diferencia entre lo que enseña y lo que
  suprime
- Un `template-injection` provocado en `debug-lab.yml`, invisible para actionlint, corregido
  pasando el dato por `env:`
- `zizmor --offline .github/workflows/` sin hallazgos sobre todos tus workflows, labs incluidos
- El job `zizmor` en `lint-workflows.yml`, con zizmor 1.31.1 y `--format=github`
- Un hallazgo ignorado con `# zizmor: ignore[...]` y su motivo, y la razón para casi nunca hacerlo

## 📋 Antes de empezar

Terminaste la [práctica 02](02-actionlint-y-problem-matchers.md): `lint-workflows.yml` está en
`main` con el job `actionlint` y su último run en verde.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
yq '.jobs | keys | join(",")' .github/workflows/lint-workflows.yml
# actionlint
zizmor --version
# zizmor 1.31.1
```

---

## Paso 1: zizmor en local y sus personas

**Por qué**: zizmor pasa cada workflow por una lista de auditorías y da a cada hallazgo una
severidad y una confianza ([teoría 05](../1-teoria/05-zizmor.md#severidad-y-confianza)). La
**persona** decide qué se enseña: `regular` es la de la puerta del CI, con los mínimos falsos
positivos; `pedantic` añade malos olores que no son vulnerabilidades
([teoría 05](../1-teoria/05-zizmor.md#personas)). Lo que una persona no enseña no desaparece:
sale contado como `suppressed`. `--offline` deja fuera las auditorías que consultan la API de
GitHub; las activas en la Semana 12.

**Comando**:

```bash
zizmor --offline .github/workflows/
# ...
# No findings to report. Good job! (4 suppressed)
```

Tu número de suprimidos puede ser otro: depende de tus labs. Si en lugar de eso sale una lista de
hallazgos, sigue leyendo este paso y arréglalos en el paso 3.

Ahora con la persona pedantic, contando los hallazgos por auditoría:

```bash
zizmor --offline --persona=pedantic .github/workflows/ 2>/dev/null | grep -E '^\w+\[' | sort | uniq -c
#       1 error[unpinned-images]: unpinned image references
#       1 help[concurrency-limits]: insufficient job-level concurrency limits
#       2 help[undocumented-permissions]: permissions without explanatory comments
```

| Auditoría | Dónde | Por qué `regular` no la enseña |
|---|---|---|
| `unpinned-images` | `postgres:17.<parche>-alpine` en los services de `ci-api` | Tag completo, sin digest: el despliegue por digest llega en la Semana 14 |
| `undocumented-permissions` | Los permisos de escritura de `images` y `nightly` | Un comentario que justifique cada permiso: lo haces en la Semana 12 |
| `concurrency-limits` | `debug-lab`, sin `concurrency` | Un lab de `workflow_dispatch` no compite con nada |

`2>/dev/null` tira los mensajes de progreso que zizmor escribe en `stderr`. La persona pedantic es
para revisar, no para la puerta: en el CI enseñaría tres avisos que aún no toca arreglar.

**Verifica**: el modo regular termina con 0 o te deja la lista de lo que tienes que arreglar.

```bash
zizmor --offline .github/workflows/ > /dev/null 2>&1; echo "exit $?"
# exit 0
```

Un código distinto de 0 no es un fallo de zizmor: es el número que codifica la severidad máxima
de lo que encontró. Cualquier valor distinto de 0 pone en rojo el step de CI.

---

## Paso 2: Un hallazgo que actionlint no ve

**Por qué**: el input de un `workflow_dispatch` lo escribe quien lanza el run. Interpolado con
`${{ }}` dentro de `run:`, el runner lo pega en el script **antes** de que bash lo lea: un valor
como `3.15"; curl ... #` deja de ser un dato y pasa a ser código. actionlint 1.7.12 trata los
inputs como confiables y no protesta; zizmor sí. Por eso la puerta tiene dos jobs y no uno.

**Comando**: en `debug-lab.yml`, añade este step justo antes de **Comprobar la versión de
Python**.

```yaml
      - name: Anunciar la comprobación
        run: |
          echo "Comprobando que Python es ${{ inputs.expected_python }}"
```

```bash
actionlint .github/workflows/debug-lab.yml; echo "exit $?"
# exit 0
zizmor --offline .github/workflows/debug-lab.yml
# error[template-injection]: code injection via template expansion
#   --> .github/workflows/debug-lab.yml:44:47
#    |
# 43 |         run: |
#    |         --- this run block
# 44 |           echo "Comprobando que Python es ${{ inputs.expected_python }}"
#    |                                               ^^^^^^^^^^^^^^^^^^^^^^ may expand into attacker-controllable code
#    |
#    = note: audit confidence → High
# ...
echo "exit $?"
# exit 14
```

Severidad alta y confianza alta: el dato llega de fuera sin pasar por nada. El arreglo es el de
siempre ([teoría 05](../1-teoria/05-zizmor.md#en-local)): el runner pone el valor en una variable
de entorno y bash lo lee como dato, sin interpretarlo.

Sustituye el step por este:

```yaml
      - name: Anunciar la comprobación
        env:
          EXPECTED_PYTHON: ${{ inputs.expected_python }}
        run: echo "Comprobando que Python es $EXPECTED_PYTHON"
```

**Verifica**: los dos linters en verde y el arreglo en `main`.

```bash
actionlint && zizmor --offline .github/workflows/ 2>/dev/null | tail -1
# No findings to report. Good job! (4 suppressed)
git add .github/workflows/debug-lab.yml
git commit -m "test(debug-lab): announce the expected version through env"
git push
```

El push toca `.github/workflows/`: `lint-workflows` corre en `main` con su job `actionlint`.

---

## Paso 3: Sin hallazgos en ninguno de tus workflows

**Por qué**: es la orden de `workflows-zizmor`, y la misma razón del paso 1 de la práctica 02:
la puerta se estrena sobre un repo limpio. Los labs cuentan, porque son workflows de tu repo
público y un `workflow_dispatch` inseguro es tan explotable como uno de CI.

**Comando**: si el paso 1 ya terminó con `exit 0`, no hay nada que hacer. Si no, estos son los
hallazgos más probables en labs de semanas anteriores, y su arreglo:

| Hallazgo | Qué significa | Arreglo |
|---|---|---|
| `template-injection` | `${{ inputs.* }}`, `${{ github.event.* }}` o `${{ matrix.* }}` dentro de `run:` | El valor a `env:`, y `"$VAR"` en el script |
| `artipacked` | `actions/checkout` sin `persist-credentials: false` | Añádelo en el `with:` del checkout (regla 5) |
| `excessive-permissions` | Un permiso de escritura en la raíz o un job sin `permissions` heredando de más | `contents: read` en la raíz y cada job sube solo lo suyo (regla 2) |
| `unpinned-uses` | Una `uses:` por tag | El SHA de `scripts/resolve-sha.sh` con el tag en comentario (regla 1) |

Corrige uno, vuelve a pasar zizmor, y así hasta el final:

```bash
zizmor --offline .github/workflows/ 2>/dev/null | grep -E '^\w+\[|-->'
# (sin salida cuando no queda ninguno)
```

Si corregiste algo, súbelo:

```bash
actionlint
git add .github/workflows/
git commit -m "ci: fix zizmor findings in lab workflows"
git push
```

**Verifica**: la orden de `workflows-zizmor`.

```bash
zizmor --offline .github/workflows/ > /dev/null 2>&1; echo "exit $?"
# exit 0
```

---

## Paso 4: El job `zizmor` en la puerta

**Por qué**: un job aparte y no un step más del de actionlint, para que sean **independientes**:
si actionlint falla, zizmor también informa, y el PR enseña todos los problemas a la vez.
`--format=github` hace que zizmor emita cada hallazgo como `::error` o `::warning` con archivo y
línea: no necesita matcher. La versión exacta (`==1.31.1`) es la misma que en tu máquina: sin
ella, una auditoría nueva de una versión nueva te rompería `main` sin que cambies nada.
`setup-uv` instala uv y añade `~/.local/bin` al `PATH`, que es donde `uv tool install` deja el
binario.

**Comando**: añade este job a `lint-workflows.yml`, debajo de `actionlint`.

```yaml
  zizmor:
    name: zizmor
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
        with:
          version: "0.13.6"
      - name: Instalar zizmor
        run: uv tool install zizmor==1.31.1
      - name: zizmor
        # --format=github emite ::error y ::warning: cada hallazgo es una anotación.
        # --offline: las auditorías que consultan la API llegan en la Semana 12.
        run: zizmor --offline --format=github .github/workflows/
```

Sin `enable-cache`: no hay `uv.lock` que cachear, y `uv tool install` de un solo paquete tarda
segundos.

```bash
actionlint && zizmor --offline .github/workflows/ 2>/dev/null | tail -1
# No findings to report. Good job! (4 suppressed)
git add .github/workflows/lint-workflows.yml
git commit -m "ci: audit workflows with zizmor on every pr"
git push
sleep 10
id=$(gh run list --workflow lint-workflows.yml --commit "$(git rev-parse HEAD)" --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status > /dev/null; echo "exit $?"
# exit 0
```

**Verifica**: los dos jobs en verde y las órdenes de `zizmor-pinned`, `zizmor-annotations` y
`jobs-timeout` para este archivo.

```bash
gh run view "$id" --json jobs --jq '.jobs[] | "\(.name) \(.conclusion)"' | sort
# actionlint success
# zizmor success
yq '[.jobs.zizmor.steps[].run // ""] | join(" ")' .github/workflows/lint-workflows.yml
# uv tool install zizmor==1.31.1 zizmor --offline --format=github .github/workflows/
yq '.jobs // {} | to_entries | .[] | select(.value | has("timeout-minutes") | not) | .key' .github/workflows/lint-workflows.yml
# (sin salida)
```

---

## Paso 5: Ignorar un hallazgo, con motivo

**Por qué**: a veces zizmor señala algo que es correcto y aun así no es un riesgo. La salida de un
step que lee un archivo del propio commit no la controla nadie de fuera; zizmor no puede saberlo
y la marca con confianza baja. Para esos casos existe `# zizmor: ignore[<auditoría>]`, siempre con
una línea que diga **por qué** ([teoría 05](../1-teoria/05-zizmor.md#ignorar-un-hallazgo-con-motivo)).
Es un experimento: al final lo descartas, porque el arreglo correcto sigue siendo `env:`.

**Comando**: añade estos dos steps al final de `debug-lab.yml`, sin comitearlos.

```yaml
      - name: Leer la versión fijada
        id: pinned
        run: echo "value=$(cat api/.python-version)" >> "$GITHUB_OUTPUT"

      - name: Usar la versión leída
        run: echo "Fijada ${{ steps.pinned.outputs.value }}"
```

```bash
zizmor --offline .github/workflows/ 2>/dev/null | grep -E '^\w+\[|confidence'
# info[template-injection]: code injection via template expansion
#    = note: audit confidence → Low
zizmor --offline .github/workflows/ > /dev/null 2>&1; echo "exit $?"
# exit 11
```

Severidad informativa y confianza baja, pero la puerta se pondría roja igual. Cambia el último
step por este:

```yaml
      - name: Usar la versión leída
        # El valor sale de api/.python-version del propio commit: nadie de fuera lo controla.
        run: echo "Fijada ${{ steps.pinned.outputs.value }}" # zizmor: ignore[template-injection]
```

El comentario tiene que ser un comentario **de YAML**. Dentro de un `run: |` de varias líneas, un
`#` es parte del script de bash y zizmor no lo ve como excepción: por eso este `run:` es de una
línea.

**Verifica**: el hallazgo pasa a `ignored`, y `--no-ignores` lo saca de nuevo.

```bash
zizmor --offline .github/workflows/ 2>/dev/null | tail -1
# No findings to report. Good job! (1 ignored, 4 suppressed)
zizmor --offline --no-ignores .github/workflows/ 2>/dev/null | tail -1
# 5 findings (4 suppressed, 1 unsafe fixes): 1 informational, 0 low, 0 medium, 0 high
```

Ahora descarta el experimento. Un `ignore` es una deuda que alguien tiene que revisar con
`--no-ignores` de vez en cuando; si el arreglo de verdad cabe en tres líneas de `env:`, no se
ignora, se arregla.

```bash
git restore .github/workflows/debug-lab.yml
git status --short .github/
# (sin salida)
zizmor --offline .github/workflows/ > /dev/null 2>&1; echo "exit $?"
# exit 0
```

---

## ✅ Resultado

- [ ] Sabes qué enseña `regular`, qué añade `pedantic` y qué significa `suppressed`
- [ ] Provocaste un `template-injection` que actionlint no vio y lo corregiste con `env:`
- [ ] zizmor no encuentra hallazgos en ninguno de tus workflows
- [ ] `lint-workflows.yml` tiene el job `zizmor` con 1.31.1, `--offline` y `--format=github`
- [ ] Los dos jobs de `lint-workflows` terminaron en verde sobre `main`
- [ ] Probaste `# zizmor: ignore[...]` con motivo y lo descartaste

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 08
# ✅ zizmor no encuentra hallazgos en tus workflows
# ✅ El job zizmor instala zizmor 1.31.1 con uv tool install
# ✅ zizmor emite sus hallazgos como anotaciones (--format=github)
# ✅ lint-workflows.yml terminó en success sobre el último commit de main
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `zizmor: command not found` en local | `uv tool install` dejó el binario en `~/.local/bin`, fuera de tu `PATH` | `uv tool update-shell` y abre otra terminal |
| `zizmor: command not found` en CI | Falta `setup-uv`, que añade `~/.local/bin` al `PATH` | Paso 4: `setup-uv` antes de `uv tool install` |
| Verde en local y rojo en CI | Versiones distintas de zizmor | `zizmor --version` en local tiene que decir 1.31.1 |
| `failed to parse input: mapping values are not allowed` | Un `: ` dentro de un `run:` de una línea rompe el YAML | Pasa a `run: \|` o quita los dos puntos |
| El `ignore` no cuenta y el hallazgo sigue | El comentario está dentro de un `run: \|` | Paso 5: comentario de YAML en un `run:` de una línea |
| Hallazgos de `github-env` o `cache-poisoning` en un lab | El lab escribe en `$GITHUB_ENV` datos de fuera o cachea en un workflow que publica | Lee el enlace `audit documentation` del hallazgo: trae el arreglo |
| zizmor tarda o falla por red | Falta `--offline` y lanza las auditorías online | `--offline` en local y en CI hasta la Semana 12 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [actionlint y problem matchers](02-actionlint-y-problem-matchers.md) | [act en local](04-act-en-local.md) |
