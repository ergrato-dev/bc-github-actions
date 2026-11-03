# Leer una ejecución

> Un CI en rojo solo sirve si sabes encontrar en un minuto qué step falló y por qué. Esta es la
> habilidad que más vas a usar en las 20 semanas, y se hace mejor desde la terminal que desde la web.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Nombrar las piezas de una ejecución: run, attempt, job y step
- Interpretar las conclusiones `success`, `failure`, `cancelled` y `skipped`
- Explicar cómo el código de salida de un comando decide el resultado del job
- Encontrar, ver, seguir y relanzar ejecuciones con `gh run`
- Lanzar un workflow a mano con `gh workflow run`

## 1. Qué problema resuelve

La pestaña Actions de GitHub enseña mucho, pero pide muchos clics: abrir la ejecución, elegir el
job, desplegar el step, buscar la línea. Cuando una ejecución falla, la pregunta siempre es la
misma: **¿qué step, qué comando, qué línea?** Con `gh run` esa respuesta está a un comando, y el
mismo comando sirve en un script o en el autograding de este bootcamp.

## 2. Cómo funciona

### Las piezas

| Pieza | Qué es | Identificador |
|---|---|---|
| **Run** (ejecución) | Una ejecución de un workflow, creada por un evento | `databaseId` numérico; lo ves en la URL `.../actions/runs/<id>` |
| **Attempt** (intento) | Cada vez que relanzas un run, se crea un intento nuevo del mismo run | 1, 2, 3... |
| **Job** | Un conjunto de steps que corre en **un** runner | Su clave en `jobs:` y un id numérico |
| **Step** | Un comando (`run:`) o una action (`uses:`) dentro de un job | Su posición y su `name:` |

Un run tiene uno o varios jobs; cada job, una lista de steps que se ejecutan en orden en el mismo
runner. Los jobs de un mismo run, si nada los encadena, corren **en paralelo y en máquinas
distintas** (lo viste en [Runners alojados por GitHub](04-runners-alojados.md)).

### Estado y conclusión

Mientras corre, un run tiene un **estado** (`status`): `queued`, `in_progress` o `completed`.
Cuando termina, tiene además una **conclusión** (`conclusion`):

| Conclusión | Significa |
|---|---|
| `success` | Todos los jobs terminaron bien |
| `failure` | Al menos un job falló |
| `cancelled` | Alguien (o algo) lo canceló antes de terminar |
| `skipped` | El job no llegó a ejecutarse porque una condición lo saltó |

El estado sirve para esperar; la conclusión, para decidir. Por eso el autograding pregunta por
`conclusion` y no por `status`.

### Cómo falla un job

La regla es la del shell: **un step falla si su comando sale con un código distinto de 0**. En
cuanto un step falla:

1. Los steps siguientes de ese job **no se ejecutan** (salen como saltados).
2. El job termina en `failure`.
3. El run termina en `failure`, aunque los demás jobs hayan salido bien.

En un `run:` de varias líneas en Linux, el runner usa `bash -e`: la primera línea que falla corta
el step. No hace falta `set -e`; el detalle completo de `shell:` está en la Semana 02.

### Logs y anotaciones

Cada step guarda su salida (stdout y stderr) en el log del job, con hora por línea. Además, un
step puede emitir **anotaciones**: líneas especiales que GitHub saca del log y pone en el resumen
del run, por ejemplo:

```bash
echo "::error file=compose.yaml::falta compose.yaml"
```

Las verás con detalle en la Semana 08. Por ahora basta con reconocerlas: si el resumen de un run
muestra un error con nombre de archivo, viene de una línea así.

### Relanzar no es volver a empezar

Un re-run usa **el mismo `GITHUB_SHA` y el mismo `GITHUB_REF`** que la ejecución original, y los
privilegios de quien la lanzó la primera vez. Consecuencias:

- Relanzar sirve para fallos **transitorios** (una red caída, un servicio externo lento).
- Relanzar **no** recoge tu arreglo: si cambiaste el código o el workflow, necesitas un commit
  nuevo, que crea un run nuevo.
- Solo se puede relanzar durante **30 días** después de la primera ejecución, y como mucho 50
  veces.

## 3. Cómo se usa

Todos los ejemplos se ejecutan dentro de tu clon de `<tu-org>/tablero`: `gh` deduce el repo del
remoto `origin`. Fuera de él, añade `--repo <tu-org>/tablero` o exporta `GH_REPO`.

### Encontrar una ejecución: `gh run list`

```bash
gh run list --limit 5
# STATUS  TITLE                 WORKFLOW  BRANCH  EVENT              ID          ELAPSED  AGE
# ✓       ci: add runner-info   ci        main    push               1234567890  21s      2m
# X       ci: add runner-info   ci        fix-ci  pull_request       1234567812  18s      5m
```

Los filtros que más usarás:

| Flag | Filtra por |
|---|---|
| `-w, --workflow ci.yml` | Workflow (por archivo o por `name:`) |
| `-b, --branch main` | Rama |
| `-c, --commit <sha>` | SHA del commit |
| `-e, --event pull_request` | Evento que lo lanzó |
| `-s, --status failure` | Estado o conclusión |
| `-L, --limit 20` | Cuántos devuelve (20 por defecto) |

Para un script, nunca leas columnas: pide JSON.

```bash
gh run list --workflow ci.yml --limit 1 --json databaseId,conclusion,headSha
# [{"conclusion":"success","databaseId":1234567890,"headSha":"..."}]
```

### Ver una ejecución: `gh run view`

```bash
gh run view 1234567890            # resumen: jobs y anotaciones
gh run view 1234567890 -v         # además, cada step
gh run view 1234567890 --log-failed   # solo el log de los steps que fallaron
gh run view 1234567890 --log      # el log completo
gh run view --job <job-id> --log  # el log de un único job
```

`--log-failed` es la respuesta directa a "¿qué falló?": imprime solo las líneas del step roto, con
el nombre del job y del step delante de cada una.

`--exit-status` hace que `gh run view` salga con código distinto de 0 si el run falló. Sirve para
encadenarlo en un script.

### Seguir una ejecución en directo: `gh run watch`

```bash
gh run watch 1234567890 --exit-status
```

Refresca cada 3 segundos (cámbialo con `-i`), muestra cada step según termina y, con
`--exit-status`, devuelve error si el run falla. `--compact` enseña solo los steps relevantes o
fallidos. El patrón de las prácticas de este bootcamp combina los dos comandos:

```bash
gh run watch "$(gh run list --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
```

### Relanzar: `gh run rerun`

```bash
gh run rerun 1234567890 --failed   # solo los jobs que fallaron
gh run rerun --job <job-id>        # un único job
gh run rerun 1234567890 --debug    # con logs de depuración
```

`--debug` activa el log de diagnóstico del runner y el log de depuración de cada step para ese
intento. Es lo primero que pruebas cuando un log normal no dice lo suficiente (Semana 08).

### Lanzar a mano: `gh workflow run`

```bash
gh workflow run hello.yml                 # en la rama por defecto
gh workflow run hello.yml --ref mi-rama   # en otra rama, si el workflow ya existe en main
```

Crea un evento `workflow_dispatch`. No devuelve el id del run: búscalo después con
`gh run list --workflow hello.yml --event workflow_dispatch --limit 1`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Leer el log entero buscando el error | Miles de líneas, casi todas de steps que salieron bien | `gh run view <id> --log-failed` |
| Relanzar después de arreglar el código | El re-run usa el mismo commit: vuelve a fallar igual | Commit y push del arreglo; eso crea un run nuevo |
| Relanzar una y otra vez un fallo determinista | Gasta minutos y no cambia nada | Relanza solo si la causa es transitoria; si no, lee el log |
| Parsear la salida en columnas de `gh run list` en un script | Las columnas cambian entre versiones de `gh` | `--json` con `--jq` |
| Mirar el `status` para decidir si algo pasó | `completed` sale también cuando falló | Mira `conclusion` |
| Usar "la última ejecución" para comprobar `main` | Puede ser de otra rama o de un commit viejo | Filtra por commit: `--commit "$(git rev-parse origin/main)"` |

## 5. Trucos

- **El run de tu último push, sin copiar ids**: `gh run watch "$(gh run list --commit "$(git
  rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')"`.
- **Abrir la ejecución en el navegador** cuando necesites la vista gráfica: `gh run view <id> --web`.
- **Ver un intento anterior**: `gh run view <id> --attempt 1` enseña el primer intento aunque lo
  hayas relanzado.
- **Buscar en el log**: `gh run view <id> --log | grep -n "error"`. Cada línea lleva el job y el
  step delante, así que el grep te dice dónde está.

Verificado con gh 2.103.3 y ubuntu-24.04, noviembre de 2026.

## 📚 Recursos Adicionales

- [Using workflow run logs](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs):
  cómo se organizan los logs en la web
- [Re-running workflows and jobs](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs):
  qué se conserva en un re-run y sus límites
- [`gh run` en el manual de gh](https://cli.github.com/manual/gh_run): todos los subcomandos y flags

## ✅ Checklist de Verificación

- [ ] Distingo run, attempt, job y step
- [ ] Sé la diferencia entre `status` y `conclusion`
- [ ] Sé qué pasa con los steps siguientes cuando uno sale con código distinto de 0
- [ ] Encuentro el log del step que falló con un solo comando
- [ ] Sé por qué relanzar no recoge un arreglo
- [ ] Lanzo un workflow a mano y encuentro su ejecución

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Eventos básicos: push, pull_request y workflow_dispatch](05-eventos-basicos.md) | [Actions de terceros y pinning por SHA](07-actions-de-terceros-y-pinning.md) |
