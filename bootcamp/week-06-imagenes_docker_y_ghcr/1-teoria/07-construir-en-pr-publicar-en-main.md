# Construir en PR, publicar en main

> Un pull request tiene que demostrar que las imágenes siguen construyendo, porque un `Dockerfile`
> roto en `main` rompe el siguiente despliegue. Pero un PR no debe publicar nada: su código aún no
> lo ha revisado nadie y, si viene de un fork, ni siquiera tiene permiso para hacerlo.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué token y qué permisos recibe un job en un PR desde una rama y en uno desde un fork
- Saltar el login y el push en los pull requests con una sola condición
- Explicar por qué la condición es `!= 'pull_request'` y no `== 'push'`
- Construir las dos imágenes con una matriz y saber qué cambia en cada entrada
- Comprobar que un PR construyó sin publicar nada

## 1. Qué problema resuelve

Hay dos formas fáciles de hacerlo mal:

- **Construir solo en `main`**. El PR sale verde, se fusiona, y el `Dockerfile` roto se descubre
  después, en `main`, con la imagen anterior como única publicada. El fallo llega tarde y en la
  rama que todos usan.
- **Publicar también en los PR**. Cualquier rama sin revisar deja imágenes en GHCR con el nombre
  de tu organización. Y en un PR desde un fork el token no puede escribir: el job falla en rojo
  para todo contribuidor externo.

Lo que quieres es un mismo workflow que **en un PR construya y compruebe**, y **fuera de los PR
construya y publique**.

## 2. Cómo funciona

### El token en cada evento

| Evento | Permisos del `GITHUB_TOKEN` | Secretos del repo |
|---|---|---|
| `push` a `main` | Los que declare el job (`packages: write`) | Sí |
| `workflow_dispatch` | Los que declare el job | Sí |
| `pull_request` desde una rama del mismo repo | Los que declare el job | Sí |
| `pull_request` desde un **fork** | **Solo lectura**, declare lo que declare | No |

La última fila es la que manda. GitHub no le da escritura a un código que puede venir de
cualquiera, así que en un PR desde un fork `packages: write` no se concede. Y la penúltima no es
una invitación: aunque una rama del mismo repo *pueda* publicar, publicar código sin revisar es
justo lo que quieres evitar. Las dos se tratan igual: en `pull_request`, ni login ni push.

### Una condición, dos sitios

```yaml
      - name: Iniciar sesión en GHCR
        if: ${{ github.event_name != 'pull_request' }}
        uses: docker/login-action@81c6f93d4bc991e510b342a00b419b3bb4efc5c6 # v4.7.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Construir y, fuera de los PR, publicar
        id: build
        uses: docker/build-push-action@c3c9e263c25d99ce0380d002d59b67737d91b0dc # v7.4.0
        with:
          context: ${{ matrix.image }}
          push: ${{ github.event_name != 'pull_request' }}
```

- **En el login, como `if:`**: en un PR el step se salta (sale gris en la UI). No hay credencial en
  el runner que nadie vaya a usar, y no hay token de un fork intentando nada contra GHCR. El check
  `images-login-not-on-pr` comprueba este `if:`.
- **En el build, como valor de `push`**: el step **siempre** corre; lo que cambia es si exporta al
  registro. La expresión da `true` o `false`, que es justo lo que el input espera.

Si pusieras el `if:` en el build en vez de en `push`, los PR no construirían nada y volverías al
primer error de la sección 1.

### Por qué `!=` y no `==`

`github.event_name == 'push'` parece equivalente y no lo es: deja fuera `workflow_dispatch`, el
botón con el que relanzas la publicación a mano sin hacer un commit. Con `!= 'pull_request'`
publican los dos eventos de confianza del workflow y solo el PR queda fuera.

| Evento | Login | `push` | Etiquetas |
|---|:--:|:--:|---|
| `pull_request` | Saltado | `false` | `pr-N`, `sha-…`, calculadas y no publicadas |
| `push` a `main` | ✅ | `true` | `main`, `sha-…` |
| `workflow_dispatch` | ✅ | `true` | Nombre de la rama elegida, `sha-…` |

Fíjate en la última fila: un dispatch sobre una rama `feature/x` publicaría `feature-x`. Solo
quien tiene permiso de escritura en el repo puede lanzar un dispatch, así que no es una puerta para
extraños, pero sí una forma de publicar algo que no pasó por `main`. Los environments con
reglas de rama, que permiten cerrarla, los verás en la Semana 13.

### Una matriz, una imagen por entrada

`tablero-api` y `tablero-web` se construyen igual: cambian la carpeta, el nombre y el scope de la
caché. Es el caso de libro para una matriz (Semana 04):

```yaml
jobs:
  build:
    name: Imagen tablero-${{ matrix.image }}
    runs-on: ubuntu-24.04
    # Los permisos de un job sustituyen a los de la raíz: contents se repite.
    permissions:
      contents: read
      packages: write
    strategy:
      fail-fast: false
      matrix:
        image:
          - api
          - web
```

`matrix.image` aparece en cuatro sitios del job y cada uno depende de que la carpeta, el paquete y
el scope se llamen igual:

| Dónde | Expresión | Con `api` |
|---|---|---|
| `name:` del job | `tablero-${{ matrix.image }}` | `Imagen tablero-api`, lo que lees en los checks del PR |
| `images:` de `metadata-action` | `ghcr.io/${{ github.repository_owner }}/tablero-${{ matrix.image }}` | `ghcr.io/<tu-org>/tablero-api` |
| `context:` del build | `${{ matrix.image }}` | La carpeta `api/` |
| `scope` de la caché | `scope=${{ matrix.image }}` | El índice `index-api-…` |

- **`fail-fast: false`**: si la web no construye, la API se publica igual. Sin él, el fallo de una
  imagen cancela la otra a medias y el fallo real se mezcla con un "cancelled".
- **Los permisos son del job**, así que cada entrada de la matriz los recibe. No hay forma de dar
  `packages: write` a una entrada sí y a otra no, ni falta que hace.
- **Cada entrada es un runner distinto**, en paralelo: las dos imágenes tardan lo que tarde la más
  lenta.

## 3. Cómo se usa

### Abrir un PR y comprobar que no publica

```bash
cd ~/code/tablero
git switch -c probe/image-pr
echo '# probe' >> api/src/tablero/main.py
git commit -am "chore: probe image build on pull request"
git push -u origin probe/image-pr
gh pr create --fill
gh pr checks --watch
# Imagen tablero-api   pass   ...
# Imagen tablero-web   pass   ...
```

Ahora mira el log del job de la API:

```bash
id=$(gh run list --workflow images.yml --branch probe/image-pr --limit 1 --json databaseId --jq '.[0].databaseId')
gh run view "$id" --json jobs --jq '.jobs[] | select(.name=="Imagen tablero-api") | .steps[] | "\(.conclusion)\t\(.name)"'
# success   Set up job
# success   Run actions/checkout@…
# success   Calcular etiquetas y labels
# success   Run docker/setup-buildx-action@…
# skipped   Iniciar sesión en GHCR
# success   Construir y, fuera de los PR, publicar
# ...
```

`skipped` en el login y `success` en el build: construyó, no publicó. Para confirmarlo en GHCR,
ninguna versión tiene la etiqueta del PR:

```bash
gh api /orgs/<tu-org>/packages/container/tablero-api/versions \
  --jq '[.[].metadata.container.tags[]] | map(select(startswith("pr-"))) | length'
# 0
```

Cierra el PR sin fusionar y borra la rama: `gh pr close --delete-branch`.

### Romper el build en un PR

Prueba una vez a cambiar `FROM python:3.15.2-slim-trixie` por una etiqueta que no existe en
`api/Dockerfile` y abre otro PR. `Imagen tablero-api` sale en rojo, `Imagen tablero-web` sigue en
verde gracias a `fail-fast: false`, y el error llega antes de fusionar. Es exactamente lo que la
sección 1 pedía.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Construir solo en `push` a `main` | El `Dockerfile` roto se descubre tras fusionar | Construir también en `pull_request` |
| Publicar desde los PR | Código sin revisar en tu registro; rojo para cada fork | `push: ${{ github.event_name != 'pull_request' }}` |
| `if:` en el step del build | En un PR no se construye nada | `if:` en el login, condición en `push` |
| `github.event_name == 'push'` | `workflow_dispatch` deja de publicar | `!= 'pull_request'` |
| `pull_request_target` para tener token con escritura | Ejecuta código del fork con permisos del repo | Lo verás en la Semana 12: aquí, `pull_request` sin publicar |
| Un job por imagen copiado y pegado | Los dos se desincronizan en el primer cambio | Una matriz con `matrix.image` |
| `fail-fast` por defecto | El fallo de una imagen cancela la otra | `fail-fast: false` |

## 5. Trucos

- **`gh pr checks --required`** enseña solo los checks obligatorios del PR. En la Semana 18 el
  único check requerido será `ci-gate`, y `Imagen tablero-api` contará a través de él.
- **`gh run view <id> --json jobs --jq '.jobs[].steps[] | select(.conclusion=="skipped") | .name'`**
  lista los steps saltados de un run: la forma rápida de confirmar que un `if:` hizo lo que
  esperabas.
- **El nombre del job con la matriz** (`Imagen tablero-${{ matrix.image }}`) es también el nombre
  del check en el PR. Si lo cambias, cualquier regla que lo exija deja de encontrarlo.

Verificado con docker/login-action@v4.7.0, docker/build-push-action@v7.4.0 y ubuntu-24.04,
noviembre 2026.

## 📚 Recursos Adicionales

- [GitHub Docs: Events that trigger workflows, `pull_request`](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request)
- [GitHub Docs: `GITHUB_TOKEN` y permisos en PR desde forks](https://docs.github.com/en/actions/concepts/security/github_token)
- [GitHub Docs: Running variations of jobs in a workflow](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations)

## ✅ Checklist de Verificación

- [ ] Sé qué permisos recibe el token en un PR desde un fork
- [ ] Sé por qué el login lleva `if:` y el build lleva la condición en `push`
- [ ] Sé por qué la condición es `!= 'pull_request'`
- [ ] Sé qué cuatro sitios del job usan `matrix.image`
- [ ] Sé por qué la matriz lleva `fail-fast: false`
- [ ] Sé comprobar que un PR construyó y no publicó

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Caché de capas type=gha](06-cache-de-capas-type-gha.md) | [Digest y consumo](08-digest-y-consumo.md) |
