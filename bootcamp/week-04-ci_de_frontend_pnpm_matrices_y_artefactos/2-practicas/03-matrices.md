# Práctica 03 — Matrices

> Un job escrito una vez y ejecutado con varias combinaciones: cuentas los jobs que genera, la
> rompes para ver qué cancela `fail-fast` y terminas con una matriz que calcula otro job.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `matrix-lab.yml`, con un job `unit` que corre en Node 24 y Node 26
- Un segundo eje, `exclude` e `include`, y saber contar de antemano cuántos jobs salen
- `fail-fast: true` frente a `false` con un fallo provocado, y qué hace `max-parallel`
- Una matriz dinámica: un job publica una lista JSON y otro la expande con `fromJSON`

## 📋 Antes de empezar

Terminaste la [práctica 02](02-pnpm-en-un-workflow.md): `web-lab.yml` está en `main`, en verde.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
```

Cada paso termina con un push y un run: una matriz solo se expande en GitHub y `actionlint` no
te dice cuántos jobs saldrán. Define en tu terminal esta función (dura lo que la sesión):

```bash
lab_run() {
  gh workflow run matrix-lab.yml
  sleep 5   # el run tarda unos segundos en aparecer en la lista
  id=$(gh run list --workflow matrix-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
  gh run watch "$id" --exit-status; echo "exit $?"
}
```

---

## Paso 1: Una matriz de un eje, con nombre

**Por qué**: el job `unit` es el mismo para Node 24 y Node 26. Con `strategy.matrix.node` lo
escribes una vez y GitHub crea un job por valor. El `name:` con `${{ matrix.node }}` dice en la UI
qué prueba cada uno; ese texto es también el nombre del check en las reglas de rama (Semana 18).

**Comando**: crea `.github/workflows/matrix-lab.yml`.

```yaml
name: matrix-lab

on:
  workflow_dispatch:

# Mínimo privilegio: el token solo lee. Lo verás a fondo en la Semana 12.
permissions:
  contents: read

defaults:
  run:
    shell: bash
    working-directory: web

jobs:
  unit:
    name: Unit (Node ${{ matrix.node }})
    runs-on: ubuntu-24.04
    strategy:
      matrix:
        node: [24, 26]
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413 # v6.1.0
        with:
          package_json_file: web/package.json
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version: ${{ matrix.node }}
          cache: pnpm
          cache-dependency-path: web/pnpm-lock.yaml
      - run: pnpm install --frozen-lockfile
      - run: pnpm test
```

```bash
actionlint .github/workflows/matrix-lab.yml
git add .github/workflows/matrix-lab.yml
git commit -m "ci(lab): add matrix-lab workflow"
git push
lab_run
```

**Verifica**:

```bash
gh run view "$id" --json jobs --jq '.jobs[] | [.name, .conclusion] | @tsv' | sort
# Unit (Node 24)	success
# Unit (Node 26)	success
```

---

## Paso 2: Un segundo eje, exclude e include

**Por qué**: con dos ejes GitHub hace el producto cartesiano. `exclude` quita combinaciones con
coincidencia parcial. `include` se procesa **después** y, entrada a entrada, o añade claves a las
combinaciones con las que encaja sin pisar un valor original, o crea una combinación nueva
(teoría 04, sección 2). El error típico es contar mal: aquí cuentas antes de lanzar.

**Comando**: sustituye `name:`, `strategy:` y el último step de `unit`.

```yaml
    name: Unit (Node ${{ matrix.node }}, ${{ matrix.reporter }})
    strategy:
      matrix:
        node: [24, 26]
        reporter: [default, dot]
        exclude:
          - node: 24
            reporter: dot
        include:
          - node: 26
            reporter: verbose
```

```yaml
      - name: Tests con el reporter de la combinación
        env:
          REPORTER: ${{ matrix.reporter }}
        run: |
          echo "node $(node --version), reporter ${REPORTER}"
          pnpm exec vitest run --reporter="$REPORTER"
```

Cuenta antes de lanzar: 2 × 2 = 4; `exclude` quita `24/dot` y quedan 3;
`{node: 26, reporter: verbose}` pisaría el valor original de `reporter` en las dos de Node 26, así
que no se añade a ninguna y crea una cuarta combinación.

```bash
actionlint .github/workflows/matrix-lab.yml
git commit -am "ci(lab): add reporter axis to matrix-lab"
git push
lab_run
```

**Verifica**:

```bash
gh run view "$id" --json jobs --jq '.jobs[].name' | sort
# Unit (Node 24, default)
# Unit (Node 26, default)
# Unit (Node 26, dot)
# Unit (Node 26, verbose)
```

---

## Paso 3: fail-fast, con un fallo provocado, y max-parallel

**Por qué**: `fail-fast` vale `true` por defecto. Con `true`, el primer job que falla cancela los
que siguen en curso o en cola, y no sabes si las demás combinaciones pasaban. Para verlo provocas
un fallo en **una** combinación sin tocar el código: Node 24 marcado con `broken: true`.

**Comando**: en `strategy` de `unit`, añade `fail-fast: true` (explícito, aunque sea el valor
por defecto) encima de `matrix:`, y una segunda entrada al final de `include`. Añade el step
`Fallo provocado` justo detrás del checkout y, de forma temporal, `- run: sleep 60` como último
step: solo sirve para que los demás jobs sigan vivos cuando falle el primero.

```yaml
          - node: 24
            broken: true
```

```yaml
      - name: Fallo provocado
        if: matrix.broken
        run: exit 1
```

```bash
actionlint .github/workflows/matrix-lab.yml
git commit -am "ci(lab): break node 24 on purpose"
git push
lab_run
# ...
# exit 1
gh run view "$id" --json jobs --jq '.jobs[] | [.name, .conclusion] | @tsv' | sort
# Unit (Node 24, default)	failure
# Unit (Node 26, default)	cancelled
# Unit (Node 26, dot)	cancelled
# Unit (Node 26, verbose)	cancelled
```

El `sleep` hace improbable, no imposible, que un job de Node 26 acabe antes del fallo. Y fíjate:
`{node: 24, broken: true}` no creó un quinto job. Es el otro comportamiento de `include`: no pisa
nada en `24/default`, así que le añade la clave `broken`.

Ahora cambia `fail-fast: true` por `fail-fast: false`, añade `max-parallel: 2` debajo y quita
el `sleep 60`:

```bash
git commit -am "ci(lab): disable fail-fast and cap parallelism"
git push
lab_run
# ...
# exit 1
```

**Verifica**:

```bash
gh run view "$id" --json jobs --jq '.jobs[] | [.name, .conclusion] | @tsv' | sort
# Unit (Node 24, default)	failure
# Unit (Node 26, default)	success
# Unit (Node 26, dot)	success
# Unit (Node 26, verbose)	success
gh run view "$id" --json jobs --jq '.jobs[] | [.startedAt, .name] | @tsv' | sort | cut -c12-19
# ...
```

Las horas exactas serán otras, pero nunca hay más de dos jobs en curso: cada uno arranca cuando
termina otro. El run sigue en rojo, pero ahora sabes **qué** falla: solo Node 24. `max-parallel`
no ahorra minutos; reparte los mismos en más tiempo de reloj.

---

## Paso 4: Una matriz que calcula otro job

**Por qué**: a veces no sabes la lista al escribir el YAML: un job por paquete, por archivo o,
aquí, por script de `package.json`. El patrón es de la Semana 02: un job escribe un array JSON en
`$GITHUB_OUTPUT` y lo expone en `outputs:`; otro lo convierte con `fromJSON` dentro de `matrix`.
Si mañana añades un script, el siguiente run tiene un job más sin tocar el workflow.

**Comando**: prueba en local la lista y añade dos jobs al final de `jobs:`.

```bash
jq -c '[.scripts | keys[] | select(. != "dev")]' web/package.json
# ["build","lint","test","test:coverage"]
```

```yaml
  discover-scripts:
    name: Descubrir scripts
    runs-on: ubuntu-24.04
    outputs:
      scripts: ${{ steps.list.outputs.scripts }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - id: list
        # jq -c deja el array en una línea: GITHUB_OUTPUT no admite saltos sin delimitador.
        run: |
          scripts=$(jq -c '[.scripts | keys[] | select(. != "dev")]' package.json)
          echo "scripts=$scripts" >> "$GITHUB_OUTPUT"
          echo "$scripts"

  script:
    name: pnpm run ${{ matrix.script }}
    needs: discover-scripts
    if: needs.discover-scripts.outputs.scripts != '[]'
    runs-on: ubuntu-24.04
    strategy:
      fail-fast: false
      matrix:
        script: ${{ fromJSON(needs.discover-scripts.outputs.scripts) }}
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
      - name: El script de esta combinación
        env:
          SCRIPT: ${{ matrix.script }}
        run: pnpm run "$SCRIPT"
```

`dev` queda fuera porque arranca un servidor que no termina. El `if` evita expandir una lista vacía. `actionlint` no sabe
qué valores tendrá `matrix.script`: solo existen en tiempo de ejecución.

```bash
actionlint .github/workflows/matrix-lab.yml
git commit -am "ci(lab): add dynamic matrix from package.json scripts"
git push
lab_run
# ...
# exit 1   (sigue en rojo por el broken del paso 3)
```

**Verifica**:

```bash
gh run view "$id" --json jobs \
  --jq '.jobs[] | select(.name | test("^(pnpm run|Descubrir)")) | [.name, .conclusion] | @tsv' | sort
# Descubrir scripts	success
# pnpm run build	success
# pnpm run lint	success
# pnpm run test	success
# pnpm run test:coverage	success
```

---

## Paso 5: Dejarlo en verde y lanzarlo

**Por qué**: un laboratorio en rojo esconde el siguiente fallo de verdad. Quitas la entrada
`broken` **y** el step que la lee: sin la entrada, `actionlint` avisa de que `matrix.broken` no
existe.

**Comando**: en `unit`, borra la entrada `{node: 24, broken: true}` del `include` y el step
`Fallo provocado`. `fail-fast: false` y `max-parallel: 2` se quedan.

```bash
grep -cE 'broken|sleep' .github/workflows/matrix-lab.yml
# 0
yq '.jobs.unit.strategy | [."fail-fast", ."max-parallel"] | join(",")' .github/workflows/matrix-lab.yml
# false,2
actionlint .github/workflows/matrix-lab.yml; echo "exit $?"
# exit 0
git commit -am "ci(lab): remove forced failure from matrix-lab"
git push
lab_run
# ...
# exit 0
```

**Verifica**:

```bash
gh run view "$id" --json jobs --jq '[.jobs[].conclusion] | unique | join(",")'
# success
gh run list --workflow matrix-lab.yml --event workflow_dispatch --status success \
  --json databaseId --jq length
# 1
```

Nueve jobs en verde (4 de `unit`, 1 de descubrimiento y 4 de `script`): `matrix-lab-dispatched`.

---

## ✅ Resultado

- [ ] `matrix-lab.yml` está en `main` y solo se lanza a mano
- [ ] Sabes contar los jobs de una matriz con `exclude` e `include` antes de lanzarla
- [ ] Has visto `fail-fast: true` cancelar las combinaciones sanas y `false` dejarlas terminar
- [ ] Sabes qué limita `max-parallel` y qué no ahorra
- [ ] `script` se expande desde un output JSON de `discover-scripts` con `fromJSON`
- [ ] Un run de `matrix-lab.yml` lanzado a mano terminó en `success`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 04
```

Ya pasan `web-package-manager`, `web-lab-dispatched` y `matrix-lab-dispatched`.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| Sale un job de más o de menos | Una entrada de `include` pisó un valor original y creó una combinación nueva | Repite la cuenta del paso 2 entrada a entrada |
| actionlint: `property "broken" is not defined in object type` | Quitaste la entrada `broken` pero no el step que la lee | Paso 5: quita también `Fallo provocado` |
| El job `script` falla antes de crear ningún job de la matriz | El output no es JSON válido o salió en varias líneas | Falta `-c` en `jq`; mira el `echo "$scripts"` del log de `discover-scripts` |
| `script` aparece como saltado | `discover-scripts` devolvió `[]` | El step `list` corre en `web/`: comprueba `defaults.run` |
| `lab_run` sale con `exit 1` en el paso 5 | Queda la entrada `broken`, el step `Fallo provocado` o el `sleep 60` | `grep -nE 'broken\|sleep' .github/workflows/matrix-lab.yml` no debe dar nada |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [pnpm en un workflow](02-pnpm-en-un-workflow.md) | [Artefactos entre jobs](04-artefactos-entre-jobs.md) |
