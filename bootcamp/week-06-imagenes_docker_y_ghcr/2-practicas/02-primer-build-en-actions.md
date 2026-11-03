# Práctica 02 — Primer build en Actions

> Lo que en la práctica 01 hiciste con un builder `docker-container` y `--load`, ahora lo hace el
> runner. Esta práctica construye la imagen de la web en Actions, la carga en el Docker del runner,
> la arranca y comprueba que nginx sirve la portada. No publica nada: el registro llega en la 03.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `build-lab.yml`, un workflow de laboratorio que solo se lanza a mano
- `setup-buildx-action` y `build-push-action` con `push: false` y `load: true`
- Arrancar la imagen recién construida con `docker run` y pedirle la portada con `curl`
- Entender por qué nginx necesita `--add-host api:127.0.0.1` aunque la API no exista en el job
- Un run rojo a propósito, con el log de nginx a la vista gracias a `if: failure()`

## 📋 Antes de empezar

Terminaste la [práctica 01](01-construir-en-local-con-buildx.md), tienes `tablero-web:dev` en tu
Docker y no hay cambios pendientes:

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
git status -sb
# ## main...origin/main
docker image ls -q tablero-web:dev | wc -l
# 1
```

`build-lab.yml` es un banco de pruebas. El workflow que entregas es `images.yml`, que empieza en la
práctica 03: no mezcles los dos, porque los checks del proyecto miran solo `images.yml`.

---

## Paso 1: Construir y cargar en el runner

**Por qué**: `setup-buildx-action` crea en el runner el mismo builder `docker-container` que
creaste a mano en el paso 6 de la práctica 01. `build-push-action` llama a `docker buildx build`
con lo que le pases ([teoría 03](../1-teoria/03-buildkit-y-buildx.md#dockerbuild-push-action)).
Con ese driver la imagen no aparece en el Docker del runner salvo que la cargues: `load: true` es
lo que permite el `docker run` del paso 3. `push: false` es el valor por defecto; lo escribes para
que quien lea el YAML no tenga que saberlo.

`context: web` es la carpeta `web/` del checkout. `tablero-web:ci` no lleva registro: es un nombre
local que nunca sale del runner, y por eso no choca con la regla de "nunca `latest`" ni necesita
login.

**Comando**: crea `.github/workflows/build-lab.yml`.

```yaml
name: build-lab

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  web:
    name: Imagen de la web, cargada y probada
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - uses: docker/setup-buildx-action@f87e5991a6d7451dcb8d9637bfbc97413f497069 # v4.4.1

      - name: Construir y cargar en el Docker del runner
        id: build
        uses: docker/build-push-action@c3c9e263c25d99ce0380d002d59b67737d91b0dc # v7.4.0
        with:
          context: web
          push: false
          load: true
          tags: tablero-web:ci
```

**Verifica**:

```bash
actionlint .github/workflows/build-lab.yml; echo "exit $?"
# exit 0
yq '.jobs.web.steps[2].with | [.push, .load] | map(tostring) | join(",")' .github/workflows/build-lab.yml
# false,true
yq '.on | keys | join(",")' .github/workflows/build-lab.yml
# workflow_dispatch
```

No lo subas todavía: falta probar la imagen.

---

## Paso 2: Por qué nginx necesita `--add-host`

**Por qué**: `web/nginx.conf` reenvía `/api/` a `http://api:8000`. nginx resuelve ese nombre **al
arrancar**, y si no lo encuentra se niega a arrancar. En Compose (Semana 05) `api` era el nombre de
un servicio de la red de la pila; en el runner, con un `docker run` suelto, no existe. Lo pruebas
primero en tu máquina, que es más rápido que un run. Usas el puerto 8081 para no chocar con
`tablero` si lo tienes levantado con Compose en el 8080.

**Comando**: sin `--add-host`, nginx muere nada más arrancar.

```bash
docker run -d --name web-noapi -p 127.0.0.1:8081:8080 tablero-web:dev
sleep 2
docker logs web-noapi 2>&1 | tail -1
# nginx: [emerg] host not found in upstream "api" in /etc/nginx/conf.d/default.conf:6
docker rm -f web-noapi
```

Con `--add-host api:127.0.0.1`, Docker escribe `api` en el `/etc/hosts` del contenedor. nginx
arranca; si alguien pide `/api/`, el proxy fallará, pero la portada se sirve.

```bash
docker run -d --name web-lab --add-host api:127.0.0.1 -p 127.0.0.1:8081:8080 tablero-web:dev
curl -fsS --retry 10 --retry-connrefused --retry-delay 1 http://127.0.0.1:8081/ \
  | grep -o '<title>.*</title>'
# <title>tablero</title>
```

**Verifica**:

```bash
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8081/
# 200
docker rm -f web-lab
# web-lab
```

---

## Paso 3: Arrancar la imagen en el runner y pedir la portada

**Por qué**: un build en verde solo dice que el `Dockerfile` terminó, no que la imagen funcione.
Arrancarla y pedirle la portada es el smoke test más barato que hay. `curl -f` convierte un `404` o
un `502` en exit distinto de cero, y `--retry-connrefused` cubre el segundo que tarda nginx en
escuchar. El `grep` confirma que lo servido es el `index.html` de `tablero` y no una página de
error de nginx.

El puerto se publica en `127.0.0.1` también en el runner (regla 12): no cuesta nada y es la misma
costumbre que en tu máquina. El step de logs, con `if: failure()`, corre solo si algo falla antes,
como en la práctica 02 de la Semana 05.

**Comando**: añade dos steps al final del job.

```yaml
      - name: Arrancar y pedir la portada
        # nginx.conf cita el host "api" en proxy_pass y nginx no arranca si no lo resuelve:
        # --add-host le da una dirección aunque la API no exista en este job.
        run: |
          docker run -d --name web --add-host api:127.0.0.1 -p 127.0.0.1:8080:8080 tablero-web:ci
          curl -fsS --retry 10 --retry-connrefused --retry-delay 1 http://127.0.0.1:8080/ \
            | grep '<title>tablero</title>'

      - name: Logs de nginx si algo falla
        if: failure()
        run: docker logs web
```

**Verifica**:

```bash
actionlint .github/workflows/build-lab.yml; echo "exit $?"
# exit 0
yq '.jobs.web.steps[-1].if' .github/workflows/build-lab.yml
# failure()
grep -c 'add-host api:127.0.0.1' .github/workflows/build-lab.yml
# 1
```

---

## Paso 4: Romperlo a propósito

**Por qué**: quieres ver el fallo del paso 2 en el runner, y comprobar que el step de logs te lo
enseña sin entrar al contenedor. `gh workflow run` solo lanza workflows que ya están en la rama por
defecto, y `build-lab.yml` no escucha `push`, así que subirlo no lanza nada: el run es el que pides
tú. Quitas `--add-host` en un commit y lo devuelves en el paso 5.

**Comando**:

```bash
sed -i 's/ --add-host api:127.0.0.1//' .github/workflows/build-lab.yml
grep -c 'add-host' .github/workflows/build-lab.yml
# 1
```

Sale `1` porque el comentario del step sigue citando `--add-host`; la orden `docker run` ya no lo
lleva. Sube y lanza:

```bash
git add .github/workflows/build-lab.yml
git commit -m "ci(lab): add build-lab workflow without api host"
git push
gh workflow run build-lab.yml
sleep 5
id=$(gh run list --workflow build-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status; echo "exit $?"
# ... X Arrancar y pedir la portada
# exit 1
```

**Verifica**:

```bash
gh run view "$id" --json conclusion --jq .conclusion
# failure
gh run view "$id" --log | grep -o 'host not found in upstream "api"' | head -1
# host not found in upstream "api"
```

Ese mensaje viene del step *Logs de nginx si algo falla*. Sin él, el log solo diría que `curl` no
pudo conectar, y tendrías que adivinar por qué.

---

## Paso 5: En verde y lanzado a mano

**Por qué**: con `--add-host` de vuelta, el run tiene que terminar en `success` y el step de logs
salir `skipped`. La comprobación `build-lab-dispatched` busca exactamente eso: al menos un run de
`build-lab.yml` disparado por `workflow_dispatch` que acabó en `success`. Un run rojo no cuenta,
aunque sea el más reciente.

**Comando**:

```bash
sed -i 's/docker run -d --name web -p/docker run -d --name web --add-host api:127.0.0.1 -p/' \
  .github/workflows/build-lab.yml
grep -c 'add-host api:127.0.0.1 -p 127.0.0.1:8080:8080' .github/workflows/build-lab.yml
# 1
git add .github/workflows/build-lab.yml
git commit -m "ci(lab): give nginx an api host in build-lab"
git push
gh workflow run build-lab.yml
sleep 5
id=$(gh run list --workflow build-lab.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$id" --exit-status; echo "exit $?"
# ... ✓ Arrancar y pedir la portada
# exit 0
gh run view "$id" --log | grep -o '<title>tablero</title>' | head -1
# <title>tablero</title>
```

El resumen del run trae además el resumen de build de `build-push-action`: duración, pasos y
cuántos salieron de caché ([teoría 03](../1-teoria/03-buildkit-y-buildx.md#el-resumen-de-build)).
Ábrelo con `gh run view "$id" --web`.

**Verifica**:

```bash
gh run list --workflow build-lab.yml --event workflow_dispatch --status success \
  --json databaseId --jq length
# 1
```

Pide al menos uno.

---

## ✅ Resultado

- [ ] `build-lab.yml` está en `main` y solo se lanza a mano
- [ ] El build usa `setup-buildx-action` y `build-push-action` fijadas por SHA, con `push: false` y `load: true`
- [ ] Sabes por qué sin `load: true` el `docker run` no encuentra `tablero-web:ci`
- [ ] Sabes por qué nginx necesita `--add-host api:127.0.0.1` fuera de Compose
- [ ] Has visto `host not found in upstream "api"` en un run rojo gracias a `if: failure()`
- [ ] Un run de `build-lab.yml` lanzado a mano terminó en `success`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 06
```

Ya pasa `build-lab-dispatched`.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `gh workflow run` dice `could not find any workflows named build-lab.yml` | El archivo no está en `main` | `git ls-tree --name-only origin/main .github/workflows/` tiene que listarlo |
| `Unable to find image 'tablero-web:ci' locally` y `pull access denied for tablero-web` | Falta `load: true`: la imagen se quedó en la caché del builder | Paso 1 |
| `curl: (7) Failed to connect` tras los 10 reintentos | nginx no arrancó; casi siempre, falta `--add-host` | El step de logs lo dice; paso 2 |
| `grep` sale con exit 1 aunque `curl` dio 200 | Sirvió otra cosa: `dist` vacío o `nginx.conf` sin `try_files` | `docker run` en local con `tablero-web:dev` y `curl` a la portada |
| `Bind for 127.0.0.1:8081 failed: port is already allocated` en local | Sigue un contenedor del paso 2 | `docker rm -f web-noapi web-lab` |
| El run falla con `startup_failure` | Tienes `sha_pinning_required` activo y una `uses:` va por tag | `scripts/resolve-sha.sh` (Semana 01, práctica 04, paso 3) |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Construir en local con buildx](01-construir-en-local-con-buildx.md) | [Publicar en GHCR](03-publicar-en-ghcr.md) |
