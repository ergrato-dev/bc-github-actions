# pnpm en CI

> El frontend se instala con pnpm, y el CI solo es reproducible si instala exactamente lo que dice
> `pnpm-lock.yaml`. Este archivo explica cómo guarda pnpm los paquetes, qué hace
> `--frozen-lockfile` y cómo llegan pnpm y Node al runner, en ese orden.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar el store direccionado por contenido de pnpm y los enlaces de `node_modules`
- Decir qué hace `pnpm install --frozen-lockfile` cuando el lockfile no casa con `package.json`
- Fijar la versión de pnpm con `packageManager` y leerla desde `pnpm/action-setup`
- Preparar Node con `actions/setup-node` y cachear el store de pnpm con `cache: pnpm`
- Explicar por qué `pnpm/action-setup` va antes que `actions/setup-node`

## 1. Qué problema resuelve

`package.json` dice qué acepta el proyecto: `"vite": "^8.3.5"`. Eso es un rango, igual que
`fastapi>=0.162.0` en la API. Si el CI resuelve el rango en cada run, instala lo último que haya
publicado ese día, y nadie lo revisó. `pnpm-lock.yaml` cierra el rango: para cada uno de los 227
paquetes guarda versión exacta e integridad (un hash SHA-512 del tarball).

El segundo problema es el tiempo. Un frontend moderno arrastra cientos de paquetes; con
`web/node_modules` en 160 MB, descargarlos y copiarlos en cada job se nota. pnpm ataca eso con su
store y Actions con la caché.

## 2. Cómo funciona

### El store y los enlaces

pnpm no copia cada paquete en cada proyecto. Lo descarga una vez a un **store global direccionado
por contenido**: cada archivo se guarda por su hash, así que dos versiones de un paquete que
comparten el 95 % de los archivos solo ocupan el 5 % de más. Luego construye `node_modules` con
enlaces:

```bash
pnpm install --frozen-lockfile
# Lockfile is up to date, resolution step is skipped
# Packages are hard linked from the content-addressable store to the virtual store.
#   Content-addressable store is at: /home/<tú>/.local/share/pnpm/store/v11
#   Virtual store is at:             node_modules/.pnpm
# Packages: +227
# Progress: resolved 227, reused 227, downloaded 0, added 227, done
# Done in 253ms using pnpm v12.16.1

readlink node_modules/react
# .pnpm/react@19.3.1/node_modules/react
stat -c %h node_modules/.pnpm/react@19.3.1/node_modules/react/package.json
# 3
```

- Los archivos de `node_modules/.pnpm` son **enlaces duros** al store: el `3` es el número de
  nombres que apuntan al mismo archivo en disco.
- `node_modules/react` es un **enlace simbólico** a `.pnpm`. En la raíz de `node_modules` solo
  aparecen las dependencias que declaraste, no las transitivas: si tu código importa un paquete
  que no está en `package.json`, falla. Con un `node_modules` plano funcionaría por casualidad.

En el runner el store empieza vacío. Lo que se cachea entre runs es **el store**, nunca
`node_modules`: el store es independiente del proyecto y `node_modules` se reconstruye en
segundos a partir de él.

### `--frozen-lockfile`: el lockfile manda y tiene que estar al día

`pnpm install` compara `pnpm-lock.yaml` con `package.json` antes de instalar:

| Comando | Si el lockfile no casa con `package.json` |
|---|---|
| `pnpm install` en tu máquina | **Reescribe `pnpm-lock.yaml`** y sigue |
| `pnpm install --frozen-lockfile` | **Falla** sin instalar nada |
| `pnpm install` con `CI=true` | Igual que `--frozen-lockfile`: pnpm lo activa solo en CI si hay lockfile |

Lo comprobé añadiendo `left-pad` a `dependencies` sin regenerar el lockfile:

```bash
pnpm install --frozen-lockfile
# Error: ERR_PNPM_OUTDATED_LOCKFILE
#
#   × installing dependencies
#   ╰─▶ Cannot install with "frozen-lockfile" because pnpm-lock.yaml is not up
#       to date with package.json.
#
#         Failure reason:
#         specifiers in the lockfile don't match specifiers in package.json:
#       * in importers["."]:
#       * 1 dependency was added: left-pad@^1.3.0
#   help: Regenerate the lockfile with `pnpm install --lockfile-only` so that
#         pnpm-lock.yaml reflects the current package.json, then re-run `pnpm
#         install --frozen-lockfile`.
echo $?
# 1
```

Es exactamente el fallo que quieres en CI: alguien cambió `package.json` y no comiteó el lockfile.
Sin el flag, pnpm arreglaría el lockfile en la copia del runner, que se destruye al terminar, y el
verde no diría nada del lockfile que hay en el repo.

¿Por qué escribirlo si pnpm ya lo activa con `CI=true`? Porque el comportamiento por defecto
depende de una variable de entorno que no ves en el YAML. Con el flag escrito, el workflow dice lo
que hace y funciona igual en `act` (Semana 08) o en un runner propio. Por eso en este bootcamp
**todo job que instala dependencias del frontend ejecuta `pnpm install --frozen-lockfile`**.

### `packageManager`: una sola versión de pnpm

`"packageManager": "pnpm@12.16.1"` fija pnpm igual que `uv.lock` fija las dependencias. pnpm 12 lo
respeta: si ejecutas otra versión dentro del proyecto, cambia a la declarada. Lo comprobé con
`"pnpm@11.0.0"` en `package.json`:

```bash
pnpm --version
# 11.0.0
```

### `pnpm/action-setup`: pnpm en el runner

pnpm no viene en la imagen `ubuntu-24.04`. Inputs de `pnpm/action-setup`, leídos de su
`action.yml` en el SHA de la v6.1.0:

| Input | Por defecto | Para qué |
|---|---|---|
| `version` | (vacío) | Sin valor, lee `packageManager` (o `devEngines.packageManager`) de `package_json_file` |
| `package_json_file` | `package.json` | Relativo a la raíz del repo. En `tablero` es `web/package.json` |
| `dest` | `~/setup-pnpm` | Dónde instala pnpm. No lo toques |
| `run_install` | `null` | Con `null` o `false` no instala dependencias. Lo haces tú, con el flag |
| `cache` | `false` | Caché propia del store. Aquí la hace `setup-node`: no actives las dos |
| `cache_dependency_path` | `pnpm-lock.yaml` | Clave de esa caché propia |
| `standalone` | `false` | Para pnpm 11 o anterior. Con pnpm 12, según su README, no tiene efecto |

Dos errores reales de su código, que conviene reconocer en un log:

- Sin `version` y sin `packageManager` en `package_json_file`: `No pnpm version is specified.`
  Es lo que pasa en `tablero` si olvidas `package_json_file: web/package.json`, porque en la raíz
  no hay `package.json`.
- Con `version` **y** `packageManager` distintos: `Multiple versions of pnpm specified`. Elige una
  fuente; en este bootcamp, `packageManager`.

### `actions/setup-node`: Node y la caché del store

Inputs de `actions/setup-node`, leídos de su `action.yml` en el SHA de la v7.1.0:

| Input | Por defecto | Para qué |
|---|---|---|
| `node-version` | (vacío) | `"26"` toma la 26.x que haya en la caché de la imagen; si no hay, la descarga |
| `node-version-file` | (vacío) | Lee la versión de un archivo. Con `package.json` mira `volta.node`, `devEngines.runtime` y luego `engines.node` |
| `check-latest` | `false` | Con `true` comprueba siempre si hay una 26.x más nueva. Más lento |
| `cache` | (vacío) | `pnpm` cachea el store. Sin él, para pnpm no hay caché |
| `cache-dependency-path` | (vacío) | Lockfile para la clave. Sin él, busca `pnpm-lock.yaml` en la raíz |
| `package-manager-cache` | `true` | Caché automática, pero **solo para npm**. Con pnpm no hace nada |
| `architecture`, `registry-url`, `scope`, `token`, `mirror`, `mirror-token` | | Arquitectura, registro privado y espejos. No los necesitas esta semana |

Con `cache: pnpm`, el código de la action (`src/cache-utils.ts` y `src/cache-restore.ts` en ese
SHA) hace tres cosas:

1. Ejecuta `pnpm store path --silent` para saber qué directorio cachear. **Por eso pnpm tiene que
   existir antes**: si no, el step falla con `Could not get pnpm cache folder path`.
2. Calcula la clave `node-cache-Linux-x64-pnpm-<hash del lockfile>`. Si `pnpm-lock.yaml` no está
   en la raíz y no le das `cache-dependency-path`, falla con
   `Dependencies lock file is not found in ... Supported file patterns: pnpm-lock.yaml`.
3. Restaura solo con **acierto exacto**: para pnpm no hay `restore-keys`. Al terminar el job, si
   fue `success`, guarda el store con esa clave (`post-if: success()`).

## 3. Cómo se usa

Un job que solo prepara el entorno del frontend y enseña qué quedó instalado:

```yaml
name: web-deps

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  install:
    name: Dependencias del frontend
    runs-on: ubuntu-24.04
    defaults:
      run:
        working-directory: web
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      # Primero pnpm: setup-node le preguntará dónde está su store.
      - uses: pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413 # v6.1.0
        with:
          package_json_file: web/package.json
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version: "26"
          cache: pnpm
          cache-dependency-path: web/pnpm-lock.yaml
      - name: Instalar exactamente el lockfile
        run: pnpm install --frozen-lockfile
      - name: Qué quedó instalado
        run: |
          node --version
          pnpm --version
          pnpm store path
          pnpm list --depth 0
```

Fíjate en tres detalles:

- `package_json_file` y `cache-dependency-path` van **relativos a la raíz**: `defaults.run` solo
  afecta a los steps `run`, igual que con `setup-uv` en la Semana 03.
- `node-version: "26"` va entre comillas: sin ellas YAML lo lee como número. Funciona igual, pero
  `"26.10"` sin comillas sería el número `26.1`.
- No hay `actions/cache`: `setup-node` ya hace la caché con la clave correcta.

Verificado con pnpm/action-setup@v6.1.0, actions/setup-node@v7.1.0 y ubuntu-24.04, noviembre de
2026.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `npm install` o `npm ci` en un proyecto pnpm <!-- antipatron --> | Ignora `pnpm-lock.yaml` y resuelve otro árbol | `pnpm install --frozen-lockfile` |
| `npx <herramienta>` <!-- antipatron --> | Descarga una versión que no está en el lockfile | `pnpm exec` si está en `devDependencies`, `pnpm dlx` si no |
| Comitear `package-lock.json` junto a `pnpm-lock.yaml` <!-- antipatron --> | Dos lockfiles que divergen; cada herramienta cree uno | Solo `pnpm-lock.yaml`, y el otro en `.gitignore` |
| `corepack enable` para tener pnpm | corepack se distribuye con Node desde la 14.19.0 hasta antes de la 25.0.0: en Node 26 no existe | `pnpm/action-setup` con `packageManager` |
| `pnpm install` sin `--frozen-lockfile` | El comportamiento depende de `CI=true`, invisible en el YAML | El flag escrito |
| `setup-node` antes que `pnpm/action-setup` con `cache: pnpm` | `pnpm store path` no existe todavía y el step falla | `pnpm/action-setup` primero |
| `cache: true` en `pnpm/action-setup` y `cache: pnpm` en `setup-node` | Dos cachés del mismo store con claves distintas | Solo `cache: pnpm` en `setup-node` |
| Cachear `node_modules` | Enlaces a un store que en el siguiente run no existe | Cachear el store, que es lo que hace `cache: pnpm` |
| `version` y `packageManager` a la vez | `Multiple versions of pnpm specified` si difieren, y dos sitios que actualizar | Solo `packageManager` |

## 5. Trucos

- **`pnpm store path`** en un step te dice qué directorio está cacheando `setup-node`; si la
  caché nunca acierta, compara ese valor entre runs.
- **`gh cache list --key node-cache-Linux-x64-pnpm-`** filtra las entradas de pnpm por prefijo y
  te deja ver si `main` tiene la suya.
- **`pnpm install --lockfile-only`** regenera el lockfile sin tocar `node_modules`: es el comando
  que te sugiere el propio error de `--frozen-lockfile`.

## 📚 Recursos Adicionales

- [pnpm: Motivation (store y enlaces)](https://pnpm.io/motivation)
- [pnpm: install, `--frozen-lockfile`](https://pnpm.io/cli/install)
- [pnpm/action-setup](https://github.com/pnpm/action-setup)
- [actions/setup-node: Advanced usage](https://github.com/actions/setup-node/blob/main/docs/advanced-usage.md)
- [nodejs/corepack](https://github.com/nodejs/corepack)

## ✅ Checklist de Verificación

- [ ] Sé qué es el store de pnpm y por qué se cachea él y no `node_modules`
- [ ] Sé qué hace `--frozen-lockfile` cuando `package.json` cambió sin el lockfile
- [ ] Fijo pnpm con `packageManager` y lo leo con `package_json_file`
- [ ] Pongo `pnpm/action-setup` antes que `actions/setup-node`
- [ ] Uso `cache: pnpm` con `cache-dependency-path` apuntando a `web/pnpm-lock.yaml`
- [ ] Sé por qué corepack no es una opción con Node 26

---

| ← Anterior | Siguiente → |
|:---|---:|
| [El frontend de tablero](01-el-web-de-tablero.md) | [Tests y build del frontend](03-tests-y-build-del-frontend.md) |
