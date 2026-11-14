# Guía de autoría — Bootcamp GitHub Actions

Este archivo es la **fuente única de verdad** de cómo se escribe el contenido
de este repositorio. `.github/copilot-instructions.md` solo apunta aquí.

---

## 📋 Contexto del Bootcamp

`bc-github-actions` enseña **GitHub Actions de cero a avanzado**: desde el
primer workflow hasta operar runners propios en Kubernetes, desplegar con
OIDC, endurecer la cadena de suministro y gobernar CI/CD a escala de
organización. El alumno termina siendo capaz de diseñar, asegurar, depurar y
optimizar los pipelines de un monorepo real, y preparado para la
certificación GitHub Actions (GH-200).

### 📊 Datos del bootcamp

| Dato | Valor |
|---|---|
| Duración | 20 semanas |
| Dedicación | 10 h/semana |
| Total | 200 horas |
| Modalidad | Autoestudio asincrónico |
| Nivel de entrada | Git y GitHub básicos (commit, branch, pull request) |
| Nivel de salida | Diseña, asegura, depura y opera CI/CD con GitHub Actions; listo para GH-200 |
| Entorno de prácticas | Una organización gratuita de GitHub con el repo público `<tu-org>/tablero`, más Docker y kind en la máquina del alumno |
| Coste | 0 €: repos públicos (minutos de runners estándar gratuitos), GHCR público, despliegue a kind local |
| Proyecto hilo conductor | `tablero`, un monorepo propio (FastAPI + uv, React + pnpm, PostgreSQL 17) cuyo CI/CD crece las 20 semanas |
| Idioma de la prosa | Español, siempre con tuteo |
| Idioma del código | Inglés: archivos de código, identificadores, claves, workflows, jobs, commits. Comentarios en español (ver "Nomenclatura y comentarios") |

### 📋 Prerrequisitos del bootcamp

| Qué se asume | Dónde se aprende si falta |
|---|---|
| Git: commit, branch, merge, push, pull request | [`bc-github`](https://github.com/ergrato-dev/bc-github) semanas 01-08 |
| Terminal: navegar, variables de entorno, ejecutar scripts | [`bc-linux-commandline`](https://github.com/ergrato-dev/bc-linux-commandline) |

Lo que **no** se asume y se enseña "lo justo" en la semana que lo necesita:
YAML (S01), Docker y Compose (S05), Kubernetes y Helm (S16).

[`bc-github`](https://github.com/ergrato-dev/bc-github) semanas 09-14 cubre
Actions con un stack solo Node. Este bootcamp es autónomo: no exige haberlas
hecho y va más a fondo.

---

## 🎯 Objetivos de Aprendizaje

Al terminar el bootcamp el alumno es capaz de:

- Explicar cómo GitHub convierte un evento en jobs que corren en un runner, y
  leer cualquier ejecución para saber qué pasó y por qué
- Escribir pipelines de CI para Python con uv y para frontend con pnpm, con
  caché, matrices, artefactos y tests de integración contra PostgreSQL
- Construir y publicar imágenes Docker en GHCR identificadas por digest
- Controlar cuándo corre cada workflow: filtros, cron, dispatch,
  encadenamiento, concurrencia y timeouts
- Probar y depurar workflows en local y en remoto con actionlint, zizmor y act
- Reutilizar CI con workflows reutilizables y actions propias (composite,
  JavaScript y Docker) gobernadas desde la organización
- Defender un pipeline: permisos mínimos, inyección de scripts,
  `pull_request_target`, actions fijadas por SHA, secretos, environments y OIDC
- Firmar la procedencia de lo que publica: releases, SBOM y attestations
- Operar runners propios efímeros, en Docker y con ARC en Kubernetes
- Desplegar de forma continua a Kubernetes con aprobación y rollback
- Escalar el CI de un monorepo con rulesets, merge queue, medición de coste y
  observabilidad

---

## 📚 Estructura del Bootcamp

### Distribución por fases

#### Fase 1 — Fundamentos (S01-04, 40 h)
Modelo de ejecución, expresiones y flujo de datos, CI de Python con uv y de
frontend con pnpm. Al terminar el alumno tiene CI verde en las dos partes del
monorepo y sabe leer cualquier ejecución.

#### Fase 2 — Pipelines de Integración (S05-08, 40 h)
Service containers con PostgreSQL, imágenes en GHCR, disparadores y
concurrencia, y pruebas de workflows. Al terminar el alumno integra contra una
base real, publica imágenes y depura un pipeline roto.

#### Fase 3 — Reutilización (S09-11, 30 h)
Workflows reutilizables, actions propias y gobierno desde la organización. Al
terminar el alumno mantiene el CI de varios repos desde un único sitio.

#### Fase 4 — Seguridad (S12-14, 30 h)
Modelo de amenazas, secretos, environments, OIDC y cadena de suministro. Al
terminar el alumno endurece un pipeline y demuestra la procedencia de lo que
publica.

#### Fase 5 — Runners y Despliegue (S15-17, 30 h)
Runners propios efímeros, ARC en kind y despliegue continuo a Kubernetes. Al
terminar el alumno despliega a un clúster con aprobación y rollback.

#### Fase 6 — Escala y Operación (S18-20, 30 h)
Rulesets, merge queue, monorepos, rendimiento, coste, observabilidad y
capstone. Al terminar el alumno defiende un pipeline de producción completo.

### Contenido semana a semana

| Semana | Slug | Tema |
|:--:|---|---|
| 01 ✅ | `week-01-primer_workflow_y_modelo_de_ejecucion` | Primer workflow y modelo de ejecución |
| 02 ✅ | `week-02-expresiones_contextos_y_flujo_de_datos` | Expresiones, contextos y flujo de datos |
| 03 ✅ | `week-03-ci_de_python_con_uv` | CI de Python con uv |
| 04 ✅ | `week-04-ci_de_frontend_pnpm_matrices_y_artefactos` | CI de frontend con pnpm, matrices y artefactos |
| 05 ✅ | `week-05-service_containers_y_postgresql` | Service containers y PostgreSQL |
| 06 ✅ | `week-06-imagenes_docker_y_ghcr` | Imágenes Docker y GHCR |
| 07 ✅ | `week-07-disparadores_filtros_y_concurrencia` | Disparadores, filtros y concurrencia |
| 08 ✅ | `week-08-probar_y_depurar_workflows` | Probar y depurar workflows |
| 09 ✅ | `week-09-workflows_reutilizables` | Workflows reutilizables |
| 10 ✅ | `week-10-actions_propias` | Actions propias: composite, JavaScript y Docker |
| 11 ✅ | `week-11-actions_a_escala_de_organizacion` | Actions a escala de organización |
| 12 ✅ | `week-12-modelo_de_amenazas_y_endurecimiento` | Modelo de amenazas y endurecimiento |
| 13 ✅ | `week-13-secretos_entornos_y_oidc` | Secretos, entornos y OIDC |
| 14 ✅ | `week-14-releases_cadena_de_suministro_y_attestations` | Releases, cadena de suministro y attestations |
| 15 ✅ | `week-15-runners_self_hosted` | Runners propios |
| 16 ✅ | `week-16-actions_runner_controller_en_kind` | Actions Runner Controller en kind |
| 17 ✅ | `week-17-despliegue_continuo_a_kubernetes` | Despliegue continuo a Kubernetes |
| 18 ✅ | `week-18-merge_queue_rulesets_y_monorepos` | Merge queue, rulesets y monorepos |
| 19 | `week-19-rendimiento_coste_y_observabilidad` | Rendimiento, coste y observabilidad |
| 20 | `week-20-capstone` | Capstone: un pipeline de producción defendido |

Qué funcionalidad de Actions introduce cada semana:
[`docs/mapa-funcionalidades.md`](docs/mapa-funcionalidades.md).

> **Esta tabla vive en cuatro archivos**: aquí, `README.md`, `README_EN.md` y
> `bootcamp/README.md`. Si cambia una, cambian todas.

### Por qué 20 semanas

Cada semana tiene **un mecanismo central** que llena 10 h con cuatro prácticas
reales y verificación remota. Los pares que parecen fusionables no caben
juntos en 10 h: runners propios y ARC (ARC exige Kubernetes y Helm desde
cero), amenazas y OIDC (OIDC necesita environments y un verificador propio),
reutilizables y actions propias (tres tipos de action más su empaquetado).
Partir más daría semanas sin un mecanismo propio.

---

## 🗂️ Estructura de Carpetas

```
bc-github-actions/
├── README.md · README_EN.md   # Contrato con el alumno y su espejo en inglés
├── CLAUDE.md                  # Esta guía — fuente única de verdad
├── LICENSE · SECURITY.md · CONTRIBUTING.md · CODE_OF_CONDUCT.md · CHANGELOG.md
├── app/                       # tablero de referencia: código completo, sin .github/
├── assets/                    # Solo recursos visuales globales
├── docs/                      # Documentación transversal a las 20 semanas
├── lab/                       # kind-config.yaml y runner en contenedor
├── scripts/                   # Verificación, resolve-sha y laboratorio
└── bootcamp/week-NN-tema/     # El contenido
```

Regla de reparto: si algo aplica a **todas** las semanas va en `docs/`; si
aplica a una, va dentro de su semana. Los SVG globales van en `assets/`; los
de una semana, en el `0-assets/` de esa semana.

### Dónde trabaja el alumno

Un workflow solo se ejecuta desde `.github/workflows/` en la raíz de un repo.
Por eso el alumno **no** trabaja en un fork de este bootcamp: en la Semana 01
crea una organización gratuita y dentro el repo público `<tu-org>/tablero`,
donde copia `app/`. Detalle y motivos en
[`docs/decision-laboratorio.md`](docs/decision-laboratorio.md).

---

## 🎓 Componentes de Cada Semana

```
week-XX-tema_principal/
├── README.md
├── rubrica-evaluacion.md
├── checks.json
├── 0-assets/
├── 1-teoria/
├── 2-practicas/
├── 3-proyecto/
│   ├── README.md
│   └── starter/            ← el único sitio donde vive código de partida
├── 4-recursos/{ebooks-free,videografia,webgrafia}/README.md
└── 5-glosario/README.md
```

No existe carpeta `solution/` en ningún sitio: `check-repo.sh` falla
si aparece una.

### 1-teoria/

**El número de archivos es libre: los que pida el temario.** Seis u ocho es lo
normal. **Nunca se sacrifica profundidad para que quepa.**

- **Extensión por archivo**: ~250 líneas, rango 200-300. Si se sale, mezcla
  dos temas: divídelo.
- **Un archivo, un concepto.**
- **Orden fijo**: qué problema resuelve → cómo funciona → cómo se usa →
  antipatrones → trucos.
- **Todo workflow de ejemplo pasa `actionlint`** y respeta las
  [reglas de seguridad de workflows](#-reglas-de-seguridad-de-workflows).
- Toda afirmación que dependa de la versión o de la plataforma lleva la marca
  `verificado con <action>@<vX> y ubuntu-24.04, <mes> <año>`.
- Diagramas en SVG, nunca arte ASCII.

Nomenclatura: `NN-tema-en-kebab-case.md`, numerados desde `01`.

### 2-practicas/

Archivos planos, **200-380 líneas** cada uno: `NN-titulo-en-kebab-case.md`.
Los workflows de la práctica van **dentro del markdown** como bloque YAML que
el alumno escribe a mano: escribirlos es parte del aprendizaje. El `starter/`
vive solo en `3-proyecto/`.

Formato canónico de un paso:

````markdown
## Paso 2: Levantar PostgreSQL junto al job

**Por qué**: un service container arranca antes que el primer step y, con
`--health-cmd`, el runner espera a que esté sano. Sin healthcheck, `pytest`
llega antes que PostgreSQL y falla con `connection refused` aunque el YAML
esté bien.

**Comando**:

```bash
git add .github/workflows/ci-api.yml
git commit -m "ci(api): add postgres 17 service"
git push
gh run watch "$(gh run list --workflow ci-api.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
```

**Verifica**:

```bash
yq '.jobs.integration.services.postgres.image' .github/workflows/ci-api.yml
# postgres:17.11-alpine
```
````

Reglas:

- **Todo paso termina en una verificación ejecutable.** Sin excepción.
- **Toda salida esperada va comentada debajo del comando.**
- **Advertencia antes de lo destructivo** (borrar un runner, un paquete de
  GHCR, una caché, un environment, forzar un push), con el respaldo delante.
- Cierra con `## ✅ Resultado` (casillas + comando de `check-week.sh`) y
  `## 🧯 Si algo sale mal` (tabla Síntoma | Causa | Solución).
- ❌ **No uses `# TODO:` en prácticas.** El `TODO` es formato de proyecto.

### 3-proyecto/README.md

La capa que esta semana añade a `tablero`. Ocho secciones:

1. `## 🎯 Objetivo`
2. `## 📦 Qué añade esta capa` — cómo encaja con la semana anterior y qué
   desbloquea en la siguiente
3. `## ✅ Requisitos verificables` — **copia literal de las descripciones de
   `checks.json`**
4. `## 🎨 Criterios de calidad` — lo que el autograding no ve
5. `## 💡 Adaptación a tu dominio` — tabla con 3-4 variantes
6. `## 🚦 Cómo entregarlo`
7. `## 🧯 Errores comunes`
8. `## 🔗 Navegación`

### 3-proyecto/starter/

El punto de partida, **nunca la solución**. Workflows, `action.yml`, scripts
o manifiestos con:

- Cabecera de comentario con qué es el archivo y a qué ruta de
  `<tu-org>/tablero` se copia
- **`# TODO N:` en cada hueco**, numerados en toda la semana y con una frase
  de qué se espera
- YAML válido tal como se entrega: **los workflows del starter pasan
  `actionlint`** y fallan los checks
- Los scripts `.sh`, con `#!/usr/bin/env bash`, `set -euo pipefail` y bit de
  ejecución

### 4-recursos/

Tres subcarpetas: `ebooks-free/`, `videografia/`, `webgrafia/`. Cada recurso
lleva una línea de por qué vale la pena y la fecha de comprobación.

### 5-glosario/

A-Z en español, con el término real en inglés entre paréntesis cuando lo haya.
Enlaza al glosario global.

### checks.json

Contrato completo en [`docs/autograding.md`](docs/autograding.md). Lo
esencial:

- Se escribe **antes** que el contenido.
- Entre 6 y 18 comprobaciones.
- Cada `description` se copia literal al proyecto; cada `hint` apunta a
  archivo + paso.
- Una comprobación, un hecho.
- Se ejecuta en el host, dentro de la copia local de `<tu-org>/tablero`
  (`APP_DIR`) y con `GH_REPO` apuntando a ese repo. **Cero lógica por semana
  en `check-week.sh`.**
- Una comprobación de ejecución remota filtra por el SHA de `origin/main`:
  un verde antiguo no cuenta.

---

## 🎩 Sección de Trucos

**Obligatoria en el README de cada semana.** Lo que no viene en la
documentación de sintaxis, o viene enterrado.

- ✅ Un flag de `gh` o una expresión poco conocida que ahorra tiempo de verdad
- ✅ Una forma de ver algo que la UI de Actions no enseña
- ❌ Repetir la teoría de esa semana
- ❌ Trivialidades

Todo truco se replica en `docs/trucos-github-actions.md`, en la sección de su
semana.

---

## 🔗 Navegación al pie de cada archivo

**Todo archivo de documentación termina con una tabla de navegación
`← Anterior` / `Siguiente →`.** Vale para el contenido de las semanas y para
`docs/`. Orden de lectura dentro de una semana:

```
README.md (de la semana)
  → 1-teoria/01 → ... → NN
  → 2-practicas/01 → ... → NN
  → 3-proyecto/README.md
  → rubrica-evaluacion.md
  → 4-recursos/ebooks-free/README.md
  → 4-recursos/videografia/README.md
  → 4-recursos/webgrafia/README.md
  → 5-glosario/README.md
  → README.md de la semana siguiente
```

Formato, al final del archivo, tras un separador `---`:

```markdown
---

| ← Anterior | Siguiente → |
|:---|---:|
| [Título del archivo anterior](ruta-relativa) | [Título del archivo siguiente](ruta-relativa) |
```

- Las flechas van solo en la cabecera; los enlaces llevan el título del
  archivo de destino, tal cual.
- El primer archivo enlaza al índice como anterior; el último, al siguiente
  bloque (la semana siguiente, o el índice si todavía no existe).
- En `docs/`, el orden es el de la tabla de `docs/README.md`.
- El README de la semana lleva además su sección `## 🔗 Navegación`, con la
  misma tabla.

---

## 🗣️ Reglas de Lenguaje y Stack

Las que se pueden comprobar con grep las comprueba `scripts/check-repo.sh`.

| Regla | Detalle | Patrón prohibido |
|---|---|---|
| **Tuteo, nunca voseo** | "tienes, puedes, haz, mira, fíjate, prueba". Nunca "tenés, podés, hacé, mirá, fijate, probá, vos" | `tenés\|podés\|querés\|sabés\|hacé\|mirá\|fijate\|probá\|usá\|\bvos\b` |
| **Python solo con uv** | `pyproject.toml` + `uv.lock`, `uv sync --locked`, `uv run`, `uv tool install`, `astral-sh/setup-uv`. Nunca pip, `requirements.txt` ni `python -m venv` | `pip install\|requirements\.txt\|python -m venv` |
| **Node solo con pnpm** | `pnpm install --frozen-lockfile`, `pnpm dlx`, `pnpm/action-setup`. Nunca npm, npx ni `package-lock.json` | `npm (i\|install\|ci\|run)\b\|\bnpx\b\|package-lock\.json` |
| **PostgreSQL, nunca MySQL** | `postgres:17.<parche>-alpine` | `mysql\|mariadb` |
| **Docker cuando haga falta** | Compose como plugin: `docker compose` y `compose.yaml` | `docker-compose ` |
| **Nomenclatura técnica en inglés, documentación en español** | Ver la tabla siguiente. Nunca mezclar idiomas en la misma frase de prosa | revisión |

### Nomenclatura y comentarios

| Va en inglés (nomenclatura técnica) | Va en español (documentación) |
|---|---|
| Archivos de código y scripts (`check-week.sh`, `ci-api.yml`, `action.yml`) | Archivos de contenido: carpetas de semana, teoría, prácticas, `docs/`, SVG |
| Funciones, variables, constantes, clases, módulos | Comentarios de código y mensajes que lee el alumno |
| Claves de JSON y YAML propias (`checks.json`: `week`, `title`, `description`, `hint`) | Valores que son texto para personas (`description`, `hint`) |
| Nombres de workflows, jobs, steps `id`, inputs, outputs, secretos, variables de entorno | `name:` de un step cuando se lee en la UI como explicación |
| Ramas, tags, mensajes de commit | README, CHANGELOG, plantillas de issue y PR |

**Comentarios: solo donde aportan, nunca repetidos.** Un comentario dice
**qué** hace algo que el código no deja ver, **para qué** existe o **qué
impacto** tiene cambiarlo o quitarlo. Si el código ya lo dice, no se comenta.

```bash
# ❌ Repite el código
export GH_REPO="$REPO"   # exporta GH_REPO

# ✅ Para qué e impacto
# GH_REPO es nativa de gh: todo "gh run" y "gh api repos/{owner}/{repo}/..."
# habla con el repo del alumno sin escribir su nombre.
export GH_REPO="$REPO"
```

- Una explicación se escribe **una vez**, en el sitio donde se aplica. Si
  vale para todo el archivo, va en la cabecera; no se repite en cada línea.
- En los starters, la cabecera dice qué es el archivo y dónde se copia; cada
  `TODO N` dice qué falta. La teoría explica el porqué: el starter no la
  copia.

Excepciones explícitas, que el script tolera:

- `package-ecosystem: "npm"` en `dependabot.yml` es el **nombre** del
  ecosistema que Dependabot usa también para pnpm, no el CLI. Se dice en el
  texto la primera vez que aparece (S12).
- Un antipatrón de pip o npm puede citarse en la tabla de antipatrones de una
  teoría si la línea lleva el marcador `<!-- antipatron -->`.

---

## 🔐 Reglas de Seguridad de Workflows

Aplican a **todo** YAML del repositorio: teoría, prácticas, starters, `app/`
y el CI propio. Versión para el alumno, con ejemplo malo y bueno de cada una:
[`docs/reglas-de-seguridad-de-workflows.md`](docs/reglas-de-seguridad-de-workflows.md).

1. **Toda `uses:` remota fijada por SHA de 40 caracteres con el tag en
   comentario**: `uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`.
   El SHA se obtiene con `scripts/resolve-sha.sh`; nunca se escribe a mano ni
   se copia de otro repo. Exentas: `uses: ./ruta`, `uses: $/ruta` y `docker://imagen@sha256:…`.
2. **`permissions:` en la raíz** con `contents: read` (o `{}`), y cada job sube
   solo lo que necesita. Antes de la S12 va anotado "lo verás a fondo en la
   Semana 12".
3. **`runs-on: ubuntu-24.04`**, nunca `ubuntu-latest`. `self-hosted` solo con
   las etiquetas del runner propio del alumno (S15+) y solo en eventos de
   confianza.
4. **Los datos no confiables llegan al shell por `env:`.** Nunca
   `${{ github.event.* }}`, `github.head_ref` ni `inputs.*` interpolados
   dentro de `run:`.
5. **`actions/checkout` con `persist-credentials: false`**, salvo que el job
   haga `git push`; entonces se justifica en un comentario.
6. **`pull_request_target` y `workflow_run` solo con el patrón seguro** de la
   S12. Nunca checkout del head del PR dentro de `pull_request_target`.
7. **Ningún secreto en el log.** Nunca `toJSON(secrets)` ni `echo` de un
   secreto. Las credenciales de CI desechables valen `cambiame` y se dice.
8. **`timeout-minutes` en todo job** desde la S07, y `concurrency` en todo
   workflow de despliegue.
9. **Herramientas con versión fijada y checksum.** `curl | bash` prohibido.
   zizmor con `uv tool install zizmor==<v>`; actionlint y act como binario de
   la release con checksum. Trivy nunca `0.69.4` ni `trivy-action` por tag
   (compromiso del 2026-03-19).
10. **Imágenes con tag completo**, nunca `latest` ni sin tag. Desde la S14 el
    despliegue se hace por digest.
11. **Runner propio blindado**: efímero (JIT o ARC), que solo `tablero` puede usar
    (runner de repositorio y política de la org limitada a `tablero`; runner group en Team), jobs `self-hosted` solo en `push` a `main`,
    `workflow_dispatch` o un environment protegido, y aprobación obligatoria
    para todos los contribuidores externos.
12. **Nada expuesto a la red pública**: puertos de Compose y de kind en
    `127.0.0.1`.

### Lo que no se enseña como vigente

| Prohibido | En su lugar | Por qué |
|---|---|---|
| `::set-output` / `::save-state` | `$GITHUB_OUTPUT` / `$GITHUB_STATE` | Deshabilitados por inyección |
| `ubuntu-latest` | `ubuntu-24.04` | La etiqueta cambia de imagen sin aviso |
| `actions/upload-artifact@v3` y anteriores | La versión de `docs/stack-versions.md` | v3 retirado |
| Runtime `node16` / `node20` en actions JS | El runtime vigente de `docs/stack-versions.md` | `node16` retirado; `node20` deprecado (el runner aún lo trae) |
| PAT clásico para ARC o para automatizar | GitHub App o `GITHUB_TOKEN` | Alcance excesivo y sin caducidad |
| `secrets: inherit` como costumbre | Secretos declarados uno a uno | Pasa todos los secretos a código ajeno |
| `docker-compose` (v1) | `docker compose` (plugin) | v1 retirado |

Lo legado se puede **mencionar** como contexto histórico o para migrar,
marcado como tal.

### Placeholders

| Placeholder | Uso |
|---|---|
| `<tu-org>` | Organización gratuita del alumno |
| `<tu-org>/tablero` | Repo público del proyecto |
| `<tu-org>/actions-tablero` | Repo central de actions y reutilizables (S11+) |
| `<tu-org>/.github` | Repo de la org con las workflow templates (S11+) |
| `kind-gha` | Contexto de kubectl del clúster del laboratorio (S16+) |
| `<sha-de-vX.Y.Z>` | SHA de una release del repo central del alumno, que solo existe en su org |
| `<TOKEN>` | Cualquier credencial en ejemplos |

Nunca un token, una clave privada de GitHub App ni un JWT con formato válido,
ni real ni inventado.

---

## 🎨 Recursos Visuales

- **SVG siempre. Arte ASCII prohibido.**
- Tema oscuro, sin degradados, tipografía sans-serif.
- Paleta:

  | Color | Hex | Uso |
  |---|---|---|
  | Lienzo | `#0d1117` | Fondo |
  | Superficie | `#161b22` | Cajas y paneles |
  | Borde | `#30363d` | Líneas y separadores |
  | Texto principal | `#f0f6fc` | Etiquetas |
  | Texto secundario | `#8b949e` | Anotaciones |
  | Azul Actions | `#2088ff` | Elemento principal: workflow, job |
  | Azul claro | `#79c0ff` | Eventos, flujo de datos |
  | Verde | `#3fb950` | `success` |
  | Amarillo | `#e3b341` | Espera, aprobación, aviso |
  | Rojo | `#f85149` | Fallo, ataque, acción destructiva |
  | Morado | `#d2a8ff` | Secretos, claims, configuración |

- Fuentes: `Inter, Segoe UI, Helvetica, Arial, sans-serif`; código en
  `ui-monospace, Menlo, Consolas, monospace`.
- `viewBox` obligatorio, más `role="img"` y un `<title>` descriptivo.
- Nombrados en orden de lectura: `01-`, `02-`…
- **Todo SVG tiene que estar enlazado desde algún `.md`.**
- **Ni de más ni de menos.** Cada SVG explica un mecanismo que la prosa sola
  no deja ver. En cada semana, `NN-tablero-capa-NN.svg` es el mapa acumulado
  del pipeline de `tablero`; lo enlazan el README y el proyecto.

---

## 📖 Documentación

### Las secciones del README de semana, en orden

1. `# Semana NN — Tema`
2. Blockquote de gancho, 2 líneas
3. `## 🎯 Objetivos de la Semana`
4. `## 📋 Prerrequisitos`
5. `## 🗂️ Estructura de la Semana`
6. `## 📝 Contenidos`
7. `## ⏱️ Distribución del Tiempo (10 horas)` — **la tabla suma 10 h exactas**
8. `## 🎩 Trucos y atajos`
9. `## 📌 Entregables`
10. `## ✅ Verificación`
11. `## 🔗 Navegación`

Entre la 7 y la 8 cabe **una** sección temática propia si el tema lo pide
(por ejemplo `## 🎓 En el examen`).

### Plantilla de archivo de teoría

````markdown
# Título del concepto

> Una línea que sitúa el concepto y por qué importa.

![Descripción del diagrama](../0-assets/NN-nombre.svg)

## 🎯 Objetivos

## 1. Qué problema resuelve

## 2. Cómo funciona

## 3. Cómo se usa

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|

## 5. Trucos

## 📚 Recursos Adicionales

## ✅ Checklist de Verificación
````

---

## 📊 Evaluación

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Las prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | Autograding + rúbrica manual de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio.

La última semana de cada fase (04, 08, 11, 14, 17) añade un minisimulacro
cronometrado de cierre de fase. La 20 cierra con la defensa del capstone y un
simulacro tipo GH-200.

### Estructura de `rubrica-evaluacion.md`

1. `## 📊 Distribución de Evidencias`
2. `## 🧠 Conocimiento (30%)` — 10 preguntas + `<details>` con respuestas
   argumentadas
3. `## 💪 Desempeño (40%)` — tabla Práctica | Criterio | Puntos
4. `## 📦 Producto (30%)` — autograding + calidad manual
5. `### Penalizaciones` — Situación | Deducción
6. Cierre con enlace de vuelta

Penalizaciones graves en toda semana: secreto real comiteado o impreso en un
log (Producto a 0 hasta rotarlo y retirarlo), `uses:` sin SHA, workflow sin
`permissions:` o con `write-all`, `${{ github.event.* }}` dentro de `run:`,
imagen sin tag o `latest`. Desde la S12 también: `pull_request_target` con
checkout del head y runner propio al alcance de PRs de forks. Menores:
`pip`/`npm` (−3), `ubuntu-latest` (−2).

---

## 🤖 Instrucciones para el agente

### Límites de respuesta

- **Una semana por tanda**, usando la última semana publicada como plantilla
  de calidad.
- Dentro de la semana: versiones en `docs/stack-versions.md` → `checks.json`
  → README → teoría y SVG → prácticas → proyecto → rúbrica → recursos y
  glosario → trucos en `docs/` → filas en `docs/proyecto-hilo-conductor.md` y
  `docs/mapa-funcionalidades.md` → ✅ en las cuatro tablas.
- **Commit + push al terminar cada semana**, mensaje en inglés con
  Conventional Commits: `feat(week-NN): add <topic> week`. El scope es
  `week-NN`, nunca el slug completo.
- Al cerrar cada fase, pasar el agente `curriculum-coherence-reviewer` y
  aplicar sus hallazgos en `docs: apply phase N curriculum coherence review`.

### Reglas de generación

1. **Profundidad sobre cobertura.**
2. **Siempre el porqué.**
3. **Verificable.** Lo que no se puede comprobar va a rúbrica manual.
4. **No inventar.** Todo campo de workflow se comprueba con `actionlint` y con
   la referencia de sintaxis; todo input de una action, en su `action.yml` en
   el SHA fijado (`gh api repos/<o>/<r>/contents/action.yml?ref=<sha>`); todo
   flag de `gh`, con `--help`. Un input plausible pero inexistente es el fallo
   más probable en este repositorio (skill `verify-workflows`).
5. **Vigencia antes que costumbre.** Antes de escribir sobre una action o
   herramienta, comprueba su versión en `docs/stack-versions.md`; si la fila
   tiene más de tres meses, revísala primero.
6. **Nunca ejecutar nada destructivo** fuera de la org de pruebas del autor.
7. **Validación sin `solution/`.** El autor resuelve cada capa en un repo
   privado de pruebas fuera de este repositorio: `check-week.sh NN` en
   verde con la capa resuelta, en rojo con el starter.

---

## 📚 Referencias Oficiales

- [GitHub Actions documentation](https://docs.github.com/en/actions)
- [Workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
- [Contexts](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts)
- [Security hardening for GitHub Actions](https://docs.github.com/en/actions/reference/security/secure-use)
- [actions/runner-images](https://github.com/actions/runner-images)
- [Actions Runner Controller](https://docs.github.com/en/actions/concepts/runners/actions-runner-controller)
- [actionlint](https://github.com/rhysd/actionlint) · [zizmor](https://docs.zizmor.sh/) · [act](https://nektosact.com/)
- [uv](https://docs.astral.sh/uv/) · [pnpm](https://pnpm.io/)

---

## ✅ Checklist para Nuevas Semanas

- [ ] Versiones de la semana fijadas y fechadas en `docs/stack-versions.md`
- [ ] `checks.json` escrito **primero**, 6-18 comprobaciones
- [ ] Cada comprobación ejecutada a mano contra el repo de pruebas del autor
- [ ] `README.md` con las secciones en orden y tabla de tiempos de **10 h exactas**
- [ ] Teoría 200-300 líneas por archivo, un concepto por archivo
- [ ] Prácticas planas (200-380 líneas), cada paso con Por qué / Comando / Verifica
- [ ] `3-proyecto/README.md` con requisitos copiados literalmente del `checks.json`
- [ ] `starter/` con `TODO N` numerados; sus workflows pasan `actionlint`
- [ ] Toda `uses:` fijada por SHA resuelto con `scripts/resolve-sha.sh`
- [ ] Todo YAML pasa el skill `verify-workflows`
- [ ] Tuteo, uv, pnpm, PostgreSQL: `check-repo.sh` sin hallazgos de estilo
- [ ] `rubrica-evaluacion.md` con 10 preguntas, respuestas y penalizaciones
- [ ] Trucos en el README, replicados en `docs/trucos-github-actions.md`
- [ ] Glosario A-Z; recursos con justificación y fecha de comprobación
- [ ] SVG en `0-assets/`, todos enlazados, ninguno de relleno
- [ ] Navegación correcta en el README y al pie de cada archivo
- [ ] Las tablas maestras coinciden (`CLAUDE.md`, `README.md`, `README_EN.md`, `bootcamp/README.md`)
- [ ] Semana marcada ✅ en `bootcamp/README.md`
- [ ] `bash scripts/check-repo.sh` en verde
- [ ] `bash scripts/check-week.sh NN` en verde con la capa resuelta, en rojo con el starter

---

## 💡 Notas Finales

- **Profundidad sobre cobertura.** Siempre.
- **Nunca comprimir para que quepa.** Si no cabe, se divide.
- **Lo que no se puede verificar no es obligatorio.**
- **Si dudas de un input, lee el `action.yml` en el SHA. No lo escribas "porque suena bien".**

_Última actualización: noviembre de 2026 · Versión 1.0_
