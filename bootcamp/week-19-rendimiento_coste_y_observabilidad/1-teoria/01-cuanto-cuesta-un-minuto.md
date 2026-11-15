# Cuánto cuesta un minuto

> `tablero` no te cuesta nada porque es un repo público con runners estándar. El mismo CI en un
> repo privado de empresa se paga job a job, y el redondeo hace que los jobs cortos salgan caros.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Decir qué uso de Actions no consume ni minutos ni dinero, y cuál sí aunque el repo sea público
- Explicar por qué el cupo incluido de un plan se mide en dinero y cuántos minutos de Linux da
- Calcular los minutos facturables de un run a partir de la duración de cada job
- Distinguir el almacenamiento de artefactos del de caché: cupo, precio y quién lo paga
- Estimar el coste mensual de un workflow con `gh run list` y una multiplicación
- Saber qué pasa con la caché cuando se agota un presupuesto

## 1. Qué problema resuelve

Durante dieciocho semanas no has mirado el coste, y con razón: en tu org gratuita, `tablero` es
público y corre en `ubuntu-24.04`, un runner estándar alojado por GitHub. Eso no consume nada.
Pero el día que lleves estos pipelines a un repo privado de una empresa, cada job empieza a
contar, y las decisiones que tomaste sin pensar en dinero (un job solo para imprimir datos del
runner, una matriz de dos versiones de Node, un smoke test en cada PR) pasan a tener precio.

Hay un segundo coste que existe también en repos públicos: el **tiempo de quien espera**. Un CI
de doce minutos en cada PR, con cinco personas haciendo tres PR al día, son tres horas diarias de
gente mirando un spinner. Esta semana aprendes a medir los dos, y este archivo empieza por el
que tiene factura.

## 2. Cómo funciona

### Lo que no consume

| Uso | ¿Consume minutos? | Por qué |
|---|:--:|---|
| Runners estándar alojados en un repo **público** | No | GitHub lo regala para código abierto |
| Runners propios (S15, S16), en cualquier repo | No | La máquina la pagas tú |
| GitHub Pages y Dependabot | No | Excluidos explícitamente |
| Runners grandes (*larger runners*) | **Sí, también en públicos** | No son estándar: se facturan siempre |
| Runners estándar en un repo **privado** | Sí | Contra el cupo del plan y, después, contra tu tarjeta |

Fíjate en la cuarta fila: si un día cambias `runs-on` a una etiqueta de runner grande para ir más
rápido, `tablero` deja de ser gratis aunque siga siendo público.

### El cupo se mide en dinero

El plan no te da "2000 minutos": te da un saldo mensual en dólares que se gasta a precio de cada
tipo de runner.

| Plan | Cupo mensual de Actions | Equivale a, en Linux estándar de 2 núcleos |
|---|:--:|:--:|
| Free | 12 USD | 2000 min |
| Team | 18 USD | 3000 min |

El Linux estándar de 2 núcleos x64 (SKU `actions_linux`) cuesta **0,006 USD por minuto** desde
el 1 de enero de 2026; antes costaba 0,008. Windows, macOS y los runners grandes tienen su propio
precio por minuto, más alto: consúltalo en la tabla de precios antes de cambiar de sistema.

Medirlo en dinero tiene una consecuencia práctica: un minuto de macOS se come el saldo mucho más
deprisa que uno de Linux, y el cupo te dura según la mezcla de runners que uses, no según un
número fijo de minutos.

### El redondeo es por job

La frase de la documentación que más importa esta semana: "GitHub rounds the minutes and partial
minutes each job uses up to the nearest whole minute". **Cada job** se redondea por arriba al
minuto, por separado:

| Run | Duración de cada job | Reloj aproximado | Minutos facturables |
|---|---|:--:|:--:|
| A: un job | 1 × 110 s | ~2 min | 2 |
| B: seis jobs en paralelo | 6 × 15 s | ~30 s | **6** |
| C: dos jobs de 61 s | 2 × 61 s | ~1 min | **4** |

El run B termina antes que el A y cuesta el triple. Un job de 15 segundos paga lo mismo que uno
de 60, y uno de 61 paga dos. Por eso **los jobs cortos son los más caros por segundo útil**, y
por eso el primer cambio de esta semana es borrar `runner-info`: un job que solo imprimía
`/etc/os-release`, `nproc` y `free -h`, que ningún otro job necesitaba y que pagaba un minuto
entero en cada run.

Dos casos que no facturan nada, porque no ocupan runner:

- Un job **saltado** por su `if:`. No llega a pedir máquina.
- Un job que solo **llama a un reutilizable** (`uses:` a nivel de job). Facturan los jobs de
  dentro del reutilizable, cada uno con su redondeo.

### Almacenamiento: dos bolsas distintas

| Qué | Cupo incluido | Exceso | Detalle |
|---|---|---|---|
| Artefactos (compartido con GitHub Packages) | Free 500 MB · Team 2 GB | 0,25 USD por GB-mes | Se mide en GB-hora: un artefacto pesado que vive un día pesa poco en la factura |
| Caché de Actions | 10 GB por repo | 0,07 USD por GB-mes | Solo si alguien sube el límite del repo por encima de 10 GB |

La caché no compite con los artefactos: es otra bolsa, por repo, y mientras no subas su límite
nunca genera cargo. Al llenarse, GitHub expulsa entradas (archivo 03); no te cobra.

### Presupuestos

Una org o una cuenta puede fijar un **presupuesto** para Actions. Qué se bloquea al agotarlo
depende de cómo lo configures, pero hay un efecto que conviene conocer: con el presupuesto
agotado, **la caché pasa a solo lectura**. Los jobs siguen restaurando lo que ya había, pero
nada nuevo se guarda, y un cambio de `uv.lock` deja de cachearse sin ningún error visible.

### Los precios cambian

En diciembre de 2025 GitHub anunció un cargo de 0,002 USD por minuto para runners propios en
repos privados, con fecha de 1 de marzo de 2026. Lo aplazó a los dos días y no está en vigor.
La lección no es la cifra: es que **una tabla de precios copiada en un documento caduca**.
Cuando estimes un coste, enlaza la página oficial y anota la fecha en que la miraste.

_Verificado con la documentación de facturación de GitHub Actions y ubuntu-24.04, noviembre de 2026._

## 3. Cómo se usa

### Cuántos runs hay que pagar

El coste de un workflow al mes es una multiplicación: runs al mes × minutos facturables por run
× precio por minuto. El primer factor sale de `gh run list`:

```bash
gh run list --workflow ci.yml --created '>=2026-10-01' --limit 1000 --json databaseId --jq length
# 87
```

`--created` acepta la sintaxis de fechas de la búsqueda de GitHub (`>=`, rangos con `..`).
`--limit 1000` evita que te quedes en los 20 runs que trae por defecto.

### Cuántos minutos factura un run

El endpoint `timing` de un run te da el reloj y, en un repo privado, lo facturable:

```bash
gh api "repos/{owner}/{repo}/actions/runs/$RUN_ID/timing"
# {"billable":{"UBUNTU":{"total_ms":0,"jobs":1,"job_runs":[...]}},"run_duration_ms":84000}
```

En `tablero`, público, `total_ms` vale 0: es la prueba de que no pagas. Para saber cuánto
pagaría el mismo run en privado, necesitas la duración de **cada job** y redondearla tú. Esa
cuenta es la que hace `scripts/job-timings.sh` en la práctica 01, a partir de la API de jobs que
ves en el archivo 02.

### La estimación

Con 87 runs al mes y un run típico de 14 minutos facturables (valores de ejemplo):

| Concepto | Cálculo | Resultado |
|---|---|:--:|
| Minutos al mes | 87 × 14 | 1218 |
| Coste en Linux estándar | 1218 × 0,006 USD | 7,31 USD |
| Fracción del cupo Free | 7,31 / 12 | 61 % |

Si quitas un job de 20 segundos que corre en cada run, ahorras 87 minutos al mes: un 7 % de la
factura con un cambio de cinco líneas. Ese es el tipo de decisión que vas a tomar con datos.

### Antes de recortar por dinero

Tres preguntas, en este orden:

1. **¿Este job aporta algo que otro no aporte?** Si nadie lee su salida ni depende de él, sobra.
2. **¿Corre cuando no hace falta?** Un `if:` a nivel de job, o el `changes` de la Semana 18,
   lo salta sin coste.
3. **¿Es corto y está solo?** Un job de 20 segundos paga un minuto; si comparte runner con otro
   trabajo del mismo run, deja de pagarlo aparte.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Medir el coste por el reloj del run | Seis jobs paralelos de 15 s duran medio minuto y facturan seis | Sumar cada job redondeado por arriba |
| Partir un job en muchos jobs pequeños "para que sea más rápido" | Cada uno paga su minuto redondeado y su arranque | Partir solo si el trabajo de cada parte supera con creces el minuto |
| Cambiar a un runner grande en un repo público sin mirar | Los runners grandes se facturan también en públicos | Medir primero si el cuello es la CPU |
| Copiar la tabla de precios en la documentación del equipo | Los precios cambian y la copia no avisa | Enlazar la página oficial con la fecha de consulta |
| Ignorar el presupuesto agotado | La caché pasa a solo lectura y el CI se vuelve lento sin error | Alertas de presupuesto y revisar la caché si el CI se ralentiza de golpe |

## 5. Trucos

- **¿Este run me costaría algo?** En un repo privado,
  `gh api "repos/{owner}/{repo}/actions/runs/$RUN_ID/timing" --jq '.billable | map_values(.total_ms / 60000)'`
  te da los milisegundos facturables de cada sistema operativo pasados a minutos.
- **Runs de un mes completo**: `--created '2026-10-01..2026-10-31'` en `gh run list` cierra el
  rango por los dos lados.
- **Jobs saltados, gratis**: un `if:` en el job no factura; un `if:` en cada step sí, porque el
  job ya ocupó el runner. Si todos los steps de un job comparten condición, súbela al job.

## 📚 Recursos Adicionales

- [GitHub Docs: GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
- [GitHub Docs: Actions runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing)
- [GitHub REST API: Get workflow run usage](https://docs.github.com/en/rest/actions/workflow-runs#get-workflow-run-usage)
- [GitHub CLI: gh run list](https://cli.github.com/manual/gh_run_list)

## ✅ Checklist de Verificación

- [ ] Sé qué uso de Actions es gratis y qué runner se factura aunque el repo sea público
- [ ] Sé por qué el cupo de un plan se mide en dólares y no en minutos
- [ ] Sé calcular los minutos facturables de un run sumando cada job redondeado
- [ ] Sé por qué un job saltado o un job que llama a un reutilizable no factura por sí mismo
- [ ] Sé qué cupo y qué precio tienen los artefactos y la caché
- [ ] Sé qué le pasa a la caché cuando se agota el presupuesto

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Semana 19 — Rendimiento, coste y observabilidad](../README.md) | [Anatomía del tiempo de un run](02-anatomia-del-tiempo-de-un-run.md) |
