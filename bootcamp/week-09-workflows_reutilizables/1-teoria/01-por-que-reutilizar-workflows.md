# Por qué reutilizar workflows

> Copiar un job funciona hasta el día en que tienes que cambiarlo en seis sitios. Un workflow
> reutilizable es un workflow que otros llaman como una función: escribes los jobs una vez y cada
> llamador decide solo cuándo corren y con qué datos.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Medir cuánto se repite el CI de `tablero` en la capa 08 y qué cuesta esa repetición
- Explicar el modelo llamador-llamado: quién decide qué, y dónde se ejecuta cada job
- Distinguir un workflow reutilizable de una action propia (Semana 10) y de una plantilla de
  workflow de la organización (Semana 11)
- Decidir qué jobs se extraen a un reutilizable y cuáles se quedan en el llamador

## 1. Qué problema resuelve

Abre los workflows de `tablero` tal como quedaron en la Semana 08 y cuenta:

```bash
git grep -c 'astral-sh/setup-uv@' .github/workflows/ci-api.yml
# .github/workflows/ci-api.yml:3
git grep -c 'pnpm install --frozen-lockfile' .github/workflows/ci-web.yml
# .github/workflows/ci-web.yml:3
wc -l .github/workflows/ci-api.yml .github/workflows/ci-web.yml
#  113 .github/workflows/ci-api.yml
#  123 .github/workflows/ci-web.yml
```

Los tres jobs de `ci-api` (lint, tests unitarios e integración) empiezan igual: `checkout` sin
credenciales, `setup-uv` con la versión fijada y la caché apuntando a `api/uv.lock`, y
`uv sync --locked`. Los tres de `ci-web` repiten `checkout`, `pnpm/action-setup`, `setup-node`
con caché de pnpm y `pnpm install --frozen-lockfile`. Funciona. El problema llega con el tiempo:

- **Cada cambio se hace N veces.** Subir `setup-uv` a un SHA nuevo son tres ediciones en
  `ci-api.yml`. Si mañana `tablero` gana un segundo servicio Python (un `worker`, por ejemplo),
  copias 113 líneas y ya son seis.
- **Las copias divergen.** Un día alguien quita `--locked` en un job para salir de un apuro y no
  en los otros. El CI sigue verde y ya no prueba lo mismo en todas partes. Nadie lo ve en la
  revisión porque el diff solo enseña una de las copias.
- **El "cuándo" y el "cómo" están mezclados.** `ci-api.yml` decide a la vez los eventos, los
  `paths` y la `concurrency` (cuándo corre) y los pasos para probar un proyecto uv (cómo se
  prueba). Son decisiones de naturaleza distinta y cambian por motivos distintos.

Un workflow reutilizable separa las dos cosas. El "cómo" vive en un archivo que no se dispara
solo; el "cuándo" vive en un archivo pequeño que lo llama.

## 2. Cómo funciona

### Dos papeles: llamador y llamado

- **El llamado** (el reutilizable) es un workflow normal, en `.github/workflows/`, cuyo
  disparador es `on: workflow_call`. Declara qué datos acepta (inputs y secretos), qué devuelve
  (outputs) y contiene jobs completos con su `runs-on`, sus `steps` y sus `services`.
- **El llamador** es cualquier workflow con un job que, en lugar de `runs-on` y `steps`, tiene
  `uses:` apuntando al archivo del reutilizable, y `with:` con los valores de sus inputs.

```yaml
jobs:
  api:
    name: API
    uses: ./.github/workflows/_python.yml # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
    with:
      working-directory: api
      package: tablero
```

El archivo 02 explica cada pieza de ese job. Lo importante ahora es qué pasa en tiempo de
ejecución.

### Un solo run

Cuando `ci-api` se dispara, GitHub lee el job `api`, ve el `uses:`, abre `_python.yml` y
**expande sus jobs dentro del mismo run**. No hay un segundo run para el reutilizable: hay uno,
con un evento, un `GITHUB_TOKEN` y un contexto `github`, los del llamador (archivo 05). Cada job
del reutilizable corre en su propio runner, igual que si lo hubieras escrito en `ci-api.yml`.

En la UI y en `gh run view`, esos jobs llevan el nombre del job que llama delante:

```bash
gh run view <run-id> --json jobs --jq '.jobs[].name'
# API / Lint y formato (ruff)
# API / Tests unitarios
# API / Tests de integración (PostgreSQL 17)
```

### Quién decide qué

| Decisión | Dónde vive | En `tablero` |
|---|---|---|
| Eventos, ramas, `paths` | Llamador | `ci-api.yml`: push a `main`, PR y `workflow_dispatch` sobre `api/**` |
| `concurrency` del workflow | Llamador | Un run por workflow y ref |
| Techo de permisos del `GITHUB_TOKEN` | Llamador | `contents: read` en la raíz |
| Valores concretos | Llamador, por `with:` | `working-directory: api`, `package: tablero` |
| `runs-on`, `steps`, `services`, `timeout-minutes` | Reutilizable | `_python.yml` |
| Qué devuelve | Reutilizable, por `outputs:` | `_node.yml` devuelve `artifact-name` |

La regla práctica: el reutilizable no sabe quién lo llama ni por qué. Si un dato depende del
llamador (la carpeta, la cobertura mínima, si se publica la imagen), entra como input.

### Reutilizable, action propia o plantilla

Hay tres formas de no repetirte en Actions y resuelven problemas distintos:

| | Workflow reutilizable | Action propia (Semana 10) | Plantilla de workflow (Semana 11) |
|---|---|---|---|
| Qué empaqueta | Jobs completos | Steps dentro de un job | Un archivo que se copia |
| Elige el runner | Sí, cada job el suyo | No: corre en el job que la usa | Sí, la copia |
| `services`, matrices, `needs` | Sí | No | Sí |
| Un cambio llega a los usuarios | Sí, al mover la referencia | Sí, al mover la referencia | No: la copia ya diverge |
| Cómo se ve en el log | Jobs con prefijo `API / ...` | Un step | Como cualquier workflow |

`_python.yml` necesita tres jobs, uno con un PostgreSQL de servicio y uno que espera a otro: eso
es un reutilizable. "Preparar uv y sincronizar dependencias", que se repite *dentro* de cada job,
es un candidato a action composite, y lo será en la Semana 10. Una plantilla resuelve otro
problema: arrancar un repo nuevo con un CI razonable, sabiendo que después cada copia vive su
vida.

## 3. Cómo se usa

### Qué extraer en `tablero`

La capa 09 crea tres reutilizables, uno por forma de construir:

| Reutilizable | Jobs | Lo llama |
|---|---|---|
| `_python.yml` | `lint`, `test` e `integration` (opcional) | `ci-api.yml` |
| `_node.yml` | `lint`, `test` en matriz y `build` con artefacto | `ci-web.yml` |
| `_image.yml` | `build` de una imagen, con push opcional a GHCR | `images.yml`, dos veces |

El guion bajo inicial es una convención de este bootcamp, no algo que GitHub interprete: ordena
los reutilizables al principio del listado y avisa a quien abre la carpeta de que esos archivos
no se disparan solos. Por lo mismo, su `on:` tiene una sola clave, `workflow_call`.

### El llamador queda en lo esencial

Este es `ci-api.yml` completo en la capa 09: 34 líneas frente a 113, y todas son decisiones.

```yaml
name: ci-api

on:
  push:
    branches: [main]
    paths:
      - "api/**"
      - ".github/workflows/ci-api.yml"
      - ".github/workflows/_python.yml"
  pull_request:
    paths:
      - "api/**"
      - ".github/workflows/ci-api.yml"
      - ".github/workflows/_python.yml"
  workflow_dispatch:

# Un run por workflow y ref: en un PR, el push nuevo cancela el run anterior;
# en main cada commit termina su run.
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  api:
    name: API
    uses: ./.github/workflows/_python.yml # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
    with:
      working-directory: api
      package: tablero
      coverage-min: 60
```

Fíjate en los `paths`: incluyen `_python.yml`. Si no, un cambio en el reutilizable no dispararía
el workflow que lo usa (archivo 06).

### Qué se queda fuera

No todo se extrae. `ci.yml`, `smoke.yml`, `nightly.yml` y `lint-workflows.yml` no se repiten en
ningún otro sitio: convertirlos en reutilizables añadiría un archivo sin quitar ninguna copia. Y
dentro de `ci-web.yml`, el job `dist-report` se queda en el llamador: usa el artefacto que
devuelve `_node.yml`, pero lo que hace con él es una decisión de `ci-web`, no de "cómo se
construye un frontend con pnpm".

`images.yml` pasa de un job con matriz `[api, web]` a **dos jobs que llaman al mismo
reutilizable**. Un job que llama también admite `strategy.matrix`, pero entonces el llamador
recibe un solo output para toda la matriz (archivo 03) y `images` necesita los dos digests.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Copiar un job a otro workflow "porque es más rápido" | Las copias divergen y el CI deja de probar lo mismo | Extraerlo a un reutilizable en cuanto haya dos usos |
| Un reutilizable con quince inputs que lo cubre todo | Nadie entiende qué combinación es válida; cada llamador prueba algo distinto | Dos reutilizables pequeños, o dejar el caso raro en el llamador |
| Un reutilizable para envolver un solo step | Un job entero, con su runner y su arranque, para un comando | Una action composite (Semana 10) |
| `on: [workflow_call, push]` en el reutilizable | Corre solo y además cuando lo llaman: runs duplicados y un contexto distinto en cada caso | `on: workflow_call` y nada más; el "cuándo" es del llamador |
| El reutilizable decide cosas del llamador (`if: github.event_name == 'push'` para publicar) | Acopla el reutilizable a un evento concreto | Un input `push: boolean` que el llamador calcula |
| Llamar a un reutilizable de otro repo por rama (`@main`) | Cualquier push a esa rama cambia tu CI sin que lo veas | Fijarlo por SHA con el tag en comentario (archivo 02) |

## 5. Trucos

- **Mide la duplicación antes y después**: `git grep -c 'actions/checkout@' .github/workflows/`
  te da cuántas veces se repite cada action por archivo. Tras la capa 09, `ci-api.yml` sale de la
  lista y `_python.yml` entra con tres.
- **`yq '.on | keys' .github/workflows/_python.yml`** confirma que un reutilizable solo escucha
  `workflow_call`. Es exactamente la primera comprobación de `checks.json`.
- **El prefijo del nombre es tu filtro**: te dice cómo terminó cada job que vino de esa llamada,
  sin mirar el resto del run.

  ```bash
  gh run view <run-id> --json jobs --jq '.jobs[] | select(.name | startswith("API /")) | .name + " " + .conclusion'
  # API / Lint y formato (ruff) success
  # API / Tests unitarios success
  # API / Tests de integración (PostgreSQL 17) success
  ```
- **Empieza por mover, no por parametrizar**: copia los jobs tal cual al reutilizable, haz que el
  llamador lo use y comprueba que el run sale igual. Después conviertes en input lo que cambia
  entre llamadores. Dos cambios pequeños se depuran mejor que uno grande.

## 📚 Recursos Adicionales

- [GitHub Docs: Reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
- [GitHub Docs: Reusing workflow configurations](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations)
- [GitHub Docs: Workflow syntax, `on.workflow_call`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onworkflow_call)

## ✅ Checklist de Verificación

- [ ] Sé contar la duplicación del CI de `tablero` y explicar por qué las copias divergen
- [ ] Sé qué decide el llamador y qué decide el reutilizable
- [ ] Sé que una llamada no crea otro run: los jobs del reutilizable se expanden en el del llamador
- [ ] Sé por qué los jobs aparecen como `API / Tests unitarios`
- [ ] Sé elegir entre reutilizable, action propia y plantilla
- [ ] Sé qué workflows de `tablero` no merece la pena extraer

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Semana 09 — Workflows reutilizables](../README.md) | [Llamar a un reutilizable](02-llamar-a-un-reutilizable.md) |
