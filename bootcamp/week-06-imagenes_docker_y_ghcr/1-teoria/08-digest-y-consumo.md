# Digest y consumo

> Publicar es la mitad. La otra mitad es poder decir "esta imagen, exactamente esta" y que quien
> la descargue reciba los mismos bytes que se probaron. Eso lo da el digest, y `build-push-action`
> te lo devuelve como output.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Sacar el digest de lo que publicó un run con el output `digest` de `build-push-action`
- Llevar el digest al resumen del job por `env:`, sin interpolarlo en `run:`
- Descargar y arrancar una imagen por digest y comprobar que es la que publicó el run
- Resolver el digest al que apunta hoy una etiqueta
- Explicar qué es la entrada `unknown/unknown` del índice y por qué no se quita
- Diagnosticar los fallos de push más comunes en GHCR

## 1. Qué problema resuelve

`ghcr.io/<tu-org>/tablero-api:main` apunta al último push a `main`. Si entre el momento en que
compruebas una imagen y el momento en que la despliegas alguien fusiona otro PR, la etiqueta se
movió y despliegas otra cosa. Con `sha-1a2b3c4` estás mejor, pero una etiqueta sigue siendo un
puntero: quien tenga escritura en el paquete puede volver a publicar con ese nombre.

El digest no tiene ese problema (teoría 01): es el hash del índice, y el registro solo devuelve
ese contenido para ese hash. La Semana 17 despliega a kind por digest; esta semana te deja el
digest a mano en cada run.

## 2. Cómo funciona

### El output `digest`

Cuando `build-push-action` publica, devuelve en `steps.<id>.outputs.digest` el digest de lo que
subió: `sha256:` y 64 caracteres hexadecimales. Como la imagen va con attestation de procedencia,
lo que se sube es un **índice**, y ese es el digest que recibes: el del índice, el mismo que
`docker buildx imagetools inspect` enseña en la línea `Digest:` de arriba.

| Output | Qué es | Para qué |
|---|---|---|
| `digest` | Digest del índice publicado | Desplegar, registrar, comparar |
| `imageid` | El id de la imagen | Identificarla en `docker images` tras `load` |
| `metadata` | JSON con todo lo que devolvió BuildKit | Sacar datos que no tienen output propio |

En un PR no hay exportación al registro (teoría 07): no hay nada publicado que identificar y no
cuentes con que `digest` traiga un valor. Por eso el resumen de `images.yml` dice además si la
imagen se publicó.

### Al resumen, por `env:`

El digest es un output de un step anterior. Aunque lo genera BuildKit y no un usuario, la regla 4
de seguridad no hace excepciones por "parece inofensivo": todo lo que llega a un `run:` llega por
`env:`. Así, si mañana el valor cambia de origen, el shell lo sigue tratando como dato:

```yaml
      - name: Digest en el resumen
        env:
          IMAGE: ghcr.io/${{ github.repository_owner }}/tablero-${{ matrix.image }}
          DIGEST: ${{ steps.build.outputs.digest }}
          PUSHED: ${{ github.event_name != 'pull_request' }}
        run: |
          {
            echo "### tablero-${IMAGE##*-}"
            echo
            echo "- Digest: \`$DIGEST\`"
            echo "- Publicada: $PUSHED"
            if [[ "$PUSHED" == "true" ]]; then
              echo "- Pull: \`docker pull ${IMAGE,,}@$DIGEST\`"
            fi
          } >> "$GITHUB_STEP_SUMMARY"
```

- **`${IMAGE##*-}`** quita todo hasta el último guion: de `ghcr.io/<tu-org>/tablero-api` deja
  `api`.
- **`${IMAGE,,}`** pasa el nombre a minúsculas, porque aquí no pasa por `metadata-action`: si tu
  organización tiene mayúsculas, el comando de `pull` que copies del resumen tiene que funcionar.
- **El bloque `{ ... } >> "$GITHUB_STEP_SUMMARY"`** abre el archivo una vez en lugar de en cada
  `echo`.

El check `images-digest-summary` mira que el step que escribe en `$GITHUB_STEP_SUMMARY` reciba
`steps.build.outputs.digest` en su `env:`.

### Pull por digest

Un nombre con `@sha256:…` sustituye a la etiqueta:

| Referencia | Qué baja |
|---|---|
| `ghcr.io/<tu-org>/tablero-api:main` | Lo que apunte `main` en este momento |
| `ghcr.io/<tu-org>/tablero-api@sha256:4e7a…` | Ese índice o un error. Nunca otra cosa |
| `ghcr.io/<tu-org>/tablero-api:main@sha256:4e7a…` | Lo mismo que la anterior: si hay digest, la etiqueta se ignora |

La tercera forma se ve en manifiestos de Kubernetes: la etiqueta queda como pista para personas y
el digest es lo que se usa.

### La attestation y la entrada `unknown/unknown`

Con `push`, `build-push-action` genera por defecto una **attestation de procedencia**: un
documento SLSA que cuenta qué workflow, qué commit y qué parámetros produjeron la imagen. Se guarda
en el mismo índice como un manifiesto más, con plataforma `unknown/unknown` y la anotación
`vnd.docker.reference.type: attestation-manifest`. La UI de GHCR lo lista junto a `linux/amd64` y
por eso parece una segunda plataforma rota.

Se podría quitar con `provenance: false`, y no conviene: es información de procedencia gratis que
la Semana 14 aprovechará, junto con el SBOM y las attestations firmadas de GitHub. Esta semana
basta con saber leerla y no asustarse.

### Depurar un push

Cuando el step del build falla al publicar, el error está al final de su log y casi siempre es uno
de estos:

| Error en el log | Causa | Arreglo |
|---|---|---|
| `denied: installation not allowed to Create organization package` | Falta `packages: write` en el job, o la org no permite paquetes | Permiso en el job; **Settings → Packages** de la org |
| `denied: permission_denied: write_package` | El paquete existía y no está enlazado al repo | **Manage Actions access → Add repository** (teoría 04) |
| `repository name must be lowercase` | Nombre construido a mano con mayúsculas | `tags` de `metadata-action` |
| `unauthorized: unauthenticated` | Falta el login, o su `if:` lo saltó en un evento que publica | El login con la misma condición que `push` |
| `ERROR: failed to build: ... not found` en un `FROM` | Etiqueta de imagen base inexistente | Comparar el tag del `Dockerfile` con `docs/stack-versions.md` |

Y para saber qué se publicó de verdad, pregunta al registro, no al log:

```bash
gh api /orgs/<tu-org>/packages/container/tablero-api/versions \
  --jq '.[0] | "\(.name)\t\(.metadata.container.tags | join(","))"'
# sha256:4e7a…    sha-1a2b3c4,main
```

En un paquete de contenedor, el `name` de cada versión es su digest.

## 3. Cómo se usa

### Del resumen a tu terminal

Copia el comando del resumen del último run de `main` y compáralo con lo que dice el registro:

```bash
docker pull ghcr.io/<tu-org>/tablero-api@sha256:4e7a…
# ghcr.io/<tu-org>/tablero-api@sha256:4e7a…: Pulling from <tu-org>/tablero-api
# ...
# Digest: sha256:4e7a…
docker buildx imagetools inspect ghcr.io/<tu-org>/tablero-api:main | awk '/^Digest:/ {print $2}'
# sha256:4e7a…
```

Si los dos digests coinciden, `main` sigue apuntando a lo que publicó ese run. Si no, alguien
publicó después: la etiqueta se movió y el digest del resumen sigue siendo el tuyo.

### Arrancar exactamente esa imagen

```bash
cd ~/code/tablero
docker compose up -d --wait db
docker run --rm -d --name api-by-digest --network tablero_default -p 127.0.0.1:8001:8000 \
  -e DATABASE_URL=postgresql://tablero:cambiame@db:5432/tablero \
  ghcr.io/<tu-org>/tablero-api@sha256:4e7a…
docker inspect api-by-digest --format '{{.Config.Image}}'
# ghcr.io/<tu-org>/tablero-api@sha256:4e7a…
docker rm -f api-by-digest
```

`.Config.Image` guarda la referencia con la que se arrancó: en un incidente te dice qué imagen
corría sin depender de que la etiqueta siga donde estaba. La API aplica migraciones al arrancar y
necesita una base: el servicio `db` de `compose.yaml` (Semana 05), en la red `tablero_default`, la
encuentra por nombre. El 8001 evita chocar con la API de la pila si la tienes levantada; al
terminar, `docker compose down`.

### Leer la attestation

```bash
docker buildx imagetools inspect ghcr.io/<tu-org>/tablero-api:main \
  --format '{{ json .Provenance }}' | jq . | head -20
```

Verás un documento SLSA con el repo, el commit y los parámetros del build. Su formato exacto
depende de la versión de BuildKit que la generó, así que no escribas scripts que dependan de él. La Semana 14 la lee
a fondo y la verifica con `gh attestation verify`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Desplegar por `main` o por `sha-…` | Una etiqueta se puede mover o reescribir | Por digest |
| `echo "${{ steps.build.outputs.digest }}"` en `run:` | Rompe la regla 4: un output interpolado en el shell | El output en `env:`, `$DIGEST` en el script |
| Copiar el digest del log a mano | Es fácil tomar el del manifiesto `linux/amd64` en vez del índice | El output `digest` o la línea `Digest:` de `imagetools inspect` |
| `provenance: false` para que GHCR "se vea limpio" | Tiras la procedencia que usará la Semana 14 | Dejarla y saber leer `unknown/unknown` |
| Diagnosticar un push solo por el log | El log dice qué intentó; el registro, qué quedó | `gh api .../versions` |

## 5. Trucos

- **`docker buildx build --metadata-file meta.json`** en local escribe el mismo JSON que el output
  `metadata`; `jq -r '."containerimage.digest"' meta.json` te da el digest sin action.
- **`docker inspect --format '{{index .RepoDigests 0}}' <imagen>`** enseña el digest de registro de
  una imagen que bajaste por etiqueta: así conviertes `:main` en `@sha256:…` para fijarla.
- **El digest está también en la UI**: en la página del paquete, cada versión enseña su
  `sha256:…`, con el comando `docker pull` por digest listo para copiar.

Verificado con docker/build-push-action@v7.4.0, GHCR y ubuntu-24.04, noviembre 2026.

## 📚 Recursos Adicionales

- [Docker: Provenance attestations](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)
- [Docker: Attestation storage](https://docs.docker.com/build/metadata/attestations/attestation-storage/)
- [GitHub Docs: REST API de paquetes](https://docs.github.com/en/rest/packages/packages)
- [OCI Distribution Spec: pulling manifests](https://github.com/opencontainers/distribution-spec/blob/main/spec.md#pulling-manifests)

## ✅ Checklist de Verificación

- [ ] Sé qué digest devuelve `build-push-action` y de qué pieza es
- [ ] Sé llevar el digest al resumen por `env:`
- [ ] Sé descargar y arrancar una imagen por digest
- [ ] Sé resolver el digest al que apunta una etiqueta
- [ ] Sé qué es la entrada `unknown/unknown` y por qué no la quito
- [ ] Sé reconocer los errores de push más comunes y dónde mirar qué se publicó

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Construir en PR, publicar en main](07-construir-en-pr-publicar-en-main.md) | [Construir en local con buildx](../2-practicas/01-construir-en-local-con-buildx.md) |
