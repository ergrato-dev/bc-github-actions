# Práctica 03 — Contenedor endurecido e imagen al día

> El runner JIT ya no deja restos entre jobs, pero cada job aún corre con `sudo` sin contraseña,
> sin techo de memoria ni de procesos y sobre una imagen que solo nombras por tag. En esta
> práctica fijas la imagen por digest, dejas que Dependabot la mantenga al día y cierras el
> contenedor para que un job no pueda salir de él.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- La imagen del runner fijada por tag y digest del índice
- Dependabot vigilando `ops/runner`, porque un runner viejo deja de recibir jobs
- El `docker run` sin capacidades, sin escalada y con techo de procesos, memoria y CPU
- La prueba de que montar el socket de Docker regala tu máquina, y de que tu script no lo hace

## 📋 Antes de empezar

Terminaste la [práctica 02](02-runner-jit-efimero-en-docker.md): `jit-runner.sh` está en `main`
y no queda ningún runner registrado. Leíste la [teoría 05](../1-teoria/05-runner-en-contenedor.md).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
grep -E '^FROM ' ops/runner/Dockerfile
# FROM ghcr.io/actions/actions-runner:2.338.2
```

Ese `FROM` es el punto de partida: un tag que mañana puede apuntar a otra imagen.

---

## Paso 1: La imagen por digest

**Por qué**: un tag es una etiqueta que quien publica puede mover; un digest es el hash del
contenido y no se mueve nunca. El runner es la pieza que ejecuta código en tu máquina: la imagen
de la que parte tiene que ser exactamente la que revisaste. `tag@digest` deja las dos cosas:
el tag para que lo lean las personas y Dependabot, el digest para que Docker no acepte otra.

Fija el digest del **índice**, no el de una arquitectura: el índice apunta a la variante amd64 y
a la arm64, y Docker elige la de tu máquina. Es el mismo criterio que en la Semana 14.

**Comando**:

```bash
docker buildx imagetools inspect ghcr.io/actions/actions-runner:2.338.2 \
  --format '{{json .Manifest}}' | jq -r .digest
# sha256:6d0b2d80d80f143f77dcb676e50920100bbb547e39e883454d57f45ab8c31300
```

Deja `ops/runner/Dockerfile` así, con el digest que te ha salido:

```dockerfile
# Imagen del runner propio de tablero. Solo fija la oficial por tag y digest: así Dependabot
# (ecosistema docker en /ops/runner) te avisa de cada versión nueva del runner, que tiene que ir
# como mucho 63 días por detrás de la última para seguir recibiendo jobs.
FROM ghcr.io/actions/actions-runner:2.338.2@sha256:6d0b2d80d80f143f77dcb676e50920100bbb547e39e883454d57f45ab8c31300
```

```bash
docker build -q -t tablero-runner:local ops/runner > /dev/null && echo build-ok
# build-ok
git add ops/runner/Dockerfile
git commit -m "chore(runner): pin runner image by digest"
```

**Verifica**: la orden de `runner-image-pinned`:

```bash
grep -E '^FROM ' ops/runner/Dockerfile | grep -cE '^FROM ghcr\.io/actions/actions-runner:[0-9]+\.[0-9]+\.[0-9]+@sha256:[0-9a-f]{64}$'
# 1
```

---

## Paso 2: Dependabot vigila la imagen del runner

**Por qué**: fijar por digest congela la imagen, y un runner congelado caduca. GitHub deja de
mandar jobs a un runner que va más de 63 días por detrás de la última versión
([teoría 02](../1-teoria/02-como-funciona-el-runner.md)). Como cada contenedor nace de la
imagen y se tira tras un job, la versión del runner es la de la imagen: tiene que estar al día.
Dependabot lee las líneas `FROM` de cada directorio que le
das y abre un PR cuando hay tag o digest nuevo; tú lo revisas como cualquier otro cambio.

**Comando**: en `.github/dependabot.yml`, la entrada `docker` que añadiste en la Semana 14 pasa
a vigilar también `/ops/runner`:

```yaml
  # Mueve el digest de las líneas FROM cuando la imagen base publica uno nuevo bajo el mismo tag.
  - package-ecosystem: docker
    directories:
      - /api
      - /web
      - /ops/runner
    schedule:
      interval: weekly
    cooldown:
      default-days: 7
```

```bash
git add .github/dependabot.yml
git commit -m "chore(runner): watch runner image with dependabot"
```

Si pasas ahora el `check-week.sh 14`, su comprobación `dependabot-docker` saldrá en rojo: espera
exactamente `/api,/web`. Es a propósito, y lo recoge la tabla de comprobaciones que cambian de
semana en [`docs/autograding.md`](../../../docs/autograding.md).

**Verifica**: la orden de `dependabot-runner-image`:

```bash
yq '.updates[] | select(."package-ecosystem" == "docker") | (.directories // [.directory]) | sort | join(",")' .github/dependabot.yml
# /api,/ops/runner,/web
```

---

## Paso 3: Sin capacidades, sin escalada y con techo

**Por qué**: el contenedor del runner ejecuta lo que diga el job. La imagen oficial trae al
usuario `runner` con `sudo` sin contraseña: cualquier step puede ser root dentro del contenedor,
y root dentro con las capacidades por defecto es el primer escalón para salir
([teoría 05](../1-teoria/05-runner-en-contenedor.md)). Cada opción cierra una puerta:

| Opción | Qué cierra |
|---|---|
| `--cap-drop ALL` | Ninguna capacidad del kernel, ni siquiera las que Docker da por defecto |
| `--security-opt no-new-privileges` | Ningún proceso gana privilegios al ejecutar: `sudo` deja de funcionar |
| `--pids-limit 512` | Una *fork bomb* se queda en 512 procesos en lugar de tumbar tu máquina |
| `--memory 4g` · `--cpus 2` | Un job desbocado no se come la RAM ni la CPU del host |

`uv`, `pytest` y `actions/checkout` no necesitan root ni capacidades: el job de `lab.yml` funciona
igual. Lo que deja de funcionar es `sudo apt-get install` dentro de un job, y está bien así: lo
que haga falta se instala en la imagen y pasa por revisión.

**Comando**: primero mira la diferencia con tus ojos:

```bash
docker run --rm tablero-runner:local sudo -n true && echo con-escalada
# con-escalada
docker run --rm --cap-drop ALL --security-opt no-new-privileges tablero-runner:local sudo -n true || echo sin-escalada
# sudo: The "no new privileges" flag is set, which prevents sudo from running as root.
# sudo: If sudo is running in a container, you may need to adjust the container configuration to disable the flag.
# sin-escalada
```

Después deja el `docker run` de `jit-runner.sh` así:

```bash
  # Sin capacidades ni escalada (el sudo de la imagen deja de funcionar), con techo de procesos,
  # memoria y CPU, sin puertos publicados ni socket de Docker: un job no sale del contenedor.
  docker run --rm --name "$name" \
    --cap-drop ALL --security-opt no-new-privileges \
    --pids-limit 512 --memory 4g --cpus 2 \
    -e ACTIONS_RUNNER_INPUT_JITCONFIG \
    "$IMAGE" ./run.sh
```

```bash
git add ops/runner/jit-runner.sh
git commit -m "ci(runner): drop capabilities and cap runner resources"
```

**Verifica**: la orden de `runner-container-locked`, que une las líneas partidas con `\` y
busca cada opción en el `docker run`:

```bash
docker_run=$(sed -e ':a' -e '/\\$/N; s/\\\n//; ta' ops/runner/jit-runner.sh | grep -E '^[[:space:]]*docker run ')
for o in '--rm' '--cap-drop ALL' 'no-new-privileges' '--pids-limit' '--memory'; do
  grep -qe "$o" <<<"$docker_run" && printf 'ok ' || printf '%s ' "falta:$o"
done; echo
# ok ok ok ok ok
```

---

## Paso 4: El socket de Docker es root en tu máquina

**Por qué**: es la tentación habitual. Un job quiere construir una imagen, montas
`/var/run/docker.sock` en el contenedor del runner y funciona. Pero ese socket es la API del
demonio de Docker, que corre como root en el host: quien habla con él puede arrancar un
contenedor `--privileged` con `/` de tu máquina montado. Ninguna de las opciones del paso 3 lo
impide, porque el contenedor nuevo lo crea el demonio, no el job. Lo mismo vale, en menor
grado, para `--privileged`, montar volúmenes del host, publicar puertos o `--network host`.

**Comando**: una demostración que solo lee. Arranca un contenedor testigo y mira si otro
contenedor con el socket montado lo ve:

```bash
docker run -d --rm --name socket-witness tablero-runner:local sleep 120 > /dev/null
docker run --rm --name socket-demo \
  --group-add "$(stat -c %g /var/run/docker.sock)" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  tablero-runner:local docker ps --filter name=socket- --format '{{.Names}}'
# socket-demo
# socket-witness
docker run --rm tablero-runner:local docker ps 2>&1 | head -1
# failed to connect to the docker API at unix:///var/run/docker.sock; check if the path is correct and if the daemon is running: dial unix /var/run/docker.sock: connect: no such file or directory
docker rm -f socket-witness > /dev/null
```

El `--group-add` da al usuario `runner` el grupo dueño del socket en tu máquina; un job con
`sudo` ni lo necesitaría. Con el socket, el contenedor ve (y podría parar, o arrancar con tu
disco montado) todo lo que corre en tu host. Sin él, ni siquiera encuentra el demonio.

**Verifica**: la orden de `runner-container-isolated`; no tiene que imprimir nada:

```bash
docker_run=$(sed -e ':a' -e '/\\$/N; s/\\\n//; ta' ops/runner/jit-runner.sh | grep -E '^[[:space:]]*docker run ')
grep -oE -e '--privileged|docker\.sock|(^| )(-v|--volume|--mount|-p|--publish)[ =]|--network[ =]host' <<<"$docker_run" || true
# (sin salida)
git push
```

---

## ✅ Resultado

- [ ] `ops/runner/Dockerfile` parte de `actions-runner:2.338.2@sha256:…` con el digest del índice
- [ ] Dependabot vigila `/api`, `/web` y `/ops/runner` en el ecosistema `docker`
- [ ] Viste `sudo` funcionar sin las opciones y fallar con `no-new-privileges`
- [ ] El `docker run` lleva `--rm`, `--cap-drop ALL`, `no-new-privileges`, `--pids-limit` y `--memory`
- [ ] Viste lo que alcanza un contenedor con el socket de Docker, y tu script no lo monta

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 15
# ...
# ✅ ops/runner/Dockerfile parte de la imagen oficial ghcr.io/actions/actions-runner fijada por tag y digest
# ✅ dependabot.yml vigila la imagen del runner: el ecosistema docker incluye /ops/runner además de /api y /web
# ✅ El contenedor del runner se borra al salir (--rm) y corre sin capacidades, sin escalada y con techo de procesos y memoria
# ✅ El contenedor del runner no es privilegiado, no monta el socket de Docker ni volúmenes y no publica puertos ni usa la red del host
# ...
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `imagetools inspect` da varias líneas o ninguna | Falta el `--format` o no llegas a `ghcr.io` | Copia la orden del paso 1 tal cual; la imagen es pública, no necesita login |
| `docker build` no encuentra la imagen | El digest no corresponde a ese tag o le falta un carácter | Vuelve a sacarlo con `imagetools inspect` y pégalo entero |
| `dependabot-runner-image` da `/api,/web` | Añadiste `/ops/runner` a otra entrada o a otro ecosistema | Una sola entrada `docker` con los tres directorios |
| `falta:--cap-drop ALL` aunque está en el script | Una línea partida tiene espacios después de la `\` | La `\` tiene que ser el último carácter de la línea |
| `docker ps` del paso 4 da `permission denied` | Falta `--group-add` o tu socket está en otra ruta | Usa el `--group-add` del paso 4; con Docker Desktop, la ruta puede ser otra |
| El testigo no aparece en la lista | Se paró antes (`sleep 120`) | Vuelve a arrancarlo y repite |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Runner JIT efímero en Docker](02-runner-jit-efimero-en-docker.md) | [El workflow del runner propio](04-workflow-del-runner-propio.md) |
