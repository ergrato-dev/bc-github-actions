# Rulesets que exigen workflows

> Las políticas del archivo 06 dicen qué **puede** ejecutarse. Un ruleset de organización puede
> decir qué **tiene que** ejecutarse, y pasar, antes de fusionar un PR en cualquier repo de la
> org. Es la pieza que cierra el gobierno del CI, y la única de la semana que no puedes practicar.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué añade la regla "Require workflows to pass before merging" a lo que ya tienes
- Saber en qué nivel se configura y qué plan de GitHub exige
- Escribir un workflow que pueda usarse como workflow exigido: eventos y filtros
- Enumerar sus límites: eventos admitidos, CodeQL, pushes directos y token
- Distinguirla de los checks requeridos de un repo, que practicarás en la Semana 18

## 1. Qué problema resuelve

Con lo hecho hasta el archivo 06 tienes:

- Un CI central que todos **pueden** llamar.
- Una plantilla que lo ofrece a los repos nuevos.
- Políticas que impiden ejecutar lo que no está en la lista.

Ninguna de las tres obliga a nadie a **usar** el CI. Un repo de la org puede borrar su
`ci-python.yml`, o no crearlo nunca, y fusionar a `main` lo que quiera. Las políticas no lo
impiden: un repo sin workflows no incumple ninguna.

Para una organización con requisitos (auditoría, cumplimiento, "nada llega a producción sin
pasar el escáner"), hace falta lo contrario: un workflow que corre en todos los repos elegidos,
lo quiera el repo o no, y cuyo resultado bloquea la fusión.

## 2. Cómo funciona

### Dónde vive la regla

Un **ruleset** es un conjunto de reglas sobre ramas o tags. Los hay de tres niveles: repo,
organización y empresa. La regla **"Require workflows to pass before merging"** solo existe en
los de **organización** y **empresa**: el workflow exigido viene de fuera del repo al que se
aplica, así que tiene que decidirlo alguien por encima de él.

Al crear la regla eliges:

1. **Qué repos**: todos los de la org, una lista, o los que casen con un patrón de nombre o con
   una propiedad personalizada.
2. **Qué ramas** de esos repos: por ejemplo, la rama por defecto.
3. **Qué workflow**: el repo de origen y el archivo de workflow que se exige.
4. **Estado**: activo, o desactivado mientras lo preparas.

Con la regla activa, cada PR hacia esas ramas ejecuta el workflow exigido **desde su repo de
origen**, además de los workflows propios del repo. Si no pasa, el PR no se puede fusionar.

### Qué workflow puede exigirse

No vale cualquiera. La documentación pone estas condiciones:

| Condición | Detalle |
|---|---|
| Eventos | `on:` tiene que incluir al menos uno de `pull_request`, `pull_request_target` o `merge_group` |
| Filtros | Los filtros que pongas en esos eventos (`branches`, `paths`...) se ignoran |
| Tipos de actividad | Corre siempre, y solo, con los tipos de actividad por defecto del evento |
| CodeQL | No puede usar las actions de CodeQL, salvo `github/codeql-action/upload-sarif` |
| Token | No corre en eventos disparados por el `GITHUB_TOKEN`: un PR abierto por un workflow no lo dispara |
| Visibilidad | Un workflow de un repo público puede exigirse en cualquier repo de la org; uno privado o interno necesita dar acceso desde fuera de su repo |

Y un efecto que hay que prever: la regla **bloquea los pushes directos** a las ramas que cubre.
Todo cambio tiene que llegar por PR, porque es el PR lo que dispara el workflow.

De esos eventos, `pull_request_target` lo verás con su patrón seguro en la Semana 12 y
`merge_group` con la merge queue en la Semana 18. Para el ejemplo basta `pull_request`.

### Un workflow exigible, con lo que ya sabes

Un workflow exigido es, en esencia, un llamador fino como la plantilla del archivo 05, que vive
en un repo de la org (por ejemplo, el propio `actions-tablero`):

```yaml
# Workflow pensado para exigirse desde un ruleset de organización: lo mínimo que todo repo
# Python de la org tiene que pasar antes de fusionar.
name: required-python

on:
  pull_request:

permissions:
  contents: read

jobs:
  python:
    name: Python (exigido por la org)
    uses: <tu-org>/actions-tablero/.github/workflows/_python.yml@a7e19ff8d215588d594f79b969b79bed58287cea # v1.0.0
    with:
      working-directory: .
      package: app
      integration: false
```

(SHA de ejemplo.) Fíjate en dos cosas:

- **Sin `paths` ni `branches`**: se ignorarían. Qué ramas se protegen lo decide el ruleset, no
  el workflow.
- **El reutilizable y su versión los decide la org**: el repo protegido no puede cambiar el SHA,
  porque el archivo no está en su repo.

Este ejemplo tiene un problema real: `working-directory: .` no sirve para `tablero`, que tiene
el código en `api/`. Un workflow exigido a muchos repos tiene que funcionar en todos, y por eso
suelen ser comprobaciones que no dependen de la estructura del repo: un escáner de secretos, una
revisión de licencias, una comprobación de que los workflows pasan actionlint.

### La función antigua: "required workflows"

Antes de los rulesets, Actions tenía una función propia llamada "required workflows", en los
ajustes de Actions de la organización. Está **retirada**: si la encuentras en un artículo o en
un examen antiguo, su sustituto es esta regla de los rulesets. No la uses como referencia
vigente.

## 3. Cómo se usa

### Por qué no se practica

La documentación de los rulesets de organización empieza así: "For customers on GitHub Team or
GitHub Enterprise plans you can create rulesets in your organization". La organización del
bootcamp es del plan Free, que no los tiene. Montarla con el plan Team supone un coste, y el
bootcamp es de 0 €. Por eso este archivo es solo teoría y no tiene comprobación en `checks.json`.

Si trabajas en una organización con plan Team o Enterprise, el recorrido es crear un ruleset
de ramas en los ajustes de la organización, elegir repos y ramas, y en las reglas activar
"Require workflows to pass before merging" con el repo de origen y el archivo.

### Lo que sí tienes en el plan Free

Los **rulesets de repo** sí están disponibles en repos públicos del plan Free, y con ellos
"Require status checks to pass before merging": exigir que los checks de **los workflows del
propio repo** (por ejemplo `ci-api`) pasen antes de fusionar. La diferencia con la regla de
este archivo:

| | Checks requeridos (ruleset de repo) | Workflows exigidos (ruleset de org) |
|---|---|---|
| Dónde vive el workflow | En el propio repo | En otro repo de la org |
| Quién puede quitarlo | Un admin del repo | Solo quien administra la org |
| Plan | Free, en repos públicos | Team o Enterprise |
| En el bootcamp | Semana 18, con la merge queue | Solo esta teoría |

Para un equipo pequeño, los checks requeridos del repo más las políticas del archivo 06 cubren
casi todo. Los workflows exigidos aparecen cuando hay muchos repos y alguien tiene que
garantizar un mínimo que ningún equipo pueda desactivar.

### En el examen

La GH-200 pregunta por el gobierno del CI a escala de organización. Lo que conviene tener claro
de este archivo: la regla está en rulesets de org o empresa, los eventos admitidos son tres, sus
filtros se ignoran y la antigua "required workflows" está retirada.

### Las cuatro piezas de la semana, juntas

| Pieza | Qué garantiza | Qué no garantiza |
|---|---|---|
| Repo central (archivos 01-04) | Una sola implementación del CI, versionada | Que alguien la use |
| Workflow template (archivo 05) | Que los repos nuevos arranquen usándola | Que la sigan usando |
| Políticas de la org (archivo 06) | Que solo se ejecute lo permitido y fijado | Que se ejecute algo |
| Workflow exigido (este archivo) | Que un mínimo corra y pase antes de fusionar | Nada más allá de ese mínimo |

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Workflow exigido solo con `on: push` | No es un evento admitido: la regla no puede usarlo | `pull_request` (o los otros dos admitidos) |
| Confiar en `paths` o `branches` del workflow exigido | Se ignoran: corre en todo PR de las ramas del ruleset | Decidir el alcance en el ruleset |
| Exigir un workflow que depende de la estructura de un repo | Falla en los repos que no la siguen y bloquea sus PR | Comprobaciones genéricas, o rulesets por propiedad |
| Activarlo en ramas que reciben pushes directos | La regla bloquea los pushes directos | Aplicarlo solo donde todo entra por PR |
| Buscar "required workflows" en los ajustes de Actions | Función retirada | Rulesets de organización |
| Workflow exigido en un repo privado sin dar acceso | Los repos de la org no pueden ejecutarlo | Repo público o acceso configurado |

## 5. Trucos

- **Lee los rulesets de una org con `gh`**: `gh api orgs/{owner}/rulesets` lista los de la org
  (en el plan Free, donde no existen, espera una lista vacía o un error). En un repo, `gh api repos/{owner}/{repo}/rulesets` lista los de repo;
  los usarás en la Semana 18.
- **`gh api repos/{owner}/{repo}/rules/branches/main`** devuelve las reglas que se aplican a
  una rama, vengan del ruleset que vengan: es la forma de saber, desde un repo, si la org le
  exige algo.
- **Prueba el workflow antes de exigirlo**: añádelo como workflow normal en un par de repos y
  mira que pasa. Una vez exigido, un fallo bloquea los PR de toda la org.

## 📚 Recursos Adicionales

- [GitHub Docs: Creating rulesets for repositories in your organization](https://docs.github.com/en/organizations/managing-organization-settings/creating-rulesets-for-repositories-in-your-organization)
- [GitHub Docs: Available rules for rulesets](https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets#require-workflows-to-pass-before-merging)
- [GitHub Docs: About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)

## ✅ Checklist de Verificación

- [ ] Sé qué añade un workflow exigido a las políticas de actions de la org
- [ ] Sé en qué nivel de ruleset existe la regla y qué plan pide
- [ ] Sé qué eventos admite un workflow exigido y qué pasa con sus filtros
- [ ] Sé sus límites: CodeQL, pushes directos, eventos del `GITHUB_TOKEN`, visibilidad
- [ ] Sé qué sustituyó a la antigua función "required workflows"
- [ ] Sé distinguirlo de los checks requeridos de un ruleset de repo

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Políticas de actions de la organización](06-politicas-de-actions-de-la-organizacion.md) | [Repo central y primera release](../2-practicas/01-repo-central-y-primera-release.md) |
