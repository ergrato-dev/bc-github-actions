# Escaneo de vulnerabilidades con Trivy

> Firmar una imagen dice de dónde viene, no si es segura. Antes de firmarla, Trivy la compara con
> las bases de avisos y decide si la release sigue o se para.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué compara Trivy y de dónde saca los avisos
- Leer un informe de Trivy: paquete, CVE, severidad, estado, versión instalada y corregida
- Elegir con criterio qué rompe el build (`--severity`, `--ignore-unfixed`, `--exit-code`)
- Instalar Trivy con versión fijada y checksum, y explicar por qué es obligatorio
- Arreglar una vulnerabilidad de la imagen base sin esperar a que el publicador la arregle
- Colocar el escaneo en el orden correcto respecto a la firma

## 1. Qué problema resuelve

`tablero-web` se construye sobre `nginx-unprivileged:1.31.7-alpine`, que a su vez trae Alpine
3.24.2 con decenas de paquetes que tú no elegiste. El día que uno de ellos publica una CVE crítica,
tu imagen la lleva aunque tu código no haya cambiado.

No puedes revisar a mano cada paquete de cada base en cada release. Un **escáner de
vulnerabilidades** cataloga la imagen (como syft) y cruza cada paquete y versión con las bases de
avisos públicas. Si encuentra algo que cumple tu política, devuelve un código de salida distinto
de cero y el job falla.

## 2. Cómo funciona

### De dónde salen los avisos

Trivy descarga su base de datos (`trivy-db`) al empezar, desde un registro OCI: por defecto
`mirror.gcr.io/aquasec/trivy-db:2` y, si falla, `ghcr.io/aquasecurity/trivy-db:2`. Esa base junta
los avisos de las distribuciones (Alpine, Debian...), de los ecosistemas de lenguajes (GitHub
Advisory Database, entre otros) y del NVD.

Por defecto escanea paquetes del sistema operativo (`os`) y de lenguajes (`library`), y también
busca secretos en las capas.

### Qué devuelve

Este es el informe real de `tablero-web` en la capa 13, antes de ningún arreglo:

```text
tablero-web:s14 (alpine 3.24.2)
===============================
Total: 1 (CRITICAL: 1)

│   Library   │  Vulnerability  │ Severity │ Status │ Installed Version │ Fixed Version │
│ brotli-libs │ CVE-2026-111497 │ CRITICAL │ fixed  │ 1.2.0-r1          │ 1.2.1-r0      │
```

_Tabla recortada: la salida real añade el título del aviso y un enlace._

| Columna | Qué te dice |
|---|---|
| `Library` | El paquete afectado, aquí una librería del sistema que trae la base |
| `Severity` | `UNKNOWN`, `LOW`, `MEDIUM`, `HIGH` o `CRITICAL` |
| `Status` | `fixed` si existe una versión corregida; `affected`, `will_not_fix`, `fix_deferred`... si no |
| `Fixed Version` | La versión que lo arregla: lo que necesitas para decidir qué hacer |

_Verificado con Trivy v0.76.2 y ubuntu-24.04, noviembre de 2026._

### La política: qué rompe el build

Tres flags deciden si el job falla:

| Flag | Efecto |
|---|---|
| `--severity CRITICAL` | Solo cuenta lo de esa severidad (acepta una lista: `HIGH,CRITICAL`) |
| `--ignore-unfixed` | Ignora lo que no tiene versión corregida |
| `--exit-code 1` | Devuelve 1 si queda algo; sin él, Trivy informa y sale con 0 |

La pregunta de fondo es: **¿qué puedo arreglar yo hoy?** Una CVE sin arreglo no la puedes quitar
cambiando de versión; romper la release por ella solo bloquea el trabajo sin mejorar nada. Una
CVE crítica con arreglo, en cambio, se arregla en minutos.

Con las imágenes reales de `tablero` (noviembre de 2026):

| Política | `tablero-api` | `tablero-web` |
|---|---|---|
| `CRITICAL` corregible | Pasa | Falla: `brotli-libs` |
| `HIGH,CRITICAL` corregible | Falla: 7 `HIGH` | Falla |
| `HIGH,CRITICAL` sin `--ignore-unfixed` | Falla: además 47 sin arreglo | Falla |

`tablero` rompe solo con `CRITICAL` corregible. Las `HIGH` son trabajo pendiente, que Dependabot
(archivo 02) va resolviendo al mover los digests de las bases; no son una puerta que bloquee cada
release.

### Por qué Trivy se instala con checksum

El 19 de marzo de 2026 se publicó una release comprometida de Trivy, la `0.69.4` (aviso
`GHSA-69fq-xp46-6x23`). Quien instalaba "la última" o usaba `trivy-action` por tag ejecutó en su
runner, con sus permisos, el código del atacante. Una herramienta de seguridad corre con acceso a
tu imagen y a tu registro: es un objetivo excelente.

Las reglas de `tablero`:

- Versión fijada (`v0.76.2`), nunca la `0.69.4`
- El tarball de la release, comprobado con el digest que publica la API de releases
- Nunca `aquasecurity/trivy-action` por tag

## 3. Cómo se usa

### Escanear una imagen en un job

```yaml
name: trivy-example
on:
  workflow_dispatch:
permissions:
  contents: read
jobs:
  scan:
    runs-on: ubuntu-24.04
    timeout-minutes: 15
    env:
      TRIVY_VERSION: v0.76.2
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false

      - name: Instalar Trivy desde su release, con checksum
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          file="trivy_${TRIVY_VERSION#v}_Linux-64bit.tar.gz"
          expected=$(gh api "repos/aquasecurity/trivy/releases/tags/$TRIVY_VERSION" \
            --jq ".assets[] | select(.name == \"$file\") | .digest" | sed 's/^sha256://')
          [[ -n "$expected" ]] || { echo "Sin digest para $file" >&2; exit 1; }
          gh release download "$TRIVY_VERSION" --repo aquasecurity/trivy --pattern "$file" --dir "$RUNNER_TEMP"
          echo "$expected  $RUNNER_TEMP/$file" | sha256sum -c
          tar -xzf "$RUNNER_TEMP/$file" -C "$RUNNER_TEMP" trivy
          echo "$RUNNER_TEMP" >> "$GITHUB_PATH"

      - name: Construir la imagen en local
        run: docker build -t tablero-web:ci web

      - name: Informe de HIGH y CRITICAL, sin romper
        run: trivy image --no-progress --severity HIGH,CRITICAL tablero-web:ci

      - name: Puerta de la release
        run: trivy image --no-progress --exit-code 1 --severity CRITICAL --ignore-unfixed tablero-web:ci
```

El primer escaneo descarga la base de datos y el segundo la reutiliza de la caché local de Trivy,
así que la puerta apenas añade tiempo.

En `release.yml` el escaneo va sobre la imagen ya publicada y **por digest**
(`<imagen>@<digest>`): escaneas exactamente lo que vas a firmar, no un tag que podría haber
cambiado entre medias.

### El orden importa

```text
build + push → Trivy → syft → attest (procedencia) → attest (SBOM)
```

Si Trivy falla, el job se para y **no hay attestations**. La imagen queda en GHCR con su tag de
versión, pero `gh attestation verify` la rechaza porque nadie la firmó. Como en la Semana 17 solo
se despliega lo que verifica, una imagen que no pasó el escaneo nunca llega al clúster.

### Arreglar la base sin esperar al publicador

`nginx-unprivileged:1.31.7-alpine` es el último tag disponible y todavía trae `brotli-libs
1.2.0-r1`. No puedes subir de base, pero sí actualizar ese paquete dentro de tu imagen. Como la
imagen corre con el usuario `nginx` (uid 101), hay que volver a `root` un momento:

```dockerfile
USER root
RUN apk upgrade --no-cache brotli-libs
USER nginx
```

Con el parche Trivy sale con 0 y la imagen sigue corriendo como `uid=101(nginx)`. Deja un
comentario con la CVE y la condición para quitarlo: cuando Dependabot suba el digest de una base
que ya traiga `1.2.1-r0`, esas tres líneas sobran.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `trivy-action` por tag o "la última" Trivy | La `0.69.4` comprometida entró así | Binario de una versión fijada con checksum |
| Romper por cualquier `HIGH` sin arreglo | Bloquea releases por algo que no puedes arreglar | `--ignore-unfixed` y severidad acordada |
| Escanear sin `--exit-code` | El informe sale y el job pasa siempre | `--exit-code 1` en la puerta |
| Escanear el tag después del push | El tag puede apuntar a otra imagen | Escanear `<imagen>@<digest>` |
| Firmar antes de escanear | Una imagen vulnerable queda firmada como buena | Trivy antes de `actions/attest` |
| Dejar el contenedor como `root` tras parchear | Pierdes el usuario sin privilegios de la base | Volver a `USER nginx` |
| `.trivyignore` sin fecha ni motivo | La excepción se queda para siempre | Motivo, enlace y condición de retirada en cada línea |

## 5. Trucos

- **Prueba la puerta en local antes del push**: `trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed tablero-web:local`
  sobre la imagen de `docker build` te dice si la release va a fallar.
- **Solo lo del sistema o solo lo de lenguajes**: `--pkg-types os` o `--pkg-types library` separan
  lo que arreglas con la base de lo que arreglas con `uv.lock` o `pnpm-lock.yaml`.
- **Informe en JSON para filtrar**: `--format json --output trivy.json` y luego
  `jq '[.Results[].Vulnerabilities[]?] | length' trivy.json` te da el total.

## 📚 Recursos Adicionales

- [Trivy documentation](https://trivy.dev/latest/docs/)
- [Trivy: vulnerability filtering](https://trivy.dev/latest/docs/configuration/filtering/)
- [GHSA-69fq-xp46-6x23](https://github.com/aquasecurity/trivy/security/advisories/GHSA-69fq-xp46-6x23)

## ✅ Checklist de Verificación

- [ ] Sé de dónde saca Trivy los avisos y qué escanea por defecto
- [ ] Sé leer cada columna de un informe de Trivy
- [ ] Sé qué hacen `--severity`, `--ignore-unfixed` y `--exit-code`
- [ ] Sé justificar por qué `tablero` rompe solo con `CRITICAL` corregible
- [ ] Sé instalar Trivy con checksum y qué versión no usar nunca
- [ ] Sé parchear un paquete de la base sin perder el usuario sin privilegios

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Attestations y Sigstore](05-attestations-y-sigstore.md) | [Dependency graph y dependency review](07-dependency-graph-y-dependency-review.md) |
