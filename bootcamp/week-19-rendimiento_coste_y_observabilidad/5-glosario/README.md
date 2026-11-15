# 📖 Glosario — Semana 19

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **Acierto de caché** (*cache hit*): restaurar la entrada cuya clave coincide exactamente con
  `key`. Solo entonces la salida `cache-hit` de `actions/cache` vale `true`; una restauración por
  `restore-keys` es un acierto parcial y da `false`.
- **Actions Performance Metrics**: página de Insights de la organización con tiempos de run, de
  cola y tasa de fallo por workflow y por job. Disponible en todos los planes de GitHub Cloud.
- **Actions Usage Metrics**: página de Insights con los minutos consumidos por workflow, job, sistema
  operativo y tipo de runner. Documentada para Enterprise Cloud; no aplica multiplicadores.
- **Alcance de la caché** (*cache scope*): qué refs pueden leer una entrada. Un run lee la de su ref,
  la de la rama por defecto y, en un PR, la de la base; nunca la de ramas hijas, hermanas ni otros
  tags.
- **Arranque** (de un job): todo lo que no es tu trabajo: pedir runner, preparar el job, checkout e
  instalar dependencias. Se paga en cada job, también en cada shard.

## B

- **Blob**: objeto de git con el contenido de un archivo en una versión. Es lo que más pesa de un
  clon, y `git diff --name-only` no lo necesita.
- **`blob:none`**: filtro de clon parcial que trae commits y árboles pero no blobs, salvo los del
  commit comprobado. En `tablero` lo usa solo el job `changes`, con el input `filter` de
  `actions/checkout`.

## C

- **Caché huérfana** (o sin dueño): entrada que ninguna ref que pueda leerla volverá a usar: la de
  un PR cerrado, la de una rama borrada o la de una ref temporal de la merge queue. `prune-caches.sh`
  las borra.
- **Camino crítico** (*critical path*): la cadena de jobs unidos por `needs` que más tarda de punta
  a punta, contando cola y duración. Marca el reloj del run; acortar un job fuera de él no lo baja.
- **Clave de caché** (*cache key*): nombre de una entrada de caché. Debe cambiar cuando cambia lo
  que guarda, por ejemplo con el hash del lockfile; una clave con `github.sha` crea una entrada por
  commit.
- **Clon parcial** (*partial clone*): clon que deja fuera parte de los objetos según un filtro y los
  pide al servidor bajo demanda. No es lo mismo que un clon superficial, que recorta la historia.
- **Cola** (*queue time*): tiempo entre que un job se crea (`created_at`) y que un runner lo coge
  (`started_at`). Depende de los runners libres, no de tu YAML.
- **Cupo incluido** (*included usage*): lo que cada plan incluye al mes para runners alojados en
  repos privados. Se mide en dinero, no en minutos.

## D

- **Dry-run** (modo prueba): ejecutar la limpieza diciendo qué borraría sin borrar nada. Es el valor
  por defecto de `cleanup.yml` lanzado a mano y `DRY_RUN=true` en `prune-caches.sh`.
- **Duración** (de un job): de `started_at` a `completed_at`. Es lo que se redondea para facturar.

## E

- **Expulsión** (*eviction*): borrado automático de entradas de caché. Ocurre a los 7 días sin
  acceso y, al llenarse los 10 GB del repo, por último acceso, la más antigua primero.

## I

- **Inmutable** (entrada de caché): una entrada no se sobrescribe. Si la clave ya existe, el
  guardado del final del job se omite.
- **Insights**: pestaña de la organización con las métricas de Actions. Da el panorama; los
  scripts de `ci-metrics` dan el detalle por job y el aviso.

## L

- **Línea base** (*baseline*): medida de varios runs antes de cambiar nada, con la que se compara
  cada optimización. En `tablero`, tres runs antes y tres después en el PR de la práctica 01.

## M

- **Merge ref** (`refs/pull/N/merge`): ref sobre la que corre un `pull_request`: la rama del PR
  fusionada con la base. Las cachés que guarda solo las leen los re-runs de ese PR.
- **Minuto facturable** (*billable minute*): minuto que cuenta para la factura. Cada job se redondea
  por arriba al minuto entero; en repos públicos los runners estándar no facturan.

## O

- **Observabilidad** (*observability*): poder responder, con datos guardados, por qué el CI tarda o
  falla sin tener que reproducirlo. En `tablero`, el resumen de cada run y la tendencia semanal de
  `ci-metrics`.

## P

- **p50** (mediana): la duración que deja la mitad de los runs por debajo. Lo que tarda un run
  típico.
- **p95**: la duración que deja el 95 % de los runs por debajo. Lo que tarda un run malo, pero no
  el peor; sobre él se fija el presupuesto.
- **Percentil por rango más cercano** (*nearest-rank*): ordena las n muestras y toma la de la
  posición ⌈p·n⌉. Con pocas muestras, el p95 coincide con el máximo.
- **Presupuesto** (*budget*): en billing, el límite de gasto que avisa o detiene el uso; con el
  presupuesto agotado la caché pasa a solo lectura. En `tablero`, también el p95 máximo del CI,
  guardado en `CI_P95_BUDGET_SECONDS`.

## R

- **Redondeo por job**: GitHub redondea por arriba al minuto entero los minutos de cada job por
  separado. Seis jobs de 15 s facturan seis minutos.
- **Reloj** (*wall-clock time*): del primer `created_at` al último `completed_at` de un run. Lo que
  espera quien abrió el PR.
- **`restore-keys`**: prefijos de clave que `actions/cache` prueba, en orden, si no hay coincidencia
  exacta. Restauran una caché parcial ("stale") y dejan `cache-hit` en `false`.
- **Retención** (*retention*): cuánto vive algo antes de que GitHub lo borre. Artefactos y logs:
  90 días por defecto en un repo público, 14 en `tablero`. Caché: 7 días sin acceso.
- **`run_started_at`**: inicio del intento actual de un run. Se usa en lugar de `created_at`, que un
  re-run conserva del primer intento.

## S

- **Shard**: cada parte de una suite de tests partida entre varios jobs. vitest reparte por archivos
  con `--shard <index>/<count>`.
- **Sharding**: partir una suite en shards que corren en paralelo. Baja el reloj si el trabajo
  domina sobre el arranque; si no, solo sube la factura.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Semana 20 — Capstone: un pipeline de producción defendido](../../week-20-capstone/README.md) |
