# Timeouts y cancelación

> Un job sin techo puede quedarse seis horas esperando a una base de datos que nunca arrancó.
> `timeout-minutes` pone ese techo, y entender qué recibe un job al cancelarse te dice qué limpieza
> llega a ejecutarse y cuál no.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Poner un techo de tiempo a un job y a un step con `timeout-minutes`
- Elegir un valor razonable a partir de la duración real de tus runs
- Explicar qué pasa paso a paso cuando un run se cancela
- Distinguir `always()`, `cancelled()` y `!cancelled()` en los steps de limpieza
- Cancelar un run desde `gh` y leer qué quedó a medias

## 1. Qué problema resuelve

El techo por defecto de un job en un runner alojado es de **360 minutos**: seis horas. Es un
límite pensado para no cortar a nadie, no para protegerte. Casos reales en los que un job se
cuelga:

- Un test espera una conexión a PostgreSQL que no llega, y el cliente no tiene timeout propio.
- Un script pide confirmación (`[y/N]`) y nadie va a teclear.
- Un `docker build` descarga de un registro que no responde.

Cada uno consume seis horas de runner, bloquea el grupo de concurrencia del archivo anterior (el
siguiente run espera como pendiente a que termine) y no te avisa hasta el final. Un job de lint
que suele tardar un minuto no tiene ninguna razón para poder durar seis horas.

Desde esta semana, la regla 8 de
[`docs/reglas-de-seguridad-de-workflows.md`](../../../docs/reglas-de-seguridad-de-workflows.md)
se aplica entera: **todo job lleva `timeout-minutes`**.

## 2. Cómo funciona

### Dos niveles

```yaml
jobs:
  test:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - name: Tests de integración
        timeout-minutes: 5
        run: ./scripts/integration.sh
```

| Nivel | Por defecto | Qué pasa al vencer |
|---|---|---|
| `jobs.<id>.timeout-minutes` | 360 | El job se cancela; los steps restantes siguen la lógica de cancelación |
| `steps[*].timeout-minutes` | Sin límite propio: el del job | El step falla; el job sigue las reglas normales de fallo |

El de step es fino: sirve para un paso concreto que puede colgarse dentro de un job que hace más
cosas. Combinado con `continue-on-error: true`, el step se corta, el job sigue y puedes subir
los logs igualmente.

### Cómo elegir el valor

Mira cuánto tardan de verdad tus runs y deja margen, del orden del doble o el triple de lo
normal:

```bash
gh run list --workflow ci-api.yml --status success --limit 20 \
  --json startedAt,updatedAt \
  --jq 'map((.updatedAt | fromdate) - (.startedAt | fromdate)) | max / 60 | ceil'
# 3
```

El run más lento de los últimos veinte tardó menos de 3 minutos: `timeout-minutes: 10` deja margen
de sobra para un día lento y corta un cuelgue en diez minutos, no en seis horas. Ajustarlo al
segundo sería un error: un runner más lento de lo normal te daría rojos falsos.

### Qué pasa al cancelar

Un run se cancela porque lo pides tú o porque `concurrency` lo sustituye. Al vencer el
`timeout-minutes` de un job pasa algo equivalente: el job se corta y los steps con `always()`
siguen corriendo. El proceso documentado de una cancelación es este:

1. **Reevalúa los `if:` de los jobs en marcha**. Un job cuyo `if:` sigue siendo verdadero tras la
   cancelación, como `if: always()`, **no se cancela**.
2. **Manda la cancelación** a los runners de los demás jobs.
3. **Reevalúa los `if:` de los steps que faltan**. Los que tienen `always()` o `cancelled()`
   corren; el resto se salta.
4. **Al step que estaba corriendo** le manda `SIGINT`. Si no termina en 7,5 segundos, `SIGTERM`; si
   sigue vivo 2,5 segundos después, mata el árbol de procesos.

El punto 4 explica un detalle de tus scripts: si capturan `SIGINT` con `trap` y limpian rápido,
llegan a limpiar. Si tardan más de diez segundos, la limpieza se corta.

### `always()`, `cancelled()` y `!cancelled()`

Los viste en la [Semana 02, teoría 03](../../week-02-expresiones_contextos_y_flujo_de_datos/1-teoria/03-condiciones-y-funciones-de-estado.md).
Con la cancelación en mente:

| Condición | Tras fallo | Tras cancelación | Uso |
|---|:--:|:--:|---|
| `success()` (por defecto) | ❌ | ❌ | Trabajo normal |
| `failure()` | ✅ | ❌ | Diagnóstico: subir logs, avisar |
| `cancelled()` | ❌ | ✅ | Anotar que se cortó |
| `!cancelled()` | ✅ | ❌ | Informes que valen aunque haya fallado algo |
| `always()` | ✅ | ✅ | Limpieza que no puede faltar |

`always()` corre incluso después de una cancelación, y eso tiene un precio: si el step que la lleva
también se cuelga, la cancelación no lo detiene hasta que venza el timeout. Úsala solo para
limpieza corta.

## 3. Cómo se usa

### Un job con techo y limpieza

```yaml
name: timeout-demo

on:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  work:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - name: Paso que se cuelga
        timeout-minutes: 1
        continue-on-error: true
        run: sleep 300

      - name: Trabajo largo
        run: sleep 300

      - name: Anotar la cancelación
        if: ${{ cancelled() }}
        run: echo "::warning::El job se canceló antes de terminar"

      - name: Limpieza corta
        if: ${{ always() }}
        run: echo "Borrando temporales"
```

Lánzalo y, cuando el primer step haya vencido, cancélalo a mano:

```bash
gh workflow run timeout-demo.yml
sleep 90
id=$(gh run list --workflow timeout-demo.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run cancel "$id"
gh run watch "$id" > /dev/null; gh run view "$id" --json jobs \
  --jq '.jobs[0].steps[] | select(.name | test("^(Anotar|Limpieza)")) | "\(.conclusion)\t\(.name)"'
# success   Anotar la cancelación
# success   Limpieza corta
```

Lo que ha pasado:

1. **Paso que se cuelga** se cortó al minuto por su `timeout-minutes`. Por `continue-on-error`,
   el job siguió; el log del step muestra el timeout.
2. **Trabajo largo** recibió `SIGINT` al cancelar y no terminó.
3. **Anotar la cancelación** corrió: `cancelled()` es verdadero.
4. **Limpieza corta** corrió: `always()`.

Sin el `timeout-minutes: 10` del job, si nadie cancelara, el techo serían 360 minutos.

### Cuando la cancelación no basta

Si un run no responde a la cancelación (un step con `always()` colgado),
`gh run cancel --force` lo corta sin esperar a los `if:`: úsalo como último recurso, porque la
limpieza no llega a correr.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Job sin `timeout-minutes` | Un cuelgue consume seis horas y bloquea el grupo de concurrencia | Techo en todo job |
| Timeout ajustado al segundo | Un runner lento da rojos falsos | Dos o tres veces la duración real |
| `if: always()` en un job entero de trabajo largo | La cancelación no lo detiene | `!cancelled()` en los informes; `always()` solo para limpieza corta |
| Limpieza que tarda minutos en un `trap` | Tras 10 segundos se mata el proceso | Limpieza rápida, o un step `always()` aparte |
| `continue-on-error` para tapar un step que se cuelga siempre | El fallo real queda en verde para siempre | Arregla la causa; `continue-on-error` solo para diagnóstico |
| `gh run cancel --force` como costumbre | Ningún step de limpieza llega a correr | `gh run cancel` y esperar |

## 5. Trucos

- **`gh run cancel --force`** se salta la reevaluación de `always()`. Es la salida cuando un run
  está atascado en un step de limpieza.
- **La duración real de tus runs con `--jq`**: `fromdate` convierte las fechas ISO de `gh` en
  segundos y la resta te da cuánto tardó cada run, sin abrir la UI.
- **`timeout-minutes` en el step de tests de integración**, no solo en el job: si el job también
  construye y sube artefactos, el techo del step te dice qué parte se colgó sin leer el log entero.

Verificado con actionlint 1.7.12 y ubuntu-24.04, noviembre 2026.

## 📚 Recursos Adicionales

- [GitHub Docs: `jobs.<job_id>.timeout-minutes`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idtimeout-minutes)
- [GitHub Docs: Workflow cancellation reference](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-cancellation)
- [GitHub Docs: Status check functions](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions#status-check-functions)

## ✅ Checklist de Verificación

- [ ] Sé el techo por defecto de un job y por qué no me vale
- [ ] Sé poner `timeout-minutes` en un job y en un step, y qué hace cada uno al vencer
- [ ] Sé calcular un valor razonable desde la duración real de mis runs
- [ ] Sé los cuatro pasos que sigue GitHub al cancelar un run
- [ ] Sé qué condición usar para limpieza, para diagnóstico y para informes
- [ ] Sé cancelar un run con `gh` y cuándo usar `--force`

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Concurrencia](06-concurrencia.md) | [github-script](08-github-script.md) |
