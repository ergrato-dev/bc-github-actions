# Estrategia de pruebas de workflows

> Ya tienes cuatro formas de probar un workflow: linters, act, una rama de prueba y
> `workflow_dispatch`. Cada una caza cosas distintas a un coste distinto. La estrategia es saber
> cuál usar primero y cuándo pasar a la siguiente.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Ordenar las capas de prueba por coste y por lo que cazan
- Elegir la capa adecuada para cada tipo de cambio en un workflow
- Probar en el runner real sin ensuciar `main` ni el historial
- Saber qué necesita `workflow_dispatch` para lanzarse desde una rama
- Provocar el fallo a propósito para comprobar que la puerta funciona

## 1. Qué problema resuelve

Sin estrategia, todo cambio en un workflow se prueba igual: push a la rama del PR y esperar. Es
lo más caro y lo más lento, y tampoco lo prueba todo: un job que solo corre en `push` a `main` o
en un `schedule` no se ejecuta nunca en tu PR. Te enteras al fusionar.

En el otro extremo, quien descubre act quiere probarlo todo en local y se fía de un verde que no
comprueba permisos, concurrencia ni timeouts.

Cada capa responde a una pregunta distinta. Ponerlas en orden evita las dos trampas.

## 2. Cómo funciona

### Cuatro capas, de barata a cara

| Capa | Cuánto tarda | Dónde | Qué responde |
|---|---|---|---|
| actionlint | Segundos | Tu máquina y CI | ¿Está bien escrito? Sintaxis, expresiones, contextos, shell |
| zizmor | Segundos | Tu máquina y CI | ¿Es seguro? Inyección, credenciales, permisos, fijado |
| act | Un minuto o dos | Tu Docker | ¿Hacen los scripts lo que creo? Comandos, `if:`, outputs, caché |
| Runner real | Minutos | GitHub | ¿Funciona de verdad? Permisos, eventos, servicios, anotaciones, concurrencia |

Las dos primeras no ejecutan nada: leen el YAML. Por eso son baratas y por eso no ven la lógica.
act ejecuta, pero en una imitación. Solo el runner real da la respuesta final.

### Qué capa caza cada error

| Error | actionlint | zizmor | act | Runner real |
|---|:--:|:--:|:--:|:--:|
| Clave mal escrita, `needs:` a un job que no existe | ✅ | | ✅ | ✅ |
| `${{ github.event.* }}` dentro de `run:` | ✅ | ✅ | | |
| `persist-credentials` sin desactivar | | ✅ | | |
| Un comando de shell que falla | Parcial (shellcheck) | | ✅ | ✅ |
| Un `if:` que nunca se cumple | | | ✅ | ✅ |
| Un permiso que falta en `permissions:` | | | | ✅ |
| Un filtro de rutas que no casa | | | | ✅ |
| Un service container que no arranca | | | | ✅ |
| Un `timeout-minutes` demasiado corto | | | | ✅ |

Fíjate en las dos últimas columnas: lo que solo ve el runner real es justo lo que depende de
GitHub como plataforma. Y la columna de seguridad es casi solo de zizmor: un workflow puede
funcionar perfectamente y ser inseguro.

### La rama de prueba

Para el runner real no hace falta tocar `main`. Una rama propia con un PR en borrador dispara
todo lo que escuche `pull_request`, y lo que dispare `push` en cualquier rama. Lo que no dispara:

- Workflows con `push: branches: [main]`: solo corren al fusionar.
- `schedule`: solo corre desde la rama por defecto.
- `workflow_dispatch`: el workflow tiene que existir **en la rama por defecto** para poder
  lanzarlo. Una vez existe allí, puedes lanzarlo contra cualquier rama con `--ref`, y corre con
  el YAML de esa rama.

La consecuencia práctica: todo workflow que no corra en los PR necesita `workflow_dispatch`. En
`tablero` ya lo tienen todos desde la Semana 07: un cambio en `nightly.yml` lo pruebas desde tu
rama sin fusionar y sin esperar al cron.

### Qué capa para qué cambio

| Cambias... | Mínimo antes de pedir revisión |
|---|---|
| Un comentario, un `name:` | actionlint |
| Una versión de action (SHA nuevo) | actionlint y zizmor; el runner real en el PR |
| Un script de `run:` | Linters y act sobre ese job |
| Un `if:`, una matriz, un `needs:` | Linters y act con `-l` y el job afectado |
| `permissions:`, `on:`, filtros, `concurrency` | Linters y el runner real: act los ignora |
| Un job con `services:` o con efectos fuera | Linters y el runner real en una rama |


## 3. Cómo se usa

### El circuito de un cambio en un workflow

```bash
# 1. Antes de comitear, los dos linters en local (segundos)
actionlint && zizmor --offline .github/workflows/

# 2. Si el cambio toca la lógica de un job, act sobre ese job (un minuto)
./scripts/ci-local.sh ci-api lint

# 3. Rama y PR en borrador: el runner real con todo lo que act no imita
git switch -c ci/ruff-format-check
git commit -am "ci(api): check ruff format"
git push -u origin ci/ruff-format-check
gh pr create --draft --fill

# 4. Un workflow que no corre en PR: lánzalo contra tu rama
gh workflow run nightly.yml --ref ci/ruff-format-check
gh run list --workflow nightly.yml --branch ci/ruff-format-check --limit 1
```

El orden importa: cada capa que pasa ahorra un intento de la siguiente, más cara. Y en el paso 3
`lint-workflows.yml` repite el paso 1 por ti, así que nadie puede saltárselo.

### Sin ensuciar el historial

Los intentos de una rama de prueba acaban en `main` solo si los fusionas así. Al terminar:

```bash
# Un solo commit limpio en el PR
gh pr merge --squash --delete-branch
```

Con squash, los cinco `fix ci` del PR se convierten en un commit en `main` con el título del PR.
Para experimentos que no vas a fusionar nunca, cierra el PR y borra la rama (asegúrate antes de
que no queda en ella nada que quieras conservar):

```bash
gh pr close --delete-branch
```

Un repo de juguete en tu organización es la otra opción para lo que tiene efectos (crear
releases, publicar imágenes): ahí puedes romper sin miedo. En `tablero`, los efectos de verdad
solo ocurren desde `main`.

### Probar que la puerta falla

Una puerta que nunca has visto en rojo no está probada. Para cada comprobación nueva, provoca el
fallo a propósito en una rama:

| Puerta | Cómo provocar el rojo |
|---|---|
| actionlint | Un permiso mal escrito (`content: read`) |
| zizmor | Un `run:` con `${{ github.event.head_commit.message }}` |
| Filtro de rutas | Un PR que no toque las rutas: el workflow no debe aparecer |
| Un test de `ci-api` | Un `assert` que falle |

Si el PR no se pone en rojo, la puerta no protege nada. La práctica 02 de esta semana hace
exactamente esto con `lint-workflows.yml`, y el check `lint-caught-a-pr` comprueba que pasó.

### Depurar en el runner real

Cuando el fallo solo aparece en GitHub, el circuito es el de esta semana completo:

1. Lee el run en orden (archivo 01): anotación, job, step, primer error.
2. Si no basta, `gh run rerun <id> --failed --debug` (archivo 03).
3. Si el problema es tu script, añade `::group::` y `::debug::` (archivo 02): se quedan, no
   molestan y estarán ahí la próxima vez.
4. Si necesitas probar hipótesis, vuelve a act o a la rama de prueba, nunca a `main`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Probar cambios de workflow con push a `main` | Cada intento queda en el historial y puede publicar algo | Rama y PR en borrador |
| Saltarse los linters "porque es un cambio pequeño" | Un minuto de runner por una comilla | `actionlint && zizmor` antes de cada commit |
| Dar por probado lo que pasó en act | No ve permisos, filtros, servicios ni timeouts | act para la lógica, el runner real para lo demás |
| Workflow solo con `schedule` | No hay forma de probarlo sin esperar al cron | Añadir `workflow_dispatch` |
| Fusionar con merge normal una rama de intentos | `main` hereda todos los `fix ci` | `--squash` |
| Una puerta que nunca se vio en rojo | No sabes si protege | Provocar el fallo una vez a propósito |

## 5. Trucos

- **`gh workflow run <wf> --ref <rama>`** seguido de **`gh run watch`** es el ciclo más corto en
  el runner real para un workflow con `workflow_dispatch`.
- **`gh pr create --draft`** dispara los mismos workflows que un PR normal, pero avisa a los
  revisores de que no es para mirar todavía.
- **`git commit --allow-empty -m "ci: retry"`** fuerza un run nuevo con un commit vacío cuando
  quieres un push y no un reintento; con squash no deja rastro en `main`.
- **Un alias** como `alias wflint='actionlint && zizmor --offline .github/workflows/'` hace que
  la capa más barata sea también la más cómoda.

Verificado con actionlint 1.7.12, zizmor 1.31.1, act 0.2.94 y ubuntu-24.04, noviembre 2026.

## 📚 Recursos Adicionales

- [GitHub Docs: Manually running a workflow](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
- [GitHub Docs: Events that trigger workflows, `schedule`](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)
- [GitHub CLI: `gh workflow run`](https://cli.github.com/manual/gh_workflow_run)

## ✅ Checklist de Verificación

- [ ] Sé ordenar las cuatro capas por coste y por lo que cazan
- [ ] Sé qué errores solo ve el runner real
- [ ] Sé probar en el runner real desde una rama sin tocar `main`
- [ ] Sé qué necesita `workflow_dispatch` para lanzarse contra mi rama
- [ ] Sé cerrar una rama de intentos sin ensuciar el historial
- [ ] Sé provocar el rojo de una puerta para comprobar que protege

---

| ← Anterior | Siguiente → |
|:---|---:|
| [act](06-act.md) | [Depurar un run que falla](../2-practicas/01-depurar-un-run-que-falla.md) |
