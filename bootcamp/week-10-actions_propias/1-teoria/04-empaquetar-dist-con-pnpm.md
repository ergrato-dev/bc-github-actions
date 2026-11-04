# Empaquetar dist/ con pnpm

> El runner ejecuta el archivo de `main` tal cual: no instala dependencias ni compila. Por eso
> una action JavaScript se entrega empaquetada, con todo su código y el de sus dependencias en
> un solo archivo dentro de `dist/`, y ese `dist/` se comitea.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar por qué `dist/` se comitea y `node_modules/` no
- Montar el proyecto pnpm de una action: `package.json`, lockfile y `pnpm-workspace.yaml`
- Empaquetar `src/` en `dist/` con esbuild y justificar cada flag
- Explicar por qué el bundle es CommonJS con extensión `.cjs`
- Detectar en CI un `dist/` que no coincide con `src/`

## 1. Qué problema resuelve

En el archivo 03 viste que `main` es un archivo que el runner ejecuta con su Node, sin
`pnpm install` previo. Hay tres formas de que ese archivo encuentre `@actions/core`:

| Opción | Qué entra en el repo | Problema |
|---|---|---|
| Comitear `node_modules/` | Miles de archivos, con los de desarrollo | Diffs ilegibles, repo pesado, binarios de plataforma |
| Instalar en un step antes de usar la action | Nada extra | La action deja de ser autónoma: cada workflow que la usa tiene que saberlo |
| **Empaquetar en `dist/`** | Uno o dos archivos generados | Hay que reconstruir y comitear `dist/` cada vez que cambia `src/` |

La tercera es la estándar: la usan las actions oficiales de GitHub. El precio, mantener `dist/`
al día, se cobra con una comprobación en CI (sección 3).

## 2. Cómo funciona

### El proyecto de la action

La carpeta de `coverage-report` es un proyecto pnpm propio, separado de `web/`:

| Archivo | Para qué | ¿Se comitea? |
|---|---|:--:|
| `action.yml` | Contrato y `runs` | Sí |
| `package.json` | Dependencias, scripts y versión de pnpm | Sí |
| `pnpm-lock.yaml` | Versiones exactas: `--frozen-lockfile` en CI | Sí |
| `pnpm-workspace.yaml` | Política de scripts de instalación | Sí |
| `src/*.js` | El código que escribes | Sí |
| `tests/*.test.js` | Tests de la lógica pura | Sí |
| `dist/*.cjs` | El bundle que ejecuta el runner | **Sí** |
| `node_modules/` | Dependencias instaladas | No: va en `.gitignore` |

### `package.json`

```json
{
  "name": "coverage-report",
  "private": true,
  "type": "module",
  "packageManager": "pnpm@12.16.1",
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

- **`"type": "module"`**: `src/` y `tests/` son ESM, con `import`. Es lo que pide
  `@actions/core` 3, que solo se publica como ESM.
- **`packageManager`**: fija la versión de pnpm. `pnpm/action-setup` la lee del `package.json`
  que le indicas con `package_json_file`, así que el CI usa la misma que tú en local.
- **`"private": true`**: el paquete no se publica en ningún registro; es solo un proyecto.
- **Versiones exactas** sin `^`: una action es código que corre con el token del job, y un
  cambio de dependencia debe ser un commit visible.

### Los flags de esbuild

| Flag | Por qué |
|---|---|
| `src/index.js src/post.js` | Dos puntos de entrada: `main` y `post` (archivo 05). Cada uno da su bundle |
| `--bundle` | Mete en el archivo todo lo importado, `@actions/core` incluido |
| `--platform=node` | Deja fuera los módulos de Node (`node:fs`, `net`...) y no intenta empaquetarlos |
| `--target=node24` | Sintaxis que entiende el runtime de la action, sin transpilar de más |
| `--format=cjs` | Salida CommonJS: ver abajo |
| `--out-extension:.js=.cjs` | Los archivos salen como `.cjs` |
| `--outdir=dist` | Un archivo por entrada dentro de `dist/` |

### Por qué CommonJS y `.cjs`

Lo natural sería un bundle ESM (`--format=esm`). Falla al ejecutarse:

```text
Error: Dynamic require of "net" is not supported
```

`@actions/core` depende de paquetes de red que todavía son CommonJS y hacen `require("net")` en
tiempo de ejecución. Dentro de un bundle ESM no hay `require`, y esbuild lo sustituye por una
función que lanza ese error. Con `--format=cjs` el bundle tiene `require` de verdad y funciona.

Pero el paquete es `"type": "module"`, así que Node trataría cualquier `dist/index.js` como ESM
y el `require` volvería a fallar. La extensión `.cjs` le dice a Node "este archivo es CommonJS"
pase lo que pase en `package.json`. Por eso `main: dist/index.cjs`.

Verificado con esbuild 0.28.2, `@actions/core` 3.0.1 y ubuntu-24.04, noviembre 2026. El bundle
de `index.cjs` pesa unos 800 kB.

### `pnpm-workspace.yaml` y los scripts de instalación

```yaml
# esbuild trae su binario como dependencia opcional: su postinstall no hace falta.
allowBuilds:
  esbuild: false
```

pnpm 12 no ejecuta los scripts de instalación de las dependencias salvo que se lo permitas, y
corta `pnpm install` con `ERR_PNPM_IGNORED_BUILDS` si una dependencia tiene uno sin decisión
tomada. `allowBuilds` es esa decisión, explícita y comiteada. Para esbuild es `false`: su
binario llega por la dependencia opcional de tu plataforma y el `postinstall` sobra. Es más
seguro decir que no y ver que funciona que decir que sí por defecto.

## 3. Cómo se usa

### El ciclo de trabajo

1. Cambias `src/` y, si toca, `tests/`.
2. `pnpm test` en la carpeta de la action.
3. `pnpm build` regenera `dist/`.
4. Comiteas `src/` y `dist/` **en el mismo commit**.

Si te saltas el paso 3, el repo tiene un `src/` nuevo y un `dist/` viejo, y el runner ejecuta el
viejo. El log no dice nada raro: la action hace lo de antes y tú no entiendes por qué tu cambio
no se nota.

### Comprobar `dist/` en CI

La comprobación reconstruye en el runner y mira si git ve cambios. Una forma, que además detecta
archivos nuevos que nadie añadió:

```yaml
- name: dist al día
  working-directory: .github/actions/bundle-size
  run: |
    pnpm build
    if [ -n "$(git status --porcelain -- dist)" ]; then
      git status --short -- dist
      echo "::error::dist/ está desactualizado: ejecuta pnpm build y comitéalo"
      exit 1
    fi
```

Funciona porque esbuild es determinista: con el mismo lockfile, las mismas entradas y la misma
versión, produce el mismo bundle byte a byte en tu máquina y en el runner. Si fijaras esbuild con
`^`, una versión menor distinta en local bastaría para que el check fallara sin motivo.

El job que hace esto prepara pnpm y Node con `setup-tablero` sobre la carpeta de la action: la
composite del archivo 02 sirve también para el proyecto de otra action.

### Revisar un PR con `dist/`

Un cambio de una línea en `src/` mueve cientos en `dist/`. Para que la revisión se centre en lo
que importa, marca el bundle como generado en `.gitattributes` de la raíz:

```text
.github/actions/*/dist/** linguist-generated=true
```

GitHub pliega esos archivos en la pestaña de cambios del PR. Siguen ahí, se pueden abrir, pero
no tapan el diff de `src/`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `dist/` en `.gitignore` | El runner no encuentra `main` y el step falla al arrancar | Comitear `dist/`, ignorar solo `node_modules/`; actionlint avisa si `main` no existe (archivo 07) |
| `--format=esm` | `Dynamic require of "net" is not supported` en el runner | `--format=cjs` con `.cjs` |
| `dist/index.js` CommonJS en un paquete `"type": "module"` | Node lo carga como ESM y no hay `require` | Extensión `.cjs` |
| Dependencias con `^` | Bundles distintos en local y en CI; la comprobación falla al azar | Versiones exactas y lockfile |
| `allowBuilds: esbuild: true` por si acaso | Ejecutas código de instalación que no necesitas | `false` mientras funcione sin él |
| Cambiar `src/` y `dist/` en commits separados | Hay un commit en `main` donde la action no es la que dice el código | Los dos en el mismo commit |

## 5. Trucos

- **`pnpm build --metafile=meta.json`** pasa el flag a esbuild y escribe qué módulo aporta
  cuántos bytes al bundle. Ábrelo en el analizador de la web de esbuild y verás por qué pesa
  800 kB.
- **`node dist/index.cjs` en local** es la prueba de humo más rápida de que el bundle arranca:
  si el formato está mal, el error sale en la primera línea, sin hacer push.
- **`git diff --stat -- dist`** tras un `pnpm build` te dice de un vistazo si tu cambio afectó al
  bundle de `main`, al de `post` o a los dos.

## 📚 Recursos Adicionales

- [esbuild: API, `bundle`, `platform`, `format`, `out-extension`](https://esbuild.github.io/api/)
- [pnpm: `pnpm-workspace.yaml`](https://pnpm.io/pnpm-workspace_yaml)
- [GitHub Docs: Customizing how changed files appear on GitHub](https://docs.github.com/en/repositories/working-with-files/managing-files/customizing-how-changed-files-appear-on-github)

## ✅ Checklist de Verificación

- [ ] Sé por qué `dist/` se comitea y `node_modules/` no
- [ ] Sé qué hace cada campo del `package.json` de la action
- [ ] Sé justificar cada flag de esbuild
- [ ] Sé por qué el bundle es CommonJS con extensión `.cjs`
- [ ] Sé para qué sirve `allowBuilds` en pnpm 12
- [ ] Sé comprobar en CI que `dist/` coincide con `src/`

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Actions JavaScript](03-actions-javascript.md) | [pre, post y estado](05-pre-post-y-estado.md) |
