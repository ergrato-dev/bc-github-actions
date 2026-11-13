# Rúbrica de evaluación — Semana 14

> Releases, cadena de suministro y attestations. Se aprueba con un **mínimo del 70 % en cada
> evidencia**, no en el promedio. Esta semana cierra la Fase 4 e incluye su minisimulacro.

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Prácticas 01 a 04, verificadas por `checks.json` y por criterios manuales |
| 📦 Producto | 30% | Autograding + calidad manual de la capa 14 |

## 🧠 Conocimiento (30%)

Responde por escrito antes de abrir cada respuesta. Cada pregunta vale 3 puntos: 1 por la idea
correcta y 2 por el razonamiento.

**1.** Un compañero propone sacar el job `images` de `release.yml` a un workflow aparte con
`on: release: types: [published]`, "para que cada cosa viva en su archivo". ¿Qué pasa la primera
vez que fusionas el PR de release, y por qué `tablero` lo hace en el mismo run?

<details>
<summary>Respuesta</summary>

**No pasa nada**: la release se publica y el workflow nuevo no arranca nunca. El tag y la release
los crea release-please con `GITHUB_TOKEN`, y los eventos que causa ese token no disparan
workflows (salvo `workflow_dispatch` y `repository_dispatch`): ni `release`, ni `push` de tags.
Es una protección de GitHub contra bucles de workflows que se disparan entre sí.

Por eso `images` vive en `release.yml`, con `needs: release-please` y
`if: needs.release-please.outputs.created == 'true'`: el output es una cadena, y el job solo
corre en el run que creó la release. La otra salida sería un token de una GitHub App, que añade
una credencial que gestionar sin ganar nada. Teoría 01.

</details>

**2.** `tablero` está en `0.4.0`, con `bump-minor-pre-major: true`. Desde la última release hay
tres commits: `fix(api): handle empty board`, `docs: fix typo in README` y
`feat(web)!: drop legacy board view`. ¿Qué versión propone release-please, qué secciones lleva
el CHANGELOG y qué harías si negocio pide que esa versión sea la `1.0.0`?

<details>
<summary>Respuesta</summary>

Propone **`0.5.0`**. El `!` marca un cambio incompatible, que en `1.x` subiría el `MAJOR`; en
`0.x`, con `bump-minor-pre-major`, sube el `MINOR`, porque SemVer dice que antes de `1.0.0`
cualquier cosa puede cambiar y el proyecto aún no ha prometido estabilidad. El `fix` sube el
parche, pero gana el salto mayor. El `docs:` no sube nada y no aparece en las secciones de
cambios.

Para fijar `1.0.0`, un commit (vacío si hace falta) con el pie `Release-As: 1.0.0`: release-please
propone exactamente esa versión. No se edita `version.txt` ni el manifest a mano, ni se crea el
tag fuera de release-please: el siguiente cálculo partiría de un estado que la herramienta no
conoce. Teoría 01 y práctica 03, paso 3.

</details>

**3.** `api/Dockerfile` empieza por `FROM python:3.15.2-slim-trixie@sha256:65a6...`. ¿Qué
imagen usa Docker si el publicador vuelve a subir el tag `3.15.2-slim-trixie`? ¿Por qué el
digest es el del índice y no el del manifiesto `linux/amd64`, y para qué sirve el tag si se
ignora?

<details>
<summary>Respuesta</summary>

Usa **la del digest**: con `tag@sha256:` Docker resuelve por el digest y no mira el tag. Un tag
es un puntero que el publicador mueve cuando quiere (reconstrucciones con parches, o un
atacante con sus credenciales); el digest es el hash del contenido y no se puede mover.

El digest del **índice** multiarquitectura (el que da `docker buildx imagetools inspect`) deja
que cada máquina elija su plataforma: el mismo `FROM` vale en un runner `amd64` y en un portátil
`arm64`. Fijar el de un manifiesto concreto obligaría a construir siempre en esa arquitectura.

El tag queda para las personas, que leen `3.15.2-slim-trixie` y no un hash, y para Dependabot,
que con el ecosistema `docker` sabe qué tag sigue y abre un PR cuando el digest de ese tag cambia
(tras el `cooldown`). Sin Dependabot, un digest fijado envejece y acumula CVE. Teoría 02.

</details>

**4.** Sale un aviso crítico en `brotli`. Tu responsable pregunta qué versiones de
`tablero-web` publicadas este trimestre lo llevan. ¿Cómo respondes con lo que tienes y por qué
importa que el SBOM esté firmado y pegado a la imagen en GHCR?

<details>
<summary>Respuesta</summary>

Con el **SBOM de cada versión**: lo descargas de GHCR junto a la imagen y una línea de `jq`
sobre los paquetes da la versión de `brotli-libs` de cada una. Sin SBOM tendrías que bajarte
cada imagen y escanearla otra vez, y quizá ya no exista la que corrió.

Firmado importa porque el SBOM es una **afirmación sobre una imagen concreta**: la attestation
une el documento SPDX al digest y al workflow que lo generó. Uno que generes hoy en tu máquina
describe lo que tú construyes ahora, no lo que se publicó; uno sin firmar lo puede reemplazar
cualquiera con acceso al registro. Teoría 04 y teoría 05.

</details>

**5.** Una attestation de procedencia de `tablero-api:0.4.0` verifica bien. ¿Qué demuestra y
qué no? ¿Por qué la de `tablero` es SLSA Build L2 y qué haría falta para L3?

<details>
<summary>Respuesta</summary>

**Demuestra** que ese digest lo construyó un job de Actions de `tablero`, desde un commit
concreto, con `release.yml` en una rama concreta, en un runner alojado por GitHub; y que nadie lo
cambió después, porque la firma cubre el digest. **No demuestra** que el código sea correcto ni
seguro, ni que las dependencias estén limpias: una procedencia perfecta puede describir un build
de código malicioso. Para eso están la revisión, Trivy y dependency-review.

Es **L2** porque la plataforma (GitHub) firma la procedencia y el material de firma no está en un
secreto del repo. **L3** pide además que los pasos del build no puedan falsificar su propia
procedencia: el build y la firma tienen que vivir en un **workflow reutilizable de otro repo**,
que el repo de producto llama pero no controla, y el verificador exige ese firmante con
`--signer-repo` o `--signer-workflow`. Teoría 03.

</details>

**6.** `actions/attest` firma sin que exista ninguna clave en los secretos de `tablero`. ¿De
dónde sale la firma, qué papel tienen Fulcio y Rekor y qué dos permisos son imprescindibles?

<details>
<summary>Respuesta</summary>

La action pide el **token OIDC del job** (Semana 13) y lo presenta a **Fulcio**, la autoridad de
certificación de Sigstore. Fulcio comprueba el token y emite un **certificado efímero** (minutos)
cuya identidad es la del token: repo, workflow, ref y commit. Con una clave privada generada en
ese momento, la action firma la attestation, y la firma queda registrada en **Rekor**, el log de
transparencia público, que sirve de prueba de que se firmó mientras el certificado era válido. La
clave se tira: no hay nada que robar ni que rotar.

Imprescindibles: **`id-token: write`**, para pedir el token, y **`attestations: write`**, para
guardar la attestation en la API de GitHub. `tablero` añade `packages: write` y
`artifact-metadata: write` porque además la sube a GHCR junto a la imagen (`push-to-registry`).
Teoría 05.

</details>

**7.** El despliegue de la Semana 17 verificará con
`gh attestation verify oci://... --repo <tu-org>/tablero`. ¿Por qué no basta y qué añade
`--signer-workflow`? ¿Cuándo `--signer-repo` sería distinto de `--repo`?

<details>
<summary>Respuesta</summary>

`--repo` comprueba que la attestation **habla de código de `tablero`**. No dice **qué workflow**
firmó: cualquier workflow de `tablero` con `id-token: write` y `attestations: write`, incluido uno
que alguien añada en una rama, podría firmar una imagen. `--signer-workflow
<tu-org>/tablero/.github/workflows/release.yml` exige que el certificado sea el de `release.yml`,
el único que construye releases. En la práctica 03 viste el otro lado: exigir `images.yml`
rechaza la imagen aunque sea de tu repo.

`--signer-repo` difiere de `--repo` cuando la firma la hace un **reutilizable de otro repo**
(el camino a L3 de la pregunta 5): el código fuente es de `tablero`, pero el firmante es el
workflow del repo central. Teoría 05 y práctica 03, pasos 4 y 5.

</details>

**8.** Trivy encuentra en `tablero-web` una `CRITICAL` con arreglo en `brotli-libs` y, en
`tablero-api`, 7 `HIGH` con arreglo y 47 sin él. `tablero` rompe solo con
`--severity CRITICAL --ignore-unfixed --exit-code 1`. Defiende esa política y explica qué
queda en GHCR cuando la puerta falla.

<details>
<summary>Respuesta</summary>

La pregunta que decide es **qué puedes arreglar hoy**. Una CVE sin versión corregida no se quita
cambiando de versión: romper por ella bloquea todas las releases sin mejorar nada. Una `CRITICAL`
con arreglo se cierra en minutos (actualizar el paquete en la base, como hiciste con
`brotli-libs`). Las `HIGH` son trabajo pendiente que Dependabot va resolviendo al mover los
digests de las bases; si fueran puerta, ninguna release saldría y acabarías bajando la política a
escondidas, que es peor que una política clara.

Si la puerta falla, la imagen **ya está en GHCR con su tag** (Trivy escanea lo publicado, por
digest) pero **sin attestations**, porque los steps de firma van detrás. No pasa
`gh attestation verify` y el despliegue de la Semana 17 la rechaza. Teoría 06 y práctica 02.

</details>

**9.** `release.yml` fija Trivy en `v0.76.2` y comprueba el tarball con `sha256sum -c` contra
el digest que publica la API de releases. ¿Frente a qué protege cada una de las dos medidas? ¿Por
qué `tablero` no usa `trivy-action`?

<details>
<summary>Respuesta</summary>

**La versión fijada** protege frente a una release nueva comprometida: el 19 de marzo de 2026 se
publicó la `0.69.4` maliciosa (`GHSA-69fq-xp46-6x23`), y quien instalaba "la última" ejecutó el
código del atacante con los permisos de su job. Fijando una versión que ya lleva tiempo publicada
y revisada, no te llega lo que salga mañana.

**El checksum** protege frente a recibir otros bytes que los de esa versión: una descarga
corrupta o un asset sustituido. No protege frente a una versión comprometida desde el origen (su
checksum coincide con su propio asset): por eso hacen falta las dos.

`trivy-action` por tag fue justo el vector del incidente: el tag apunta a lo que el publicador
diga y la action instala Trivy por su cuenta. Una herramienta de seguridad corre con acceso a tu
imagen y a tu registro: es un objetivo excelente. Teoría 06.

</details>

**10.** Antes de la capa 14, un PR que añadía un paquete vulnerable a `web/pnpm-lock.yaml` pasaba
`dependency-review-action` en verde. ¿Por qué? ¿Qué cambia el job `snapshot`, por qué se salta en
PR desde forks y en qué se diferencia dependency-review de Dependabot?

<details>
<summary>Respuesta</summary>

dependency-review compara lo que el **dependency graph** sabe de la base y de la cabeza del PR, y
el grafo **no lee** `uv.lock` ni el `pnpm-lock.yaml` de pnpm 11+, que se escribe como dos
documentos YAML. Si el grafo no ve el paquete, no hay diferencia que revisar y el check sale
verde.

El job `snapshot` le da los ojos que le faltan: syft cataloga los lockfiles, `jq` rellena el SHA
(el del head del PR), la ref y el job, y el resultado se envía a la API de dependency submission.
Esa API exige `contents: write`, y un PR desde un fork recibe un token de solo lectura: el job se
salta con un `if:` sobre `head.repo.full_name` y la revisión de ese PR ve solo lo que el grafo ve
por su cuenta.

**Dependabot** actúa después, sobre lo que ya tienes en la rama por defecto (alertas y PR de
actualización); **dependency-review** actúa antes, en el PR, sobre lo que entra, y falla el
check. Se complementan. Teoría 07.

</details>

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — release-please y versionado semántico | Config de un paquete `simple` sin componente en el tag y manifest; `release.yml` en `push` a `main` con la action por SHA; el job escribe solo en `contents`, `pull-requests` e `issues`; release `vX.Y.Z` publicada y `release.yml` en verde (checks `release-please-config`, `release-please-job`, `release-please-permissions`, `release-published`) | 5 |
| 01 — release-please y versionado semántico | Permite a `GITHUB_TOKEN` crear PR en la org y en el repo con `default_workflow_permissions=read`, enseña el PR de release sin checks y explica por qué, y la release la firma `github-actions[bot]` con la etiqueta `autorelease: tagged` | 5 |
| 02 — Imágenes versionadas y escaneo | `images` depende de `release-please` y solo corre si hubo release; publica `api` y `web` con la versión como tag; Trivy y syft como binario con `sha256sum`; Trivy sobre la imagen por digest con `--exit-code 1` (checks `images-gated-by-release`, `images-versioned`, `tools-with-checksum`, `trivy-gate`) | 5 |
| 02 — Imágenes versionadas y escaneo | Enseña el run de `v0.3.0` con `tablero-web` en rojo por `CVE-2026-111497`, el parche de `brotli-libs` como `fix(web)` en `v0.3.1` y la imagen que sigue corriendo como uid 101 | 5 |
| 03 — SBOM y attestations | Dos `actions/attest` por SHA sobre el digest publicado, procedencia y SBOM, en el registro; permisos del job exactos (checks `attest-steps`, `attest-permissions`, `attestations-verify`) | 5 |
| 03 — SBOM y attestations | Enseña las cuatro verificaciones rechazadas del paso 5 (sin firmar, otro firmante, otro repo, otro predicado) con el control positivo aceptado, y lee la identidad del certificado firmante | 5 |
| 04 — Digests y revisión de dependencias | Bases, `COPY --from` y services por tag y digest; Dependabot `docker` con cooldown; snapshot desde un job con `contents: write`; revisión de solo lectura que falla con `high`; escrituras solo donde tocan; actionlint y zizmor limpios (checks `base-images-by-digest`, `services-by-digest`, `dependabot-docker`, `dependency-snapshot`, `dependency-review-gate`, `writes-only-where-needed`, `workflows-lint`) | 5 |
| 04 — Digests y revisión de dependencias | Enseña el número de paquetes del grafo antes y después del snapshot, y el PR con `lodash@4.17.20` en rojo con `GHSA-35jh-r3h4-6jhm` y `GHSA-r5fr-rjxr-66jc`, cerrado sin fusionar y con la rama borrada | 5 |
| **Total** | | **40** |

## 📦 Producto (30%)

**Autograding (12 puntos)**: `./scripts/check-week.sh 14` con 18/18. Cada comprobación en rojo
resta la parte proporcional (12/18 de punto).

**Calidad manual de la capa 14 (18 puntos)**:

| Criterio | Puntos |
|---|:--:|
| Los digests salen de `docker buildx imagetools inspect` (o de un PR de Dependabot) y son los del índice multiarquitectura del tag que dice cada línea, no copiados de un blog | 3 |
| El parche de `brotli-libs` lleva un comentario con la CVE, la fecha y cuándo quitarlo; si la base ya venía arreglada no hay parche, y el commit lo dice | 3 |
| Ninguna excepción de Trivy sin justificar: si hay `.trivyignore`, cada línea lleva el porqué y una fecha de revisión | 3 |
| El CHANGELOG se lee bien: commits convencionales con alcance (`fix(web): ...`, `feat(api): ...`), ningún `update` ni `wip` | 3 |
| Las versiones de syft y Trivy coinciden con `docs/stack-versions.md` y aparecen una sola vez, en `env:` | 2 |
| Los workflows de prueba de las prácticas y la rama del PR vulnerable están borrados; el PR, cerrado sin fusionar | 2 |
| Sin `TODO` en el repo | 2 |
| **Total** | **18** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Secreto real comiteado o impreso en un log, o el token OIDC impreso en un log o en el resumen del job | Grave: Producto a 0 hasta rotar el secreto y retirar el log |
| `pull_request_target` con checkout del head del PR | Grave: −10 |
| Runner propio al alcance de PRs de forks | Grave: −10 |
| `uses:` remota sin SHA, o con un SHA copiado que no pertenece al repo oficial | Grave: −10 |
| Workflow sin `permissions:` o con `write-all` | Grave: −10 |
| `${{ github.event.* }}`, `github.head_ref`, `inputs.*`, `secrets.*` o `vars.*` interpolado dentro de `run:` o de `script:` | Grave: −10 |
| Imagen sin tag o con `latest` | Grave: −10 |
| Trivy `0.69.4`, `trivy-action` por tag, o una herramienta instalada con `curl \| bash` | Grave: −10 |
| syft o Trivy descargados sin comprobar el checksum | −5 |
| Bajar la severidad, quitar `--exit-code 1` o añadir un `.trivyignore` sin justificar para que la release pase | −5 |
| `id-token: write` o `attestations: write` en la raíz o en el job `release-please` | −5 |
| Tag de una release movido o release recreada a mano en lugar de publicar una versión nueva | −5 |
| PR vulnerable de la práctica 04 fusionado en `main` | −5 |
| Verificación de attestations (script, documentación o README de tu repo) sin `--signer-workflow` | −3 |
| Attestation con `subject-name` con tag, o sobre un digest que no es el que devolvió el build | −3 |
| PAT para release-please en lugar de `GITHUB_TOKEN` | −3 |
| `secrets: inherit` al llamar a un reutilizable | −3 |
| Job con `runs-on` sin `timeout-minutes` | −3 por cada uno |
| `pip`, `npm` o Compose v1 en un workflow, un Dockerfile o la documentación de tu repo | −3 <!-- antipatron --> |
| `ubuntu-latest` | −2 <!-- antipatron --> |
| `TODO` sin resolver en la entrega | −1 por cada uno |

## 🏁 Minisimulacro de cierre de la Fase 4

Cierra las semanas 12-14 en las condiciones del examen GH-200: **60 minutos cronometrados**, sin
abrir la teoría ni buscar en la web. Cubre los dominios D2 (consumir y depurar workflows) y D4
(gestionar Actions en la organización y su seguridad), con repaso de D3 (actions de terceros y
su fijación). Pon el reloj antes de leer la primera pregunta.

| Parte | Qué es | Tiempo | Puntos |
|---|---|:--:|:--:|
| A | 12 preguntas tipo test, una sola respuesta correcta | 35 min | 12 |
| B | Una release de parche de `tablero`, de punta a punta | 25 min | 8 |
| **Total** | | **60 min** | **20** |

**Aprobado: 14 puntos (70 %).** No suma a los pesos de la semana: es tu termómetro de la fase. Si
no llegas, la explicación de cada fallo te dice qué semana repasar antes de la Fase 5.

### Parte A — Preguntas tipo test (35 minutos)

Marca una opción por pregunta y apunta tus respuestas; abre las soluciones solo al final.

**A1.** Un workflow declara en la raíz `permissions: contents: read` y un job declara
`permissions: pull-requests: write`. ¿Qué permisos tiene el `GITHUB_TOKEN` de ese job?

- A) `contents: read` y `pull-requests: write`: se suman
- B) Solo `pull-requests: write`; el resto, incluido `contents`, queda en `none`
- C) Los permisos por defecto del repo más `pull-requests: write`
- D) `write-all`, porque el job pide escritura

<details>
<summary>Solución</summary>

**B.** Los `permissions` de un job **sustituyen** a los de la raíz, no se suman, y todo lo que
no se nombra queda en `none`. Si ese job hace `actions/checkout`, necesita repetir
`contents: read`. Semana 12, teoría 02.

</details>

**A2.** Un step hace `run: echo "Revisando ${{ github.event.pull_request.title }}"`. ¿Cuál es el
riesgo y el arreglo?

- A) Ninguno: GitHub escapa las expresiones antes de pasarlas al shell
- B) Inyección de scripts: la expresión se sustituye en el texto del script antes de que lo lea el shell; el arreglo es pasar el título por `env:` y usar `"$TITLE"`
- C) Fuga del título en el log; el arreglo es `::add-mask::`
- D) Inyección, y el arreglo es poner la expresión entre comillas simples

<details>
<summary>Solución</summary>

**B.** Un título como `"; curl ... | sh; "` se convierte en código. Las comillas no sirven: el
atacante cierra las que pongas. Con `env:`, el valor llega como variable de entorno y el shell
nunca lo interpreta como código. Semana 12, teoría 03.

</details>

**A3.** Un workflow usa `pull_request_target` para etiquetar PRs de forks. ¿Qué es cierto?

- A) Corre con el código del PR y un token de solo lectura, como `pull_request`
- B) Corre en el contexto de la rama base, con secretos y un token que puede escribir: nunca debe hacer checkout del head del PR ni ejecutar su código
- C) Es seguro hacer checkout del head del PR si el job tiene `permissions: {}`
- D) Solo se dispara para PRs de colaboradores del repo

<details>
<summary>Solución</summary>

**B.** Por eso es útil (puede comentar o etiquetar un PR de un fork) y por eso es peligroso: el
código del PR en ese contexto se ejecuta con los secretos y el token de la base. `permissions: {}`
no quita los secretos ni la caché. Semana 12, teoría 04.

</details>

**A4.** Configuras Dependabot para `github-actions` con `cooldown.default-days: 7`. ¿Qué gana
`tablero`?

- A) Dependabot revisa el código de cada versión antes de proponerla
- B) No se proponen versiones hasta que llevan 7 días publicadas: una release comprometida suele detectarse y retirarse en ese plazo
- C) Los PR de Dependabot se fusionan solos a los 7 días
- D) Dependabot deja de proponer cambios de SHA y solo propone tags

<details>
<summary>Solución</summary>

**B.** El cooldown reduce el riesgo, no lo elimina: los PR se siguen leyendo y pasan el CI. Es
la misma idea que no instalar la última Trivy el día que sale. Semana 12, teoría 06.

</details>

**A5.** Existe un secreto `DB_URL` en la organización, en el repo y en el environment
`staging`. Un job con `environment: staging` lee `secrets.DB_URL`. ¿Cuál recibe?

- A) El de la organización
- B) El del repo
- C) El del environment
- D) El job falla por ambigüedad

<details>
<summary>Solución</summary>

**C.** Gana el nivel más específico: environment sobre repo y repo sobre organización. Semana
13, teoría 01.

</details>

**A6.** Un PR desde un fork dispara un workflow con `on: pull_request` que usa
`secrets.API_TOKEN`. ¿Qué pasa?

- A) El job recibe el secreto si el autor ya contribuyó antes
- B) El secreto llega vacío y el `GITHUB_TOKEN` es de solo lectura
- C) El run espera a que un administrador apruebe el uso del secreto
- D) GitHub copia el secreto al fork

<details>
<summary>Solución</summary>

**B.** Los secretos no se pasan a workflows disparados por PRs de forks (salvo `GITHUB_TOKEN`,
que llega de solo lectura). Es lo mismo que obliga a saltar el job `snapshot` en forks. Semana
13, teoría 01.

</details>

**A7.** Quieres que un job solo corra si existe el secreto `SLACK_WEBHOOK`. ¿Qué funciona?

- A) `if: secrets.SLACK_WEBHOOK != ''` en el job
- B) Pasar el secreto a una variable en `env:` y condicionar el step con `if: env.SLACK_WEBHOOK != ''`
- C) `if: ${{ secrets.SLACK_WEBHOOK }}` en el job
- D) No se puede saber si un secreto existe

<details>
<summary>Solución</summary>

**B.** `secrets` no se puede referenciar directamente en un `if:`. Se pasa a `env:` y se
condiciona sobre la variable. Semana 13, teoría 01.

</details>

**A8.** Un job necesita credenciales de corta vida de una nube por OIDC. ¿Qué permiso declara?

- A) `id-token: write`, que por sí solo no da acceso a nada: la nube decide según los claims del token
- B) `id-token: read`
- C) `contents: write` y `id-token: write`
- D) Ninguno: el token OIDC se emite siempre

<details>
<summary>Solución</summary>

**A.** `write` es el nivel que permite **pedir** el token. El acceso lo concede la política de
confianza del consumidor, comparando `iss`, `aud` y `sub`. Semana 13, teoría 04.

</details>

**A9.** Un job usa `environment: production`, que tiene revisores obligatorios y un secreto
`DEPLOY_KEY`. ¿Cuándo recibe el job el secreto?

- A) Al empezar el run, para preparar el despliegue
- B) Solo cuando se cumplen las reglas de protección: hasta que alguien aprueba, el job no arranca y no ve los secretos del environment
- C) Nunca: los secretos de environment solo se leen desde la UI
- D) Al terminar el job, para el paso de limpieza

<details>
<summary>Solución</summary>

**B.** Por eso las credenciales de producción van en el environment y no en el repo: quedan
detrás de la aprobación. Semana 13, teoría 03.

</details>

**A10.** Un job firma la procedencia de una imagen con `actions/attest`. ¿Qué permisos son
imprescindibles?

- A) `contents: write` y `packages: write`
- B) `id-token: write` y `attestations: write`
- C) `attestations: write` solamente
- D) `id-token: write` y `security-events: write`

<details>
<summary>Solución</summary>

**B.** `id-token` para obtener el certificado de Fulcio con la identidad del job, `attestations`
para guardar la attestation. Subirla también al registro (`push-to-registry`) añade
`packages: write` y `artifact-metadata: write`. Semana 14, teoría 05.

</details>

**A11.** `gh attestation verify` acepta la procedencia de una imagen. ¿Qué queda demostrado?

- A) Que la imagen no tiene vulnerabilidades conocidas
- B) Que el código pasó la revisión de un PR
- C) Dónde y cómo se construyó ese digest (repo, workflow, commit) y que no se modificó después
- D) Que la imagen se construyó en la máquina de un mantenedor de confianza

<details>
<summary>Solución</summary>

**C.** La procedencia habla del build, no de la calidad del código ni de sus vulnerabilidades.
Semana 14, teoría 03.

</details>

**A12.** ¿Qué hace `actions/dependency-review-action` en un PR?

- A) Abre PRs para actualizar las dependencias vulnerables de la rama por defecto
- B) Compara las dependencias de la base y de la cabeza del PR según el dependency graph y falla si entra una con un aviso de la gravedad configurada
- C) Escanea la imagen Docker del PR con Trivy
- D) Envía al dependency graph los lockfiles que no sabe leer

<details>
<summary>Solución</summary>

**B.** A describe a Dependabot, C es Trivy y D es el job `snapshot` con la API de dependency
submission. Semana 14, teoría 07.

</details>

### Parte B — Una release de parche de punta a punta (25 minutos)

Publica la siguiente versión de **parche** de `tablero` (en el recorrido normal, de `v0.4.0` a
`v0.4.1`) con un arreglo pequeño de tu elección en `api/`: un mensaje de error más claro, una
validación que faltaba. Nada de cambios en `.github/`: la cadena de la capa 14 tiene que llevar
ese cambio a producción sin que la toques.

> ⚠️ **Una release publicada no se rehace.** Si algo sale mal, no muevas el tag ni borres la
> release para repetirla: el arreglo es otro `fix` y la siguiente versión de parche.

Lo que tienes que hacer, sin más guía que lo aprendido en la fase:

1. Una rama con el arreglo en un commit `fix(api): ...`, su PR con los checks en verde
   (incluida la revisión de dependencias) y el merge.
2. El PR de release que abre release-please, revisado y fusionado.
3. El run de `release.yml` de esa fusión, en verde, con las dos imágenes publicadas y firmadas.

Corrige con estas ocho comprobaciones, 1 punto cada una:

```bash
cd ~/code/tablero && git switch -q main && git pull -q --ff-only && git fetch -q --tags
export GH_REPO=<tu-org>/tablero
o=${GH_REPO%%/*}; o=${o,,}
new=$(gh release view --json tagName --jq .tagName)
prev=$(git describe --tags --abbrev=0 "$new^")
# 1. La versión nueva es el parche siguiente, publicada por release-please
echo "$prev -> $new $(gh release view --json author --jq .author.login)"
# v0.4.0 -> v0.4.1 github-actions[bot]
# 2. Las notas de la release recogen el arreglo
gh release view --json body --jq .body | grep -c 'Bug Fixes'
# 1
# 3. release.yml en verde sobre el commit del tag
gh run list --workflow release.yml --commit "$(git rev-list -n 1 "$new")" --json conclusion --jq '.[0].conclusion'
# success
# 4. El PR del arreglo pasó la revisión de dependencias
sha=$(git log --format=%H --grep '^fix(api)' -n 1 "$prev..$new")
fix=$(gh api "repos/$GH_REPO/commits/$sha/pulls" --jq '.[0].number')
gh pr checks "$fix" --json name,bucket --jq '.[] | select(.name | test("dependencias")) | .name + " " + .bucket' | sort
# Revisión de dependencias pass
# Snapshot de dependencias pass
# 5. Nadie tocó la cadena: ni un workflow cambió entre las dos versiones
git diff --name-only "$prev" "$new" -- .github | wc -l
# 0
# 6. Procedencia y SBOM de las dos imágenes, firmados por release.yml
for c in api web; do for p in https://slsa.dev/provenance/v1 https://spdx.dev/Document/v2.3; do gh attestation verify "oci://ghcr.io/$o/tablero-$c:${new#v}" --repo "$GH_REPO" --signer-workflow "$GH_REPO/.github/workflows/release.yml" --predicate-type "$p" >/dev/null 2>&1 && printf 'ok ' || printf 'mal '; done; done; echo
# ok ok ok ok
# 7. El digest que sirve el tag es el que se firmó
d=$(docker buildx imagetools inspect "ghcr.io/$o/tablero-api:${new#v}" --format '{{json .Manifest}}' | jq -r .digest)
gh attestation verify "oci://ghcr.io/$o/tablero-api:${new#v}" --repo "$GH_REPO" --signer-workflow "$GH_REPO/.github/workflows/release.yml" --format json --jq '.[].verificationResult.statement.subject[0].digest.sha256' | grep -c "${d#sha256:}"
# 1
# 8. La capa sigue completa
cd ~/code/bc-github-actions && ./scripts/check-week.sh 14 | tail -1
# 18/18 comprobaciones superadas.
```

<details>
<summary>Solución de referencia y fallos típicos</summary>

```bash
# 1. El arreglo, por PR
cd ~/code/tablero && git switch -c fix/api-empty-board
# ... el arreglo en api/ y su test ...
git commit -am "fix(api): return 404 for an unknown board" && git push -u origin HEAD
gh pr create --fill && gh pr checks --watch > /dev/null && gh pr merge --squash --delete-branch

# 2. El PR de release
git switch main && git pull -q --ff-only && sleep 5
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
pr=$(gh pr list --label "autorelease: pending" --json number --jq '.[0].number')
gh pr diff "$pr"
gh pr merge "$pr" --squash --delete-branch

# 3. La release y las imágenes
git switch main && git pull -q --ff-only && sleep 5
run=$(gh run list --workflow release.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status > /dev/null && echo release ok
gh run view "$run" --json jobs --jq '.jobs[] | .name + " " + .conclusion' | sort
```

Fallos que cuestan puntos:

- **El commit dice `fix: update`** o va sin tipo: sin tipo convencional release-please no abre
  PR; sin alcance el CHANGELOG no dice qué parte cambió. Semana 14, teoría 01.
- **Commit directo a `main`**: te saltas la revisión de dependencias y la comprobación 4 no
  encuentra el PR. Semana 14, teoría 07.
- **`images` falla en Trivy**: una base nueva trajo otra `CRITICAL` con arreglo. No bajes la
  severidad: arréglalo con otro `fix(web)` (o `fix(api)`) y publica el parche siguiente; la
  versión que falló queda en GHCR sin firmar, que es lo correcto. Semana 14, práctica 02, paso 5.
- **Retocar `release.yml` "ya que estabas"**: la comprobación 5 lo ve. Un cambio de la cadena va
  en su propio PR, con su `ci:`, y no en una release de parche de la API. Semana 14, teoría 01.
- **Verificar sin `--signer-workflow`**: la comprobación pasaría también con una imagen firmada
  por cualquier otro workflow de `tablero`. Semana 14, teoría 05.
- **Repetir la versión borrando la release o moviendo el tag** tras un fallo: la imagen de esa
  versión ya existe en GHCR y su tag apuntaría a otra cosa. Semana 11, teoría 04, y Semana 14,
  teoría 02.

</details>

Vuelve al [README de la semana](README.md) para ver los entregables.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Proyecto: capa 14 de tablero](3-proyecto/README.md) | [eBooks gratuitos](4-recursos/ebooks-free/README.md) |
