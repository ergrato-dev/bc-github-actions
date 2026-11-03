# Práctica 02 — Condiciones y estado

> En la Semana 01 viste que un step que falla deja en `skipped` todo lo que viene detrás. Esa es
> solo la regla por defecto. Con `if:` y las funciones de estado decides qué corre cuando algo
> falla, qué corre siempre y qué no corre si cancelas el run.

**Tiempo estimado**: 1,5 h

## 🎯 Qué vas a conseguir

- `conditions.yml`, un workflow de práctica que se lanza a mano
- Steps que corren según el evento y la rama
- Un step de diagnóstico con `failure()` y uno de limpieza con `always()`
- Distinguir `outcome` de `conclusion` con `continue-on-error`
- Ver un job entero en `skipped` y la diferencia entre `always()` y `!cancelled()` al cancelar

## 📋 Antes de empezar

Terminaste la [práctica 01](01-explorar-contextos.md). Como allí, `conditions.yml` solo usa
`workflow_dispatch`.

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
```

---

## Paso 1: Condiciones sobre el evento y la rama

**Por qué**: todo step lleva un `if:` implícito, `success()`: corre solo si nada falló antes. Al
escribir tu propio `if:` decides con cualquier expresión. En `if:` las llaves `${{ }}` son
opcionales; aquí se omiten salvo cuando la expresión empieza por `!` (paso 5), porque en YAML un
valor que empieza por `!` es una etiqueta y no una cadena.

**Comando**: crea `.github/workflows/conditions.yml`:

```yaml
name: conditions

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  steps-demo:
    name: Condiciones en steps
    runs-on: ubuntu-24.04
    steps:
      - name: Solo si lo lanzas a mano
        if: github.event_name == 'workflow_dispatch'
        run: echo "lanzado a mano"

      - name: Solo en main
        if: github.ref_name == 'main'
        run: echo "estás en main"

      - name: Nunca en main
        if: github.ref_name != 'main'
        run: echo "no deberías ver esto si lanzas desde main"
```

**Verifica**:

```bash
actionlint .github/workflows/conditions.yml
# (sin salida: no hay errores)
yq '[.jobs."steps-demo".steps[].if] | join(" | ")' .github/workflows/conditions.yml
# github.event_name == 'workflow_dispatch' | github.ref_name == 'main' | github.ref_name != 'main'
```

---

## Paso 2: failure() para diagnosticar, always() para limpiar

**Por qué**: cuando un step falla, los siguientes con el `if:` implícito se saltan. Un step con
`if: failure()` corre **solo** si algo falló antes: es el sitio para volcar logs o el estado que
explica el fallo. Uno con `if: always()` corre pase lo que pase: limpieza, avisos.

**Comando**: añade al final de `steps:`:

```yaml
      - name: Falla a propósito
        id: boom
        run: |
          echo "salgo con código 1"
          exit 1

      - name: Siguiente normal
        run: echo "no corre si un step anterior falló"

      - name: Diagnóstico
        if: failure()
        run: echo "algo falló antes que yo; aquí volcarías los logs que lo explican"

      - name: Limpieza
        if: always()
        run: echo "corro siempre"
```

```bash
git add .github/workflows/conditions.yml
git commit -m "ci: add conditions workflow"
git push
gh workflow run conditions.yml
sleep 5
RUN_ID=$(gh run list --workflow conditions.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status; echo "exit $?"
# ...
# exit 1
```

**Verifica**:

```bash
gh run view "$RUN_ID" --json jobs --jq '.jobs[0].steps[] | .name + ": " + .conclusion'
# Set up job: success
# Solo si lo lanzas a mano: success
# Solo en main: success
# Nunca en main: skipped
# Falla a propósito: failure
# Siguiente normal: skipped
# Diagnóstico: success
# Limpieza: success
# Complete job: success
```

El run termina en `failure`: `failure()` y `always()` deciden qué corre, no tapan el fallo.

---

## Paso 3: continue-on-error, outcome y conclusion

**Por qué**: a veces un fallo no debe tumbar el job (un aviso, una comprobación opcional). Con
`continue-on-error: true` el step falla pero el job sigue como si nada. El contexto `steps` guarda
las dos caras: `outcome` es lo que pasó **antes** de aplicar `continue-on-error` (`failure`) y
`conclusion` lo que cuenta para el job **después** (`success`).

**Comando**: en el step `boom` añade `continue-on-error: true` debajo de `id: boom`, y añade este
step justo después de él:

```yaml
      - name: Outcome frente a conclusion
        env:
          OUTCOME: ${{ steps.boom.outcome }}
          CONCLUSION: ${{ steps.boom.conclusion }}
        run: echo "outcome=$OUTCOME conclusion=$CONCLUSION"
```

```bash
git commit -am "ci(conditions): continue on error"
git push
gh workflow run conditions.yml
sleep 5
RUN_ID=$(gh run list --workflow conditions.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status; echo "exit $?"
# exit 0
```

**Verifica**:

```bash
gh run view "$RUN_ID" --log | grep 'outcome='
# ...  outcome=failure conclusion=success
gh run view "$RUN_ID" --json jobs \
  --jq '.jobs[0].steps[] | select(.name | test("normal|Diagnóstico")) | .name + ": " + .conclusion'
# Siguiente normal: success
# Diagnóstico: skipped
```

Fíjate en el cambio: ahora *Siguiente normal* corre y *Diagnóstico* se salta, porque para el job
nada ha fallado.

---

## Paso 4: if a nivel de job

**Por qué**: un `if:` en un job decide si el job entero arranca. Un job que no arranca termina en
`skipped`, no consume runner, y los jobs que lo necesitan con `needs:` también se saltan. Este
paso adelanta `needs:`, que verás a fondo en la práctica 03 y en la teoría 06.

**Comando**: añade dos jobs al final de `jobs:`:

```yaml
  only-on-push:
    name: Solo en push
    if: github.event_name == 'push'
    runs-on: ubuntu-24.04
    steps:
      - run: echo "este workflow no tiene push, así que nunca me verás"

  after-push-job:
    name: Después del job de push
    needs: only-on-push
    runs-on: ubuntu-24.04
    steps:
      - run: echo "me salto porque el job que necesito se saltó"
```

```bash
git commit -am "ci(conditions): add job level if"
git push
gh workflow run conditions.yml
sleep 5
RUN_ID=$(gh run list --workflow conditions.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status
```

**Verifica**:

```bash
gh run view "$RUN_ID" --json jobs --jq '.jobs[] | .name + ": " + .conclusion'
# Condiciones en steps: success
# Solo en push: skipped
# Después del job de push: skipped
```

---

## Paso 5: Cancelar: always() frente a !cancelled()

**Por qué**: `always()` corre **incluso si cancelas el run**. Para una limpieza eso es lo que
quieres; para un resumen o un aviso de "el CI terminó", no: si cancelas, no quieres esperar a que
termine. `!cancelled()` corre si algo falló pero se salta al cancelar. Y como empieza por `!`, va
con `${{ }}` para que YAML no lo lea como etiqueta.

**Comando**: añade un job lento al final de `jobs:`:

```yaml
  slow:
    name: Job lento
    runs-on: ubuntu-24.04
    steps:
      - name: Esperar un minuto
        run: sleep 60

      - name: Con always
        if: always()
        run: echo "corro aunque canceles"

      - name: Con not cancelled
        if: ${{ !cancelled() }}
        run: echo "me salto si cancelas"
```

> ⚠️ `gh run cancel` para el run en curso. No borra nada: el run queda en el historial como
> `cancelled`. Asegúrate de pasarle el ID de **este** run y no el de otro workflow.

```bash
git commit -am "ci(conditions): add slow job"
git push
gh workflow run conditions.yml
sleep 20   # deja que el job lento empiece el sleep
RUN_ID=$(gh run list --workflow conditions.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run view "$RUN_ID" --json status --jq .status
# in_progress
gh run cancel "$RUN_ID"
# ✓ Request to cancel workflow <run-id> submitted.
gh run watch "$RUN_ID"
```

**Verifica**:

```bash
gh run view "$RUN_ID" --json conclusion --jq .conclusion
# cancelled
gh run view "$RUN_ID" --json jobs \
  --jq '.jobs[] | select(.name == "Job lento") | .steps[] | .name + ": " + .conclusion'
# Set up job: success
# Esperar un minuto: cancelled
# Con always: success
# Con not cancelled: skipped
# Complete job: success
```

Lánzalo una vez más sin cancelar para dejar un run completo en verde: los tres steps corren y el
run termina en `success`.

---

## ✅ Resultado

- [ ] `conditions.yml` está en `main` y se ha ejecutado varias veces a mano
- [ ] Sabes que todo step lleva un `if: success()` implícito
- [ ] Has visto `failure()` para diagnosticar y `always()` para limpiar
- [ ] Sabes leer `outcome` y `conclusion` de un step con `continue-on-error`
- [ ] Has visto un job en `skipped` arrastrar a los que lo necesitan
- [ ] Sabes por qué un resumen usa `!cancelled()` y una limpieza `always()`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 02
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| actionlint: `string should not be empty` en `if: !cancelled()` | En YAML `!` abre una etiqueta y el valor queda vacío | Escribe `if: ${{ !cancelled() }}` |
| *Diagnóstico* sale `skipped` en el paso 2 | El step `boom` ya tiene `continue-on-error` | Eso es el paso 3: quítalo para repetir el paso 2 |
| *Nunca en main* sale `success` | Lanzaste el run desde otra rama con `-r` | Lánzalo sin `-r`: usa la rama por defecto |
| `gh run cancel` dice que el run ya terminó | Cancelaste después del `sleep 60` | Cancela antes: reduce el `sleep 20` previo o aumenta el del workflow |
| `Esperar un minuto: failure` en lugar de `cancelled` | La cancelación llegó como señal y el proceso salió con error | El job sigue `cancelled`; lo que cuenta es qué steps de después corrieron |
| `outcome=` sale vacío | El step que lee `steps.boom` va antes que `boom` | `steps` solo contiene los steps anteriores con `id:` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Explorar contextos](01-explorar-contextos.md) | [Outputs entre steps y jobs](03-outputs-entre-steps-y-jobs.md) |
