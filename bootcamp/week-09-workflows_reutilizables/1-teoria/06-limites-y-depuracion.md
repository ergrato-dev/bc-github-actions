# Límites y depuración

> Casi todos los fallos de un reutilizable están en la frontera: un workflow que no se dispara,
> un archivo que no se encuentra, una llamada que no valida. Este archivo reúne los límites de la
> plataforma y las cuatro herramientas que ya tienes para leer y probar una llamada.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Conocer los límites de anidamiento y de número de reutilizables, y la regla de las subcarpetas
- Explicar por qué un cambio en `_python.yml` puede no disparar `ci-api` y cómo evitarlo
- Encontrar un error de llamada antes del push con actionlint y zizmor
- Ejecutar un reutilizable local con act y leer sus jobs con `gh run view`

## 1. Qué problema resuelve

Con jobs normales, un error suele estar en un step y el log lo señala. Con reutilizables aparecen
fallos nuevos que no tienen un step al que mirar:

- Cambias `_python.yml`, abres el PR y **no corre nada**. Ningún check en rojo: simplemente no
  hay run.
- El run de `images` aparece en la lista, pero **sin jobs**: la llamada no validó (un input que
  falta, un permiso que no alcanza) y GitHub no llegó a crear ninguno.
- El run termina **cancelado** sin que nadie haya empujado nada nuevo.
- En local todo parece bien, pero el reutilizable que llamas está en una subcarpeta o pasa del
  límite de anidamiento.

Saber los límites y tener una rutina para leer una llamada convierte cada uno de esos misterios en
un error con nombre.

## 2. Cómo funciona

### Los límites de la plataforma

| Límite | Valor | Qué pasa si lo superas |
|---|---|---|
| Niveles de anidamiento | Hasta 10: el llamador de nivel superior más nueve reutilizables encadenados | La llamada no valida |
| Reutilizables únicos por archivo de nivel superior | 50, contando los anidados | La llamada no valida |
| Ubicación | Directamente en `.github/workflows/` | Las subcarpetas no están soportadas |

"Únicos" quiere decir archivos distintos: `images.yml` llama dos veces a `_image.yml` y cuenta
como uno. `tablero` usa un solo nivel y tres reutilizables; los límites importan cuando un repo
central (Semana 11) empieza a encadenar reutilizables que llaman a otros.

### Los `paths` no siguen las llamadas

Los filtros `paths` de la Semana 07 se evalúan sobre los archivos que cambia el push o el PR, y
**GitHub no sabe que `ci-api.yml` usa `_python.yml`** cuando decide si dispararlo. Si
`ci-api.yml` filtra solo por `api/**` y por sí mismo, un PR que solo toca `_python.yml` no
dispara `ci-api`: el reutilizable cambia sin que ningún run lo pruebe, y el fallo aparece en el
siguiente PR que toque `api/`.

Por eso cada llamador de `tablero` lista su reutilizable en `push` y en `pull_request`:

```yaml
paths:
  - "api/**"
  - ".github/workflows/ci-api.yml"
  - ".github/workflows/_python.yml"
```

### Qué se resuelve y cuándo

Con `./`, GitHub lee el reutilizable **del mismo commit que el llamador** al crear el run. Si
la llamada no cuadra con el contrato (input obligatorio que falta, tipo que no coincide, permiso
que el job que llama no concede, archivo que no existe), el error es del archivo de workflow, no
de un step: el run aparece fallido y sin jobs, con el mensaje en la página del run. Por eso
merece la pena cazarlo antes, en local.

## 3. Cómo se usa

### 1: actionlint, antes del push

Con referencias `./`, actionlint lee los reutilizables y valida cada llamada contra su contrato:

```bash
actionlint
# .github/workflows/images.yml:22:11: secret "registry-password" is required by "./.github/workflows/_image.yml" reusable workflow [workflow-call]
# .github/workflows/ci-api.yml:13:7: input "bogus" is not defined in "./.github/workflows/_python.yml" reusable workflow. ...
```

También detecta una referencia a un archivo que no existe, como el de una subcarpeta:

```text
could not read reusable workflow file for "./.github/workflows/sub/_x.yml": open .../.github/workflows/sub/_x.yml: no such file or directory [workflow-call]
```

Lo que actionlint 1.7.12 no puede validar: referencias remotas `owner/repo/...@sha` (no tiene el
archivo), la sintaxis `$/` (la rechaza) y `cache-mode` (no lo conoce). Los permisos que pide el
reutilizable frente a los que concede el llamador tampoco los compara.

### 2: zizmor, la misma puerta

```bash
zizmor --offline .github/workflows/
# No findings to report. Good job! (4 ignored, 6 suppressed)
```

Sobre la capa 09, los cuatro ignorados son las cuatro llamadas con
`# zizmor: ignore[self-repository]`. Si quitas uno, aparece el hallazgo `help[self-repository]`
con `use '$/...' instead of './...'` y zizmor termina con código distinto de cero. Si alguien
añade `secrets: inherit`, aparece `warning[secrets-inherit]` (archivo 04). Las dos cosas las
bloquea `lint-workflows.yml` sin tocar nada: los reutilizables viven en `.github/workflows/`, que
ya está en sus `paths`.

### 3: act, en tu Docker

act 0.2.94 ejecuta reutilizables locales. `act -l` lista también sus jobs, con el evento
`workflow_call`:

```bash
scripts/ci-local.sh --list
# Stage  Job ID       Job name                              Workflow name  Workflow file  Events
# 0      lint         Lint y formato (ruff)                 _python        _python.yml    workflow_call
# 0      test         Tests unitarios                       _python        _python.yml    workflow_call
# 0      api          API                                   ci-api         ci-api.yml     push,pull_request,workflow_dispatch
# 1      integration  Tests de integración (PostgreSQL 17)  _python        _python.yml    workflow_call
# ...
```

Para ejecutar una llamada, apunta al job que llama, no a los del reutilizable:

```bash
scripts/ci-local.sh ci-api api
# Cada línea del log lleva delante el job que la produce:
#   API/_python/Lint y formato (ruff)
#   API/_python/Tests unitarios
#   API/_python/Tests de integración (PostgreSQL 17)
```

Los nombres siguen el patrón `API/_python/<job>`: job que llama, `name:` del reutilizable y job
dentro de él. `ci-web` en act falla en el post de `setup-node` por la caché de pnpm. Es la misma
limitación de act que ya tenías en la Semana 08, no un problema del reutilizable. Verificado con
act 0.2.94, actionlint 1.7.12, zizmor 1.31.1 y ubuntu-24.04, noviembre 2026.

### 4: `gh run view`, en remoto

```bash
run_id="$(gh run list --workflow ci-api.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
gh run view "$run_id" --json jobs --jq '.jobs[] | .name + " " + .conclusion'
# API / Lint y formato (ruff) success
# API / Tests unitarios success
# API / Tests de integración (PostgreSQL 17) success
```

Si la lista sale vacía, la llamada no validó: `gh run view "$run_id"` enseña el error del archivo
de workflow. Si sale un job en `skipped`, mira su `if:`; en `_python.yml`, `integration` se salta
cuando el llamador pasa `integration: false`. Y para ver el log de lo que falló:

```bash
gh run view "$run_id" --log-failed
```

### Una rutina de diagnóstico

| Síntoma | Primera comprobación |
|---|---|
| No hay run tras cambiar el reutilizable | `yq '.on.pull_request.paths' .github/workflows/ci-api.yml`: ¿está `_python.yml`? |
| Run sin jobs | `actionlint` en local; `gh run view <id>` para el mensaje |
| Run cancelado sin commit nuevo | `grep -n concurrency .github/workflows/_*.yml` (archivo 05) |
| Error de permisos al crear el run | `permissions:` del job que llama frente a la raíz del reutilizable |
| Un output llega vacío | Los cuatro saltos del archivo 03, empezando por `workflow_call.outputs` |
| Un job no aparece | Su `if:` y los inputs que lo controlan |

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `paths` del llamador sin su reutilizable | Un cambio en `_python.yml` no se prueba hasta el siguiente PR de `api/` | Listar el reutilizable en `push` y en `pull_request` |
| Organizar reutilizables en subcarpetas | No están soportadas: la llamada no encuentra el archivo | Todo en `.github/workflows/`, con el prefijo `_` |
| Cadenas de reutilizables "por si acaso" | Más difícil de leer y más cerca de los límites de 10 niveles y 50 únicos | Un nivel mientras baste |
| Probar el reutilizable solo empujando a `main` | Cada error es un run fallido en la rama principal | actionlint, zizmor y act antes; el PR después |
| `act -j lint` sobre un reutilizable | Ejecuta el job sin llamador: sin inputs, con otro contexto | `scripts/ci-local.sh ci-api api` |
| Pasar a referencia remota sin actionlint en el repo del reutilizable | Nadie valida el contrato | Lint en los dos repos (Semana 11) |

## 5. Trucos

- **`gh run view <id> --json jobs --jq '.jobs | length'`** te dice en un segundo si la llamada
  validó: `0` es un error del archivo, no de un step.
- **`act -l -W .github/workflows/_python.yml`** enseña solo los jobs de ese reutilizable y en qué
  orden (`Stage`) corren, sin ejecutar nada ni necesitar inputs.
- **`yq '.on.push.paths, .on.pull_request.paths'`** sobre un llamador saca las dos listas a la
  vez; la comprobación `paths-include-reusable` mira exactamente eso.
- **`gh run rerun <id> --debug`** relanza el run con el log de depuración del runner, también en
  los jobs del reutilizable: lo que verías con `ACTIONS_STEP_DEBUG` sin tocar los secretos.

## 📚 Recursos Adicionales

- [GitHub Docs: Reusing workflow configurations, limitaciones](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations)
- [GitHub Docs: Reuse workflows, monitorizar qué workflows se usan](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
- [actionlint: comprobaciones de `workflow_call`](https://github.com/rhysd/actionlint/blob/main/docs/checks.md)
- [act: documentación](https://nektosact.com/)

## ✅ Checklist de Verificación

- [ ] Sé los límites: 10 niveles, 50 reutilizables únicos y nada en subcarpetas
- [ ] Sé por qué los `paths` del llamador tienen que incluir su reutilizable
- [ ] Sé qué valida actionlint en una llamada local y qué no puede validar
- [ ] Sé qué hallazgos de zizmor tocan a los reutilizables
- [ ] Sé ejecutar una llamada con `scripts/ci-local.sh` y leer los nombres `API/_python/<job>`
- [ ] Sé distinguir con `gh run view` un run sin jobs de un job que falló

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Contexto, permisos y concurrencia](05-contexto-permisos-y-concurrencia.md) | [Primer reutilizable](../2-practicas/01-primer-reutilizable.md) |
