# Rúbrica de evaluación — Semana 01

> Primer workflow y modelo de ejecución. Se aprueba con un **mínimo del 70 % en cada evidencia**,
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

**1.** Haces `git push` a `main` y en la pestaña Actions aparece una línea nueva. Nombra, en orden,
las cuatro piezas que hay entre tu push y la primera línea de log, y di qué es cada una.

<details>
<summary>Respuesta</summary>

1. **Evento** (`push`): GitHub registra que ha pasado algo en el repo, con su SHA y su rama.
2. **Ejecución** (*workflow run*): por cada workflow de `.github/workflows/` cuyo `on:` casa con
   ese evento, GitHub crea una ejecución ligada a ese SHA concreto.
3. **Job**: cada job de la ejecución se encola y se asigna a un runner que cumple su `runs-on`.
4. **Step**: dentro del runner, los steps del job corren uno detrás de otro; el primer log que ves
   es el del primer step (precedido por el *Set up job* que añade el propio runner).

Si un workflow no aparece, el fallo está en el paso 2: su `on:` no casa con el evento, o el archivo
no está en la ruta correcta.

</details>

**2.** Tu workflow tiene dos jobs, `runner-info` y `structure`. En `runner-info` escribes un
archivo en `/tmp/info.txt` y en `structure` intentas leerlo. ¿Qué pasa y por qué?

<details>
<summary>Respuesta</summary>

`structure` no encuentra el archivo. Cada job de un runner alojado corre en **su propia máquina
virtual**, recién creada para ese job y destruida al terminar: no comparten disco, ni procesos, ni
variables. Sin `needs:` además corren en paralelo, así que ni siquiera hay un orden. Para pasar
datos entre jobs hacen falta outputs o artefactos, que verás en las Semanas 02 y 04. Lo que sí
comparten los steps de un **mismo** job es la máquina y el directorio de trabajo.

</details>

**3.** `ubuntu-latest` y `ubuntu-24.04` arrancan hoy exactamente la misma imagen. ¿Por qué este <!-- antipatron -->
bootcamp prohíbe la primera?

<details>
<summary>Respuesta</summary>

Porque `ubuntu-latest` es una **etiqueta móvil**: GitHub la mueve a la imagen nueva cuando decide, <!-- antipatron -->
sin que cambies nada en tu repo. Hoy apunta a 24.04, pero `ubuntu-26.04` ya existe en
`actions/runner-images`, y el día que `latest` salte tu CI cambiará de sistema operativo, de
versiones de herramientas preinstaladas y quizá de comportamiento, sin un commit que lo explique.
Con `ubuntu-24.04` el cambio de imagen es un commit tuyo, revisable y reversible.

</details>

**4.** Un script de Python lee tu workflow con un parser YAML 1.1 y escribe sus claves de primer
nivel: `name`, `True`, `permissions`, `jobs`. ¿Dónde está `on` y por qué ha pasado esto?

<details>
<summary>Respuesta</summary>

YAML 1.1 interpreta como booleanos palabras como `on`, `off`, `yes` y `no`, así que la clave `on`
se ha leído como el booleano `true`. GitHub Actions no tiene este problema porque trata `on` como
una cadena, pero cualquier herramienta tuya que use un parser 1.1 sí. Es el mismo fenómeno que
convierte el código de país `NO` en `false` (el «problema de Noruega»). Por eso en las prácticas se
usa `yq` (mikefarah v4), que lee `on` como cadena, y conviene entrecomillar los valores que parecen
booleanos o números (`"3.15"`, no `3.15`).

</details>

**5.** Abres un pull request desde la rama `feature/login` hacia `main`. El workflow se ejecuta con
el evento `pull_request`. ¿El código que prueba es exactamente el último commit de `feature/login`?

<details>
<summary>Respuesta</summary>

No. Con `pull_request`, `GITHUB_SHA` es el **commit de merge** que GitHub prepara en
`refs/pull/<N>/merge`: tu rama ya fusionada con el `main` actual. Prueba lo que quedaría en `main`
si aceptaras el PR, que es lo que importa. Consecuencia práctica: si `main` avanza, el mismo PR
puede pasar a rojo sin que toques tu rama, y el SHA de la ejecución no coincide con el de tu último
commit.

</details>

**6.** Añades `workflow_dispatch` a un workflow en tu rama `feature/ci` y, antes de fusionarla,
quieres lanzarlo desde la pestaña Actions. El botón *Run workflow* no aparece. ¿Por qué?

<details>
<summary>Respuesta</summary>

Porque GitHub decide si un workflow admite `workflow_dispatch` leyendo el archivo **en la rama por
defecto** (`main`). Mientras el trigger solo exista en `feature/ci`, para GitHub ese workflow no se
puede lanzar a mano. Una vez que el archivo con `workflow_dispatch` está en `main`, sí puedes
elegir otra rama al lanzarlo (`gh workflow run hello.yml --ref feature/ci`), y entonces se ejecuta
la versión del archivo de esa rama.

</details>

**7.** Un tutorial usa `uses: alguien/accion@v2`. Explica con el caso de `tj-actions/changed-files`
(marzo de 2025) por qué este bootcamp exige `@<SHA de 40 caracteres> # v2.x.y`.

<details>
<summary>Respuesta</summary>

Un tag de Git es un puntero que el dueño del repo, o quien robe sus credenciales, puede mover a
otro commit. En marzo de 2025 un atacante movió los tags de `tj-actions/changed-files` a un commit
malicioso que volcaba los secretos del runner en el log; todos los workflows que usaban `@v45` o
`@v35` ejecutaron ese código sin cambiar una línea (GHSA-mw4p-6x4p-x5m5). Un SHA identifica el
contenido: no se puede mover. Fijar por SHA hace que solo corra el código que tú revisaste, y el
comentario `# v2.x.y` deja legible qué versión es. Con `sha_pinning_required` el repo rechaza
cualquier `uses:` que no cumpla esto.

</details>

**8.** ¿Qué hace `persist-credentials: false` en `actions/checkout` y por qué se pone en un job que
solo lee el código?

<details>
<summary>Respuesta</summary>

Por defecto, `actions/checkout` guarda el token con el que clona en la configuración de Git del
directorio de trabajo, para que los steps siguientes puedan hacer `git push` o `git fetch`.
`persist-credentials: false` no lo guarda. En un job que solo lee, ese token guardado no sirve para
nada y es un riesgo: cualquier step o herramienta posterior (un script, una dependencia, una action
de terceros) puede leerlo del disco. Si no lo necesitas, no lo dejes ahí. Solo se quita cuando el
job hace `git push`, y entonces se justifica en un comentario.

</details>

**9.** ¿Por qué tu `ci.yml` declara `permissions: contents: read` en la raíz si además has puesto el
token del repo como «solo lectura» en los ajustes?

<details>
<summary>Respuesta</summary>

Porque son dos capas distintas. El ajuste del repo es un **valor por defecto** que cualquier
administrador puede cambiar, y que no viaja con el código: si alguien copia `ci.yml` a otro repo
con el valor por defecto en lectura y escritura, el workflow heredaría permisos de escritura. El
bloque `permissions:` en el archivo fija el permiso en el propio workflow, se revisa en cada PR y
declara de forma explícita qué necesita. Mínimo privilegio en los dos sitios: lo verás a fondo en
la Semana 12.

</details>

**10.** Un job falla. Arreglas el problema con un commit nuevo y luego pulsas *Re-run failed jobs*
en la ejecución que falló. Sigue en rojo. ¿Por qué?

<details>
<summary>Respuesta</summary>

Porque un *re-run* vuelve a ejecutar **la misma ejecución**: el mismo evento, el mismo SHA y el
mismo archivo de workflow que tenía ese commit. Tu arreglo está en un commit posterior, que tiene su
propia ejecución. El re-run sirve para fallos ajenos al código (una caída de red, un servicio
externo intermitente) o para repetir con `--debug` y ver más log. Para probar tu arreglo, mira la
ejecución del commit nuevo.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Organización y repo tablero | Repo público dentro de una organización (checks `repo-is-public` y `repo-owned-by-org`) | 5 |
| 01 — Organización y repo tablero | El código de `tablero` en la raíz (check `app-at-root`) | 5 |
| 01 — Organización y repo tablero | Token por defecto de solo lectura y aprobación para todos los colaboradores externos (checks `default-token-read` y `fork-approval-all`) | 5 |
| 02 — Tu primer workflow | `hello.yml` corrió en push; sabe enseñar el step que hizo fallar a propósito y el commit que lo arregló | 5 |
| 03 — gh CLI para Actions | `hello.yml` lanzado a mano y en verde (check `hello-dispatched`) | 5 |
| 03 — gh CLI para Actions | Sabe localizar el log de un step fallido con `gh run view --log-failed` y explicar qué repite un `gh run rerun` | 5 |
| 04 — actionlint y pinning por SHA | El repo exige SHA completo (check `sha-pinning-required`) | 5 |
| 04 — actionlint y pinning por SHA | Toda `uses:` remota fijada por SHA con el tag en comentario (check `workflows-pinned`) | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 01` con 17/17. Cada comprobación en rojo
resta la parte proporcional (12/17 de punto).

**Calidad manual de `.github/workflows/ci.yml` (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| Cada step tiene un `name:` que se entiende en la UI sin abrir el YAML | 3 |
| El step de estructura dice **qué archivo** falta, no solo que algo falla | 4 |
| Commits en inglés con Conventional Commits (`ci: add ci workflow`) | 3 |
| Ningún `TODO` en `.github/workflows/` | 3 |
| Un comentario junto a `permissions:` explica para qué está | 3 |
| Ningún `ubuntu-latest` en ningún workflow | 2 <!-- antipatron --> |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log | Grave: Producto a 0 hasta rotarlo y retirarlo |
| `uses:` remota sin SHA | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}` interpolado dentro de `run:` | Grave: −10 |
| Imagen sin tag o con `latest` | Grave: −10 |
| `pip` o `npm` en cualquier workflow o script | −3 |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 01 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
