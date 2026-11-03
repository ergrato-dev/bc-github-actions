# Práctica 04 — Smoke test con Compose

> El service container te dio una base; ahora el runner levanta `tablero` entero, como hiciste en
> la práctica 01, y lo prueba de punta a punta. Rompes el smoke test dos veces a propósito: una
> para ver los logs de la pila y otra para comprobar que la limpieza corre aunque todo falle.

**Tiempo estimado**: 1 h 15 min

## 🎯 Qué vas a conseguir

- `compose-lab.yml`, un workflow de laboratorio que levanta la pila con Compose y se lanza a mano
- `docker compose up --build --wait --quiet-pull` con un `COMPOSE_PROJECT_NAME` propio
- `scripts/smoke-test.sh` contra nginx, en el runner
- Estado y logs de la pila **solo** si algo falla, con `if: failure()`
- `docker compose down` con `if: always()`, y la prueba en el log de que corre tras un fallo

## 📋 Antes de empezar

Terminaste la [práctica 03](03-job-en-contenedor-frente-a-runner.md) y no tienes cambios
pendientes:

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
```

`compose-lab.yml` es un banco de pruebas. El workflow que entregas es `smoke.yml`, en el proyecto
de la semana: no lo crees aquí, porque sus checks miran ese archivo y no este.

---

## Paso 1: Levantar la pila y esperar a que esté sana

**Por qué**: el runner `ubuntu-24.04` trae Docker 28.0.4 y Compose 2.38.2, así que no instalas
nada (teoría 06). `compose.yaml` está en la raíz de `tablero`, y por eso los `run:` no llevan
`working-directory`. Las tres opciones de `up` tienen un motivo cada una:

- `--build` construye `api` y `web` desde el código del commit, no desde una imagen vieja.
- `--wait` no devuelve el control hasta que los tres servicios están `healthy`; si uno no llega,
  el step falla ahí, con el nombre del servicio, y no más tarde con un `curl` confuso.
- `--quiet-pull` quita las barras de progreso de la descarga, que en un log son cientos de líneas.

`COMPOSE_PROJECT_NAME` cambia el prefijo de todo lo que crea Compose: contenedores, red, volumen e
imágenes empiezan por `tablero-lab`. En un runner alojado no hay con quién chocar, pero en tu
máquina o en un runner propio (Semana 15) dos pilas con el mismo nombre se pisan.

**Comando**: crea `.github/workflows/compose-lab.yml`.

```yaml
name: compose-lab

on:
  workflow_dispatch:

# Mínimo privilegio: el token solo lee. Lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  stack:
    name: tablero con Compose
    runs-on: ubuntu-24.04
    env:
      # Prefijo propio para contenedores, red, volumen e imágenes de este workflow.
      COMPOSE_PROJECT_NAME: tablero-lab
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Versiones de Docker y Compose
        run: |
          docker version --format '{{.Server.Version}}'
          docker compose version

      - name: Construir y esperar a que todo esté sano
        run: docker compose up --build --wait --quiet-pull
```

Antes de subirlo, haz lo mismo en tu máquina con el mismo nombre de proyecto:

```bash
export COMPOSE_PROJECT_NAME=tablero-lab
docker compose up --build --wait --quiet-pull
# ...
#  Container tablero-lab-api-1 Healthy
#  Container tablero-lab-db-1 Healthy
#  Container tablero-lab-web-1 Healthy
docker compose ps --format '{{.Name}} {{.Status}}'
# tablero-lab-api-1 Up 11 seconds (healthy)
# tablero-lab-db-1 Up 16 seconds (healthy)
# tablero-lab-web-1 Up 5 seconds (healthy)
```

**Verifica**:

```bash
actionlint .github/workflows/compose-lab.yml; echo "exit $?"
# exit 0
yq '.jobs.stack.env.COMPOSE_PROJECT_NAME' .github/workflows/compose-lab.yml
# tablero-lab
```

Deja la pila local levantada: la usas en el paso 2.

---

## Paso 2: El smoke test contra nginx

**Por qué**: `--wait` dice que cada contenedor pasa **su** healthcheck, no que la pila funcione
junta. `smoke-test.sh` entra por nginx (`127.0.0.1:8080`), así que prueba el proxy hacia la API, y
la API habla con PostgreSQL al crear, listar y borrar una tarea. Con `set -euo pipefail` y
`curl -f`, cualquier respuesta de error para el script con código distinto de 0 y el step falla.

El script tiene que tener el bit de ejecución **en git**, no solo en tu disco: el runner hace
checkout de lo que hay en el repo.

**Comando**: añade el step al final del job.

```yaml
      - name: Smoke test a través de nginx
        run: ./scripts/smoke-test.sh
```

```bash
./scripts/smoke-test.sh
# health:
# {"status":"ok","version":"dev"}
# creada la tarea 1
# la tarea aparece en el listado
# borrada. Smoke test OK
```

**Verifica**:

```bash
git ls-files -s scripts/smoke-test.sh | cut -c1-6
# 100755
./scripts/smoke-test.sh | tail -1
# borrada. Smoke test OK
```

Si el primer comando da `100644`, `git update-index --chmod=+x scripts/smoke-test.sh` y comitéalo.

---

## Paso 3: Estado y logs si algo falla, con un fallo a propósito

**Por qué**: si el smoke test falla, `curl` solo dice que no obtuvo respuesta. Saber si la culpa
es de la pila o de la prueba exige ver el estado de los contenedores y sus logs, y el step con
`if: failure()` los imprime solo cuando hacen falta (teoría 07). A diferencia de los service
containers, aquí *Stop containers* no te salva: esos contenedores los creó Compose, no el runner,
y nadie vuelca sus logs si tú no lo pides.

Lo pruebas pasando al script una URL donde no escucha nadie, el puerto `8081`. Es el mismo fallo
que verías si el puerto de `web` cambiara en `compose.yaml` y el script no.

**Comando**: añade el step al final y rompe la URL del smoke test.

```yaml
      - name: Estado y logs si algo falla
        if: failure()
        run: |
          docker compose ps --all
          docker compose logs --no-color
```

```bash
./scripts/smoke-test.sh http://127.0.0.1:8081; echo "exit $?"
# health:
# curl: (7) Failed to connect to 127.0.0.1 port 8081 after 0 ms: Connection refused
# exit 7
actionlint .github/workflows/compose-lab.yml; echo "exit $?"
# exit 0
git add .github/workflows/compose-lab.yml
git commit -m "ci(lab): add compose-lab workflow"
sed -i 's|run: ./scripts/smoke-test.sh$|run: ./scripts/smoke-test.sh http://127.0.0.1:8081|' \
  .github/workflows/compose-lab.yml
git commit -am "ci(lab): break smoke url on purpose"
git push
gh workflow run compose-lab.yml
sleep 5   # el run tarda unos segundos en aparecer en la lista
id=$(gh run list --workflow compose-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status; echo "exit $?"
# ... X Smoke test a través de nginx
# exit 1
gh run view "$id" --log | grep -E 'curl: \(7\)|\(healthy\)' | cut -c1-140
# ... curl: (7) Failed to connect to 127.0.0.1 port 8081 ...
# ... tablero-lab-api-1 ... Up ... (healthy) ...
# ... tablero-lab-db-1 ... Up ... (healthy) ...
# ... tablero-lab-web-1 ... Up ... (healthy) ...
```

La lectura es la que harías en un incidente: los tres servicios `healthy` y un `Connection
refused` en el `8081` dicen que la pila está bien y la prueba apunta mal.

Ahora deshazlo. El fallo va solo en el último commit, así que `revert` quita la URL rota y deja
el step de logs:

```bash
git revert --no-edit HEAD
git push
```

**Verifica**:

```bash
gh run view "$id" --json conclusion --jq .conclusion
# failure
grep -c 8081 .github/workflows/compose-lab.yml
# 0
yq '.jobs.stack.steps[-1].if' .github/workflows/compose-lab.yml
# failure()
```

---

## Paso 4: Apagar siempre, también tras un fallo

**Por qué**: un step sin `if:` lleva implícito `if: success()`: tras el fallo del paso 3, nada
habría apagado la pila. En un runner alojado da igual, porque la máquina se borra; en tu portátil
o en un runner propio quedan contenedores, el volumen con datos y las imágenes construidas, y el
siguiente job puede encontrarse la base de este (teoría 06). `if: always()` corre pase lo que
pase, y `--volumes --rmi local` borra lo que creó este proyecto sin tocar `postgres:17.11-alpine`.

> ⚠️ **Advertencia**: en tu máquina, `docker compose down --volumes` con
> `COMPOSE_PROJECT_NAME=tablero-lab` borra solo la pila `tablero-lab` de esta práctica, no el
> volumen `tablero_db-data` de tu `tablero` local. Si en la terminal no exportaste la variable,
> el proyecto es `tablero` y **sí** borra esos datos: comprueba antes con `echo "$COMPOSE_PROJECT_NAME"`.

**Comando**: apaga la pila local, añade el step al final y rompe la URL una vez más.

```bash
echo "$COMPOSE_PROJECT_NAME"
# tablero-lab
docker compose down --volumes --rmi local
# ...
#  Volume tablero-lab_db-data Removed
#  Network tablero-lab_default Removed
#  Image tablero-lab-web:latest Removed
#  Image tablero-lab-api:latest Removed
```

```yaml
      - name: Apagar y limpiar
        if: always()
        run: docker compose down --volumes --rmi local
```

```bash
git add .github/workflows/compose-lab.yml
git commit -m "ci(lab): always tear down the compose stack"
sed -i 's|run: ./scripts/smoke-test.sh$|run: ./scripts/smoke-test.sh http://127.0.0.1:8081|' \
  .github/workflows/compose-lab.yml
git commit -am "ci(lab): break smoke url again on purpose"
git push
gh workflow run compose-lab.yml
sleep 5
id=$(gh run list --workflow compose-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status; echo "exit $?"
# exit 1
git revert --no-edit HEAD
git push
```

Esta vez el `revert` deshace solo la URL rota: el step de limpieza iba en el commit anterior.

**Verifica**:

```bash
gh run view "$id" --json jobs --jq '.jobs[0].steps[] | [.name, .conclusion] | @tsv' \
  | grep -E 'Smoke|logs|limpiar'
# Smoke test a través de nginx	failure
# Estado y logs si algo falla	success
# Apagar y limpiar	success
gh run view "$id" --log | grep 'Apagar y limpiar' | grep 'Volume'
# ... Volume tablero-lab_db-data Removed
```

La línea que importa es `Apagar y limpiar	success` justo detrás de un `failure`: el volumen se
borró en un run rojo.

---

## Paso 5: En verde y lanzado a mano

**Por qué**: con la URL buena el run termina en `success`: el step de logs se salta y el de
limpieza corre igual, porque `always()` también es cierto cuando todo va bien.

**Comando**:

```bash
grep -c 8081 .github/workflows/compose-lab.yml
# 0
gh workflow run compose-lab.yml
sleep 5
id=$(gh run list --workflow compose-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status; echo "exit $?"
# exit 0
gh run view "$id" --log | grep -E 'Smoke test OK'
# ... borrada. Smoke test OK
```

**Verifica**:

```bash
gh run view "$id" --json jobs --jq '.jobs[0].steps[] | [.name, .conclusion] | @tsv' | grep -E 'logs|limpiar'
# Estado y logs si algo falla	skipped
# Apagar y limpiar	success
gh run list --workflow compose-lab.yml --event workflow_dispatch --status success \
  --json databaseId --jq length
# 1
```

---

## ✅ Resultado

- [ ] `compose-lab.yml` está en `main` y solo se lanza a mano
- [ ] La pila se levanta con `up --build --wait --quiet-pull` y un `COMPOSE_PROJECT_NAME` propio
- [ ] `smoke-test.sh` tiene el bit de ejecución en git y pasa en el runner
- [ ] Has leído el estado y los logs de la pila en un run rojo, gracias a `if: failure()`
- [ ] Has visto `Apagar y limpiar` en `success` justo detrás de un step en `failure`
- [ ] Un run de `compose-lab.yml` lanzado a mano terminó en `success`
- [ ] No queda ninguna pila `tablero-lab` en tu máquina

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 05
```

Esta práctica no tiene check propio: los `smoke-*` miran `smoke.yml`, que escribes en el proyecto
con lo que acabas de probar aquí.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `Permission denied` en el smoke test | `scripts/smoke-test.sh` está en git como `100644` | Paso 2: `git update-index --chmod=+x` y comitéalo |
| `no configuration file provided: not found` | Hay un `working-directory` o el checkout falta | `compose.yaml` está en la raíz del repo: paso 1 |
| `up --wait` sale con `dependency failed to start` | Un servicio no llegó a `healthy` | El step del paso 3 enseña cuál; mira su log |
| El step de logs no aparece en un run rojo | Falta `if: failure()`, o comiteaste el step y la URL rota juntos y el `revert` se llevó los dos | Paso 3: dos commits, y el `revert` solo del segundo |
| `Apagar y limpiar` sale `skipped` tras un fallo | Le falta `if: always()` | Paso 4 |
| En local, `down --volumes` borró tus tareas de `tablero` | `COMPOSE_PROJECT_NAME` no estaba exportado en esa terminal | Restaura tu volcado de la práctica 01, paso 5; exporta la variable antes |
| `Bind for 127.0.0.1:8080 failed: port is already allocated` en local | Sigue levantado tu `tablero` de la práctica 01 | `docker compose -p tablero down` o para lo que ocupe el puerto (`docker ps`) |
| El run falla con `startup_failure` | Tienes `sha_pinning_required` activo y una `uses:` va por tag | `scripts/resolve-sha.sh` (Semana 01, práctica 04, paso 3) |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Job en contenedor frente a runner](03-job-en-contenedor-frente-a-runner.md) | [Proyecto: capa 05 de tablero](../3-proyecto/README.md) |
