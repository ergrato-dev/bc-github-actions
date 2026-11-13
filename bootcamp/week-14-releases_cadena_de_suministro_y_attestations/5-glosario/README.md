# 📖 Glosario — Semana 14

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **Attestation** (*artifact attestation*): afirmación firmada sobre un artefacto, identificado
  por su digest. Lleva un `subject` (nombre y digest), un `predicateType` y un `predicate`. En
  `tablero`, dos por imagen: procedencia y SBOM.
- **`attestations: write`**: permiso del `GITHUB_TOKEN` que deja guardar attestations en la API
  de GitHub. Junto con `id-token: write`, el mínimo para firmar con `actions/attest`.
- **`artifact-metadata: write`**: permiso que `actions/attest` necesita para crear el registro de
  almacenamiento (*storage record*) cuando sube la attestation al registro con
  `push-to-registry`. `create-storage-record: false` lo evita.
- **Autorelease** (etiquetas `autorelease: pending` y `autorelease: tagged`): etiquetas que
  release-please pone a su PR de release: pendiente mientras está abierto, `tagged` cuando ya
  creó el tag y la release.

## B

- **`bootstrap-sha`**: opción de `release-please-config.json` que marca desde qué commit leer el
  historial en la primera release. Sin ella, el primer CHANGELOG recoge todo el historial.
- **`bump-minor-pre-major`**: opción de release-please que, en versiones `0.x`, hace que un cambio
  incompatible suba el `MINOR` en lugar de saltar a `1.0.0`.

## C

- **Cadena de suministro** (*software supply chain*): todo lo que interviene entre el código y lo
  que se despliega: actions, herramientas, imágenes base, dependencias, el build, el registro y
  quien consume el artefacto. Cada eslabón es un punto de ataque.
- **CHANGELOG**: archivo con los cambios de cada versión. release-please lo escribe a partir de
  los commits convencionales, agrupados en secciones como *Features* y *Bug Fixes*.
- **Commits convencionales** (*Conventional Commits*): convención de mensajes `tipo(alcance): descripción`.
  `feat` sube el `MINOR`, `fix` y `deps` el `PATCH`, y un `!` o el pie `BREAKING CHANGE` marcan un
  cambio incompatible. Otros tipos (`docs`, `ci`, `chore`) no suben versión.
- **CVE** (*Common Vulnerabilities and Exposures*): identificador público de una vulnerabilidad
  (`CVE-AAAA-NNNNN`). Es lo que Trivy enseña para cada paquete afectado.
- **CycloneDX**: formato estándar de SBOM de OWASP. La alternativa a SPDX; `tablero` usa SPDX.

## D

- **Dependency graph**: la vista que GitHub tiene de las dependencias de un repo, a partir de los
  manifiestos y lockfiles que sabe leer y de los snapshots que le envías. No lee `uv.lock` ni el
  `pnpm-lock.yaml` de dos documentos de pnpm 11+.
- **Dependency review** (`actions/dependency-review-action`): check de PR que compara las
  dependencias de la base y de la cabeza según el dependency graph y falla si entra una con un
  aviso de la gravedad configurada (`fail-on-severity`). Actúa antes del merge; Dependabot,
  después.
- **Dependency submission** (API de envío de dependencias): endpoint
  `repos/{owner}/{repo}/dependency-graph/snapshots` que recibe un snapshot y lo suma al
  dependency graph. Exige `contents: write`.
- **Digest**: hash `sha256:` del contenido de una imagen o de un índice. No se mueve: el mismo
  digest es siempre el mismo contenido. `tag@sha256:...` fija la imagen y deja el tag para las
  personas.

## F

- **Fulcio**: autoridad de certificación de Sigstore. Recibe el token OIDC del job y emite un
  certificado de pocos minutos con la identidad del workflow que firma.

## G

- **GHSA** (*GitHub Security Advisory*): identificador de un aviso de la GitHub Advisory Database
  (`GHSA-xxxx-xxxx-xxxx`). dependency-review informa por GHSA; muchos llevan también su CVE.
- **`gh attestation verify`**: orden de `gh` que busca las attestations de un archivo o de una
  imagen (`oci://...`), comprueba la firma y exige las reglas que le pidas: `--repo`,
  `--signer-workflow`, `--predicate-type`.

## I

- **Índice de imagen** (*image index*): lista de manifiestos, uno por plataforma
  (`linux/amd64`, `linux/arm64`…). Su digest es el que va en `FROM` y en `services:`.
- **in-toto**: marco de attestations cuyo formato (`subject`, `predicateType`, `predicate`) usan
  las attestations de GitHub.

## M

- **Manifest de release-please** (`.release-please-manifest.json`): archivo con la versión actual
  de cada paquete; release-please parte de él para calcular la siguiente.
- **Manifiesto de imagen** (*image manifest*): descripción de una imagen para una plataforma: su
  configuración y sus capas. Un índice apunta a varios.

## P

- **Predicado** (*predicate*, `predicateType`): el cuerpo de una attestation y su tipo.
  `https://slsa.dev/provenance/v1` para la procedencia, `https://spdx.dev/Document/v2.3` para un
  SBOM SPDX 2.3.
- **Procedencia** (*provenance*): attestation que dice dónde y cómo se construyó un artefacto:
  repo, commit, workflow, ref y runner. No dice nada de la calidad del código.
- **PR de release** (*release PR*): PR que release-please abre y mantiene con la próxima versión,
  el CHANGELOG y el manifest. Al fusionarlo se crean el tag y la release.
- **purl** (*Package URL*): identificador `pkg:tipo/nombre@versión` de un paquete, el que llevan
  el SBOM y el snapshot.
- **`push-to-registry`**: input de `actions/attest` que sube la attestation al registro OCI, junto
  a la imagen. Necesita `packages: write`.

## R

- **Rekor**: log de transparencia público de Sigstore. Cada firma queda registrada con su hora, y
  eso permite verificar después un certificado que ya caducó.
- **`Release-As`**: pie de commit (`Release-As: 1.0.0`) que obliga a release-please a proponer
  esa versión exacta.
- **release-please**: herramienta de Google que convierte commits convencionales en una versión
  SemVer, un CHANGELOG, un tag y una release, mediante un PR de release.

## S

- **SBOM** (*Software Bill of Materials*): inventario de los componentes de un artefacto, con sus
  versiones e identificadores. Sirve para responder "¿estamos afectados?" cuando sale un aviso.
- **SemVer** (*Semantic Versioning*): versionado `MAJOR.MINOR.PATCH`: incompatible, nueva
  funcionalidad compatible y arreglo. Antes de `1.0.0` no hay promesa de estabilidad.
- **Severidad** (*severity*): gravedad de un aviso: `LOW`, `MEDIUM`, `HIGH`, `CRITICAL` (y
  `UNKNOWN` en Trivy). `tablero` rompe la release solo con `CRITICAL` que tenga arreglo.
- **`--signer-workflow`**: flag de `gh attestation verify` que exige qué workflow firmó
  (`<org>/<repo>/.github/workflows/<archivo>`). Sin él, vale cualquier workflow del repo.
- **Sigstore**: proyecto de la OpenSSF para firmar sin claves de larga vida: certificados
  efímeros (Fulcio) y log de transparencia (Rekor).
- **SLSA** (*Supply-chain Levels for Software Artifacts*, "salsa"): marco de la OpenSSF que ordena
  las garantías de la cadena de suministro en niveles. `tablero` alcanza Build L2; L3 exige firmar
  desde un reutilizable aislado.
- **Snapshot** (*dependency snapshot*): lista de dependencias que envías al dependency graph para
  un commit concreto (`sha`, `ref`, `job`, `detector`, `manifests`). En `tablero`, la genera syft
  con `-o github-json`.
- **SPDX** (*Software Package Data Exchange*): formato estándar de SBOM de la Linux Foundation.
  syft genera SPDX 2.3 con `-o spdx-json`.
- **syft**: herramienta de Anchore que cataloga los paquetes de una imagen o de un directorio y
  genera SBOM en varios formatos. `tablero` la instala como binario con checksum.

## T

- **Tag de imagen**: nombre legible que apunta a un digest (`0.4.0`, `17.11-alpine`). El
  publicador puede moverlo; por eso se fija junto al digest.
- **Trivy**: escáner de vulnerabilidades de Aqua Security. `tablero` lo instala en `v0.76.2` con
  checksum, nunca la `0.69.4` comprometida ni `trivy-action` por tag.
- **`.trivyignore`**: archivo con avisos que Trivy debe ignorar. Cada línea necesita un porqué y
  una fecha de revisión; si no, es una forma de bajar la puerta a escondidas.

## U

- **`--ignore-unfixed`**: flag de Trivy que ignora las vulnerabilidades sin versión corregida.
  Junto con `--severity CRITICAL` y `--exit-code 1`, la política de `tablero`.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Semana 15 — Runners propios](../../week-15-runners_self_hosted/README.md) |
