# SBOM con syft

> Un SBOM es la lista de ingredientes de un artefacto. No te protege de nada el día que lo
> generas; te ahorra días el día que sale una CVE y alguien pregunta "¿estamos afectados?".

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué es un SBOM y qué pregunta responde
- Comparar SPDX y CycloneDX y justificar el formato que usa `tablero`
- Explicar qué cataloga syft en un directorio y qué en una imagen
- Instalar syft en un job con versión fijada y checksum
- Generar un SBOM, contarlo y buscar un paquete con `jq`
- Decidir qué SBOM generar para cada uso: inventario, attestation o dependency graph

## 1. Qué problema resuelve

Cuando se publicó la puerta trasera de xz-utils, la pregunta en todas las empresas fue la misma:
¿qué imágenes nuestras llevan esa versión de `liblzma`? Quien tenía un inventario respondió en
minutos con una búsqueda. Quien no, tuvo que descargar y abrir cada imagen en producción.

Un **SBOM** (Software Bill of Materials) es ese inventario: un documento que enumera los paquetes
que contiene un artefacto, con nombre, versión, origen y licencia. Para `tablero` hay dos
inventarios distintos, y cada uno sirve para una cosa:

| SBOM de | Contiene | Para qué |
|---|---|---|
| El código (`dir:.`) | Lo que declaran los lockfiles | Que el dependency graph y dependency-review sepan qué usas (archivo 07) |
| La imagen (`registry:...@sha256:`) | Lo que hay de verdad en las capas: paquetes del sistema y de cada lenguaje | Firmarlo junto a la imagen y responder "¿esta imagen lleva X?" (archivo 05) |

## 2. Cómo funciona

### Dos formatos estándar

| | SPDX | CycloneDX |
|---|---|---|
| Quién lo mantiene | Linux Foundation; norma ISO/IEC 5962:2021 | OWASP; norma ECMA-424 |
| Origen | Cumplimiento de licencias | Seguridad de aplicaciones |
| Formatos | JSON, tag-value, RDF, YAML | JSON, XML |
| En el ecosistema de GitHub | El SBOM que exporta el dependency graph; `actions/attest` lo acepta en `sbom-path` | `actions/attest` también lo acepta en `sbom-path` |

Los dos describen paquetes con su **purl** (package URL), un identificador común como
`pkg:pypi/fastapi@<versión>` o `pkg:npm/react@<versión>`, que es lo que cruzan los escáneres con
las bases de avisos.

`tablero` usa **SPDX en JSON** para la imagen: es el formato del SBOM que exporta GitHub, así que
comparas manzanas con manzanas, y `actions/attest` le asigna el tipo de predicado de SPDX sin que
lo declares.

### Qué hace syft

[syft](https://github.com/anchore/syft) es un catalogador de Anchore: recorre un origen, aplica
**catalogers** según lo que encuentra y escribe el resultado en el formato que pidas.

| Origen | Sintaxis | Qué lee |
|---|---|---|
| Directorio | `syft scan dir:.` | Lockfiles y manifiestos |
| Imagen en un registro | `syft scan registry:<imagen>@<digest>` | Base de paquetes del sistema (apk, dpkg) y metadatos de cada lenguaje instalados en las capas |
| Imagen local | `syft scan docker:<imagen>:<tag>` | Lo mismo, desde el daemon |

Sobre el código de `tablero`, sin `.venv` ni `node_modules`, syft 1.57.0 cataloga:

| Archivo | Paquetes |
|---|:--:|
| `web/pnpm-lock.yaml` | 267 (npm) |
| `api/uv.lock` | 31 (python) |
| `tools/oidc-verifier/uv.lock` | 14 (python) |

Sobre la imagen de la API, con `-o spdx-json`, sale un documento SPDX-2.3 con 114 paquetes: los
de Debian de la base más los de Python del entorno virtual. No coincide con el lockfile, y no
tiene por qué: la imagen no lleva las dependencias de desarrollo y sí lleva el sistema operativo.

_Verificado con syft v1.57.0 y ubuntu-24.04, noviembre de 2026._

### Formatos de salida

`-o` acepta `syft-json`, `syft-table`, `syft-text`, `spdx-json`, `spdx-tag-value`,
`cyclonedx-json`, `cyclonedx-xml`, `github-json`, `purls` y `template`. Con `formato=archivo`
escribe a disco, y puedes repetir `-o` para sacar varios formatos en una sola pasada.

`github-json` es el formato de la API de dependency submission, el que usarás en el archivo 07.

## 3. Cómo se usa

### Instalar syft con checksum

Las releases de GitHub publican el digest SHA-256 de cada asset en la API. Es el mismo patrón que
usaste para actionlint en [`docs/setup-entorno.md`](../../../docs/setup-entorno.md): leer el
digest de la API, descargar el asset y comprobarlo con `sha256sum -c` antes de ejecutar nada.

```yaml
name: sbom-example
on:
  workflow_dispatch:
permissions:
  contents: read
jobs:
  sbom:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    env:
      SYFT_VERSION: v1.57.0
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Instalar syft desde su release, con checksum
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          file="syft_${SYFT_VERSION#v}_linux_amd64.tar.gz"
          expected=$(gh api "repos/anchore/syft/releases/tags/$SYFT_VERSION" \
            --jq ".assets[] | select(.name == \"$file\") | .digest" | sed 's/^sha256://')
          [[ -n "$expected" ]] || { echo "Sin digest para $file" >&2; exit 1; }
          gh release download "$SYFT_VERSION" --repo anchore/syft --pattern "$file" --dir "$RUNNER_TEMP"
          echo "$expected  $RUNNER_TEMP/$file" | sha256sum -c
          tar -xzf "$RUNNER_TEMP/$file" -C "$RUNNER_TEMP" syft
          echo "$RUNNER_TEMP" >> "$GITHUB_PATH"

      - name: SBOM del código en SPDX
        run: |
          syft scan dir:. -q -o "spdx-json=$RUNNER_TEMP/sbom.spdx.json"
          count=$(jq '.packages | length' "$RUNNER_TEMP/sbom.spdx.json")
          echo "SBOM del código: $count paquetes" >> "$GITHUB_STEP_SUMMARY"
```

La comprobación `[[ -n "$expected" ]]` importa: si te equivocas en el nombre del asset, `jq` no
devuelve nada y `sha256sum -c` con un hash vacío fallaría con un mensaje confuso. Mejor fallar
diciendo qué falta.

### Responder "¿estamos afectados?"

Con el SBOM delante, la pregunta es una línea de `jq`:

```bash
jq -r '.packages[] | select(.name == "brotli-libs") | .versionInfo' sbom-web.spdx.json
# 1.2.0-r1
```

Lo mismo para cualquier nombre que publique un aviso. En la práctica 03 lo harás sobre el SBOM
**firmado** que descargues de GHCR, no sobre uno que generes en tu máquina: así sabes que es el de
la imagen que corre, no el de otra.

### Por qué el SBOM de la imagen se firma

Un SBOM suelto es un JSON que cualquiera puede editar. Si mañana alguien te pasa un
`sbom-web.spdx.json` que dice `brotli-libs 1.2.1-r0`, no tienes forma de saber si describe la
imagen que corre o si alguien quitó la línea incómoda.

Por eso `tablero` no lo deja como artefacto: lo firma como attestation **sobre el digest de la
imagen** (archivo 05). La firma ata tres cosas: este documento, este digest y este workflow. Si
cambias un byte del SBOM, la verificación falla; si lo intentas pegar a otra imagen, el sujeto no
coincide.

### La alternativa conocida

`anchore/sbom-action` es la action oficial de Anchore. `tablero` no la usa: en tiempo de ejecución
descarga un script de instalación de `raw.githubusercontent.com` y con él un syft cuya versión por
defecto no es la que tú fijaste. Es un `curl | bash` con otro nombre, justo lo que prohíbe la regla
9 de seguridad. Instalar el binario con checksum son seis líneas y no depende de nadie más.

_Verificado con anchore/sbom-action@v0.24.3 y ubuntu-24.04, noviembre de 2026._

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Generar el SBOM del código y llamarlo SBOM de la imagen | Le faltan los paquetes del sistema, que son los de muchas CVE | `registry:<imagen>@<digest>` |
| SBOM de la imagen por tag | Entre el build y el escaneo el tag puede apuntar a otra cosa | Por digest |
| Guardar el SBOM como artefacto del run | Caduca con la retención y nadie sabe de qué imagen era | Firmarlo como attestation junto a la imagen |
| Instalar syft con un script remoto | Ejecutas código que no revisaste ni fijaste | Binario de la release con `sha256sum -c` |
| Generar SBOM y no consultarlo nunca | Es un archivo más | Saber responder con `jq` qué versión lleva cada imagen |
| Escanear el directorio con `.venv` o `node_modules` | Cataloga lo instalado en tu máquina, no lo declarado | Escanear un checkout limpio |

## 5. Trucos

- **Varios formatos en una pasada**: `syft scan dir:. -o spdx-json=a.json -o cyclonedx-json=b.json`
  cataloga una vez y escribe dos archivos.
- **Una tabla rápida para mirar a ojo**: sin `-o`, syft imprime `syft-table` con nombre, versión
  y tipo; útil en local para ver si un lockfile se cataloga antes de montar el job.
- **Cuántos paquetes ve GitHub frente a syft**:
  `gh api 'repos/{owner}/{repo}/dependency-graph/sbom' --jq '.sbom.packages | length'` devuelve el
  SBOM SPDX que exporta el dependency graph. La diferencia con syft es lo que el grafo no ve.

## 📚 Recursos Adicionales

- [syft](https://github.com/anchore/syft)
- [SPDX specification](https://spdx.dev/use/specifications/)
- [CycloneDX specification overview](https://cyclonedx.org/specification/overview/)
- [Package URL (purl) specification](https://github.com/package-url/purl-spec)
- [GitHub Docs: Exporting a software bill of materials](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/exporting-a-software-bill-of-materials-for-your-repository)

## ✅ Checklist de Verificación

- [ ] Sé qué pregunta responde un SBOM y cuándo la vas a necesitar
- [ ] Sé qué diferencia el SBOM del código del de la imagen
- [ ] Sé qué ofrece SPDX frente a CycloneDX y por qué `tablero` usa SPDX
- [ ] Sé instalar syft con versión fijada y checksum
- [ ] Sé buscar un paquete y su versión en un SBOM con `jq`
- [ ] Sé por qué `tablero` no usa `anchore/sbom-action`

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Cadena de suministro y SLSA](03-cadena-de-suministro-y-slsa.md) | [Attestations y Sigstore](05-attestations-y-sigstore.md) |
