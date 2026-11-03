# Eventos básicos: push, pull_request y workflow_dispatch

> Un workflow no corre "cuando subes código": corre cuando GitHub emite un evento que su `on:`
> escucha. Cada evento decide qué commit se ejecuta, y confundirlos es la causa de la mitad de los
> "en mi PR pasaba".

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Elegir entre `push`, `pull_request` y `workflow_dispatch` según lo que quieres comprobar
- Decir qué commit (`GITHUB_SHA`) y qué ref (`GITHUB_REF`) recibe el runner con cada evento
- Explicar por qué un `pull_request` prueba un commit que no existe en ninguna rama
- Limitar `push` a la rama `main` y saber dónde están los filtros completos
- Saber qué cambia cuando el pull request viene de un fork, y qué ajuste te protege

## 1. Qué problema resuelve

Sin eventos tendrías dos opciones malas: lanzar el CI a mano después de cada cambio (y olvidarte),
o lanzarlo con cada cosa que pasa en el repo (y gastar minutos en una etiqueta nueva o un
comentario). El bloque `on:` resuelve las dos: **dice exactamente qué actividad del repo crea una
ejecución**.

En `tablero` quieres tres cosas distintas, y cada una es un evento:

| Quieres | Evento |
|---|---|
| Saber que `main` está sana después de cada merge | `push` a `main` |
| Saber **antes** del merge que el cambio no rompe `main` | `pull_request` |
| Relanzar el CI cuando tú quieras, sin commit nuevo | `workflow_dispatch` |

GitHub tiene más de treinta eventos (`schedule`, `release`, `issues`, `workflow_run`...). Esta
semana solo necesitas estos tres. Los filtros avanzados, el cron y el encadenamiento llegan en la
Semana 07; `pull_request_target`, en la 12.

## 2. Cómo funciona

### Qué commit recibe el runner

Cada evento fija dos variables que el runner exporta a todos los steps: `GITHUB_SHA` (el commit
que se descarga y se ejecuta) y `GITHUB_REF` (la referencia de git asociada). El archivo del
workflow también se lee de ese commit.

| Evento | `GITHUB_SHA` | `GITHUB_REF` |
|---|---|---|
| `push` | El último commit empujado a la ref | La ref actualizada: `refs/heads/main` |
| `pull_request` | El último **merge commit** de la ref de merge | `refs/pull/<número>/merge` |
| `workflow_dispatch` | El último commit de la rama o tag elegido | La rama o tag elegido |

La fila de `pull_request` es la que sorprende. GitHub no prueba la punta de tu rama: crea un
commit de merge **temporal** que une tu rama con la base (normalmente `main`) y prueba ese. Es lo
correcto, porque lo que importa es cómo quedará `main` si fusionas, pero tiene dos consecuencias:

- El SHA de la ejecución **no** es el último commit de tu rama. Si buscas la ejecución por el SHA
  de tu commit (`gh run list --commit`), no la encuentras con ese SHA.
- Si la rama tiene **conflictos de merge** con la base, ese commit no se puede crear y el workflow
  de `pull_request` **no se ejecuta**. No sale rojo: simplemente no aparece.

### Tipos de actividad de `pull_request`

Un pull request tiene muchas actividades: se abre, se le suben commits, se etiqueta, se edita el
título, se cierra... Con `pull_request:` a secas solo corren tres:

| Tipo | Cuándo |
|---|---|
| `opened` | Se abre el PR |
| `synchronize` | Se suben commits nuevos a la rama del PR |
| `reopened` | Se reabre un PR cerrado |

Cambiar el título o añadir una etiqueta no relanza el CI. Es lo que quieres casi siempre. Elegir
otros tipos con `types:` se ve en la Semana 07.

### `workflow_dispatch` y la rama por defecto

`workflow_dispatch` crea una ejecución a mano: con el botón **Run workflow** de la pestaña
Actions, con `gh workflow run` o con la API. Tiene una condición que despista el primer día:

> **El evento solo existe si el archivo del workflow está en la rama por defecto.** Mientras
> `hello.yml` viva solo en una rama de trabajo, no hay botón y `gh workflow run` falla.

Una vez que el workflow está en `main` y ha corrido al menos una vez, puedes lanzarlo contra
cualquier rama o tag con la API o con `gh workflow run --ref <rama>`. `workflow_dispatch` acepta
además `inputs:` (parámetros que escribe quien lo lanza). Los usarás en la Semana 02 y los verás a
fondo en la 07.

### Pull requests desde forks

En un repo público cualquiera puede hacer un fork y abrirte un pull request. Ese PR ejecuta
**su** código en **tus** runners. GitHub lo limita así:

- El `GITHUB_TOKEN` es de **solo lectura**, aunque tu workflow pida más.
- **No se pasa ningún secreto** al runner, salvo el propio `GITHUB_TOKEN`.
- Según la política del repo, la ejecución **espera a que la apruebes** antes de empezar.

La política tiene tres niveles: aprobar solo a quien es nuevo en GitHub, a quien contribuye por
primera vez al repo, o a **todos los colaboradores externos**. En `tablero` eliges el último en la
[práctica 01, paso 5](../2-practicas/01-organizacion-y-repo-tablero.md): un PR de un desconocido
no gasta minutos ni toca nada hasta que tú lo miras. Los pull requests de Dependabot tienen las
mismas restricciones que los de un fork.

## 3. Cómo se usa

### Los tres eventos juntos

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  show-event:
    runs-on: ubuntu-24.04
    steps:
      - name: Qué evento y qué commit
        run: |
          echo "evento: $GITHUB_EVENT_NAME"
          echo "ref:    $GITHUB_REF"
          echo "sha:    $GITHUB_SHA"
```

Fíjate en tres detalles:

- `pull_request:` y `workflow_dispatch:` van **vacíos**. Un mapa vacío en YAML significa "este
  evento, con su configuración por defecto".
- `branches: [main]` en `push` evita que cada rama de trabajo lance el CI dos veces: una por el
  `push` y otra por el `pull_request`. La rama ya se prueba en su PR; `main` se prueba al fusionar.
- Las variables `GITHUB_*` se leen como cualquier variable de entorno del shell. En la Semana 02
  verás la otra forma, los contextos, y cuándo usar cada una.

### Lo que verás en cada caso

Con el workflow anterior en `main`, el step imprime algo así:

```text
# push a main
evento: push
ref:    refs/heads/main
sha:    <SHA del commit que empujaste>

# pull request número 3
evento: pull_request
ref:    refs/pull/3/merge
sha:    <SHA de un merge commit que no está en ninguna rama>

# gh workflow run ci.yml
evento: workflow_dispatch
ref:    refs/heads/main
sha:    <SHA de la punta de main>
```

### Ignorar un commit concreto

Para un commit que no necesita CI (un typo en el README), basta con poner `[skip ci]` en el
mensaje. GitHub también acepta `[ci skip]`, `[no ci]`, `[skip actions]` y `[actions skip]`. Solo
afecta a `push` y `pull_request`, y solo a las ejecuciones de ese commit.

```bash
git commit -m "docs: fix typo in README [skip ci]"
```

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `on: push` sin `branches` junto con `pull_request` | Cada commit de una rama con PR ejecuta el CI dos veces: el doble de minutos y de ruido | `push` solo a `main`; las ramas se prueban por su PR |
| Esperar que `workflow_dispatch` aparezca en una rama de trabajo | No hay botón ni `gh workflow run` hasta que el archivo está en la rama por defecto | Fusiona primero el workflow en `main` |
| Buscar la ejecución de un PR por el SHA de tu último commit | El PR ejecuta un merge commit con otro SHA | Busca por rama o por evento: `gh run list --branch <rama> --event pull_request` |
| Pensar que un PR con conflictos "pasó" porque no sale rojo | Con conflictos, `pull_request` no se ejecuta | Resuelve el conflicto; el check vuelve a aparecer |
| `[skip ci]` en un commit que cambia código | Ese commit llega a `main` sin probar | Úsalo solo en cambios que no tocan nada que se ejecute |
| Aprobar a ciegas los workflows de un fork | El PR ejecuta código de un desconocido en tus runners | Lee el diff, sobre todo `.github/workflows/`, antes de aprobar |

## 5. Trucos

- **Ver qué evento lanzó cada ejecución**: `gh run list --json event,headBranch,headSha --jq
  '.[] | [.event, .headBranch, .headSha[0:7]] | @tsv'`. Es la forma rápida de ver que un mismo
  commit tiene una ejecución de `push` y otra de `pull_request`.
- **Ver el merge commit que prueba un PR**: `git fetch origin refs/pull/3/merge && git log -1
  FETCH_HEAD` descarga la misma ref que usa el runner. Si el CI falla en el PR y no en tu rama,
  aquí está la diferencia.
- **Lanzar contra otra rama**: `gh workflow run ci.yml --ref mi-rama`, siempre que el workflow
  ya exista en `main` y en `mi-rama`.
- **Más de tres tags a la vez no crean eventos**: si empujas `--tags` con muchos tags, no esperes
  una ejecución por tag.

Verificado con `actions/checkout@v7.0.1` y ubuntu-24.04, noviembre de 2026.

## 📚 Recursos Adicionales

- [Events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows):
  la tabla de `GITHUB_SHA` y `GITHUB_REF` de cada evento
- [Skipping workflow runs](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs):
  las cadenas de `[skip ci]` y sus límites
- [Approving workflow runs from forks](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/approve-runs-from-forks):
  qué significa cada nivel de aprobación

## ✅ Checklist de Verificación

- [ ] Sé qué `GITHUB_SHA` recibe el runner en `push`, `pull_request` y `workflow_dispatch`
- [ ] Puedo explicar qué es `refs/pull/<número>/merge` y por qué existe
- [ ] Sé por qué un PR con conflictos no muestra el CI
- [ ] Sé qué tres tipos de actividad de `pull_request` corren por defecto
- [ ] Sé por qué `workflow_dispatch` no aparece hasta que el archivo está en `main`
- [ ] Puedo decir qué restricciones tiene un PR que viene de un fork

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Runners alojados por GitHub](04-runners-alojados.md) | [Leer una ejecución](06-leer-una-ejecucion.md) |
