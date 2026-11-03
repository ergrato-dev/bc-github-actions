# Compose en CI

> Un service container te da una base al lado de los tests. Para probar `tablero` como lo usa
> alguien (las imágenes construidas, nginx delante, la API hablando con la base por la red) hace
> falta la pila entera, y la pila entera ya está descrita en `compose.yaml`.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Saber qué Docker y qué Compose trae `ubuntu-24.04` y cómo comprobarlo
- Levantar la pila en el runner con `up --build --wait --quiet-pull` y probarla con
  `scripts/smoke-test.sh`
- Volcar estado y logs solo cuando algo falla, y apagar con `down` pase lo que pase
- Elegir entre un service container y Compose según lo que quieras probar

## 1. Qué problema resuelve

Los tests de integración de la teoría 05 ejecutan la API dentro del proceso de `pytest`, con
`TestClient`. No pasan por el `Dockerfile` de la API, ni por el de la web, ni por el proxy de
nginx que reenvía `/api/` a la API, ni por los healthchecks de `compose.yaml`. Cualquiera de esas
piezas puede romperse con todos los tests en verde: una ruta mal copiada en el `Dockerfile`, un
`proxy_pass` con la barra de más, un healthcheck que apunta a un puerto viejo.

Un **smoke test** es la prueba mínima de que el conjunto arranca y responde. En `tablero` es
[`scripts/smoke-test.sh`](../../../app/scripts/smoke-test.sh), y necesita la pila levantada. El
runner ya trae lo necesario para levantarla.

## 2. Cómo funciona

### Docker y Compose en el runner

La imagen `ubuntu-24.04` trae Docker Engine y el plugin Compose instalados y en marcha: no hace
falta ninguna action para instalarlos. Las versiones exactas están en el
[README de la imagen](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md),
que cambia con cada publicación semanal. En la imagen `20261026.354.1`:

| Herramienta | Versión |
|---|---|
| Docker Client y Server | 28.0.4 |
| Docker Compose | 2.38.2 |
| Docker Buildx | 0.38.1 |

Fíjate en que no es la misma versión que tienes en local (aquí, Docker 29.9.2 y Compose v5.6.1).
Lo que usa esta semana (`up --build --wait --quiet-pull`, `ps --all`, `logs`, `down --volumes
--rmi local`) existe en las dos. El primer step del ejemplo imprime las versiones: si un día algo
se comporta distinto, el log dice con qué versión corrió.

### El flujo del job

1. **Checkout**: `compose.yaml`, los `Dockerfile` y `scripts/` tienen que estar en el disco.
2. **`docker compose up --build --wait --quiet-pull`**: construye `api` y `web`, descarga
   `postgres`, arranca en el orden de `depends_on` y **no vuelve hasta que los tres estén
   `healthy`**. Si alguno queda `unhealthy`, sale con código 1 y el step falla. No hace falta
   ningún `sleep` ni bucle de `curl` delante: la espera ya está hecha y ya falla sola.
3. **`./scripts/smoke-test.sh`**: con `set -euo pipefail` y `curl -fsS`, cualquier respuesta que
   no sea 2xx corta el script con error. Pide `/api/health`, crea una tarea, la busca en el
   listado y la borra, todo a través de `http://127.0.0.1:8080`, es decir, a través de nginx.
4. **Logs con `if: failure()`**: solo si algo de lo anterior falló, `docker compose ps --all` y
   `docker compose logs`. Es lo único que te dirá por qué no arrancó la API cuando el run ya no
   exista en tu terminal.
5. **`down` con `if: always()`**: corre aunque falle cualquier step anterior.

### Por qué `down` en un runner que se va a borrar

En un runner alojado por GitHub, la máquina virtual se destruye al terminar el job: el `down` no
libera nada que no fuera a desaparecer. Se pone igual por dos razones:

- **Runners propios** (Semana 15): ahí la máquina sigue. Sin `down`, el siguiente job encuentra
  contenedores, la red, el volumen con datos viejos y los puertos 8000 y 8080 ocupados.
- **El workflow dice lo que hace**: leerlo cuenta el ciclo completo, y moverlo a otro runner no
  exige recordar que faltaba limpiar.

`--volumes` borra `db-data` y `--rmi local` las imágenes construidas, como en la teoría 02.

### `COMPOSE_PROJECT_NAME`

En el `env:` del job, `COMPOSE_PROJECT_NAME: tablero-ci` gana a `name: tablero` del archivo. Todo
lo que crea el job lleva ese prefijo (`tablero-ci-api-1`, `tablero-ci_db-data`) y el `down` del
final borra exactamente eso. En un runner propio con otra pila de `tablero` en marcha, la tuya no
toca la suya. Como está en el `env:` del job, la ven todos los steps sin repetir `-p` en cada
orden.

### Service container o Compose

| Necesitas... | Service container | Compose |
|---|---|---|
| Una base para `pytest` en el mismo job | ✅ Lo natural | Funciona, con más pasos |
| Que el runner espere y limpie por ti | ✅ *Initialize* y *Stop containers* | Tú: `--wait` y `down` con `always()` |
| Construir imágenes de tu código | ❌ Solo imágenes ya publicadas | ✅ `build:` |
| Probar `Dockerfile`, nginx, red entre servicios | ❌ | ✅ |
| La misma definición que en local | ❌ Otra sintaxis en el workflow | ✅ El mismo `compose.yaml` |
| Ids de contenedor en el contexto `job.services` | ✅ | ❌ Se consultan con `docker compose ps` |
| Coste típico | Segundos | Minutos, por el build |

Por eso `tablero` usa los dos: `integration` en `ci-api.yml` con un service, rápido y en cada
cambio de la API, y `smoke.yml` con Compose para la pila entera.

## 3. Cómo se usa

```yaml
name: stack-check

on:
  pull_request:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  stack:
    name: Pila completa con Compose
    runs-on: ubuntu-24.04
    env:
      # Nombre de proyecto propio: contenedores, red, volumen e imágenes llevan este prefijo.
      COMPOSE_PROJECT_NAME: tablero-ci
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
      - name: Smoke test a través de nginx
        run: ./scripts/smoke-test.sh
      - name: Estado y logs si algo falla
        if: failure()
        run: |
          docker compose ps --all
          docker compose logs --no-color
      - name: Apagar y limpiar
        if: always()
        run: docker compose down --volumes --rmi local
```

- Sin `working-directory`: `compose.yaml` está en la raíz de `<tu-org>/tablero`.
- `{{.Server.Version}}` es una plantilla de Go para `docker`, no una expresión de Actions: las
  expresiones empiezan por `${{`, así que el runner la deja tal cual.
- `smoke-test.sh` tiene que tener el bit de ejecución en git; si no, el step falla con
  `Permission denied`. `git ls-files -s scripts/smoke-test.sh` debe empezar por `100755`.
- Ningún secreto: `POSTGRES_PASSWORD` cae en el valor por defecto `cambiame` de `compose.yaml`,
  desechable como el de la teoría 04.

En local lo mismo se reduce a tres órdenes:

```bash
export COMPOSE_PROJECT_NAME=tablero-lab
docker compose up --build --wait --quiet-pull && ./scripts/smoke-test.sh
# ...
# borrada. Smoke test OK
docker compose down --volumes --rmi local
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `up -d` y `sleep 30` | Lento cuando sobra, roto cuando no basta, y no detecta `unhealthy` | `up --wait` |
| Bucle de `curl` hasta que responda | Reimplementa el healthcheck, peor | Healthchecks en `compose.yaml` y `--wait` |
| `down` sin `if: always()` | Si el smoke falla, el `down` no corre | `if: always()` |
| Logs sin `if: failure()` | Miles de líneas en cada run verde | Solo al fallar |
| Instalar Compose con una action o `curl` | Una dependencia más y otra versión que fijar | El plugin que trae la imagen |
| Publicar `0.0.0.0:8080` | En un runner propio, la app queda abierta a su red | `127.0.0.1:` en `compose.yaml` |
| Sin `COMPOSE_PROJECT_NAME` | En un runner propio, `down` puede tumbar la pila de otro job | Nombre propio en el `env:` del job |

## 5. Trucos

- **`docker compose up --wait --wait-timeout 120`** pone un tope en segundos a la espera, por
  encima de lo que sumen `interval` y `retries` de cada healthcheck.
- **`docker compose logs --tail 50 api`** acota el volcado a un servicio y a sus últimas
  líneas cuando ya sabes cuál falló.
- **`docker compose ps --format json`** da el estado de cada servicio para procesarlo con `jq`.

Verificado con actions/checkout@v7.0.1, la imagen ubuntu-24.04 `20261026.354.1` (Docker 28.0.4,
Compose 2.38.2), noviembre de 2026.

## 📚 Recursos Adicionales

- [actions/runner-images: Ubuntu 24.04](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md)
- [`docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/)
- [`docker compose down`](https://docs.docker.com/reference/cli/docker/compose/down/)
- [Funciones de estado: `failure()` y `always()`](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions#status-check-functions)

## ✅ Checklist de Verificación

- [ ] Sé dónde mirar qué Docker y qué Compose trae el runner
- [ ] Levanto la pila con `--wait` y no tengo ningún `sleep`
- [ ] El smoke test pasa por nginx en `127.0.0.1:8080`
- [ ] Los logs salen solo con `if: failure()` y el `down` corre con `if: always()`
- [ ] Sé para qué sirve `COMPOSE_PROJECT_NAME` aunque el runner se borre
- [ ] Sé elegir entre service container y Compose

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Tests de integración](05-tests-de-integracion.md) | [Depurar servicios](07-depurar-servicios.md) |
