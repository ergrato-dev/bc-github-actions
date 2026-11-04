# 📖 Glosario — Semana 10

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **Action** (*action*): unidad reutilizable de steps, definida por un `action.yml` y llamada con
  `uses:` desde un step. Corre dentro del job que la llama, con su runner y su workspace. Frente a
  un workflow reutilizable (Semana 09), que empaqueta jobs completos, es solo una parte de un job.
- **Action local** (*local action*): action que vive en el mismo repo y se llama con
  `uses: ./.github/actions/<nombre>`. El runner la lee del disco del workspace, así que exige un
  `actions/checkout` antes. actionlint valida sus inputs contra su `action.yml`.
- **`action.yml`** (*action metadata file*): archivo de metadatos de una action: `name`,
  `description`, `inputs`, `outputs`, `runs` y, solo para el Marketplace, `branding`.
- **`@actions/core`**: paquete de `actions/toolkit` que habla con el runner desde una action
  JavaScript: `getInput`, `setOutput`, `saveState`, `getState`, `summary` y `setFailed`.
- **`allowBuilds`**: clave de `pnpm-workspace.yaml` que decide qué dependencias pueden ejecutar
  scripts de instalación. `esbuild: false` evita que pnpm 12 corte con `ERR_PNPM_IGNORED_BUILDS`.

## B

- **Bundle** (*bundle*): un único archivo con tu código y todas sus dependencias, generado con
  esbuild. Es lo que ejecuta el runner, porque no instala dependencias de una action.

## C

- **CommonJS** (`.cjs`): formato de módulos de Node con `require`. `dist/` sale en CommonJS porque
  un bundle ESM rompe con `Dynamic require of "net" is not supported`; la extensión `.cjs` lo fuerza
  dentro de un paquete `"type": "module"`.
- **Composite** (*composite action*): action con `runs.using: composite`: una lista de steps que se
  despliega dentro del job que la llama. Cada step `run:` declara `shell:` obligatoriamente.

## D

- **`dist/`**: carpeta con el bundle de una action JavaScript. **Se comitea**: es lo que `main` y
  `post` ejecutan. `node_modules/` no.
- **`dist/` desfasado** (*stale dist*): bundle que ya no corresponde a `src/` porque alguien cambió
  el código y no ejecutó `pnpm build`. `test-actions.yml` lo detecta con `git diff --exit-code`.
- **Docker action** (*Docker container action*): action con `runs.using: docker`. El runner
  construye la imagen desde `image: Dockerfile` (o descarga una `docker://`) y ejecuta su
  `ENTRYPOINT` con el workspace montado. Solo corre en runners Linux y se construye en cada job.

## E

- **Entrypoint** (*entrypoint*): el programa que ejecuta el contenedor de una action Docker. En
  `sql-lint`, `entrypoint.sh`, que lee los inputs y escribe los outputs.
- **esbuild**: empaquetador que genera `dist/index.cjs` y `dist/post.cjs` con `--bundle
  --platform=node --target=node24 --format=cjs`.

## G

- **`GITHUB_STATE`**: archivo de entorno en el que una action guarda estado privado para sus
  propias fases. Lo escribe `core.saveState`; sustituye a `::save-state`, deshabilitado.

## I

- **`INPUT_<NOMBRE>`**: variable de entorno con la que el runner entrega cada input: el nombre en
  mayúsculas, **con el guion intacto**. `INPUT_EXCLUDE-RULES` no se lee con `$`, sino con
  `printenv 'INPUT_EXCLUDE-RULES'`.

## J

- **JavaScript action** (*JavaScript action*): action con `runs.using: node24` y un `main` que el
  runner ejecuta con su propio Node. Arranca rápido y corre en Linux, Windows y macOS.

## M

- **`main`**: el archivo que ejecuta una action JavaScript cuando le toca su step. En
  `coverage-report`, `dist/index.cjs`.

## N

- **`node24`**: el runtime vigente de las actions JavaScript. Es el Node que trae el propio runner,
  no el que instala `setup-node`. `node16` está retirado y `node20` deprecado.

## P

- **`post`** (*post action*): archivo que el runner ejecuta al final del job, en orden inverso a los
  steps. Sirve para limpiar o informar. En Docker, `post-entrypoint`.
- **`post-if`**: condición del `post`. Por defecto `always()`: corre aunque el `main` haya fallado.
- **`pre`** (*pre action*): archivo que el runner ejecuta al empezar el job, antes de cualquier
  step, con `pre-if` como condición. En Docker, `pre-entrypoint`.

## R

- **`runs`**: la sección de `action.yml` que dice cómo se ejecuta la action. Su clave `using`
  (`composite`, `node24` o `docker`) decide el tipo y qué otras claves admite.

## S

- **`saveState` / `getState`**: funciones de `@actions/core` que escriben en `$GITHUB_STATE` y leen
  la variable `STATE_<nombre>` en otra fase de la misma action. Ningún otro step ve ese estado.
- **SQLFluff**: linter de SQL con dialecto PostgreSQL que empaqueta `sql-lint`. Con
  `--format github-annotation-native` cada infracción sale como anotación `::warning`.
- **`STATE_<nombre>`**: variable de entorno con la que el runner entrega a `pre`, `main` o `post`
  el estado guardado por otra fase de la misma action.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Índice del bootcamp](../../README.md) |
