# CODEOWNERS y revisión en equipo

> Un check prueba que el código funciona; una revisión, que alguien que entiende esa parte está
> de acuerdo. CODEOWNERS dice quién es ese alguien para cada ruta.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Escribir un archivo CODEOWNERS y saber dónde lo busca GitHub
- Predecir qué dueño se aplica a un archivo cuando varios patrones casan
- Detectar líneas inválidas antes de que se ignoren en silencio
- Configurar la revisión obligatoria de un equipo con los parámetros de la regla `pull_request`
- Explicar qué ataque cierra cada parámetro de revisión
- Justificar por qué `tablero`, con un solo autor, exige 0 aprobaciones

## 1. Qué problema resuelve

`ci-gate` responde a "¿funciona?". No responde a "¿debería estar aquí?". Un PR puede pasar todos
los tests y aun así:

- Subir `permissions:` de un workflow a `write` sin motivo.
- Cambiar el ruleset en `ops/github/` para quitar `ci-gate`.
- Añadir un step que manda un secreto a un servidor externo, con tests impecables.

Los tres tocan rutas sensibles: `.github/` y `ops/`. En un equipo, esas rutas tienen dueño: la
persona o el equipo que responde de ellas y que tendría que ver cada cambio. CODEOWNERS escribe
ese reparto en un archivo, y la regla `pull_request` del ruleset puede convertirlo en obligatorio.

## 2. Cómo funciona

### Dónde vive el archivo

La documentación dice: "create a new file called `CODEOWNERS` in the `.github/`, root, or `docs/`
directory [...] GitHub will search for them in that order and use the first one it finds."
`tablero` lo pone en `.github/CODEOWNERS`, junto a lo que protege.

Dos condiciones más:

- **Se lee de la rama base del PR**: "the CODEOWNERS file must be on the base branch of the pull
  request." Un PR que cambia CODEOWNERS no se aplica a sí mismo su versión nueva.
- **Tamaño**: por encima de 3 MB no se carga. Nunca te pasará, salvo que generes el archivo.

### Cómo se escribe

Cada línea es un patrón y uno o más dueños (`@usuario`, `@org/equipo` o un email):

```text
# Quién responde de cada ruta de tablero. GitHub pide su revisión en cada PR que la toque;
# si el ruleset activa require_code_owner_review, además hace falta su aprobación.
# Gana el último patrón que casa: lo general arriba, lo concreto abajo.
/.github/ @<tu-usuario>
/ops/ @<tu-usuario>
```

Los patrones siguen casi todas las reglas de `.gitignore`. Los que más vas a usar:

| Patrón | Casa con |
|---|---|
| `/ops/` | El directorio `ops` de la raíz y todo lo que hay dentro |
| `ops/` | Cualquier directorio llamado `ops`, a cualquier profundidad |
| `*.sql` | Cualquier archivo `.sql` del repo |
| `/api/**/test_*.py` | Tests de cualquier subdirectorio de `api/` |
| `*` | Todo: el dueño por defecto |

La `/` inicial ancla a la raíz. `tablero` la usa siempre: `/ops/` no debería casar con un
hipotético `web/src/ops/`.

### El último patrón gana

"Order is important; the last matching pattern takes the most precedence." No se suman: para
cada archivo cuenta solo la última línea que casa.

```text
*                 @<tu-org>/devs
/.github/         @<tu-org>/platform
/.github/labeler.yml  @<tu-org>/devs
```

`.github/workflows/ci.yml` es de `platform` (la segunda línea es la última que casa).
`.github/labeler.yml` es de `devs` (la tercera). `api/main.py` es de `devs` (solo casa la
primera). Por eso el orden es de lo general a lo concreto: una línea `*` al final se comería
todas las anteriores.

### Los dueños tienen que poder escribir

"The people you choose as code owners must have write permissions for the repository. When the
code owner is a team, that team must be visible and it must have write permissions". Un dueño sin
escritura no cuenta: su línea existe, pero nadie la satisface.

### Las líneas inválidas se ignoran en silencio

"If any line in your CODEOWNERS file contains invalid syntax, that line will be skipped." Un
usuario mal escrito o un patrón raro no rompen nada visible: esa ruta se queda sin dueño. La API
te lo dice:

```bash
gh api 'repos/{owner}/{repo}/codeowners/errors' --jq '.errors[] | "\(.line): \(.kind) \(.message)"'
# (sin salida: no hay errores)
```

Cada error trae `line`, `column`, `kind` (`Invalid pattern`, `Invalid owner`...), `message` y,
cuando puede, una `suggestion`. La Práctica 02 lo comprueba con `--jq '.errors | length'`.

_Verificado con la API REST de repos (2022-11-28), gh 2.104.0 y ubuntu-24.04, noviembre de 2026._

## 3. Cómo se usa

### La revisión de un equipo

Con CODEOWNERS en su sitio, GitHub pide revisión a los dueños de lo que toca cada PR. Pedir no es
exigir. Lo que lo hace obligatorio son los parámetros de la regla `pull_request` (archivo 02).
Así los configuraría un equipo:

```yaml
  - type: pull_request
    parameters:
      required_approving_review_count: 1
      require_code_owner_review: true
      require_last_push_approval: true
      dismiss_stale_reviews_on_push: true
      required_review_thread_resolution: true
      allowed_merge_methods: [squash]
```

| Parámetro | Qué ataque o error cierra |
|---|---|
| `required_approving_review_count: 1` | Que alguien fusione su propio cambio sin que otra persona lo vea |
| `require_code_owner_review: true` | Que apruebe cualquiera un cambio en `.github/`: tiene que ser su dueño |
| `require_last_push_approval: true` | El "aprueba y cuelo": según la API, "the most recent reviewable push must be approved by someone other than the person who pushed it" |
| `dismiss_stale_reviews_on_push: true` | Que una aprobación de ayer valga para el código que se subió hoy |
| `required_review_thread_resolution: true` | Que se fusione con una objeción sin responder |

`require_last_push_approval` y `dismiss_stale_reviews_on_push` se parecen y no son lo mismo. El
primero mira **quién** hizo el último push: si fuiste tú, otra persona tiene que aprobar después.
El segundo invalida aprobaciones **anteriores** a un push nuevo, haya sido quien haya sido. Juntos
cierran el caso de un revisor que aprueba y luego empuja un commit suyo al PR.

La regla admite además `dismissal_restriction` y `required_reviewers` (equipos obligatorios por
patrón de archivo), que no necesitas para entender el modelo.

### Por qué `tablero` usa 0

Trabajas solo. GitHub no deja aprobar tu propio PR. Con
`required_approving_review_count: 1`, ningún PR tuyo podría entrar nunca, salvo con un bypass, y
un bypass permanente es peor que no exigir revisión: enseña a saltarse la regla.

Así que el ruleset de `tablero` lleva 0 aprobaciones y los tres booleanos de revisión a `false`.
Lo que **sí** exige sigue valiendo para un equipo: todo por PR, `ci-gate` en verde, cola y
conversaciones resueltas.

¿Y CODEOWNERS, si no se exige? Tres razones para tenerlo igual:

- **Documenta**: cualquiera que abra el repo sabe quién responde de `.github/` y `ops/`.
- **Está listo**: el día que entra una segunda persona, activar `require_code_owner_review` es
  cambiar un `false` por `true` en `ops/github/ruleset-main.yaml`.
- **Se protege a sí mismo**: `.github/CODEOWNERS` está dentro de `/.github/`, así que su propio
  dueño responde de cualquier cambio en él.

Como tú eres el autor de todos los PR, GitHub no te pedirá revisión a ti mismo: no esperes ver el
aviso de code owner en tus PR.

### Revisión y bots

Si un equipo exige 1 aprobación, el PR de release que abre la App del archivo 07 también la
necesita. Es lo que se quiere: la release la aprueba una persona. Por eso el ajuste que deja a
`GITHUB_TOKEN` aprobar PR (archivo 07) vuelve a `false`: con él, un workflow podría satisfacer la
revisión obligatoria sin que nadie la hiciera.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `*` al final del archivo | Se come todas las líneas anteriores | `*` arriba, lo concreto abajo |
| Patrones sin `/` inicial | `ops/` casa también con `web/src/ops/` | `/ops/` |
| Dueño sin permiso de escritura | Su línea no la satisface nadie | Dueños con escritura; equipos visibles |
| No revisar `codeowners/errors` | Una línea inválida deja la ruta sin dueño sin avisar | `gh api .../codeowners/errors` tras cada cambio |
| Exigir 1 aprobación trabajando solo | Ningún PR entra; acabas añadiendo un bypass | 0 aprobaciones y el resto de la regla |
| Aprobación sin `dismiss_stale_reviews_on_push` | Se aprueba una versión y se fusiona otra | `true` en un equipo |

## 5. Trucos

- **Quién es dueño de un archivo, a mano**: recorre CODEOWNERS de abajo arriba y quédate con la
  primera línea que case. Es lo mismo que hace GitHub y evita sorpresas con el orden.
- **Probar el archivo sin PR**: `codeowners/errors` acepta `?ref=<rama>`, así validas la versión
  de tu rama antes de abrir el PR.
- **Dueño de CODEOWNERS**: añade una línea `/.github/CODEOWNERS @<tu-org>/platform` al final si
  quieres que el archivo tenga un dueño distinto del resto de `.github/`.

## 📚 Recursos Adicionales

- [GitHub Docs: About code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- [GitHub Docs: List CODEOWNERS errors](https://docs.github.com/en/rest/repos/repos#list-codeowners-errors)
- [GitHub Docs: Available rules for rulesets — require a pull request](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [GitHub Docs: About pull request reviews](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/about-pull-request-reviews)

## ✅ Checklist de Verificación

- [ ] Sé en qué tres sitios busca GitHub el archivo CODEOWNERS y en qué orden
- [ ] Sé qué dueño se aplica cuando varios patrones casan
- [ ] Sé qué pasa con una línea inválida y cómo detectarla
- [ ] Sé qué cierra cada parámetro de revisión de la regla `pull_request`
- [ ] Sé distinguir `require_last_push_approval` de `dismiss_stale_reviews_on_push`
- [ ] Sé por qué `tablero` exige 0 aprobaciones y por qué tiene CODEOWNERS igualmente

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Merge queue](05-merge-queue.md) | [Bots que abren PR y el token de una App](07-bots-que-abren-pr-y-el-token-de-una-app.md) |
