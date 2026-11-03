# Práctica 01 — pnpm en local

> Antes de pedirle a un runner que instale el frontend, compruébalo en tu máquina. Esta práctica
> ejecuta en local las mismas órdenes que correrá el CI, rompe el lockfile a propósito y te enseña
> a preguntarle a pnpm por qué tiene instalado cada paquete.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- pnpm 12.16.1 fijado en `web/package.json` y en tu máquina
- Las dependencias de `web/` instaladas desde `pnpm-lock.yaml`, y entender dónde viven de verdad
- `pnpm lint`, `pnpm test` y `pnpm build` en verde con las órdenes que usará el CI
- Ver con tus ojos qué pasa cuando `package.json` y `pnpm-lock.yaml` no coinciden
- Saber leer `pnpm why` y `pnpm list --depth 0`

## 📋 Antes de empezar

Tienes `check-week.sh 03` en verde y tu clon de `<tu-org>/tablero` en `~/code/tablero`, con la
rama `main` al día:

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
```

Todo lo de esta práctica pasa en `~/code/tablero/web`. No subes nada a GitHub hasta la práctica 02.

---

## Paso 1: pnpm 12.16.1 y el campo packageManager

**Por qué**: el CI no elige versión de pnpm: la lee de `packageManager` en `web/package.json`
(práctica 02, paso 2). Si ese campo falta o dice solo `pnpm@12`, cada máquina puede instalar con
otra versión y el lockfile cambia de formato sin que nadie lo pida. Con la versión exacta, tu
máquina y el runner usan el mismo pnpm. La instalación con checksum está en
[`docs/setup-entorno.md`](../../../docs/setup-entorno.md), apartado 5.

**Comando**:

```bash
cd ~/code/tablero/web
pnpm --version
node --version
jq -r .packageManager package.json
```

Si `pnpm --version` dice otra cosa o `command not found`, vuelve al apartado 5 de
`setup-entorno.md`. Si `packageManager` sale `null`, tu `web/` no viene de la copia de `app/`
de este bootcamp: cópialo de nuevo (Semana 01, práctica 01, paso 3).

**Verifica**:

```bash
pnpm --version
# 12.16.1
node --version
# v26.13.0
jq -r .packageManager package.json
# pnpm@12.16.1
```

Ese último comando es exactamente el de la comprobación `web-package-manager` de `checks.json`.
Tu Node puede ser otra 26.x: lo que importa es el 26.

---

## Paso 2: Instalar desde el lockfile y ver dónde quedan los paquetes

**Por qué**: `pnpm install --frozen-lockfile` instala **exactamente** lo que dice
`pnpm-lock.yaml` y falla si el lockfile no está al día con `package.json`. Es la orden del CI.
Además conviene ver cómo instala pnpm: los paquetes no se copian en `node_modules/`. Viven una
sola vez en el **store** (el almacén global, direccionado por contenido) y `node_modules/.pnpm`
los enlaza con enlaces duros. Lo que ves en `node_modules/react` es un enlace simbólico hacia ahí.
Esto es lo que `setup-node` cacheará en la práctica 02: el store, no `node_modules/`.

**Comando**:

```bash
rm -rf node_modules
pnpm install --frozen-lockfile
```

```
# ✓ Lockfile passes supply-chain policies (verified ...)
# Lockfile is up to date, resolution step is skipped
# Packages are hard linked from the content-addressable store to the virtual store.
#   Content-addressable store is at: /home/<tu-usuario>/.local/share/pnpm/store/v11
#   Virtual store is at:             node_modules/.pnpm
# Packages: +227
# Progress: resolved 227, reused 227, downloaded 0, added 227, done
# ...
# Done in 226ms using pnpm v12.16.1
```

`reused 227, downloaded 0` dice que todo salió del store: ya lo habías instalado antes. En una
máquina limpia verías `downloaded 227`. Esa es la diferencia que la caché de CI quiere ahorrar.

**Verifica**:

```bash
pnpm store path
# /home/<tu-usuario>/.local/share/pnpm/store/v11
ls -la node_modules/.pnpm | head -5
# total 1008
# drwxr-xr-x 230 <tu-usuario> <tu-usuario> 12288 ... .
# drwxr-xr-x   9 <tu-usuario> <tu-usuario>  4096 ... ..
# drwxr-xr-x   3 <tu-usuario> <tu-usuario>  4096 ... @asamuzakjp+css-color@7.1.9
# drwxr-xr-x   3 <tu-usuario> <tu-usuario>  4096 ... @asamuzakjp+dom-selector@10.0.5
readlink node_modules/react
# .pnpm/react@19.3.1/node_modules/react
stat -c '%h' node_modules/.pnpm/react@19.3.1/node_modules/react/package.json
# 4
```

El `4` es el número de enlaces duros de ese archivo: el mismo contenido aparece en el store y en
cada proyecto que lo usa, pero ocupa disco una sola vez. Tu número puede ser otro según cuántos
proyectos con React tengas.

---

## Paso 3: Lint, tests y build como los correrá el CI

**Por qué**: son tres comprobaciones distintas y el CI las ejecutará por separado. `pnpm lint`
lanza ESLint con la configuración plana de `eslint.config.js`; `pnpm test` lanza `vitest run`,
que termina en lugar de quedarse vigilando cambios; `pnpm build` hace `tsc --noEmit` y luego
`vite build`, así que un error de tipos rompe el build aunque Vite sepa empaquetarlo. Si algo
falla aquí, fallará en el runner: arréglalo antes de escribir YAML.

**Comando**:

```bash
pnpm lint; echo "exit $?"
pnpm test
pnpm build
```

```
# $ eslint .
# exit 0
#  Test Files  2 passed (2)
#       Tests  4 passed (4)
#    Duration  702ms (environment 81%, import 7%, tests 6%, transform 5%, worker 1%)
# $ tsc --noEmit && vite build
# vite v8.3.5 building client environment for production...
# ✓ 16 modules transformed.
# dist/index.html                  0.31 kB │ gzip:  0.22 kB
# dist/assets/index-B_X_rmRw.js  221.09 kB │ gzip: 69.26 kB
# ✓ built in 114ms
```

ESLint sin hallazgos no imprime nada más que la orden: el silencio es el verde.

**Verifica**:

```bash
ls dist dist/assets
# dist:
# assets
# index.html
#
# dist/assets:
# index-B_X_rmRw.js
git status --short
# (sin salida: dist/ y node_modules/ están en .gitignore)
```

`web/dist` es lo que subirás como artefacto en la práctica 04. Nunca se comitea: lo construye el CI.

---

## Paso 4: Romper el lockfile a propósito

**Por qué**: el fallo más común del CI de frontend es un PR que cambia `package.json` y olvida
el lockfile. En local, `pnpm install` a secas lo "arregla" en silencio reescribiendo
`pnpm-lock.yaml`. En CI no quieres eso: el runner arreglaría un lockfile que nadie revisa y que se
pierde al destruir la máquina. `--frozen-lockfile` convierte ese descuido en un error rojo y
legible. Aquí lo provocas cambiando la cota de `vitest` sin instalar.

**Comando**:

```bash
jq '.devDependencies.vitest = "^5.0.6"' package.json > package.json.tmp
mv package.json.tmp package.json
git diff --stat
pnpm install --frozen-lockfile; echo "exit $?"
```

```
#  web/package.json | 2 +-
#  1 file changed, 1 insertion(+), 1 deletion(-)
# Error: ERR_PNPM_OUTDATED_LOCKFILE
#
#   × installing dependencies
#   ╰─▶ Cannot install with "frozen-lockfile" because pnpm-lock.yaml is not up
#       to date with package.json.
#
#         Failure reason:
#         specifiers in the lockfile don't match specifiers in package.json:
#       * in importers["."]:
#       * 1 dependency is mismatched:
#         - vitest (lockfile: ^5.0.5, manifest: ^5.0.6)
#   help: Regenerate the lockfile with `pnpm install --lockfile-only` so that
#         pnpm-lock.yaml reflects the current package.json, then re-run `pnpm
#         install --frozen-lockfile`.
#
# exit 1
```

Fíjate en lo que te da el error: el código (`ERR_PNPM_OUTDATED_LOCKFILE`), el paquete y las dos
cotas enfrentadas. Es lo primero que buscarás en el log de un job rojo. La solución real, en un PR
de verdad, es la que propone el `help`: regenerar el lockfile en tu máquina y comitear los dos
archivos juntos.

Aquí no quieres conservar el cambio. Deshazlo:

```bash
git restore package.json
```

**Verifica**:

```bash
git status --short -- package.json pnpm-lock.yaml
# (sin salida: no hay cambios)
pnpm install --frozen-lockfile; echo "exit $?"
# Lockfile is up to date, resolution step is skipped
# Done in 13ms using pnpm v12.16.1
# exit 0
```

---

## Paso 5: Preguntarle a pnpm qué tiene instalado y por qué

**Por qué**: cuando un job falla por un paquete que tú no declaraste (un aviso de seguridad, una
versión rara en el log), necesitas saber **quién** lo trae. `pnpm why` recorre el árbol hacia
arriba hasta tu `package.json`. `pnpm list --depth 0` hace lo contrario: enseña solo lo que tú
declaraste, con la versión exacta que fijó el lockfile. Lo usarás en la práctica 02 para
comprobar que el runner instaló lo mismo que tu máquina.

**Comando**:

```bash
pnpm why vite
pnpm list --depth 0
```

**Verifica**:

```bash
pnpm why vite
# vite@8.3.5
# ├─┬ @vitejs/plugin-react@6.1.2
# │ └── tablero-web@1.0.0 (devDependencies)
# ├─┬ @vitest/mocker@5.0.5
# │ └─┬ vitest@5.0.5
# │   ├─┬ @vitest/coverage-v8@5.0.5
# │   │ ├── tablero-web@1.0.0 (devDependencies)
# │   │ └── vitest@5.0.5 [circular]
# │   └── tablero-web@1.0.0 (devDependencies)
# ├── tablero-web@1.0.0 (devDependencies)
# └── vitest@5.0.5 [deduped]
#
# Found 1 version of vite
# ...
pnpm list --depth 0 | tail -6
# ├── typescript@6.0.3
# ├── typescript-eslint@8.72.1
# ├── vite@8.3.5
# └── vitest@5.0.5
#
# 17 packages
pnpm list --depth 0 | grep -c '@'
# 18
```

Lee el árbol de `pnpm why` de abajo arriba: `vite` llega por tres caminos (directo, por el plugin
de React y por vitest), pero `Found 1 version of vite` dice que todos comparten la misma. Si un
día ves dos versiones, ahí tienes por qué crece el bundle o por qué falla un tipo. El `18` cuenta
las 17 dependencias directas (las que dice `17 packages`) más la línea del propio
`tablero-web@1.0.0`.

---

## ✅ Resultado

- [ ] `pnpm --version` dice `12.16.1` y `node --version` empieza por `v26`
- [ ] `jq -r .packageManager web/package.json` dice `pnpm@12.16.1`
- [ ] Sabes que los paquetes viven en el store y `node_modules/.pnpm` los enlaza
- [ ] `pnpm lint`, `pnpm test` y `pnpm build` pasan en local y `web/dist` existe
- [ ] Has visto `ERR_PNPM_OUTDATED_LOCKFILE` con un `package.json` desincronizado
- [ ] `package.json` y `pnpm-lock.yaml` sin cambios y `pnpm install --frozen-lockfile` sale con 0

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 04
```

De momento solo pasa `web-package-manager` (y las que heredas de semanas anteriores, como
`workflows-pinned`): el resto llega con los workflows de las prácticas siguientes y del proyecto.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `pnpm: command not found` | El directorio de pnpm no está en tu `PATH` | `docs/setup-entorno.md`, apartado 5 |
| `pnpm --version` dice otra versión fuera de `web/` | Normal: fuera del proyecto no hay `packageManager` que obedecer | Mira la versión siempre dentro de `web/` |
| `jq -r .packageManager` da `null` | Tu `web/package.json` no viene de `app/web` | Copia de nuevo `app/web` del bootcamp (Semana 01, práctica 01, paso 3) |
| `ERR_PNPM_OUTDATED_LOCKFILE` sin haber tocado nada | Quedó un cambio del paso 4 sin restaurar | `git diff package.json`; `git restore package.json` |
| `git status` muestra `pnpm-lock.yaml` modificado | Ejecutaste `pnpm install` sin `--frozen-lockfile` con el cambio del paso 4 | `git restore package.json pnpm-lock.yaml` y repite con el flag |
| `git status` muestra `web/dist/` o `web/node_modules/` | Falta el `.gitignore` de la raíz | Copia `app/.gitignore` a la raíz de tu repo |
| `pnpm build` falla con `error TS...` | Un error de tipos: `tsc --noEmit` corre antes que Vite | Arréglalo en `src/`; es justo lo que el CI debe parar (teoría 03) |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Artefacto frente a caché](../1-teoria/06-artefacto-frente-a-cache.md) | [pnpm en un workflow](02-pnpm-en-un-workflow.md) |
