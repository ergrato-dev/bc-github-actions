# Práctica 03 — SBOM y attestations

> Un tag en GHCR solo dice que alguien con permiso subió esa imagen. Una attestation dice quién
> la construyó, desde qué commit, con qué workflow y qué lleva dentro, y lo firma con la
> identidad OIDC del job. En esta práctica firmas la procedencia y el SBOM de cada imagen y los
> verificas con `gh`, también en los casos en que la verificación tiene que fallar.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- El job `images` con los permisos justos para firmar: `id-token`, `attestations` y
  `artifact-metadata`
- Una attestation de procedencia SLSA y otra de SBOM SPDX por imagen, guardadas en GHCR
- La release `v0.4.0` forzada con `Release-As`, con sus imágenes firmadas
- `gh attestation verify` aceptando lo que firmó `release.yml` y rechazando todo lo demás

## 📋 Antes de empezar

Terminaste la [práctica 02](02-imagenes-versionadas-y-escaneo.md): `v0.3.1` está publicada con
los tres jobs en verde. Leíste la [teoría 04](../1-teoria/04-sbom-con-syft.md) y la
[teoría 05](../1-teoria/05-attestations-y-sigstore.md).

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
o=$(gh repo view --json owner --jq '.owner.login | ascii_downcase')
gh release view --json tagName --jq .tagName
# v0.3.1
gh attestation verify "oci://ghcr.io/$o/tablero-api:0.3.1" --repo "$GH_REPO" > /dev/null 2>&1 && echo firmada || echo sin-firmar
# sin-firmar
```

Ese último es el punto de partida: hoy ninguna imagen de `tablero` se puede verificar.

---

## Paso 1: Permisos para firmar y la attestation de procedencia

**Por qué**: `actions/attest` no tiene claves que guardar. Pide al emisor OIDC de GitHub un token
del job (`id-token: write`, como en la Semana 13), lo canjea en Fulcio, la CA pública de
Sigstore, por un certificado de diez minutos que lleva dentro la identidad del workflow, firma
con él y apunta la firma en Rekor, el registro público de transparencia. Después guarda la
attestation en el almacén del repo (`attestations: write`) y, con `push-to-registry: true`, la
sube también a GHCR junto a la imagen; ese push crea un registro de almacenamiento que pide
`artifact-metadata: write`. Sin `sbom-path` ni predicado, firma **procedencia** SLSA v1: qué
repo, qué commit, qué workflow y qué runner construyeron ese digest
([teoría 03](../1-teoria/03-cadena-de-suministro-y-slsa.md)).

Va **después** del escaneo a propósito: si Trivy falla, el job se para y esa imagen nunca tiene
attestation. Por eso `tablero-web:0.3.0` existe pero no se podrá verificar nunca.

**Comando**: en `.github/workflows/release.yml`, los permisos del job `images` quedan así:

```yaml
    permissions:
      contents: read
      packages: write
      # Firma de Sigstore con el token OIDC del job y almacén de attestations del repo.
      id-token: write
      attestations: write
      artifact-metadata: write
```

Y detrás del step de Trivy:

```yaml
      - name: Attestation de procedencia
        uses: actions/attest@1e69f48acb82d1966a394da916b4c1698aa569d6 # v4.2.2
        with:
          subject-name: ${{ steps.name.outputs.image }}
          subject-digest: ${{ steps.build.outputs.digest }}
          push-to-registry: true
```

El sujeto es el **digest**, no el tag: el tag se puede mover a otra imagen, el digest no
([teoría 02](../1-teoria/02-tags-digests-e-imagenes-versionadas.md)).

**Verifica**: las órdenes de `attest-permissions` y `writes-only-where-needed` (aún sin
`dependency-review.yml`, que llega en la práctica 04):

```bash
yq '.jobs.images.permissions | to_entries | map(.key + "=" + .value) | sort | join(" ")' .github/workflows/release.yml
# artifact-metadata=write attestations=write contents=read id-token=write packages=write
yq -N '.jobs | to_entries | .[] | .value.permissions // {} | to_entries | .[] | select(.value == "write") | (filename | sub(".*/"; "")) + ":" + .key' .github/workflows/*.yml | sort -u | tr '\n' ' '; echo
# codeql.yml:security-events deploy-gate.yml:id-token images.yml:packages labeler.yml:pull-requests nightly.yml:actions pr-report.yml:pull-requests release.yml:artifact-metadata release.yml:attestations release.yml:contents release.yml:id-token release.yml:issues release.yml:packages release.yml:pull-requests
```

---

## Paso 2: El SBOM de la imagen, firmado

**Por qué**: la procedencia dice de dónde sale la imagen; el SBOM dice qué lleva dentro. Cuando
salga la próxima CVE de una librería, preguntarás a los SBOM firmados qué versiones de `tablero`
la contienen, sin volver a descargar ni escanear nada. syft lo genera sobre la imagen
**publicada, por digest**, la misma que escaneó Trivy, en SPDX 2.3. `actions/attest` con
`sbom-path` firma ese documento con su propio tipo de predicado, `https://spdx.dev/Document/v2.3`,
y lo sube a GHCR como la procedencia. Que sean dos attestations y no una permite pedir cada una
por separado al verificar.

Primero en local, sobre la imagen que construiste en la práctica 02:

```bash
docker build -q -t tablero-api:local api > /dev/null
syft scan docker:tablero-api:local -q -o spdx-json | jq -r '.spdxVersion, ([.packages[].name] | index("fastapi") != null)'
# SPDX-2.3
# true
```

**Comando**: entre el step de Trivy y la attestation de procedencia, el del SBOM:

```yaml
      - name: SBOM de la imagen
        env:
          REF: ${{ steps.name.outputs.image }}@${{ steps.build.outputs.digest }}
          COMPONENT: ${{ matrix.component }}
        run: syft scan "registry:$REF" -q -o "spdx-json=sbom-$COMPONENT.spdx.json"
```

Y detrás de la attestation de procedencia, la del SBOM:

```yaml
      - name: Attestation del SBOM
        uses: actions/attest@1e69f48acb82d1966a394da916b4c1698aa569d6 # v4.2.2
        with:
          subject-name: ${{ steps.name.outputs.image }}
          subject-digest: ${{ steps.build.outputs.digest }}
          sbom-path: sbom-${{ matrix.component }}.spdx.json
          push-to-registry: true
```

`registry:` hace que syft lea la imagen directamente de GHCR, con las credenciales que dejó
`docker/login-action`, sin `docker pull`.

**Verifica**: la orden de `attest-steps`:

```bash
yq '.jobs.images.steps[] | select(.uses // "" | test("^actions/attest@[0-9a-f]{40}$")) | "sbom=" + (.with | has("sbom-path") | tostring) + ":" + (.with."subject-digest" | test("steps\.build\.outputs\.digest") | tostring) + ":" + (.with."push-to-registry" | tostring)' .github/workflows/release.yml | sort | tr '\n' ' '; echo
# sbom=false:true:true sbom=true:true:true
```

---

## Paso 3: El digest en el resumen y una release forzada con `Release-As`

**Por qué**: el resumen del run es donde una persona mira qué se publicó: con el digest y la
orden de verificación a la vista, nadie tiene que buscarlos. Y necesitas una release nueva para
que corra el job firmado, pero tu cambio es un `ci:`, que no sube versión. No te inventas un
`feat`: el pie `Release-As: 0.4.0` le dice a release-please la versión exacta que debe
proponer. Es la misma herramienta con la que un día saldrás de `0.x` hacia `1.0.0`.

**Comando**: al final del job `images`:

```yaml
      - name: Digest en el resumen
        env:
          IMAGE: ${{ steps.name.outputs.image }}
          DIGEST: ${{ steps.build.outputs.digest }}
        run: |
          {
            echo "### ${IMAGE##*/} $VERSION"
            echo
            echo "\`$IMAGE@$DIGEST\`"
            echo
            echo "\`gh attestation verify oci://$IMAGE@$DIGEST --repo $GITHUB_REPOSITORY\`"
          } >> "$GITHUB_STEP_SUMMARY"
```

```bash
actionlint
git commit -am "ci(release): sign provenance and sbom attestations for images" -m "Release-As: 0.4.0"
git push
sleep 5
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
# release ok
pr=$(gh pr list --label "autorelease: pending" --json number --jq '.[0].number')
branch=$(gh pr view "$pr" --json headRefName --jq .headRefName)
git fetch -q origin "$branch" && git show "origin/$branch:version.txt"
# 0.4.0
gh pr merge "$pr" --squash --delete-branch
git pull --ff-only && sleep 5
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
# release ok
```

El resumen con los dos digests: `gh run view "$run" --web`.

**Verifica**: la release, los jobs y las dos attestations de la API en el almacén del repo:

```bash
gh release view --json tagName --jq .tagName
# v0.4.0
gh run view "$run" --json jobs --jq '.jobs[] | .name + " " + .conclusion' | sort
# Imagen tablero-api success
# Imagen tablero-web success
# Release PR o release success
d=$(docker buildx imagetools inspect "ghcr.io/$o/tablero-api:0.4.0" --format '{{json .Manifest}}' | jq -r .digest)
gh api "repos/{owner}/{repo}/attestations/$d" --jq '.attestations | length'
# 2
```

---

## Paso 4: `gh attestation verify`, como lo hará el despliegue

**Por qué**: `gh attestation verify` busca las attestations del digest, comprueba la firma
contra la raíz de confianza de Sigstore y el certificado contra las reglas que le pongas.
`--repo` exige que el código fuente sea de `tablero`. `--signer-workflow` exige además que firmara
`release.yml`: si la firma la hiciera un reutilizable del repo central, el firmante sería ese
reutilizable y no `tablero`, y por eso existen `--signer-workflow` y `--signer-repo` aparte de
`--repo`. `--predicate-type` elige qué attestation verificar; por defecto es la procedencia.
Es exactamente la comprobación que la Semana 17 hará antes de desplegar.

**Comando**:

```bash
img="oci://ghcr.io/$o/tablero-api:0.4.0"
for p in https://slsa.dev/provenance/v1 https://spdx.dev/Document/v2.3; do
  gh attestation verify "$img" --repo "$GH_REPO" \
    --signer-workflow "$GH_REPO/.github/workflows/release.yml" --predicate-type "$p" > /dev/null 2>&1 &&
    echo "aceptada $p" || echo "rechazada $p"
done
# aceptada https://slsa.dev/provenance/v1
# aceptada https://spdx.dev/Document/v2.3
gh attestation verify "$img" --repo "$GH_REPO" --format json \
  --jq '.[0].verificationResult.signature.certificate.subjectAlternativeName'
# https://github.com/<tu-org>/tablero/.github/workflows/release.yml@refs/heads/main
```

La identidad del certificado es la del workflow y la rama que firmaron: nadie la escribió a
mano, la puso Fulcio a partir del token OIDC del job.

**Verifica**: la orden de `attestations-verify` (sobre la última release, sea cual sea):

```bash
owner=${GH_REPO%%/*}; v=$(gh release view --json tagName --jq .tagName); img="oci://ghcr.io/${owner,,}/tablero-api:${v#v}"; for p in https://slsa.dev/provenance/v1 https://spdx.dev/Document/v2.3; do gh attestation verify "$img" --repo "$GH_REPO" --signer-workflow "$GH_REPO/.github/workflows/release.yml" --predicate-type "$p" >/dev/null 2>&1 && printf 'ok ' || printf 'mal '; done; echo
# ok ok
```

---

## Paso 5: Lo que tiene que fallar

**Por qué**: una verificación que nunca has visto rechazar algo no sabes si comprueba algo.
Cuatro intentos, cada uno con una regla distinta:

1. **Imagen sin firmar**: `tablero-web:0.3.0` es de tu repo y está en tu GHCR, pero Trivy la
   paró antes de firmar. Así se verá cualquier imagen subida a mano desde un portátil.
2. **Otro firmante**: exiges `images.yml`, el workflow de CI que publica `:main`. No firmó nada.
3. **Otro repo**: buscas las attestations en `actions-tablero`. Que la imagen esté en tu org no
   basta; tiene que venir de `tablero`.
4. **Otro predicado**: pides un SBOM CycloneDX y solo hay SPDX.

**Comando**:

```bash
api="oci://ghcr.io/$o/tablero-api:0.4.0"
wf="$GH_REPO/.github/workflows"
try() { gh attestation verify "$@" > /dev/null 2>&1 && echo aceptada || echo rechazada; }
try "oci://ghcr.io/$o/tablero-web:0.3.0" --repo "$GH_REPO"
# rechazada
try "$api" --repo "$GH_REPO" --signer-workflow "$wf/images.yml"
# rechazada
try "$api" --repo "${GH_REPO%%/*}/actions-tablero"
# rechazada
try "$api" --repo "$GH_REPO" --predicate-type https://cyclonedx.org/bom
# rechazada
```

**Verifica**: el control positivo, para descartar que todo falle por otro motivo (red, sesión
de `gh`):

```bash
try "$api" --repo "$GH_REPO" --signer-workflow "$wf/release.yml"
# aceptada
```

---

## ✅ Resultado

- [ ] El job `images` pide `id-token`, `attestations`, `artifact-metadata` y `packages` en
      escritura y nada más
- [ ] Cada imagen sale con un SBOM SPDX generado sobre su digest publicado
- [ ] Dos attestations por imagen, procedencia y SBOM, firmadas después del escaneo y subidas a GHCR
- [ ] `v0.4.0` publicada con `Release-As`, sin inventar un `feat`
- [ ] `gh attestation verify` acepta las dos con `--signer-workflow` y rechaza los cuatro intentos

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 14
# ...
# ✅ gh attestation verify acepta la procedencia y el SBOM de tablero-api en la última versión, ...
# ...
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `Error: Failed to get ID token` en `actions/attest` | Falta `id-token: write` en el job | Paso 1 |
| `Resource not accessible by integration` al firmar | Faltan `attestations: write` o `artifact-metadata: write` | Paso 1, los dos |
| syft falla con un error de autenticación en `registry:` | El step del SBOM está antes de `docker/login-action` | Respeta el orden: login, build, Trivy, SBOM, attestations |
| No se abre PR tras el commit con `Release-As` | El pie no está en un párrafo propio | `-m` dos veces, como en el paso 3; el pie va separado del título por una línea en blanco |
| El paso 4 da `rechazada` en todo, también en el control positivo | `GH_REPO` vacío o con otra capitalización que la de tu org | `echo "$GH_REPO"` y compáralo con `gh repo view --json nameWithOwner` |
| `attestations-verify` da `mal mal` tras otro push | La última release es una sin attestations (por ejemplo, una con Trivy en rojo) | Arregla la causa y publica una release nueva |
| `gh api .../attestations/...` da `0` | Usaste el digest de una arquitectura y no el del índice | `imagetools inspect` con `{{json .Manifest}}`, como en el paso 3 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Imágenes versionadas y escaneo](02-imagenes-versionadas-y-escaneo.md) | [Digests y revisión de dependencias](04-digests-y-revision-de-dependencias.md) |
