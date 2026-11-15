# Retención y limpieza

> Cada run deja logs, artefactos y cachés. Unos caducan solos, otros se quedan sin dueño ocupando
> sitio. Saber cuánto vive cada cosa y borrar a tiempo lo que ya no sirve es la última pieza de un
> CI que se mantiene solo.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Decir cuánto vive por defecto un artefacto, un log y una entrada de caché, y dónde se cambia
- Bajar la retención de artefactos y logs del repo por API
- Explicar qué es una caché sin dueño y por qué no basta con esperar a que caduque
- Diseñar un workflow de limpieza con un modo de prueba seguro por defecto
- Elegir los permisos mínimos y el shell correcto para un job que borra
- Borrar artefactos y logs de un run concreto sabiendo que no tiene vuelta atrás

## 1. Qué problema resuelve

Tras dieciocho semanas, `tablero` acumula cientos de runs. Cada uno guarda sus logs; muchos, sus
artefactos (`web-dist`, `dist-report`); y cada PR y cada paso por la merge queue ha dejado
entradas de caché en refs que ya no existen. Nada de eso falla, pero pesa:

- **Coste**: en un repo privado, los artefactos cuentan contra el almacenamiento del plan y el
  exceso se paga por GB-mes (archivo 01).
- **Espacio útil**: las cachés huérfanas cuentan en los 10 GB del repo y, cuando se llenan, la
  expulsión puede llevarse la de `main`, la única que comparten todos (archivo 03).
- **Exposición**: un log o un artefacto que vive 90 días es 90 días en que cualquier lector del
  repo puede descargarlo. Si un día se cuela algo sensible, menos retención es menos daño.

## 2. Cómo funciona

### Cuánto vive cada cosa

| Qué | Por defecto en un repo público | Dónde se cambia | Quién lo borra |
|---|---|---|---|
| Artefactos y logs | 90 días (máximo 90) | Ajuste del repo, por UI o API; `retention-days` por subida | GitHub, al caducar |
| Entrada de caché | 7 días sin acceso | Límite de retención de caché del repo o de la org | GitHub, al caducar o al llenarse |
| Espacio de caché | 10 GB por repo | Límite de tamaño del repo o de la org | GitHub expulsa por último acceso |

En repos privados la retención de artefactos y logs también se configura, con un máximo que
depende del plan.

Dos reglas de jerarquía:

- `retention-days` en `actions/upload-artifact` **no puede superar** la retención del repo. Si
  bajas el repo a 14 días, un artefacto con `retention-days: 30` vivirá 14.
- En la caché, un nivel inferior **nunca supera** el límite del superior: el repo no puede tener
  más retención ni más tamaño que lo que permita la org.

### Bajar la retención del repo

```bash
gh api "repos/{owner}/{repo}/actions/permissions/artifact-and-log-retention"
# {"days":90,"maximum_allowed_days":90}
gh api -X PUT "repos/{owner}/{repo}/actions/permissions/artifact-and-log-retention" -F days=14
```

`-F` envía `14` como número, no como cadena. Catorce días cubren una iteración de trabajo: el
artefacto que necesitas para depurar un fallo de esta semana sigue ahí; el de hace tres meses, no.
Lo que de verdad debe durar (una release, un SBOM) va a un sitio hecho para durar: la release
de GitHub o GHCR, como en la Semana 14.

### Cachés sin dueño

Una caché **no tiene dueño** cuando ninguna ref que la pueda leer va a volver a correr:

| Ref de la caché | Huérfana cuando... |
|---|---|
| `refs/pull/N/merge` | El PR N ya no está abierto (fusionado o cerrado) |
| `refs/heads/<rama>` | La rama ya no existe, por ejemplo tras fusionar con borrado de rama |
| `refs/heads/gh-readonly-queue/main/...` | Siempre tras salir de la cola: la ref temporal se borra |
| `refs/heads/main` | Nunca |
| `refs/tags/...` | No se toca: no es una rama de trabajo |

Esperar a que caduquen a los 7 días funciona, pero durante esos días ocupan sitio, y en una
semana de mucho movimiento pueden empujar fuera la caché de `main`. Una limpieza diaria las quita
antes de que estorben.

### El script: dos listas y un recorrido

El algoritmo cabe en pocas líneas, pero el orden importa para no hacer una llamada a la API por
cada caché:

1. Lista **una vez** las ramas que existen y los PR abiertos.
2. Recorre las cachés del repo, con su `id` y su `ref`.
3. Para cada una, decide con las dos listas si es huérfana. Si lo es, la borra por `id` o, en
   modo prueba, solo dice que la borraría.

La lista de cachés sale así:

```bash
gh cache list --limit 1000 --json id,ref --jq '.[] | "\(.id) \(.ref)"'
# 2214786 refs/heads/main
# 2213990 refs/pull/31/merge
# 2210057 refs/heads/gh-readonly-queue/main/pr-30-6f2a...
```

Borrar por `id` (`gh cache delete <id>`) quita exactamente esa entrada. Borrar por clave quitaría
todas las que comparten clave en cualquier ref, `main` incluida, salvo que filtres con `--ref`.

### El workflow: seguro por defecto según quién lo lance

`cleanup.yml` corre con dos disparadores y cada uno tiene su comportamiento seguro:

| Disparador | `inputs.dry-run` | Qué hace |
|---|---|---|
| `workflow_dispatch` | `true` por defecto | Lista lo que borraría. Para borrar, `-f dry-run=false` explícito |
| `schedule` diario | No existe: llega vacío | Borra de verdad, que es para lo que existe el cron |

El script recibe el input en `DRY_RUN` por `env:` y solo borra si no vale `true`.

Tres decisiones más del job:

- **Permisos**: `actions: write` para borrar cachés, `contents: read` para el checkout y para
  listar ramas, y `pull-requests: read` para listar los PR abiertos. Nada más.
- **`concurrency`** con el nombre del workflow y `cancel-in-progress: false`: dos limpiezas a la
  vez intentarían borrar las mismas entradas, y cancelar una a medias deja el trabajo por la mitad.
- **`shell: bash`** en `defaults`. Sin shell explícito, un step de Linux corre con `bash -e {0}`,
  sin `pipefail`. Como la salida pasa por `tee` hacia el resumen, un fallo del script quedaría
  tapado por el éxito de `tee`. Con `shell: bash` explícito, el runner usa
  `bash --noprofile --norc -eo pipefail {0}` y el fallo se ve.

_Verificado con gh 2.104.0, la API REST de Actions y ubuntu-24.04, noviembre de 2026._

## 3. Cómo se usa

### Limitar la caché por API

```bash
gh api "repos/{owner}/{repo}/actions/cache/retention-limit"
gh api "repos/{owner}/{repo}/actions/cache/storage-limit"
```

Devuelven `max_cache_retention_days` y `max_cache_size_gb`. Un `PUT` con
`-F max_cache_retention_days=<n>` acorta la vida de toda la caché del repo. En `tablero` no hace
falta: la limpieza diaria ya quita lo que sobra sin acortar la vida de la de `main`.

### Probar la limpieza

```bash
gh workflow run cleanup.yml --ref main
gh workflow run cleanup.yml --ref main -f dry-run=false
```

El primero solo lista; el segundo borra. Lee el resumen del primero antes de lanzar el segundo.

### Borrar lo de un run concreto

> ⚠️ **Destructivo y sin vuelta atrás.** Borrar los logs o los artefactos de un run no se puede
> deshacer. Antes, descarga lo que quieras conservar con `gh run download <id>` y
> `gh run view <id> --log > run.log`.

```bash
gh api "repos/{owner}/{repo}/actions/runs/$RUN_ID/artifacts" --jq '.artifacts[] | "\(.id) \(.name)"'
gh api -X DELETE "repos/{owner}/{repo}/actions/artifacts/<artifact-id>"
gh api -X DELETE "repos/{owner}/{repo}/actions/runs/$RUN_ID/logs"
```

Es lo que harías si un log mostrara algo que no debía: borrar el log y **rotar** la credencial,
porque quien lo leyó antes ya la tiene.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Dejar la retención en 90 días sin pensarlo | Más almacenamiento y más exposición sin uso | La retención que cubre tu ciclo de depuración |
| Usar artefactos para lo que debe durar | Caducan con la retención del repo | Releases o GHCR |
| `workflow_dispatch` que borra por defecto | Un clic de prueba borra de verdad | `dry-run` con `true` por defecto |
| Borrar cachés por clave sin `--ref` | Se lleva también la de `main` | Borrar por `id` |
| Consultar la API por cada caché | Cientos de llamadas y límites de tasa | Listar ramas y PR una vez |
| Pipeline con `tee` sin `pipefail` | El script falla y el step sale verde | `shell: bash` en `defaults` |
| Borrar un log con un secreto y no rotarlo | Quien lo leyó sigue teniéndolo | Rotar primero, borrar después |

## 5. Trucos

- **Cuánto ocupa lo que se puede limpiar**: `gh cache list --limit 1000 --json ref,sizeInBytes --jq 'map(select(.ref | startswith("refs/pull/"))) | (map(.sizeInBytes) | add) / 1048576 | floor'`
  te da los MiB en cachés de PR.
- **Todas las cachés de una ref de golpe**: `gh cache delete --all --ref <ref> --succeed-on-no-caches`.
- **Comprobar la retención en una línea**: `gh api "repos/{owner}/{repo}/actions/permissions/artifact-and-log-retention" --jq .days`.

## 📚 Recursos Adicionales

- [GitHub REST API: GitHub Actions permissions — artifact and log retention](https://docs.github.com/en/rest/actions/permissions)
- [GitHub REST API: GitHub Actions cache](https://docs.github.com/en/rest/actions/cache)
- [GitHub REST API: Artifacts](https://docs.github.com/en/rest/actions/artifacts)
- [GitHub Docs: Workflow syntax — defaults.run.shell](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#defaultsrunshell)

## ✅ Checklist de Verificación

- [ ] Sé cuánto viven por defecto artefactos, logs y cachés en un repo público
- [ ] Sé bajar la retención del repo por API y qué pasa con `retention-days` por encima
- [ ] Sé reconocer una caché sin dueño por su ref
- [ ] Sé por qué `cleanup.yml` lista a mano y borra en el cron
- [ ] Sé qué permisos necesita el job y por qué lleva `shell: bash`
- [ ] Sé borrar artefactos y logs de un run y por qué un secreto expuesto se rota además

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Métricas y observabilidad del CI](06-metricas-y-observabilidad.md) | [Práctica 01 — Medir la línea base](../2-practicas/01-medir-la-linea-base.md) |
