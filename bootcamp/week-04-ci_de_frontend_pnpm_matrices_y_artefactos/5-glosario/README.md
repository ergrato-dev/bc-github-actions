# 📖 Glosario — Semana 04

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **Artefacto** (*artifact*): archivo o carpeta que un job sube a GitHub con `upload-artifact` para
  que otro job del mismo run lo descargue, o para bajarlo cuando el run ha terminado. Es un
  resultado, no un atajo: si falta, el job que lo necesita falla.
- **`artifact-digest`**: output de `upload-artifact` con el SHA-256 del zip subido.
  `download-artifact` lo comprueba al descargar y falla si no coincide.

## B

- **Bundle**: el JavaScript que genera `vite build` en `dist/assets/`, con un hash en el nombre
  (`index-B_X_rmRw.js`) que cambia cuando cambia su contenido.

## C

- **Caché frente a artefacto**: la caché guarda entre runs algo que el job sabría regenerar (el
  store de pnpm); el artefacto guarda lo que produce un job para otro job (`web/dist`). La pregunta
  que decide: si no estuviera, ¿el resultado sería distinto o solo tardaría más?
- **`cache: pnpm`**: input de `actions/setup-node` que guarda y restaura el store de pnpm, con una
  clave basada en el hash de `pnpm-lock.yaml`. Exige que pnpm esté instalado antes.
- **Combinación** (*combination*): cada conjunto de valores que sale de expandir una matriz. Cada
  combinación es un job, y sus valores se leen con el contexto `matrix`.
- **Corepack**: herramienta que se distribuía con Node para activar gestores de paquetes. En
  Node 26 ya no existe; en este bootcamp pnpm llega con `pnpm/action-setup`.

## D

- **`dist/`**: carpeta con el resultado de `pnpm build`: `index.html` y los bundles. No se comitea;
  en CI viaja de `build` a `dist-report` como el artefacto `web-dist`.

## E

- **Enlace duro** (*hard link*): otro nombre para los mismos datos en disco. Los archivos de
  `node_modules/.pnpm` son enlaces duros al store, por eso diez proyectos no ocupan diez veces.
- **Enlace simbólico** (*symbolic link*, *symlink*): archivo que apunta a otra ruta. Cada
  dependencia directa en la raíz de `node_modules` es un enlace simbólico a `node_modules/.pnpm`.
- **`engines`**: campo de `package.json` con las versiones de Node que el proyecto promete
  soportar. En `tablero`, `"node": ">=24"`; la matriz prueba lo que promete.
- **ESLint**: el analizador estático del frontend. `pnpm lint` lo ejecuta con la configuración de
  `eslint.config.js`; no depende de la versión de Node, así que corre una sola vez.
- **`exclude`**: lista de combinaciones que se quitan de una matriz. Basta una coincidencia
  parcial, y se aplica antes que `include`.

## F

- **`fail-fast`**: clave de `strategy`. Con `true`, el valor por defecto, el fallo de un job de la
  matriz cancela los que están en curso o en cola. Con `false`, todos terminan y ves qué
  combinaciones fallan.
- **`--frozen-lockfile`**: flag de `pnpm install` que falla con `ERR_PNPM_OUTDATED_LOCKFILE` si
  `pnpm-lock.yaml` no casa con `package.json`, en lugar de reescribirlo.
- **`fromJSON`**: función de expresiones que convierte una cadena JSON en un valor. En una matriz
  dinámica convierte el output de otro job en el array que se expande.

## I

- **`if-no-files-found`**: input de `upload-artifact`. Por defecto `warn`; con `error`, un build que
  no dejó archivos falla en el step de subida, que es donde está la causa.
- **`include`**: lista de entradas que amplían combinaciones existentes, sin pisar sus valores
  originales, o crean combinaciones nuevas cuando no encajan con ninguna.
- **Inmutabilidad** (*immutability*): desde la v4 de las actions de artefactos, un artefacto subido
  no admite cambios. Un segundo upload con el mismo nombre en el mismo run falla con `409 Conflict`.

## J

- **jsdom**: implementación del DOM en JavaScript. Vitest la usa con `environment: "jsdom"` para
  probar componentes React en Node, sin navegador.

## M

- **Matriz** (*matrix*): `strategy.matrix` de un job. GitHub hace el producto cartesiano de sus
  variables y crea un job por combinación, con un máximo de 256 por matriz.
- **Matriz dinámica** (*dynamic matrix*): matriz cuyos valores vienen de un output de otro job,
  convertido con `fromJSON`. Se protege con un `if` para que no se expanda una lista vacía.
- **`max-parallel`**: clave de `strategy` que limita cuántos jobs de la matriz corren a la vez. No
  ahorra minutos: sirve cuando los jobs compiten por algo externo.
- **`merge-multiple`**: input de `download-artifact`. Con `true`, varios artefactos se extraen todos
  en el mismo `path` en lugar de uno por directorio.

## N

- **Node LTS** (*Long Term Support*): versión de Node con soporte extendido. `tablero` prueba en
  Node 24 y Node 26 porque es lo que promete `engines`, no "todas las versiones".
- **`node_modules/.pnpm`**: el *virtual store* de pnpm dentro del proyecto, con un directorio por
  paquete y versión, enlazado al store global.

## P

- **`packageManager`**: campo de `package.json` que fija la versión exacta del gestor de paquetes
  (`pnpm@12.16.1`). `pnpm/action-setup` lo lee cuando no le pasas `version`.
- **pnpm**: gestor de paquetes de Node que guarda cada archivo una sola vez en un store global y lo
  enlaza en cada proyecto. El único que usa este bootcamp para el frontend.
- **`pnpm-lock.yaml`**: lockfile de pnpm, con la versión exacta y el hash de cada dependencia,
  directa o transitiva. Se comitea y su hash forma parte de la clave de la caché.
- **`pnpm/action-setup`**: action que instala pnpm en el runner. Va antes que `actions/setup-node`.
- **Producto cartesiano** (*cartesian product*): todas las combinaciones posibles de los valores de
  las variables de una matriz. Dos versiones por tres reporters dan seis jobs.

## R

- **Retención** (*retention*): días que un artefacto existe antes de caducar. Se fija al subirlo
  con `retention-days`; sin él toma el valor del repo, 90 días por defecto en uno público.

## S

- **Store de pnpm** (*content-addressable store*): directorio global donde pnpm guarda cada
  archivo de cada paquete por su contenido. Es lo que setup-node cachea, no `node_modules`.
- **Store path**: la ruta del store en una máquina, que da `pnpm store path`. setup-node la pide a
  pnpm para saber qué cachear.

## T

- **tsc**: el compilador de TypeScript. `tsc --noEmit` comprueba tipos sin generar archivos; en
  `tablero` va delante de `vite build`, así que un error de tipos rompe el build.

## V

- **Vite**: herramienta de build y servidor de desarrollo del frontend. `vite build` genera `dist/`.
- **Vitest**: el runner de tests del frontend, configurado en `vite.config.ts`. `pnpm test` lo
  ejecuta una vez y `pnpm test:coverage` mide cobertura con un umbral.

## W

- **Workspace**: en pnpm, un repositorio con varios paquetes declarados en `pnpm-workspace.yaml`
  que comparten un único lockfile. `web/` es un único paquete, sin workspace.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Semana 05 — Service containers y PostgreSQL](../../week-05-service_containers_y_postgresql/README.md) |
