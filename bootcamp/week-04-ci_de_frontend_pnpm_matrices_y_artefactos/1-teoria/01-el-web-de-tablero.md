# El frontend de tablero

> Antes de escribir el CI de una aplicación tienes que saber qué hay dentro, qué comandos la
> comprueban y qué produce. Este archivo recorre `web/` entero y termina con la lista de lo que
> `ci-web.yml` tiene que ejecutar.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Describir la estructura de `web/` y para qué sirve cada archivo
- Explicar qué hace cada script de `package.json` y qué herramienta hay detrás
- Entender cómo se prueban los componentes sin navegador real y sin API
- Saber qué produce el build, dónde lo deja y quién lo usa después
- Decidir qué comandos tiene que correr el CI del frontend y cuáles no

## 1. Qué problema resuelve

En la Semana 03 el CI de la API corría en `api/`. El frontend vive al lado, en `web/`, y comparte
repositorio pero nada más: otro lenguaje (TypeScript), otro gestor de paquetes (pnpm), otro
runtime (Node) y otro lockfile (`web/pnpm-lock.yaml`). Si copias el job de la API y cambias
`uv` por `pnpm`, te faltará la mitad: aquí hay una comprobación de tipos que Python no tenía y un
build que produce archivos que otro job (y en la Semana 06, una imagen Docker) necesita.

Conocer la aplicación evita dos errores clásicos de CI de frontend:

- Ejecutar solo `vite build` y creer que los tipos están comprobados. No lo están: lo verás en el
  archivo 03.
- Correr comandos que en CI no tienen sentido, como `pnpm dev`, que arranca un servidor y nunca
  termina.

## 2. Cómo funciona

### Estructura de `web/`

```text
web/
├── package.json        dependencias, scripts, engines y packageManager
├── pnpm-lock.yaml      versión exacta e integridad de los 227 paquetes instalados
├── index.html          punto de entrada que Vite procesa
├── src/
│   ├── main.tsx        monta <App /> en #root
│   ├── App.tsx         lista, alta, marcado y borrado de tareas
│   └── api.ts          cliente HTTP de /api/tasks y la función pura pendingCount
├── tests/
│   ├── api.test.ts     prueba pendingCount, sin DOM
│   └── App.test.tsx    renderiza App con fetch simulado
├── eslint.config.js    configuración plana de ESLint
├── tsconfig.json       TypeScript estricto, sin emitir archivos
├── vite.config.ts      plugin de React, proxy de desarrollo y configuración de Vitest
├── nginx.conf          sirve dist/ y reenvía /api/ a la API (Semana 06)
├── Dockerfile          build multi-stage: Node y pnpm solo en la etapa de build
└── .dockerignore       node_modules, dist y coverage fuera del contexto de Docker
```

Es una aplicación React mínima: una pantalla que lista las tareas de la API, cuenta las
pendientes y permite añadir, marcar y borrar. `api.ts` concentra todas las llamadas HTTP en una
función `request` que lanza un error si la respuesta no es `ok`.

### `package.json`: los campos que le importan al CI

```json
{
  "packageManager": "pnpm@12.16.1",
  "engines": { "node": ">=24" },
  "scripts": {
    "dev": "vite",
    "build": "tsc --noEmit && vite build",
    "lint": "eslint .",
    "test": "vitest run",
    "test:coverage": "vitest run --coverage"
  }
}
```

- **`packageManager`** fija la versión exacta de pnpm. pnpm 12 la respeta: si ejecutas otra
  versión dentro de `web/`, cambia a la declarada (archivo 02). `pnpm/action-setup` la lee de
  aquí si no le das `version`.
- **`engines.node: ">=24"`** es una promesa: la aplicación funciona con Node 24 y con cualquier
  versión posterior. El CI tiene que comprobarla en más de una versión, y para eso existe la
  matriz del archivo 04.
- **`scripts`** son la interfaz entre el proyecto y el CI. El workflow ejecuta `pnpm lint`,
  `pnpm test` y `pnpm build`, no los binarios a mano: si mañana cambias de herramienta, cambias
  el script y el workflow sigue igual.

| Script | Herramienta | Qué comprueba o produce | ¿En CI? |
|---|---|---|:--:|
| `dev` | Vite | Servidor de desarrollo con recarga y proxy a la API | ❌ Nunca termina |
| `lint` | ESLint 10 | Errores de estilo y de uso de React Hooks en `src/` y `tests/` | ✅ |
| `test` | Vitest 5 | Los 4 tests de `tests/` en un DOM simulado | ✅ |
| `test:coverage` | Vitest + v8 | Lo mismo, con informe de cobertura en `coverage/` | Opcional |
| `build` | TypeScript 6 + Vite 8 | Tipos correctos y bundle de producción en `dist/` | ✅ |

### Los tests: sin navegador y sin API

`vite.config.ts` configura Vitest con `environment: "jsdom"`: los tests corren en Node, pero con
un `document` y un `window` simulados en JavaScript. Testing Library renderiza `<App />` en ese
DOM y busca elementos por texto o etiqueta, como lo haría una persona.

La API no existe en el runner. `App.test.tsx` sustituye el `fetch` global por una función de
Vitest que devuelve respuestas preparadas en orden:

```tsx
function mockFetch(responses: unknown[]) {
  const queue = [...responses];
  return vi.fn(async () => new Response(JSON.stringify(queue.shift()), { status: 200 }));
}

vi.stubGlobal("fetch", mockFetch([[{ id: 1, title: "escribir ci.yml", done: false, created_at: "" }]]));
```

`afterEach` deshace el cambio con `vi.unstubAllGlobals()` y limpia el DOM con `cleanup()`. Es el
mismo principio que los dobles en memoria de la API en la Semana 03: los tests unitarios no
dependen de nada que el job no controle. La integración real con la API llega más adelante.

`include: ["tests/**/*.test.{ts,tsx}"]` limita qué archivos son tests, y la cobertura mide solo
`src/**` salvo `main.tsx`, que solo monta la aplicación.

### El build: `dist/`

`pnpm build` hace dos cosas en orden: `tsc --noEmit` comprueba los tipos de `src`, `tests` y
`vite.config.ts` sin generar nada, y `vite build` empaqueta la aplicación. El resultado:

```bash
pnpm build
# $ tsc --noEmit && vite build
# vite v8.3.5 building client environment for production...
# ✓ 16 modules transformed.
# dist/index.html                  0.31 kB │ gzip:  0.22 kB
# dist/assets/index-B_X_rmRw.js  221.09 kB │ gzip: 69.26 kB
# ✓ built in 144ms
```

`dist/` son dos archivos estáticos. El nombre del JavaScript lleva un hash de su contenido: si
cambia el código, cambia el nombre, y un navegador nunca usa una versión vieja de la caché.

### Quién usa `dist/`: nginx

`nginx.conf` sirve `dist/` en el puerto 8080, reenvía `/api/` al servicio `api` y devuelve
`index.html` para cualquier otra ruta. El `Dockerfile` construye `dist/` en una etapa con Node y
pnpm y copia solo el resultado a una imagen de nginx sin privilegios. Lo usarás en la Semana 06;
esta semana basta con saber que **`dist/` es lo que se despliega**, y por eso el CI lo guarda como
artefacto (archivo 05).

## 3. Cómo se usa

Lo que tiene que hacer el CI del frontend, deducido de lo anterior:

1. Instalar exactamente `pnpm-lock.yaml`: `pnpm install --frozen-lockfile` (archivo 02).
2. `pnpm lint`. Basta con una versión de Node: ESLint analiza el código, no lo ejecuta.
3. `pnpm test` en cada versión de Node que `engines` promete: Node 24 y Node 26.
4. `pnpm build`, solo si lo anterior pasó, y guardar `web/dist` como artefacto.

Pruébalo en tu máquina antes de escribir una línea de YAML. Desde `web/`:

```bash
pnpm install --frozen-lockfile
pnpm lint
pnpm test
pnpm build
ls dist dist/assets
# assets  index.html
# index-B_X_rmRw.js
```

Si algo falla en local, fallará en el runner. Al revés no siempre: el runner empieza sin
`node_modules`, sin `dist/` y con la versión de Node que tú le pidas, no la que tengas instalada.

Verificado con pnpm 12.16.1, Node 24.19.0 y Vitest 5.0.5 en local, noviembre de 2026.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Ejecutar `pnpm dev` en CI | Arranca un servidor que no termina: el job se queda colgado | `pnpm build` y, si quieres servirlo, otro job o la imagen de la S06 |
| Solo `vite build`, sin `tsc --noEmit` | Vite no comprueba tipos: un error de tipos llega a `main` en verde | El script `build` completo |
| Llamar a `node_modules/.bin/vitest` en el workflow | El workflow y `package.json` divergen | `pnpm test`; el script es la interfaz |
| Tests que llaman a la API real | Fallan en el runner, donde no hay API, o dependen de datos | `vi.stubGlobal("fetch", ...)` como en `App.test.tsx` |
| Comitear `dist/` o `coverage/` | Archivos generados que nadie revisa y que divergen del código | `.gitignore` y artefactos |
| Probar solo la versión de Node que tienes instalada | `engines` promete más de lo que se comprueba | Matriz con las versiones que promete `engines` |

## 5. Trucos

- **`pnpm run`** sin argumentos lista los scripts de `package.json` con su comando: es lo primero
  que miras en un frontend que no conoces.
- **`pnpm why <paquete>`** explica por qué está instalado un paquete transitivo. Con
  `pnpm why react-is` ves que llega por `pretty-format`, que trae `@testing-library/dom`.
- **`pnpm exec vitest run tests/api.test.ts`** ejecuta un solo archivo de test: útil para aislar
  el que falla antes de mirar el log del CI.

## 📚 Recursos Adicionales

- [Vite: Building for production](https://vite.dev/guide/build)
- [Vitest: Test environment](https://vitest.dev/guide/environment)
- [Testing Library: React](https://testing-library.com/docs/react-testing-library/intro/)
- [pnpm: package.json](https://pnpm.io/package_json)

## ✅ Checklist de Verificación

- [ ] Sé qué archivo de `web/` contiene la lógica que se prueba sin DOM
- [ ] Sé qué hace cada script de `package.json` y cuál no va en CI
- [ ] Sé por qué los tests no necesitan la API ni un navegador
- [ ] Sé que `pnpm build` comprueba tipos antes de empaquetar
- [ ] Sé qué produce el build y quién lo consume después
- [ ] He ejecutado `install`, `lint`, `test` y `build` en local sin errores

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Semana 04](../README.md) | [pnpm en CI](02-pnpm-en-ci.md) |
