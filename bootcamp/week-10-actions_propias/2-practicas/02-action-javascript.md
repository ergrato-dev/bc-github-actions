# Práctica 02 — Una action JavaScript

> La cobertura de la web se mide en cada run de Vitest, pero nadie la ve si no abre el log. En
> esta práctica escribes `coverage-report`, una action JavaScript que la pone en el resumen del
> job, la devuelve como output y falla si baja del mínimo.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- Un paquete pnpm en `.github/actions/coverage-report/` con `@actions/core` y esbuild fijados
- La decisión (pasa o no pasa) en una función pura con tres tests de `node:test`
- `main` y `post` ejecutados con `node24` desde `dist/`, comiteado sin `node_modules`
- La action ejecutada a mano, con los mismos archivos de entorno que le da el runner

## 📋 Antes de empezar

Terminaste la [práctica 01](01-primera-action-composite.md): `setup-tablero` está en `main`.
Esta práctica, la 03 y la 04 van en la misma rama; la 04 abre el PR.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git switch -c ci/own-actions
mkdir -p .github/actions/coverage-report/{src,tests}
pnpm --version
# 12.16.1
```

---

## Paso 1: El paquete y su lockfile

**Por qué**: el runner no instala dependencias de una action JavaScript: ejecuta el archivo de
`main` tal cual ([teoría 04](../1-teoria/04-empaquetar-dist-con-pnpm.md)). Así que
`@actions/core` y esbuild son dependencias **tuyas**, de desarrollo, y se fijan como las de
`web/`: versión exacta, `packageManager` y lockfile. `"type": "module"` deja escribir `src/` con
`import`.

**Comando**: crea `.github/actions/coverage-report/package.json`.

```json
{
  "name": "coverage-report",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "packageManager": "pnpm@12.16.1",
  "description": "Publica la cobertura de líneas en el resumen del job y falla si baja del mínimo",
  "scripts": {
    "build": "esbuild src/index.js src/post.js --bundle --platform=node --target=node24 --format=cjs --out-extension:.js=.cjs --outdir=dist",
    "test": "node --test"
  },
  "dependencies": {
    "@actions/core": "3.0.1"
  },
  "devDependencies": {
    "esbuild": "0.28.2"
  }
}
```

```bash
cd .github/actions/coverage-report
pnpm install 2>&1 | grep -E 'ERR_|Ignored'
# Error: ERR_PNPM_IGNORED_BUILDS
#   ╰─▶ Ignored build scripts: esbuild@0.28.2
```

pnpm 12 no ejecuta scripts de instalación que no apruebes, y para en vez de seguir. esbuild trae
su binario como dependencia opcional por plataforma: su `postinstall` sobra. Dilo en
`pnpm-workspace.yaml`, y deja `node_modules` fuera de git:

```yaml
# esbuild trae su binario como dependencia opcional: su postinstall no hace falta.
allowBuilds:
  esbuild: false
```

```bash
printf 'node_modules/\n' > .gitignore
pnpm install 2>&1 | grep -E '^\+'
# + @actions/core 3.0.1
# + esbuild 0.28.2
```

**Verifica**: la orden de `coverage-pnpm`, desde la carpeta de la action.

```bash
jq -r '.packageManager + " " + .dependencies["@actions/core"]' package.json && test -f pnpm-lock.yaml && echo "lockfile ok"
# pnpm@12.16.1 3.0.1
# lockfile ok
```

---

## Paso 2: La lógica, pura y probada

**Por qué**: lo que se puede equivocar (leer el porcentaje, compararlo con el mínimo, rechazar un
JSON que no es el esperado) va en una función sin E/S. Se prueba con `node --test`, que viene con
Node, sin runner ni `@actions/core` de por medio
([teoría 07](../1-teoria/07-probar-actions.md)).

**Comando**: crea `src/evaluate.js`:

```js
// Decide si la cobertura de líneas llega al mínimo. Pura (sin E/S) para poder probarla con node --test.
export function evaluate(total, minimum) {
  const percent = Number(total?.lines?.pct);
  if (!Number.isFinite(percent)) {
    throw new Error("El resumen no trae total.lines.pct: ¿es un coverage-summary.json de Istanbul o Vitest?");
  }
  return { percent, ok: percent >= minimum };
}
```

Y `tests/evaluate.test.js`, con el borde exacto, uno por debajo y el JSON equivocado:

```js
import assert from "node:assert/strict";
import { test } from "node:test";
import { evaluate } from "../src/evaluate.js";

test("pasa cuando llega al mínimo", () => {
  assert.deepEqual(evaluate({ lines: { pct: 60 } }, 60), { percent: 60, ok: true });
});

test("falla por debajo del mínimo", () => {
  assert.equal(evaluate({ lines: { pct: 59.9 } }, 60).ok, false);
});

test("rechaza un resumen sin total.lines.pct", () => {
  assert.throws(() => evaluate({}, 60), /total\.lines\.pct/);
});
```

**Verifica**: `node --test` encuentra `tests/*.test.js` sin que se lo digas.

```bash
pnpm test 2>&1 | grep -E '^(✔|ℹ (pass|fail))'
# ✔ pasa cuando llega al mínimo (1.036052ms)
# ✔ falla por debajo del mínimo (0.133169ms)
# ✔ rechaza un resumen sin total.lines.pct (0.311496ms)
# ℹ pass 3
# ℹ fail 0
```

---

## Paso 3: `main`, `post` y el `action.yml`

**Por qué**: `main` lee los inputs con `core.getInput`, escribe la tabla en el resumen con
`core.summary`, deja el porcentaje con `core.setOutput` y, si no llega, marca el step con
`core.setFailed` ([teoría 03](../1-teoria/03-actions-javascript.md)). `post` corre al final del
job aunque `main` haya fallado, y es un proceso aparte: lo único que comparte con `main` es lo
que este guardó con `core.saveState` en `$GITHUB_STATE`
([teoría 05](../1-teoria/05-pre-post-y-estado.md)).

**Comando**: crea `src/index.js`:

```js
import { readFile } from "node:fs/promises";
import * as core from "@actions/core";
import { evaluate } from "./evaluate.js";

async function run() {
  // Estado para el paso post: llega a post.js por $GITHUB_STATE como STATE_started.
  core.saveState("started", String(Date.now()));

  const file = core.getInput("summary-file", { required: true });
  const minimum = Number(core.getInput("minimum"));
  if (!Number.isFinite(minimum)) {
    core.setFailed(`minimum debe ser un número y es '${core.getInput("minimum")}'`);
    return;
  }

  const { total } = JSON.parse(await readFile(file, "utf8"));
  const { percent, ok } = evaluate(total, minimum);

  const head = [{ data: "Métrica", header: true }, { data: "Cobertura", header: true }];
  const rows = ["lines", "statements", "functions", "branches"].map((k) => [k, `${total[k].pct}%`]);
  await core.summary.addHeading("Cobertura de la web", 2).addTable([head, ...rows]).write();

  core.setOutput("percent", String(percent));
  if (!ok) core.setFailed(`Cobertura de líneas ${percent}% por debajo del mínimo ${minimum}%`);
}

run().catch((error) => core.setFailed(error.message));
```

`src/post.js`:

```js
import * as core from "@actions/core";

// Corre al final del job aunque main haya fallado (post-if por defecto: always()).
const started = Number(core.getState("started"));
if (started) core.info(`coverage-report: ${Date.now() - started} ms entre el inicio de main y este post`);
```

Y `action.yml`. El output `percent` no lleva `value:`: en una action JavaScript lo escribe el
código, no una expresión.

```yaml
name: coverage-report
description: Lee un coverage-summary.json, publica la cobertura en el resumen del job y falla si las líneas bajan del mínimo
inputs:
  summary-file:
    description: Ruta al coverage-summary.json (reporter json-summary de Vitest o Istanbul)
    required: true
  minimum:
    description: Cobertura de líneas mínima, en porcentaje
    default: "60"
outputs:
  percent:
    description: Cobertura de líneas leída, en porcentaje
runs:
  using: node24
  main: dist/index.cjs
  post: dist/post.cjs
```

**Verifica**: las órdenes de `coverage-main-post` y `coverage-state`.

```bash
yq '.runs.using + " " + .runs.main + " " + .runs.post' action.yml
# node24 dist/index.cjs dist/post.cjs
{ grep -c 'core.saveState(' src/index.js && grep -c 'core.getState(' src/post.js; } | paste -sd' '
# 1 1
```

---

## Paso 4: `dist/`, al repo; `node_modules`, no

**Por qué**: `main: dist/index.cjs` tiene que existir en el commit que el runner descarga, con
`@actions/core` dentro. esbuild lo empaqueta todo en un archivo por punto de entrada. Sale en
CommonJS porque las dependencias de `@actions/core` usan `require`: un bundle ESM rompe al
arrancar. Y la extensión `.cjs` hace falta porque el paquete es `"type": "module"`: con `.js`,
Node lo trataría como ESM ([teoría 04](../1-teoria/04-empaquetar-dist-con-pnpm.md)).

**Comando**:

```bash
pnpm build 2>&1 | grep dist/
#   dist/index.cjs  804.8kb
#   dist/post.cjs   799.3kb
git add .
git status --short .
# A  .gitignore
# A  action.yml
# A  dist/index.cjs
# A  dist/post.cjs
# A  package.json
# A  pnpm-lock.yaml
# A  pnpm-workspace.yaml
# A  src/evaluate.js
# A  src/index.js
# A  src/post.js
# A  tests/evaluate.test.js
git commit -m "ci: add coverage-report javascript action"
```

Unos 800 kB cada uno: es `@actions/core` con todo lo que arrastra. `node_modules` no aparece:
lo para el `.gitignore` del paso 1.

**Verifica**: lo mismo que mira `coverage-dist-committed`: dos archivos en `dist/` y ninguno
en `node_modules/`.

```bash
git ls-files dist node_modules | cut -d/ -f1 | sort | uniq -c
#       2 dist
```

---

## Paso 5: Ejecutarla a mano, como el runner

**Por qué**: el runner le pasa a una action JavaScript los inputs como variables
`INPUT_<NOMBRE EN MAYÚSCULAS>`, con el guion intacto, y tres archivos donde escribir: output,
estado y resumen. Si los das tú, `node` ejecuta la action igual que en el job, y ves qué
escribe en cada archivo ([teoría 05](../1-teoria/05-pre-post-y-estado.md)). Una variable con
guion no se puede escribir como `VAR=x` en bash: `env` sí la acepta.

**Comando**: genera la cobertura de la web y ejecuta `main` desde la raíz del repo.

```bash
cd ~/code/tablero
(cd web && pnpm install --frozen-lockfile --silent && pnpm test:coverage --coverage.reporter=json-summary > /dev/null)
d=$(mktemp -d); touch "$d/out" "$d/state" "$d/summary"
export GITHUB_OUTPUT="$d/out" GITHUB_STATE="$d/state" GITHUB_STEP_SUMMARY="$d/summary"
env 'INPUT_SUMMARY-FILE=web/coverage/coverage-summary.json' INPUT_MINIMUM=60 node .github/actions/coverage-report/dist/index.cjs; echo "exit $?"
# exit 0
env 'INPUT_SUMMARY-FILE=web/coverage/coverage-summary.json' INPUT_MINIMUM=80 node .github/actions/coverage-report/dist/index.cjs; echo "exit $?"
# ::error::Cobertura de líneas 68.96%25 por debajo del mínimo 80%25
# exit 1
INPUT_MINIMUM=60 node .github/actions/coverage-report/dist/index.cjs; echo "exit $?"
# ::error::Input required and not supplied: summary-file
# exit 1
```

El `%25` es `%` codificado: en un comando de workflow, `%` se escapa, y el runner lo vuelve a
convertir antes de enseñarlo.

**Verifica**: el output, el estado con su delimitador y lo que `post` lee de él.

```bash
sed -n 2p "$d/out"
# 68.96
head -1 "$d/state" | cut -d_ -f1
# started<<ghadelimiter
STATE_started=$(sed -n 2p "$d/state") node .github/actions/coverage-report/dist/post.cjs
# coverage-report: 135 ms entre el inicio de main y este post
grep -o '<h2>[^<]*</h2>' "$d/summary" | head -1
# <h2>Cobertura de la web</h2>
unset GITHUB_OUTPUT GITHUB_STATE GITHUB_STEP_SUMMARY
```

Los milisegundos cambian en cada ejecución. En el runner, `STATE_started` la pone él al lanzar
el `post`, leyendo `$GITHUB_STATE`; aquí la pones tú.

---

## ✅ Resultado

- [ ] `coverage-report` tiene `package.json` con `packageManager` y versiones exactas, y `pnpm-lock.yaml`
- [ ] Los tres tests de `evaluate` pasan con `pnpm test`
- [ ] `action.yml` ejecuta `dist/index.cjs` como `main` y `dist/post.cjs` como `post`, con `node24`
- [ ] `dist/` está comiteado y `node_modules`, no
- [ ] Viste el `::error::` con 80 y el mensaje de `post` leído del estado

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 10
# ✅ coverage-report ejecuta dist/index.cjs como main y dist/post.cjs como post
# ✅ coverage-report fija @actions/core y pnpm, y trae su pnpm-lock.yaml
# ✅ El main de coverage-report guarda estado con saveState y el post lo lee con getState
# ✅ dist/index.cjs y dist/post.cjs de coverage-report están en el repo y node_modules no
# ✅ Los tests de coverage-report pasan con pnpm test
# ...
```

`sql-lint` y el uso de las actions en los workflows siguen en rojo: prácticas 03 y 04.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `ERR_PNPM_IGNORED_BUILDS` con `esbuild@0.28.2` | Falta `pnpm-workspace.yaml` con `allowBuilds` | Paso 1 |
| `Error: Dynamic require of "net" is not supported` | `build` con `--format=esm`: las dependencias de `@actions/core` usan `require` | Paso 1: `--format=cjs` en el script `build` |
| `ReferenceError: require is not defined in ES module scope` | Bundle CommonJS con extensión `.js` en un paquete `"type": "module"` | `--out-extension:.js=.cjs` y `main: dist/index.cjs` |
| El step de la action falla en el run porque no encuentra `dist/index.cjs` | `dist/` no está comiteado o el `.gitignore` lo excluye | Paso 4: `pnpm build` y `git add dist` |
| `git status` enseña miles de archivos de `node_modules` | Falta el `.gitignore` de la action | Paso 1: `printf 'node_modules/\n' > .gitignore` |
| `post` no imprime nada | `main` no llegó a `saveState` o la clave no coincide | Paso 3: la misma clave `started` en los dos archivos |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Primera action composite](01-primera-action-composite.md) | [Una action Docker](03-action-docker.md) |
