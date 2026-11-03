# 📖 Glosario — Semana 01

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **Action**: unidad reutilizable de código que un step ejecuta con `uses:`. Vive en un repo
  (`actions/checkout`) y se referencia por `owner/repo@ref`.
- **actionlint**: linter de workflows. Detecta claves inexistentes, expresiones mal escritas y
  errores de shell en `run:` antes de hacer push.
- **Aprobación de workflows de forks** (*fork pull request approval*): ajuste del repo que hace que
  los workflows de un pull request de un colaborador externo esperen a que alguien con permiso los
  apruebe. En `tablero` se exige para todos los colaboradores externos.
- **Attempt**: cada intento de una misma ejecución. Un re-run no crea una ejecución nueva: añade un
  attempt con el mismo SHA y el mismo evento.

## B

- **Bloque literal** (*literal block scalar*): en YAML, `|` seguido de líneas indentadas. Conserva
  los saltos de línea: es la forma de escribir un `run:` de varias líneas.

## C

- **Colaborador externo** (*outside collaborator*): persona con acceso a un repo de la organización
  sin ser miembro de ella. Para la política de aprobación cuenta igual que cualquier autor de un
  fork.
- **Commit de merge del pull request**: commit que GitHub prepara en `refs/pull/<N>/merge`
  fusionando la rama del PR con la rama destino. Es el `GITHUB_SHA` de un evento `pull_request`.
- **Conclusión** (*conclusion*): resultado final de una ejecución, job o step: `success`,
  `failure`, `cancelled`, `skipped`… Es el campo que lee `gh run list --json conclusion`.

## E

- **Ejecución** (*workflow run*): una instancia de un workflow lanzada por un evento concreto, ligada
  a un SHA. Tiene número, attempts, jobs y logs.
- **Escalar** (*scalar*): en YAML, un valor simple: cadena, número, booleano o nulo.
- **Etiqueta del runner** (*runner label*): el valor de `runs-on` que elige en qué máquina corre un
  job (`ubuntu-24.04`). Una etiqueta como `ubuntu-latest` es móvil: GitHub cambia la imagen a la <!-- antipatron -->
  que apunta.
- **Evento** (*event*): algo que pasa en el repo (`push`, `pull_request`) o una orden manual
  (`workflow_dispatch`) que puede disparar workflows según su `on:`.

## G

- **gh CLI**: la herramienta de línea de comandos de GitHub. `gh run` y `gh workflow` cubren casi
  todo lo que hace la pestaña Actions.
- **GITHUB_TOKEN**: token que GitHub crea para cada job y que caduca al terminar. Sus permisos los
  fija `permissions:`.

## I

- **Imagen del runner** (*runner image*): el sistema operativo y el software preinstalado de la
  máquina virtual de un runner alojado. Se documentan en `actions/runner-images`.

## J

- **Job**: conjunto de steps que corre en un mismo runner. Cada job tiene su propia máquina
  virtual; sin `needs:`, los jobs de un workflow corren en paralelo.

## L

- **Log**: la salida de cada step de un job. Se lee en la UI o con `gh run view --log`.

## M

- **Mapa** (*mapping*): en YAML, un conjunto de pares `clave: valor`. Un workflow entero es un mapa.
- **Marketplace**: el catálogo público de actions de GitHub. Que una action esté en el Marketplace
  no dice nada de su seguridad.

## O

- **Organización** (*organization*): cuenta compartida de GitHub que agrupa repos y personas, con
  ajustes y políticas propias. La gratuita basta para todo el bootcamp.

## P

- **permissions**: clave de un workflow o de un job que fija qué puede hacer el `GITHUB_TOKEN`. En
  este bootcamp, la raíz siempre lleva `contents: read`.
- **persist-credentials**: input de `actions/checkout`. Con `false`, el token no queda configurado
  en git después de clonar y los steps siguientes no pueden usarlo.
- **Pinning**: fijar una action a un commit concreto con su SHA de 40 caracteres en lugar de a un
  tag o una rama.
- **pull_request**: evento que se dispara al abrir, actualizar o reabrir un pull request.
- **push**: evento que se dispara al subir commits o tags a una rama del repo.

## R

- **Re-run**: repetir una ejecución, entera o solo sus jobs fallidos. Usa el mismo SHA, el mismo
  evento y el mismo archivo de workflow.
- **Runner alojado** (*GitHub-hosted runner*): máquina virtual que GitHub crea para un job y destruye
  al terminar. En repos públicos sus minutos no cuestan nada.

## S

- **SHA**: el identificador de 40 caracteres hexadecimales de un commit, calculado a partir de su
  contenido. A diferencia de un tag, no se puede mover.
- **sha_pinning_required**: ajuste de Actions del repo o de la organización que rechaza toda
  `uses:` que no esté fijada por SHA completo.
- **Secuencia** (*sequence*): en YAML, una lista. Cada elemento empieza por `- `; `steps:` es una
  secuencia.
- **Step**: cada paso de un job. Ejecuta un comando (`run:`) o una action (`uses:`). Los steps de un
  job comparten máquina y directorio de trabajo.

## T

- **Tag**: nombre legible que apunta a un commit (`v7.0.1`). Quien controla el repo puede moverlo a
  otro commit.

## W

- **Workflow**: archivo YAML en `.github/workflows/` que dice ante qué eventos reaccionar y qué jobs
  ejecutar.
- **workflow_dispatch**: evento que lanza un workflow a mano, desde la UI o con `gh workflow run`.
  Solo está disponible si el archivo con ese trigger está en la rama por defecto.
- **Workspace**: el directorio de trabajo del job en el runner (`GITHUB_WORKSPACE`), donde
  `actions/checkout` deja el código.

## Y

- **YAML**: formato de texto de los workflows. GitHub Actions trata `on` como cadena, pero los
  parsers YAML 1.1 lo leen como el booleano `true`.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Semana 02 — Expresiones, contextos y flujo de datos](../../week-02-expresiones_contextos_y_flujo_de_datos/README.md) |
