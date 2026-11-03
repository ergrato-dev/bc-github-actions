# Etiquetas con metadata-action

> Una imagen sin etiquetas útiles es una imagen que nadie sabe de qué commit salió. Escribir las
> etiquetas a mano en el YAML acaba en mayúsculas rechazadas, ramas con `/` y un `latest` que se
> cuela. `docker/metadata-action` las calcula del evento y te da también los labels OCI.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué hace `metadata-action` con el evento y qué devuelve en `tags` y `labels`
- Elegir las reglas `type=sha`, `type=ref,event=branch` y `type=ref,event=pr` y prever qué
  etiquetas salen en cada evento
- Desactivar `latest` con `flavor` y explicar por qué se hace aunque hoy no salga
- Pasar las etiquetas y los labels a `build-push-action`
- Leer los labels OCI de una imagen publicada

## 1. Qué problema resuelve

En la teoría 04, el workflow `publish-api` etiqueta con el SHA completo y necesita un step solo
para pasar el dueño a minúsculas. Si además quieres la etiqueta `main` en los push a `main` y una
`pr-12` en los PR, el YAML se llena de expresiones condicionales, y aún falta:

- **Sanear**: una rama `feature/login` no es una etiqueta válida (la `/` no se admite).
- **Trazabilidad**: alguien que encuentra la imagen en GHCR necesita saber de qué repo y de qué
  commit salió, sin abrir el workflow.
- **No colar `latest`**: la etiqueta que todo el mundo baja por defecto y que nadie sabe a qué
  apunta.

`metadata-action` resuelve las tres con unas reglas declarativas.

## 2. Cómo funciona

### Entrada: `images`, `tags` y `flavor`

| Input | Qué recibe |
|---|---|
| `images` | El nombre base de la imagen, sin etiqueta. Uno por línea si publicas en varios registros |
| `tags` | Reglas, una por línea, que dicen qué etiquetas generar según el evento |
| `flavor` | Opciones globales: `latest`, `prefix`, `suffix` |

La action lee el contexto del evento (`github.event_name`, `github.ref`, `github.sha`), aplica
cada regla que corresponda y combina el resultado con cada nombre de `images`. Pasa el nombre de la
imagen a minúsculas y cambia por `-` los caracteres no válidos de las etiquetas.

### Las reglas de `tablero`

| Regla | En `push` a `main` | En `pull_request` #12 | En `workflow_dispatch` en `main` |
|---|---|---|---|
| `type=sha` | `sha-1a2b3c4` | `sha-<merge commit>` | `sha-1a2b3c4` |
| `type=ref,event=branch` | `main` | (no aplica) | `main` |
| `type=ref,event=pr` | (no aplica) | `pr-12` | (no aplica) |

- **`type=sha`** usa `prefix=sha-` y `format=short` (7 caracteres) por defecto. Es la etiqueta que
  te dice de qué commit salió la imagen y que no se reutiliza: cada commit tiene la suya.
- **`type=ref,event=branch`** da el nombre de la rama: `main`, o `releases-v1` para
  `releases/v1`. Es una etiqueta móvil a propósito: "lo último de `main`".
- **`type=ref,event=pr`** da `pr-<número>`.

Un detalle de `type=sha` en un PR: el `github.sha` de un evento `pull_request` es el commit de
merge que GitHub crea en `refs/pull/N/merge`, no el último commit de tu rama. Si necesitas el del
head, la action admite `DOCKER_METADATA_PR_HEAD_SHA: true` en el `env:` del step. En `tablero` no
importa: en un PR la imagen no se publica (teoría 07).

### `latest` y `flavor`

Con `flavor: latest=auto`, que es el valor por defecto, la action añade `latest` cuando aplica
alguna de estas reglas: `type=ref,event=tag`, `type=semver`, `type=pep440` o `type=match`. Con las
tres reglas de `tablero` no saldría nunca. Entonces, ¿para qué `latest=false`?

- **Porque la regla cambia sin avisar en el diff.** El día que añadas `type=semver` (Semana 14),
  `latest` aparecería solo, y en el diff de ese PR no habría ninguna línea con la palabra `latest`.
- **Porque el YAML dice la intención.** Quien lee `latest=false` sabe que es una decisión, no un
  olvido.

Y por qué nada de `latest` en un registro: no dice qué commit es, se mueve con cada publicación y
es lo que se baja por defecto cuando alguien escribe el nombre sin etiqueta. La regla 10 del
repositorio prohíbe consumirla y esta semana evita producirla.

### Salida: `tags`, `labels` y `version`

| Output | Qué contiene |
|---|---|
| `tags` | Nombres completos, uno por línea: `ghcr.io/<tu-org>/tablero-api:sha-1a2b3c4` |
| `labels` | Labels OCI, uno por línea: `org.opencontainers.image.revision=<sha>`... |
| `version` | La "versión" principal calculada: `main`, `pr-12` |

Los labels se calculan de los datos del repo y del evento:

| Label | Valor |
|---|---|
| `org.opencontainers.image.title` | Nombre del repo |
| `org.opencontainers.image.description` | Descripción del repo |
| `org.opencontainers.image.url` y `.source` | URL del repo. `source` es el que GitHub usa para enlazar el paquete |
| `org.opencontainers.image.version` | El output `version` |
| `org.opencontainers.image.created` | Fecha del build |
| `org.opencontainers.image.revision` | SHA completo del commit |
| `org.opencontainers.image.licenses` | Licencia del repo, si GitHub la detecta |

`revision` es el que importa: cualquier imagen te dice su commit con un `docker inspect`, sin
fiarte de la etiqueta.

## 3. Cómo se usa

### El step `meta` y el build que lo consume

Los dos steps de `images.yml` que trabajan juntos:

```yaml
      - name: Calcular etiquetas y labels
        id: meta
        uses: docker/metadata-action@dc802804100637a589fabce1cb79ff13a1411302 # v6.2.0
        with:
          images: ghcr.io/${{ github.repository_owner }}/tablero-${{ matrix.image }}
          flavor: |
            latest=false
          tags: |
            type=sha
            type=ref,event=branch
            type=ref,event=pr

      # ...setup-buildx y login...

      - name: Construir y, fuera de los PR, publicar
        id: build
        uses: docker/build-push-action@c3c9e263c25d99ce0380d002d59b67737d91b0dc # v7.4.0
        with:
          context: ${{ matrix.image }}
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

Tres detalles:

- **`images:` puede llevar mayúsculas**: `github.repository_owner` llega tal cual y la action lo
  pasa a minúsculas. Ya no hace falta el step `${OWNER,,}` de la teoría 04.
- **`type=sha`** es lo que comprueba el check `images-sha-tag`: sin ella, la imagen solo lleva
  `main`, que mañana apunta a otra cosa.
- **`tags` y `labels`** van de `steps.meta.outputs` a `build-push-action` tal cual. Los dos son
  listas separadas por saltos de línea, el formato que `build-push-action` espera. Si pasas solo
  `tags`, la imagen sale sin labels OCI; es lo que comprueba `images-tags-from-meta`.

`build-push-action` no necesita `env:` para estos outputs porque no los ejecuta ningún shell: van
a un input de una action, no a un `run:`.

### Qué etiquetas salieron

El log del step `meta` imprime lo calculado en grupos plegables. Para verlo desde la terminal:

```bash
gh run view <id-del-run> --log | grep -A4 'Docker tags' | head -5
# ... Docker tags
# ... ghcr.io/<tu-org>/tablero-api:sha-1a2b3c4
# ... ghcr.io/<tu-org>/tablero-api:main
```

### Leer los labels de una imagen publicada

```bash
docker pull -q ghcr.io/<tu-org>/tablero-api:main
docker inspect ghcr.io/<tu-org>/tablero-api:main \
  --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}'
# 1a2b3c4d5e6f…
git -C ~/code/tablero log -1 --format=%H origin/main
# 1a2b3c4d5e6f…
```

Si los dos SHA coinciden, `main` en GHCR es exactamente tu último commit de `main`.

### Antes y después en un PR

En un PR el step calcula `pr-12` y `sha-…`, y `build-push-action` las aplica a una imagen que no
se publica. Parece inútil, pero no lo es: un error de una regla (`type=semvr`, mal escrito) rompe
el PR, no el push a `main`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Publicar `latest` | No dice qué commit es y se mueve con cada push | `type=sha` + `flavor: latest=false` |
| Confiar en `latest=auto` | El día que añades `type=semver` aparece `latest` sin que el diff lo diga | `latest=false` explícito |
| Solo `type=ref,event=branch` | `main` se mueve: no hay forma de volver a la imagen de ayer | Añadir `type=sha` |
| Etiquetas escritas a mano con `${{ github.ref_name }}` | Ramas con `/` rompen el push; las mayúsculas, el nombre | Reglas de `metadata-action` |
| Pasar `tags` y olvidar `labels` | La imagen no dice de qué commit ni de qué repo salió | `labels: ${{ steps.meta.outputs.labels }}` |
| `type=sha,format=long` "por si acaso" | 40 caracteres en cada etiqueta sin ganar unicidad real en un repo así | El formato corto; `DOCKER_METADATA_SHORT_SHA_LENGTH` si un día colisiona |

## 5. Trucos

- **`steps.meta.outputs.json`** es todo lo calculado en un JSON. Con
  `fromJSON(steps.meta.outputs.json).tags[0]` sacas la primera etiqueta en una expresión, sin
  partir texto en el shell.
- **`DOCKER_METADATA_SHORT_SHA_LENGTH`** en el `env:` del step cambia la longitud de `type=sha` sin
  tocar las reglas. Útil en repos muy grandes, donde 7 caracteres pueden repetirse.
- **`type=raw,value=...,enable=${{ ... }}`** añade una etiqueta fija solo cuando la expresión sea
  verdadera. Es la forma de crear una etiqueta propia sin tocar el resto de reglas.

Verificado con docker/metadata-action@v6.2.0 y ubuntu-24.04, noviembre 2026.

## 📚 Recursos Adicionales

- [docker/metadata-action: README](https://github.com/docker/metadata-action)
- [Docker: Manage tags and labels with GitHub Actions](https://docs.docker.com/build/ci/github-actions/manage-tags-labels/)
- [OCI: Pre-defined annotation keys](https://github.com/opencontainers/image-spec/blob/main/annotations.md)

## ✅ Checklist de Verificación

- [ ] Sé qué etiquetas salen en un push a `main`, en un PR y en un dispatch
- [ ] Sé qué SHA usa `type=sha` en un `pull_request`
- [ ] Sé por qué `latest=false` se escribe aunque hoy no salga `latest`
- [ ] Sé pasar `tags` y `labels` de `metadata-action` a `build-push-action`
- [ ] Sé leer el label `revision` de una imagen y compararlo con `main`

---

| ← Anterior | Siguiente → |
|:---|---:|
| [GHCR y el GITHUB_TOKEN](04-ghcr-y-github-token.md) | [Caché de capas type=gha](06-cache-de-capas-type-gha.md) |
