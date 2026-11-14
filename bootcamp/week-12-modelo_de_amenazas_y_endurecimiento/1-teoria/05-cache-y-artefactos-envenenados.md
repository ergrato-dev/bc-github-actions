# Caché y artefactos envenenados

> La caché y los artefactos son archivos que un run escribe y otro lee. Si el que escribe
> tiene menos confianza que el que lee, el atacante no necesita permisos: le basta con dejar
> el archivo preparado.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué cachés puede restaurar un run y en qué ámbito guarda las suyas
- Decir qué triggers pueden escribir en la caché de la rama por defecto y cuáles solo leerla
- Describir un ataque de envenenamiento de caché y por qué GitHub lo cierra por defecto
- Leer y escribir la clave `cache-mode`, y saber por qué `tablero` no la usa todavía
- Tratar un artefacto de otro run como entrada no confiable
- Saber qué no debe guardarse nunca en caché

## 1. Qué problema resuelve

En el archivo 01, la tercera frontera de confianza era **lo que se hereda entre runs**. Desde
la Semana 03 cacheas el entorno de `uv` y desde la 04 el almacén de `pnpm`. Desde la 04 pasas
artefactos entre jobs y desde la 07, entre runs. Son atajos de rendimiento, y también son un
canal: lo que un run deja, otro lo usa sin preguntar de dónde viene.

El riesgo aparece cuando el canal cruza de menos confianza a más:

- **Caché**: un run disparado por un PR guarda una entrada que luego restaura un run de `main`
  con permisos de escritura o de publicación.
- **Artefacto**: un run que ejecutó código del PR sube un archivo que descarga un run con
  escritura, como `pr-report` en el archivo 04.

Ninguno de los dos se firma ni se verifica. El que lee recibe lo que el que escribió quiso.

## 2. Cómo funciona

### De dónde restaura un run

Un run restaura cachés de **su propia rama**, de **la rama por defecto** y, si es un PR, de **la
rama base**. Nunca de ramas hijas ni hermanas. Las cachés de un `pull_request` se crean en el
ref `refs/pull/N/merge`, así que otro PR no las ve.

Consecuencia: la caché de `main` es la más valiosa. **La restaura todo el mundo.**

### Quién puede escribir en la caché de la rama por defecto

| Puede crear o sobrescribir | Solo lee |
|---|---|
| `push`, `workflow_dispatch`, `repository_dispatch`, `delete`, `registry_package`, `page_build`, `schedule` | `pull_request_target`, `issue_comment`, `workflow_run` y el resto de los que resuelven a la rama por defecto |

`pull_request` no entra en la tabla: escribe en su merge ref, que nadie más restaura.

_Verificado con la documentación de dependency caching y ubuntu-24.04, noviembre de 2026._

La segunda columna es la que cierra el ataque clásico. Un `pull_request_target` corre en el
contexto de `main`. Si pudiera guardar caché ahí, un PR de fork que consiguiera ejecutar algo
dentro de él (por inyección o por un checkout indebido) dejaría un `.venv` o un almacén de
`pnpm` modificado. El siguiente `push` a `main` lo restauraría y construiría la imagen de GHCR
con él. **El atacante pasa de un job sin valor a la imagen que publicas**, sin tocar nunca un
token con escritura.

### cache-mode

GitHub expone ese comportamiento como una clave nueva, `cache-mode`, en la raíz del workflow o
en un job:

| Valor | Qué hace |
|---|---|
| `read` | Restaura, no guarda |
| `write` | Restaura y guarda |
| `write-only` | Guarda sin restaurar |
| `none` | Ni restaura ni guarda |

Si la omites, vale `write` en los triggers de confianza y `read` en los de baja confianza. El
runner la publica como variable `ACTIONS_CACHE_MODE`, y `actions/cache` la respeta: si el modo
no permite guardar, salta el guardado con un mensaje informativo y el job no falla. En los
reutilizables, el job llamador fija el techo, como con los permisos, y pedir más es un error de
validación.

Un fragmento, para que reconozcas la forma:

```text
# ⚠️ Fragmento, no un workflow completo: actionlint 1.7.12 rechaza esta clave
# ("unexpected key "cache-mode" for "workflow" section", rhysd/actionlint#745).
cache-mode: read
jobs:
  build:
    cache-mode: none
```

El valor por defecto ya es el seguro. Lo peligroso es lo contrario: **escribir
`cache-mode: write` en un trigger de baja confianza reabre el envenenamiento** que el default
cerraba.

¿Por qué `tablero` no la usa? Porque no le hace falta, y porque actionlint todavía no la conoce
(issues rhysd/actionlint#745 y #762, abiertos). Añadirla rompería `lint-workflows` para no
cambiar nada.

_Verificado con actionlint 1.7.12 y ubuntu-24.04, noviembre de 2026._

### Dónde ves el modo efectivo

Lo viste en el archivo 02: el grupo **GITHUB_TOKEN Permissions** de **Set up job** termina con
`Cache mode: write` o `Cache mode: read`. Es lo que el job recibió, igual que los permisos.

### Lo que la caché nunca debe guardar

El contenido de la caché no está firmado, y cualquiera que abra un PR puede **leer** las cachés
de la rama base. En un repo público eso es cualquiera. Nada sensible en caché: ni `.env`, ni
credenciales de un registro, ni un `~/.docker/config.json`.

Además, el límite es de 10 GB por repo, y una entrada que nadie usa en 7 días se expulsa. No
es un almacén.

## 3. Cómo se usa

### Artefactos: el ataque

```yaml
name: pr-report
on:
  workflow_run:
    workflows: [ci-web]
    types: [completed]
permissions: {}
jobs:
  comment:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    permissions:
      actions: read
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      # ❌ El artefacto se descomprime encima del checkout
      - uses: actions/download-artifact@9000827ccba6bdab643e8b6fd33ac0654aef8333 # v8.0.2
        with:
          name: dist-report
          run-id: ${{ github.event.workflow_run.id }}
          github-token: ${{ github.token }}
      - run: ./scripts/post-report.sh
```

`dist-report` lo subió `ci-web`, que ejecutó el código del PR. El PR puede subir un
`scripts/post-report.sh` dentro del artefacto. Sin `path:`, `download-artifact` lo extrae en el
workspace, encima del checkout de `main`, y el step siguiente ejecuta **el script del
atacante** con `pull-requests: write`.

### Artefactos: la defensa

Tres reglas, y el `pr-report` del archivo 04 las cumple todas:

1. **Fuera del workspace**: `path: ${{ runner.temp }}/dist-report`. Nada del artefacto pisa
   archivos que vayas a ejecutar.
2. **Sin checkout si no hace falta.** `pr-report` no lo necesita y no lo hace.
3. **Datos, nunca código.** Lo que sale del artefacto se valida antes de usarse (`^[0-9]+$`
   para el número) o se pasa como archivo (`--body-file`). Nunca se ejecuta, nunca se
   carga con `source`, nunca se interpola en un `${{ }}`.

Cuando el artefacto sí tiene que ser código, como las imágenes que despliegas en la Semana 17, la
respuesta es otra: que lo produzca un run de confianza (`push` a `main`) y comprobar su
procedencia (Semana 14).

### Caché: qué cambia en tablero

Nada, y es intencional. Los reutilizables de `<tu-org>/actions-tablero` guardan la caché de
`uv` y `pnpm` en los `push` a `main` y la leen en los PR. Los workflows nuevos de la semana (`labeler`, `pr-report`) no restauran ni guardan
caché. Lo que haces es **comprobarlo**: en el log de `labeler` verás `Cache mode: read`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `cache-mode: write` en `pull_request_target` o `workflow_run` | Reabre el envenenamiento de la caché de `main` | Dejar el default |
| Secretos o credenciales en una ruta cacheada | Cualquiera que abra un PR la lee | Nada sensible en caché |
| Usar la caché como almacén de builds | Se expulsa a los 7 días y no se verifica | Artefactos o releases |
| `download-artifact` sin `path:` en un job con permisos | El artefacto pisa el workspace | `path: ${{ runner.temp }}/...` |
| Checkout y artefacto de un PR en el mismo job con escritura | El artefacto puede sustituir lo que ejecutas | Sin checkout, o el artefacto fuera |
| Ejecutar o `source` un archivo del artefacto | Código del PR con tus permisos | Validar y tratarlo como datos |
| Añadir `cache-mode` "por si acaso" | actionlint 1.7.12 la rechaza y el default ya es seguro | Esperar a que actionlint la soporte |

## 5. Trucos

- **Mira el modo de caché de un job** con
  `gh run view <run-id> --log | grep "Cache mode:"`. En un `pull_request_target` tiene que
  decir `read`.
- **Lista las cachés por rama** con `gh cache list --ref refs/heads/main`. Si ves entradas en
  `main` que no reconoces, `gh cache delete <clave>` y que el siguiente `push` las rehaga.
- **Mira qué trae un artefacto antes de usarlo**: descárgalo en local con
  `gh run download <run-id> --name dist-report --dir /tmp/dist-report` y lista su contenido.

## 📚 Recursos Adicionales

- [GitHub Docs: Dependency caching reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching)
- [GitHub Docs: Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- [zizmor: cache-poisoning](https://docs.zizmor.sh/audits/#cache-poisoning)
- [rhysd/actionlint#745](https://github.com/rhysd/actionlint/issues/745): soporte de `cache-mode`

## ✅ Checklist de Verificación

- [ ] Sé de qué ramas restaura caché un run de PR
- [ ] Sé qué triggers pueden escribir en la caché de la rama por defecto
- [ ] Sé contar el ataque de un `pull_request_target` que envenena la caché de `main`
- [ ] Sé qué hacen los cuatro valores de `cache-mode` y cuál es el default
- [ ] Sé por qué `tablero` no declara `cache-mode`
- [ ] Sé dónde ver el modo de caché efectivo de un job
- [ ] Sé las tres reglas para usar un artefacto de otro run

---

| ← Anterior | Siguiente → |
|:---|---:|
| [pull_request_target y workflow_run](04-pull-request-target-y-workflow-run.md) | [Dependencias de actions](06-dependencias-de-actions.md) |
