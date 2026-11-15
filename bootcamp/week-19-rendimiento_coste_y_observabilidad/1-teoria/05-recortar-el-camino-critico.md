# Recortar el camino crítico

> Con la línea base delante, cada recorte es una apuesta que puedes comprobar: quitar un job que
> nadie usa, clonar sin bajar lo que no lees, no repetir trabajo y no dejar que un job colgado
> queme seis horas.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Detectar un job que sobra y quitarlo sin romper los `needs` que dependían de él
- Explicar qué descarga un clon con `fetch-depth: 0` y qué ahorra `filter: blob:none`
- Saber cuándo un clon sin blobs se vuelve más lento en lugar de más rápido
- Usar la cancelación por concurrencia para no pagar runs que ya nadie mira
- Fijar `timeout-minutes` a partir de lo que mides y no de un número redondo
- Aplicar los recortes de uno en uno, midiendo cada uno

## 1. Qué problema resuelve

El archivo 02 te dio dónde se va el tiempo; el 04, por qué partir no siempre ayuda. Lo que queda
es lo más rentable y lo menos vistoso: **hacer menos**. Menos jobs, menos bytes descargados,
menos runs que se tiran a la basura y menos minutos perdidos en jobs colgados. Ninguno de estos
cambios necesita una action nueva: son ajustes de cinco líneas en `ci.yml` cuyo efecto se ve en
la siguiente medición.

## 2. Cómo funciona

### Jobs que sobran

Un job sobra cuando se cumplen tres cosas: **ningún job lo espera** con `needs`, **nadie lee su
salida** y **no protege nada** (no es un check exigido ni falla cuando algo va mal).

`runner-info` nació en la Semana 01 para que vieras el sistema operativo, los núcleos y la
memoria del runner. Cumplía su papel didáctico, pero se quedó en `ci.yml` corriendo en cada run:
un arranque completo para tres comandos, un minuto facturable entero cada vez, y un job más
compitiendo por runner. Solo `summary` lo tenía en sus `needs`, y no usaba nada de él.

Quitarlo exige dos cambios, no uno: borrar el job y sacarlo de la lista `needs` de `summary`. Si
olvidas el segundo, el workflow no es válido: `needs` apunta a un job que no existe, y actionlint
lo detecta antes del push.

### Qué descarga un clon

`actions/checkout` clona por defecto **un commit** (`fetch-depth: 1`). El job `changes` de la
Semana 18 necesita la base del diff, que puede estar muchos commits atrás, y por eso clona con
`fetch-depth: 0`: toda la historia. Un clon completo trae tres tipos de objetos de git:

| Objeto | Qué es | ¿Lo necesita `git diff --name-only`? |
|---|---|:--:|
| Commit | Autor, fecha, padre, árbol | Sí |
| Árbol (*tree*) | La lista de archivos de un directorio con el hash de cada uno | Sí |
| Blob | El contenido de un archivo, en cada versión | **No** |

`git diff --name-only BASE HEAD` compara árboles: si el hash de un archivo cambió, el archivo
cambió. No necesita abrir su contenido. Y los blobs son, con diferencia, lo que más pesa: cada
versión de cada archivo que ha existido en el repo.

### Clon parcial: `filter: blob:none`

`actions/checkout` tiene el input `filter`: "Partially clone against a given filter. Overrides
sparse-checkout if set." Con `filter: blob:none`, git hace un **clon parcial**: trae todos los
commits y todos los árboles, y de los blobs solo los que necesita para dejar en disco el commit
que se comprueba. El resto se descarga **bajo demanda** si algún comando lo pide.

Para `changes` es exactamente lo justo: historia completa para encontrar la base, árboles para
comparar, y solo el contenido de `HEAD` para ejecutar `scripts/changed-areas.sh`. Probado:
`changed-areas.sh` da la misma salida en un clon sin blobs.

### Cuándo el clon parcial sale caro

La descarga bajo demanda tiene dos trampas:

- **Comandos que leen contenido antiguo**: `git diff` sin `--name-only`, `git log -p`,
  `git blame`. Cada blob que falta se pide al servidor; con muchos, el job tarda más que con el
  clon completo.
- **Credenciales**: la descarga bajo demanda es un `fetch` contra `origin`. Con
  `persist-credentials: false` funciona en un repo público como `tablero`; en uno privado
  fallaría por falta de autenticación.

Por eso `filter: blob:none` va en `changes` y en ningún otro job: los demás usan el clon por
defecto de un commit, que ya es lo mínimo.

### Runs que nadie mira

`ci.yml` tiene un bloque `concurrency` (el mecanismo de la Semana 07) con
`cancel-in-progress: ${{ github.event_name == 'pull_request' }}`. En un PR, cada push nuevo
cancela el run anterior: nadie va a fusionar ese commit, y sus minutos se ahorran. En `main` no se
cancela: cada commit de `main` necesita su run completo, porque es el que mide `ci-metrics.yml`
(archivo 06), y un hueco en `main` es un hueco en las métricas.

### Timeouts con datos

Un job sin `timeout-minutes` tiene el límite por defecto: **360 minutos**. Un test que se cuelga
esperando una conexión quema seis horas de runner; en un repo privado, 360 minutos facturables.
Desde la Semana 07 todo job de `tablero` tiene un timeout, pero puesto a ojo.

Con métricas (archivo 06) puedes ajustarlo: un margen de dos o tres veces el p95 de la duración
del job. Suficiente para que un runner lento no lo corte; lo bastante corto para que un cuelgue
cueste minutos y no horas.

_Verificado con actions/checkout@v7.0.1, actionlint 1.7.12 y ubuntu-24.04, noviembre de 2026._

## 3. Cómo se usa

### Quitar `runner-info`

Además de borrar el job entero, `summary` deja de esperarlo:

```yaml
  summary:
    needs: [structure, version, sql]
    if: ${{ !cancelled() }}
```

### Un timeout a partir de los runs

La duración de un job en los últimos diez runs verdes de `main`, la mayor al final:

```bash
for id in $(gh run list --workflow ci.yml --branch main --status success --limit 10 \
    --json databaseId --jq '.[].databaseId'); do
  gh api "repos/{owner}/{repo}/actions/runs/$id/jobs" --paginate --jq '.jobs[]
    | select(.name == "Áreas que cambian")
    | (.completed_at | fromdate) - (.started_at | fromdate)'
done | sort -n | tail -1
# 14
```

Con diez muestras, el p95 por rango más cercano es la mayor de ellas. Un `changes` que nunca
pasa de 14 segundos no necesita 5 minutos de timeout, pero tampoco gana mucho bajándolo: el
ajuste importa en los jobs largos, donde la diferencia entre el timeout y el p95 son minutos de
runner en cada cuelgue.

### El job `changes` sin blobs

```yaml
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          # La base del diff puede estar muchos commits atrás.
          fetch-depth: 0
          # Historia y árboles completos; de los blobs, solo los de HEAD.
          filter: blob:none
          persist-credentials: false
```

### Ver la diferencia en local

```bash
git clone --quiet https://github.com/<tu-org>/tablero full
git clone --quiet --filter=blob:none https://github.com/<tu-org>/tablero blobless
du -sh full/.git blobless/.git
# 4.1M	full/.git
# 1.3M	blobless/.git
cd blobless && git diff --name-only HEAD~5 HEAD | head -3
```

Las cifras son de ejemplo; la proporción crece con la historia del repo. El `git diff
--name-only` del final no descarga nada.

### Un cambio cada vez

Cada recorte, en un commit propio, con tres runs medidos después. Si juntas tres recortes en un
commit y el reloj baja, no sabes cuál lo hizo; si sube, no sabes cuál deshacer. Anota antes y
después en la descripción del PR: es la prueba de que el cambio valió.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Borrar un job y no tocar los `needs` que lo nombran | El workflow deja de ser válido | Buscar el nombre en todo `ci.yml` y pasar actionlint |
| Mantener jobs "informativos" en cada run | Un minuto facturable y un arranque por run, para nada | Un `workflow_dispatch` aparte si de verdad hace falta |
| `fetch-depth: 0` sin filtro en un repo grande | Descarga cada versión de cada archivo | `filter: blob:none` si solo comparas árboles |
| `filter: blob:none` y luego `git log -p` | Cada blob se pide aparte: más lento que el clon completo | Clon completo cuando lees contenido antiguo |
| Cancelar runs en `main` | Commits de `main` sin run completo: métricas con huecos | `cancel-in-progress` solo en PR |
| Jobs sin `timeout-minutes` | Un cuelgue quema 360 minutos | Timeout de 2-3 veces el p95 del job |

## 5. Trucos

- **¿Alguien depende de este job?** `yq '.jobs | to_entries[] | select([.value.needs // []] | flatten | any_c(. == "runner-info")) | .key' .github/workflows/ci.yml`
  lista los jobs que lo nombran en `needs`. Vacío: puedes borrarlo.
- **¿El clon es parcial?** En el job, `git config remote.origin.partialclonefilter` imprime
  `blob:none` si el filtro se aplicó.
- **Runs cancelados de un PR**: `gh run list --workflow ci.yml --status cancelled --limit 20`
  te dice cuántos runs te ahorró la concurrencia.

## 📚 Recursos Adicionales

- [actions/checkout: inputs](https://github.com/actions/checkout#usage)
- [Git: partial clone](https://git-scm.com/docs/partial-clone)
- [GitHub Blog: Get up to speed with partial clone and shallow clone](https://github.blog/open-source/git/get-up-to-speed-with-partial-clone-and-shallow-clone/)
- [GitHub Docs: Workflow syntax — timeout-minutes](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idtimeout-minutes)

## ✅ Checklist de Verificación

- [ ] Sé reconocer un job que sobra y qué hay que tocar al quitarlo
- [ ] Sé qué objetos trae un clon completo y cuáles necesita `git diff --name-only`
- [ ] Sé qué hace `filter: blob:none` y por qué solo va en `changes`
- [ ] Sé cuándo un clon parcial sale más caro que uno completo
- [ ] Sé por qué `ci.yml` cancela runs en PR y no en `main`
- [ ] Sé fijar un `timeout-minutes` a partir del p95 del job

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Paralelismo y sharding](04-paralelismo-y-sharding.md) | [Métricas y observabilidad del CI](06-metricas-y-observabilidad.md) |
