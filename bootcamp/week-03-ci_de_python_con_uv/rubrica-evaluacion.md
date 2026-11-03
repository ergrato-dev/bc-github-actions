# Rúbrica de evaluación — Semana 03

> CI de Python con uv. Se aprueba con un **mínimo del 70 % en cada evidencia**, no en el promedio.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` |
| 📦 Producto | 30% | Autograding + calidad manual de `ci-api.yml` |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** `api/pyproject.toml` declara `fastapi>=0.162.0`. ¿Qué te garantiza `api/uv.lock` que ese
archivo no te garantiza?

<details>
<summary>Respuesta</summary>

`pyproject.toml` declara **rangos**: hoy `>=0.162.0` puede resolver a una versión y mañana a otra,
y las dependencias transitivas (Starlette, Pydantic…) ni siquiera aparecen. `uv.lock` guarda el
resultado de la resolución: la versión **exacta** de cada paquete, directo o transitivo, con el
hash de cada archivo, para todas las plataformas a la vez. Con el lockfile, tu máquina, el runner y
la imagen de la Semana 06 instalan exactamente lo mismo, y un paquete cuyo contenido cambie sin
cambiar de versión hace fallar la instalación por hash en vez de colarse.

</details>

**2.** `uv sync --locked` y `uv sync --frozen` usan los dos el lockfile. ¿En qué se diferencian y
cuál va en CI?

<details>
<summary>Respuesta</summary>

Con `--locked`, uv comprueba primero que `uv.lock` corresponde a `pyproject.toml` y **falla** si
no: alguien cambió una dependencia y no regeneró el lock. Con `--frozen`, uv instala lo que dice el
lockfile **sin comprobarlo** contra `pyproject.toml`. En CI va `--locked`: convierte "se me olvidó
hacer `uv lock`" en un fallo visible en el pull request. `--frozen` instalaría un lockfile viejo en
silencio y el CI daría verde con dependencias que no son las que declara el proyecto.

</details>

**3.** Tu job hace `uv sync --locked` y después `uv run --no-sync pytest`. ¿Qué evita el
`--no-sync`?

<details>
<summary>Respuesta</summary>

Por defecto, `uv run` vuelve a comprobar el proyecto antes de ejecutar: si ve que el entorno o el
lock no están al día, resuelve y sincroniza por su cuenta, y puede **reescribir `uv.lock`** sin que
nadie lo pida. Con `--no-sync`, `uv run` ejecuta en el entorno que dejó el `uv sync --locked`
anterior, sin tocar nada. Así hay un único punto donde se instalan dependencias, el que tiene la
garantía de `--locked`, y los steps siguientes no gastan tiempo ni cambian lo que se está probando.

</details>

**4.** Un compañero propone usar `actions/setup-python` y luego instalar las dependencias con `pip`.
¿Por qué este bootcamp no lo hace?

<details>
<summary>Respuesta</summary>

Porque `pip` resuelve las dependencias **en el momento de instalar**, sin el `uv.lock` del
proyecto: lo que se prueba en CI dejaría de ser lo que se ha bloqueado y lo que instala la imagen.
Además serían dos herramientas para algo que uv hace solo: uv lee `.python-version`, descarga esa
versión de Python si el runner no la tiene (el runner trae 3.12 y `tablero` pide 3.15) e instala
desde el lockfile. Una herramienta y un lockfile en local, en CI y en Docker significan un único
comportamiento que entender y depurar.

</details>

**5.** `astral-sh/setup-uv` ya está fijado por SHA. ¿Por qué además le pasas `version: "0.13.6"`?

<details>
<summary>Respuesta</summary>

El SHA fija **el código de la action**, no la versión de uv que descarga. Sin `version`, la action
instala la última versión de uv publicada ese día. Un uv nuevo puede cambiar cómo resuelve, el
formato del lockfile o un valor por defecto, y tu CI cambiaría de comportamiento sin un commit tuyo
que lo explique: el mismo problema que `ubuntu-latest`, en otra pieza. Con la versión fijada, subir <!-- antipatron -->
de uv es un cambio explícito en `docs/stack-versions.md` y en el workflow, revisable y reversible.

</details>

**6.** Con `enable-cache: true`, setup-uv guarda la caché de uv entre ejecuciones. ¿Por qué se
cachea esa caché y no directamente `api/.venv`, que ya tiene todo instalado?

<details>
<summary>Respuesta</summary>

Un `.venv` no es portable: guarda rutas absolutas y enlaces al intérprete concreto con el que se
creó, así que restaurarlo en otra máquina o con otro Python da errores raros o, peor, un entorno
que parece bien y no lo está. La caché de uv guarda paquetes descargados y construidos, y uv los
**enlaza** en un `.venv` nuevo en segundos: el entorno siempre se reconstruye desde el lockfile y
la caché solo ahorra la descarga. Antes de guardarla, setup-uv la poda (`uv cache prune --ci`):
quita las wheels que se descargan casi tan rápido como se restauran y conserva las que hubo que
compilar, que es donde la caché ahorra de verdad.

</details>

**7.** Abres un pull request y el job tarda lo mismo que sin caché, aunque `main` lleva días con la
caché en verde. En cambio, al segundo push al PR ya va rápido. ¿Qué está pasando?

<details>
<summary>Respuesta</summary>

Una caché tiene **ámbito de rama**: un run puede restaurar cachés de su propia rama, de la rama por
defecto y, en un pull request, de la rama base. Si el primer run del PR no encontró nada, la causa
más probable es que la clave no coincide con ninguna caché de `main`, por ejemplo porque el PR cambió
`api/uv.lock`, que forma parte de la clave. Ese run guarda una caché nueva con ámbito
`refs/pull/<N>/merge`, que solo ve ese PR: por eso el segundo push va rápido. Además, una caché que
nadie usa en 7 días se borra, y el repo tiene un límite de 10 GB: si `main` no ejecuta el workflow
a menudo, sus cachés desaparecen.

</details>

**8.** `ci-api.yml` repite checkout, setup-uv y `uv sync --locked` en `lint` y en `test`. ¿No sería
mejor un solo job con todos los steps?

<details>
<summary>Respuesta</summary>

Con dos jobs hay **dos señales independientes**: si falla ruff, sigues viendo si los tests pasan, y
al revés. En un solo job, el primer step que falla corta el resto y el PR te enseña un único rojo
sin decirte cuántos problemas hay. Además corren en paralelo y aparecen como dos checks con nombre
propio, que en la Semana 18 podrás exigir por separado. El coste es repetir la preparación; la
caché de uv lo deja en segundos, y en la Semana 10 lo reducirás a un solo step con una action
propia.

</details>

**9.** Tu job `test` pasa con `--cov-fail-under=60` y un 62 % de cobertura. ¿Qué te dice ese 62 % y
qué no te dice? ¿Por qué el umbral es 60 y no 90?

<details>
<summary>Respuesta</summary>

Dice qué porcentaje de **líneas del paquete `tablero`** se ejecutó durante los tests. No dice si
los tests comprueban algo: una línea ejecutada sin una aserción cuenta igual. Tampoco dice nada del
código que no está en `--cov=tablero`. El umbral es 60 porque `tests/unit` no toca la base de datos:
`migrate.py` y el repositorio de PostgreSQL solo se cubren con los tests de integración, que llegan
en la Semana 05. El umbral sirve de trinquete: protege la cobertura que tienes hoy, y se sube cuando
hay tests que la justifican, no para quedar bien.

</details>

**10.** En el job `lint`, ruff corre con `--output-format=github`. ¿Qué cambia respecto a la salida
normal y por qué compensa en CI?

<details>
<summary>Respuesta</summary>

Con ese formato, ruff escribe cada error como un **comando de workflow** que el runner convierte en
una anotación: el aviso aparece en el resumen del run y, en un pull request, junto a la línea exacta
del diff en *Files changed*. Ves el error sin abrir el log ni buscar el archivo. La salida normal
solo vive en el log del step. Es la misma información con mejor sitio; los comandos de workflow
que hay detrás los verás a fondo en la Semana 08.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — uv en local | `api/uv.lock` al día con `pyproject.toml` (check `uv-lock-in-sync`) | 5 |
| 01 — uv en local | Sabe provocar el fallo de `uv sync --locked` con un lock desincronizado y explicar qué haría `--frozen` | 5 |
| 02 — uv en un workflow | `python-lab.yml` lanzado a mano y en verde (check `python-lab-dispatched`) | 5 |
| 02 — uv en un workflow | Enseña en el log qué versión de Python usó el job y de dónde salió, sin `setup-python` | 5 |
| 03 — Caché y tiempos | El repo guarda al menos una caché (check `uv-cache-saved`) | 5 |
| 03 — Caché y tiempos | Compara la duración de un run sin caché y otro con acierto, con los datos de `gh run view --json jobs` | 5 |
| 04 — Romper y arreglar | `python-lab.yml` falló a propósito al menos una vez (check `python-lab-failed-once`) | 5 |
| 04 — Romper y arreglar | Para cada fallo sembrado señala el step que falló, el mensaje decisivo y el arreglo | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 03` con 17/17. Cada comprobación en rojo
resta la parte proporcional (12/17 de punto).

**Calidad manual de `.github/workflows/ci-api.yml` (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| Cada step tiene un `name:` que se entiende en la UI sin abrir el YAML | 3 |
| `cache-dependency-glob` apunta a `api/uv.lock`: la caché cambia cuando cambian las dependencias, no con cualquier archivo | 3 |
| ruff corre sin `--fix`: en CI se comprueba, no se corrige | 3 |
| Solo `tests/unit` en este workflow: los de integración esperan a PostgreSQL en la Semana 05 | 3 |
| Un comentario explica por qué el umbral de cobertura es el que es | 2 |
| Ningún `TODO` en `.github/workflows/` | 2 |
| Commits en inglés con Conventional Commits (`ci(api): add lint and test jobs`) | 2 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log | Grave: Producto a 0 hasta rotarlo y retirarlo |
| `pip`, un archivo de requirements o un `venv` creado a mano en cualquier workflow | Grave: −10 |
| `uses:` remota sin SHA | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}` interpolado dentro de `run:` | Grave: −10 |
| Imagen sin tag o con `latest` | Grave: −10 |
| `pip` o `npm` en un script o en la documentación de tu repo | −3 |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 03 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
