# Tests y build del frontend

> Cuatro herramientas comprueban el frontend y cada una ve una cosa distinta: ESLint el estilo y
> las reglas de React, Vitest el comportamiento, TypeScript los tipos y Vite que se pueda
> empaquetar. Este archivo enseña qué rompe cada una y cómo se lee su fallo en un log.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Leer la configuración plana de ESLint de `web/` y reconocer sus errores
- Ejecutar Vitest en modo CI y leer un test fallido
- Medir cobertura con el proveedor v8 y exigir un mínimo desde la línea de comandos
- Explicar por qué `tsc --noEmit` va antes de `vite build` y qué pasa si falta
- Ordenar las comprobaciones de un job para que el fallo salga lo antes posible

## 1. Qué problema resuelve

En la API, ruff y pytest cubrían estilo y comportamiento. En el frontend aparece un hueco nuevo:
**los tipos**. TypeScript los comprueba, pero Vite, el empaquetador, no: quita las anotaciones y
empaqueta lo que haya. Si el CI solo ejecuta `vite build`, un error de tipos llega a `main` en
verde. Lo demuestro en la sección 2.

El otro problema es leer los fallos. Cada herramienta escribe distinto y sale con un código
distinto; en un log de 300 líneas tienes que saber qué buscar.

## 2. Cómo funciona

### ESLint: configuración plana

`web/` usa la configuración plana de ESLint 10: un `eslint.config.js` que exporta una lista de
objetos que se aplican en orden. La de `tablero`:

```js
export default tseslint.config(
  { ignores: ["dist", "coverage"] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  reactHooks.configs.flat.recommended,
  { languageOptions: { globals: globals.browser } },
);
```

| Bloque | Qué aporta |
|---|---|
| `ignores` | No analiza lo generado. Sin esto, el JavaScript de `dist/` llenaría el log de errores |
| `js.configs.recommended` | Reglas básicas de JavaScript |
| `tseslint.configs.recommended` | Reglas para TypeScript, como `no-unused-vars` con tipos |
| `reactHooks.configs.flat.recommended` | Las reglas de los Hooks: orden fijo y dependencias |
| `globals.browser` | `window`, `document` y `fetch` existen: no los marca como no definidos |

Dos fallos reales provocados a propósito en `src/`:

```bash
pnpm lint
# $ eslint .
#
# /home/<tú>/code/tablero/web/src/api.ts
#   28:7  error  'unused' is assigned a value but never used  @typescript-eslint/no-unused-vars
#
# ✖ 1 problem (1 error, 0 warnings)
#
# [ELIFECYCLE] Command failed with exit code 1.
```

```bash
pnpm lint
# /home/<tú>/code/tablero/web/src/Bad.tsx
#   4:17  error  React Hook "useState" is called conditionally. React Hooks must be called in
#   the exact same order in every component render. Did you accidentally call a React Hook
#   after an early return?  react-hooks/rules-of-hooks
```

Cada línea dice archivo, `línea:columna`, gravedad, mensaje y regla. El nombre de la regla es lo
que buscas en la documentación. Con un `error` ESLint sale con 1 y el step falla; con solo
`warning` sale con 0.

### Vitest: `vitest run`

`vitest` a secas elige el modo según dónde corre: en una terminal interactiva entra en modo
*watch* y espera cambios; sin terminal o con `CI=true` ejecuta una vez y sale. Lo comprobé con las
dos variantes. El script `test` usa `vitest run` para no depender de esa detección, por la misma
razón que escribes `--frozen-lockfile`. En verde:

```bash
pnpm test
#  Test Files  2 passed (2)
#       Tests  4 passed (4)
#    Duration  698ms (environment 82%, import 8%, tests 5%, transform 4%, worker 1%)
```

El 82 % del tiempo es `environment`: montar jsdom. Es normal en tests de componentes.

Con un error en `pendingCount` (cuenta las terminadas en vez de las pendientes):

```bash
pnpm test
#  FAIL  tests/api.test.ts > pendingCount > cuenta solo las tareas sin terminar
# AssertionError: expected 1 to be 2 // Object.is equality
#
# - Expected
# + Received
#
# - 2
# + 1
#
#  ❯ tests/api.test.ts:13:75
#
#  Test Files  2 failed (2)
#       Tests  2 failed | 2 passed (4)
echo $?
# 1
```

Fíjate en que fallan **dos** tests: el de `api.test.ts` y el de `App.test.tsx`, que muestra el
contador. Un solo error en la lógica, dos síntomas. Empieza siempre por el test más pequeño: el
que prueba la función pura te dice la causa; el del componente, solo la consecuencia.

### Cobertura con v8

`@vitest/coverage-v8` usa la cobertura que mide el propio motor V8 de Node, sin instrumentar el
código. `pnpm test:coverage` escribe la tabla en el log y el informe HTML en `coverage/`:

```text
File      | % Stmts | % Branch | % Funcs | % Lines | Uncovered Line #s
----------|---------|----------|---------|---------|-------------------
All files |   59.45 |    33.33 |      50 |   68.96 |
 App.tsx  |   53.84 |    33.33 |      40 |   68.42 | 22-28,45-48
 api.ts   |   72.72 |    33.33 |   71.42 |      70 | 14,24-25
```

`vite.config.ts` no define umbral. Puedes exigirlo desde la línea de comandos, igual que
`--cov-fail-under` en pytest:

```bash
pnpm exec vitest run --coverage --coverage.thresholds.lines=80
# ERROR: Coverage for lines (68.96%) does not meet global threshold (80%)
echo $?
# 1
```

### TypeScript: `tsc --noEmit`

`tsconfig.json` activa `strict`, `noUnusedLocals` y `noUnusedParameters`, e incluye `src`,
`tests` y `vite.config.ts`. `--noEmit` comprueba sin generar archivos: el JavaScript lo produce
Vite.

Con `pendingCount` devolviendo un `string` cuando su firma dice `number`:

```bash
pnpm build
# $ tsc --noEmit && vite build
# src/api.ts(29,3): error TS2322: Type 'string' is not assignable to type 'number'.
# [ELIFECYCLE] Command failed with exit code 2.
```

Y con el **mismo** error, solo `vite build`:

```bash
pnpm exec vite build
# dist/assets/index-CnPL2meo.js  221.10 kB │ gzip: 69.27 kB
# ✓ built in 127ms
```

Verde. Vite transforma cada archivo por separado y descarta los tipos sin comprobarlos; es lo que
lo hace rápido. Por eso el script `build` encadena los dos con `&&`: si `tsc` falla, `vite build`
ni empieza.

### Vite: `vite build`

Lo que puede romper el empaquetado sin que lo vea `tsc` es poco en este proyecto: un import de un
archivo que no existe en `index.html`, un plugin mal configurado o una dependencia que no se puede
resolver. Su salida en verde la viste en el archivo 01. Lo importante para el CI es **qué deja**:
`web/dist/`, que el archivo 05 convierte en artefacto.

## 3. Cómo se usa

Un job que pasa las cuatro comprobaciones en orden, de la más barata a la más cara:

```yaml
name: web-checks

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  checks:
    name: Comprobaciones del frontend
    runs-on: ubuntu-24.04
    defaults:
      run:
        working-directory: web
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
      - name: Lint
        run: pnpm lint
      - name: Tests con umbral de cobertura
        run: pnpm exec vitest run --coverage --coverage.thresholds.lines=60
      - name: Tipos
        run: pnpm exec tsc --noEmit
      - name: Build
        run: pnpm exec vite build
```

Separar `tsc` y `vite build` en dos steps no cambia lo que se comprueba, pero en la UI ves de un
vistazo cuál de los dos falló. Un step que falla salta todos los siguientes: con ESLint en rojo,
no sabrás si los tests pasan. Esa es la razón de partir lint, tests y build en jobs distintos,
como hace `ci-web.yml`: cada uno informa por su cuenta.

Verificado con ESLint 10.14.0, Vitest 5.0.5, TypeScript 6.0.3 y Vite 8.3.5 en local, y con
actions/setup-node@v7.1.0 y ubuntu-24.04, noviembre de 2026.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `vitest` sin `run` | El modo depende de la detección de terminal y de `CI`; en tu máquina se queda en *watch* | `vitest run`, el script `test` |
| Solo `vite build` | Los errores de tipos pasan en verde | `tsc --noEmit` antes, como en el script `build` |
| Quitar `ignores` de ESLint | Analiza `dist/` y `coverage/` y llena el log de falsos errores | Ignorar todo lo generado |
| Bajar errores a `warning` para que el CI pase | ESLint sale con 0 y el problema se queda | Arreglarlo o desactivar la regla con un comentario que diga por qué |
| Exigir un umbral de cobertura que no se cumple hoy | El CI nace rojo y alguien lo quita | Fijar el umbral en lo que hay y subirlo con cada test |
| Leer solo el último test que falla | Suele ser la consecuencia, no la causa | Empezar por el test de la función más pequeña |

## 5. Trucos

- **`pnpm exec vitest run --reporter verbose`** imprime cada test con su tiempo, no solo el
  total: sirve para encontrar el test lento.
- **`pnpm exec eslint . --max-warnings 0`** convierte los avisos en fallo sin tocar la
  configuración: útil para endurecer el CI poco a poco.
- **`pnpm exec tsc --noEmit --pretty false`** da una línea por error, sin colores ni contexto:
  más fácil de copiar del log o de filtrar con `grep`.

## 📚 Recursos Adicionales

- [ESLint: Configuration files](https://eslint.org/docs/latest/use/configure/configuration-files)
- [Vitest: Coverage](https://vitest.dev/guide/coverage)
- [TypeScript: `noEmit`](https://www.typescriptlang.org/tsconfig/#noEmit)
- [Vite: Transpile only](https://vite.dev/guide/features#transpile-only)

## ✅ Checklist de Verificación

- [ ] Sé qué aporta cada bloque de `eslint.config.js`
- [ ] Sé leer archivo, línea, mensaje y regla en un error de ESLint
- [ ] Ejecuto Vitest con `run` y sé leer un `AssertionError`
- [ ] Sé exigir un umbral de cobertura desde la línea de comandos
- [ ] Sé demostrar que `vite build` no comprueba tipos
- [ ] Ordeno las comprobaciones de la más barata a la más cara

---

| ← Anterior | Siguiente → |
|:---|---:|
| [pnpm en CI](02-pnpm-en-ci.md) | [Matrices](04-matrices.md) |
