# 📖 Glosario — Semana 02

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **`always()`**: función de estado que devuelve siempre verdadero, incluso si el run se cancela.
  Solo para tareas que tienen que correr pase lo que pase y no pueden quedarse colgadas.

## C

- **`cancelled()`**: función de estado verdadera si el run se ha cancelado. `!cancelled()` es la
  forma recomendada de "correr aunque falle algo antes, pero no si cancelo".
- **Comando de workflow** (*workflow command*): instrucción para el runner. Los actuales se
  escriben en archivos (`$GITHUB_OUTPUT`, `$GITHUB_ENV`...); otros se imprimen en la salida
  estándar con `::` (los verás en la Semana 08).
- **Conclusion**: resultado final de un step **después** de aplicar `continue-on-error`. Es el que
  cuenta para el job.
- **Contexto** (*context*): objeto con información del run que se lee dentro de `${{ }}`:
  `github`, `env`, `vars`, `job`, `steps`, `runner`, `needs`... Cada uno está disponible solo en
  ciertas claves del workflow.
- **`continue-on-error`**: clave de step (o de job) que hace que un fallo no haga fallar al job.
  El step queda con `outcome` `failure` y `conclusion` `success`.

## D

- **`defaults`**: clave de workflow o de job que fija valores por defecto de todos sus `run:`:
  `shell` y `working-directory`.
- **Delimitador** (*delimiter*): marca que encierra un valor multilínea al escribirlo en
  `$GITHUB_OUTPUT` o `$GITHUB_ENV` (`name<<EOF` ... `EOF`). Si el valor puede contener el
  delimitador, usa uno aleatorio.

## E

- **`env`**: clave que define variables de entorno a nivel de workflow, de job o de step; gana la
  más concreta. También es el contexto que las lee en una expresión (`env.STAGE`).
- **Expresión** (*expression*): código entre `${{ }}` que GitHub evalúa **antes** de enviar el job
  al runner. Su resultado se pega como texto donde está escrita.

## F

- **`failure()`**: función de estado verdadera si algún step anterior (o job del que dependes) ha
  fallado. Para steps de diagnóstico que solo tienen sentido cuando algo se rompe.
- **Falsy**: valor que una expresión convierte en falso: `false`, `0`, `-0`, `""` y `null`. Todo
  lo demás es verdadero, incluida la cadena `"false"`.
- **`format()`**: función que sustituye `{0}`, `{1}`... en una plantilla por sus argumentos.
- **`fromJSON()`**: función que convierte una cadena JSON en un valor (objeto, número, booleano).
  La usarás para matrices dinámicas en la Semana 04.
- **Función de estado** (*status check function*): `success()`, `failure()`, `cancelled()` y
  `always()`. Un `if:` sin ninguna lleva `success() &&` implícito.

## G

- **`GITHUB_ENV`**: archivo donde un step escribe `NOMBRE=valor` para que los steps **siguientes**
  del mismo job tengan esa variable de entorno.
- **`GITHUB_OUTPUT`**: archivo donde un step con `id` escribe `nombre=valor` para publicar un output
  de step.
- **`GITHUB_PATH`**: archivo donde un step añade un directorio al `PATH` de los steps siguientes.
- **`GITHUB_STEP_SUMMARY`**: archivo donde un step escribe Markdown que aparece en la página del
  run, debajo del grafo de jobs.
- **Grafo de dependencias** (*dependency graph*): orden de los jobs que definen sus `needs:`. Los
  jobs sin relación corren en paralelo.

## H

- **`hashFiles()`**: función que devuelve un hash de los archivos que casan con un patrón
  (`hashFiles('api/uv.lock')`). Cambia solo si cambia el contenido. Base de las claves de caché de
  la Semana 03.

## I

- **Inyección de scripts** (*script injection*): ataque en el que un dato controlado por otro (el
  título de un PR, el nombre de una rama) se interpola con `${{ }}` dentro de un `run:` y se
  ejecuta como código. Se evita pasándolo por `env:`.

## J

- **Job saltado** (*skipped job*): job cuyo `if:` resulta falso, o que depende de uno que falló o
  se saltó. Su `result` vale `skipped` y sus outputs, cadena vacía.

## L

- **Literal**: valor escrito tal cual en una expresión: `true`, `42`, `'texto'` (siempre con
  comillas simples) o `null`.

## N

- **`needs`**: clave de job con la lista de jobs que tienen que terminar antes. También es el
  contexto que lee su `result` y sus `outputs` (`needs.version.outputs.version`).

## O

- **Objeto filtro** (*object filter*): sintaxis `*` que recorre todos los elementos de un objeto o
  lista dentro de una expresión: `needs.*.result` da la lista de resultados de todos los `needs`.
- **Outcome**: resultado de un step **antes** de aplicar `continue-on-error`. Es el que dice si el
  comando falló de verdad.
- **Output de job** (*job output*): valor que un job publica en su clave `outputs:`, mapeado desde
  un output de step. Lo leen los jobs que lo tienen en `needs`.
- **Output de step** (*step output*): valor que un step con `id` escribe en `$GITHUB_OUTPUT`. Solo
  lo ven los steps siguientes del mismo job, con `steps.<id>.outputs.<nombre>`.

## P

- **pipefail**: opción de bash (`set -o pipefail`) que hace fallar una tubería si falla cualquiera
  de sus comandos, no solo el último. `shell: bash` la activa; el shell por defecto, no.

## R

- **`result`**: resultado de un job leído desde otro con `needs.<job>.result`: `success`,
  `failure`, `cancelled` o `skipped`.

## S

- **set-output (retirado)**: comando antiguo `echo "::set-output name=x::valor"`. Se retiró porque
  cualquier texto impreso podía falsificarlo; hoy se usa `$GITHUB_OUTPUT`.
- **Shell**: intérprete que ejecuta un `run:`. En Linux, por defecto `bash -e {0}`; con
  `shell: bash`, `bash --noprofile --norc -eo pipefail {0}`.
- **Step id**: identificador (`id:`) que das a un step para leer sus outputs, su `outcome` y su
  `conclusion` desde los steps siguientes.
- **`success()`**: función de estado verdadera si nada anterior ha fallado ni se ha cancelado. Es
  la que se aplica sin escribirla.

## T

- **`toJSON()`**: función que convierte un valor en texto JSON. Útil para pasar un contexto entero
  (`toJSON(needs)`) a un script por `env:`. Nunca con `secrets`.

## V

- **Variable de configuración** (*configuration variable*): valor en claro definido en el repo o en
  la organización y leído con `vars.NOMBRE`. Para configuración, nunca para credenciales.
- **Variable de entorno por defecto** (*default environment variable*): variable que el runner
  define en todo job: `GITHUB_SHA`, `GITHUB_REF`, `GITHUB_WORKSPACE`, `RUNNER_OS`... Se lee desde
  el shell como `$GITHUB_SHA`.
- **`vars`**: contexto con las variables de configuración del repo, de la organización y del
  environment.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Semana 03 — CI de Python con uv](../../week-03-ci_de_python_con_uv/README.md) |
