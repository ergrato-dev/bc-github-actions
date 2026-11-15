# 📖 Glosario — Semana 20

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **Alias** (*alias*): `*nombre` en YAML. Repite tal cual el nodo marcado con el ancla del mismo
  nombre: un mapa, un step o un job entero. GitHub los admite desde el 18 de septiembre de 2025.
- **Ancla** (*anchor*): `&nombre` en YAML. Marca un nodo para repetirlo con un alias. Tiene que
  aparecer antes que el alias y no cruza archivos.
- **Área** (de `changed-areas.sh`): conjunto de rutas cuyo cambio obliga a correr un componente.
  Se define por de qué depende el componente: el área `worker` incluye `api/migrations/`.
- **Auditoría** (*audit*): revisión del pipeline en cuatro capas: workflows, ajustes del repo y de
  la org, cadena de suministro y ejecución.

## C

- **Capstone**: proyecto final que demuestra que el conjunto aguanta, no una capacidad nueva. En
  este bootcamp, el worker integrado, la auditoría y la defensa de `tablero`.
- **Clave de fusión** (*merge key*): `<<` en YAML, para heredar las claves de un ancla y
  sobrescribir alguna. GitHub **no** la admite y actionlint la rechaza con `[syntax-check]`.
- **Contrato** (de un reutilizable): sus inputs más lo que asume en sus steps. El de `_python.yml`:
  `uv.lock` al día, `tests/unit`, `tests/integration` y un módulo `<package>.migrate`.
- **Criterios de producción**: los siete que usa el capstone: una sola puerta, privilegio mínimo,
  todo fijado, reutilización versionada, artefactos firmados, despliegue verificado y reversible,
  y observable.

## D

- **Decisión** (en la defensa): qué se eligió, por qué y qué alternativa se descartó a cambio de
  qué coste. Sin alternativa es solo una descripción.
- **Defensa del capstone**: diez minutos de exposición sin abrir un YAML y una ronda de preguntas
  respondidas en dos frases con su prueba.
- **Deshabilitar un workflow** (*disable*): pararlo sin borrar el archivo ni su historial, con
  `gh workflow disable`. Sale en `gh workflow list` solo con `--all`; `enable` lo reactiva.
- **Documento de defensa**: `docs/pipeline.md`, con mapa, modelo de amenazas, decisiones, riesgos
  aceptados y evidencias, en ese orden.
- **Dominio** (del examen, *domain*): cada uno de los cinco bloques de la guía del GH-200, con su
  peso. Desde enero de 2026, "Secure and optimize automation" es uno propio.

## E

- **Etiqueta `-latest`**: `ubuntu-latest`, `windows-latest` y `macos-latest`, alias que GitHub
  mueve de imagen. Una org Team o Enterprise puede deshabilitar las etiquetas estándar como
  `ubuntu-latest` desde el 25 de junio de 2026.
- **Evidencia** (*evidence*): la prueba de una afirmación: un run, un comando con su salida o una
  respuesta de la API con fecha. Se elige regenerable, porque los runs caducan con la retención.

## G

- **GH-200**: el examen de certificación de GitHub Actions. Aprobado con 700 sobre 1000; su guía
  vigente es "Skills measured as of January 2026".

## I

- **Immutable actions**: actions publicadas como paquete OCI en GHCR que no se pueden mover. Su
  herramienta de publicación sigue "not ready for public use"; hoy, releases inmutables y SHA.

## L

- **Lista de IP permitidas** (*IP allow list*): restricción de acceso a una org o empresa por
  dirección IP, solo en GitHub Enterprise Cloud. Con ella, Actions necesita runners propios o
  runners grandes con IP estática.

## P

- **Plantillas no públicas** (*non-public workflow templates*): plantillas de workflow en un repo
  `.github` privado o interno, que GitHub ofrece a los miembros de la org desde septiembre de 2025.
- **Política propia** (*policy*): reglas del equipo que actionlint y zizmor no exigen, escritas en
  `scripts/audit-workflows.sh` y ejecutadas por el job `policy` en cada cambio de workflows.

## R

- **Riesgo aceptado** (*accepted risk*): lo que se sabe no cubierto, con por qué se acepta y qué
  lo cerraría. Si es vago ("podría mejorarse"), no es un riesgo: no se puede discutir.
- **`RUNNER_TOOL_CACHE`**: directorio del toolcache (`/opt/hostedtoolcache` en Linux), donde las
  `setup-*` buscan primero una versión y guardan lo que descargan.

## S

- **Simulacro** (*mock exam*): prueba cronometrada en condiciones de examen. El final reparte sus
  preguntas por los cinco dominios según su peso.
- **Software preinstalado** (*preinstalled software*): lo que trae cada imagen de runner alojado,
  listado por imagen en `actions/runner-images`. El grupo "Runner Image" del paso "Set up job"
  enlaza a su lista.

## T

- **Toolcache**: caché de versiones de lenguajes y herramientas de la imagen del runner, en
  `RUNNER_TOOL_CACHE`. Acelera una `setup-*`, pero no sustituye a fijar la versión.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Índice del bootcamp](../../README.md) |
