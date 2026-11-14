# Las reglas de un ruleset

> Un ruleset vale lo que valen sus reglas. Cada una cierra un camino concreto a `main`, y elegir
> sus parámetros es elegir qué riesgo aceptas y qué fricción pagas.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Elegir la regla que cierra cada camino a `main`: borrado, force push, push directo y PR en rojo
- Configurar la regla `pull_request` y saber qué hace cada uno de sus parámetros
- Exigir un check con `integration_id` para que solo cuente si viene de GitHub Actions
- Decidir si `strict_required_status_checks_policy` compensa cuando hay merge queue
- Escribir el ruleset de `main` como YAML versionado y aplicarlo o cambiarlo con `gh api`

## 1. Qué problema resuelve

El archivo 01 dejó cuatro caminos abiertos: push directo, force push, borrado y PR con el CI en
rojo. Un ruleset sin reglas no cierra ninguno. Y una regla mal parametrizada da una falsa
sensación de seguridad: un check obligatorio que cualquiera puede satisfacer creando un status
con el mismo nombre no protege nada.

Este archivo recorre las reglas que usa `tablero`, una por camino, con sus parámetros reales de
la API. La de la merge queue tiene archivo propio (05) y la revisión de equipo también (06).

## 2. Cómo funciona

### Las reglas sin parámetros

| Regla (`type`) | Qué impide | En `tablero` |
|---|---|---|
| `deletion` | Borrar la rama, salvo a quien tiene bypass | Sí |
| `non_fast_forward` | Force push: reescribir la historia publicada | Sí |
| `required_linear_history` | Commits de merge en la rama | No: el squash ya da historia lineal |
| `update` | Cualquier push a la rama, salvo a quien tiene bypass | No: cerraría también la fusión de PR |

`update` es la regla "Restrict updates" de la UI. Suena a lo que quieres, pero sin bypass deja
la rama congelada. El push directo se cierra con la regla siguiente.

### `pull_request`: todo cambio llega por PR

Con esta regla, la única forma de cambiar `main` es fusionar un PR. Sus parámetros, todos
obligatorios en la API salvo el último:

| Parámetro | Qué controla | En `tablero` |
|---|---|---|
| `required_approving_review_count` | Aprobaciones necesarias | `0` (archivo 06) |
| `dismiss_stale_reviews_on_push` | Si un push nuevo invalida las aprobaciones | `false` |
| `require_code_owner_review` | Si hace falta la aprobación de un code owner | `false` |
| `require_last_push_approval` | Si el último push lo tiene que aprobar otra persona | `false` |
| `required_review_thread_resolution` | Si hay que resolver todas las conversaciones | `true` |
| `allowed_merge_methods` | Métodos permitidos: `merge`, `squash`, `rebase` | `[squash]` |

Con 0 aprobaciones la regla sigue cerrando el push directo: el cambio tiene que pasar por un PR y,
con la regla siguiente, por el CI. Los tres `false` son la configuración de alguien que trabaja
solo; el archivo 06 explica la de un equipo.

`allowed_merge_methods: [squash]` deja un commit por PR en `main` cuyo mensaje es el título del
PR. Es lo que lee release-please (Semana 14): un título `feat(api): …` se convierte en una
entrada del CHANGELOG y en una subida de versión menor.

### `required_status_checks`: el PR no entra en rojo

| Parámetro | Qué controla |
|---|---|
| `required_status_checks[].context` | El nombre del check que tiene que estar en verde |
| `required_status_checks[].integration_id` | Opcional: la app de la que tiene que venir |
| `strict_required_status_checks_policy` | Si la rama del PR tiene que estar al día con `main` |
| `do_not_enforce_on_create` | Si se permite crear la rama aunque el check no haya pasado |

**`context`** es el nombre del check tal como aparece en el PR. En `tablero` es `ci-gate`, el
`name:` de un job de `ci.yml` (archivo 03). Uno solo, a propósito.

**`integration_id`** cierra un agujero. Un status de commit lo puede crear cualquiera con permiso
de escritura en statuses, con la API y con el nombre que quiera. Sin `integration_id`, un
`POST repos/{owner}/{repo}/statuses/<sha>` con `context: ci-gate` y `state: success` daría el PR
por bueno sin que el CI corra. Con `integration_id: 15368` solo cuenta el `ci-gate` que publica
la app **GitHub Actions**. El número no está en la documentación; lo confirma la API pública:

```bash
gh api apps/github-actions --jq '"\(.id) \(.slug)"'
# 15368 github-actions
```

**`strict_required_status_checks_policy`** es "Require branches to be up to date before merging".
Con `true`, si `main` avanzó desde que tu PR pasó el CI, tienes que actualizar la rama y esperar
otra vuelta de CI. Garantiza que lo probado es lo que entra, pero en un repo con movimiento se
convierte en una carrera: actualizas, otro fusiona antes, actualizas otra vez. La merge queue
(archivo 05) da la misma garantía sin la carrera, porque prueba cada PR sobre el `main` real en
el momento de entrar. Por eso `tablero` usa `false`.

**`do_not_enforce_on_create: false`** mantiene la regla también al crear la rama. Para `main`,
que ya existe, no cambia nada; lo dejas explícito para que nadie tenga que adivinarlo.

### Un check que no aparece no se puede elegir

La documentación de los checks obligatorios avisa: "A required status check must have completed
successfully in the chosen repository during the past seven days". Afecta a la UI, que solo
ofrece checks recientes. Con la API lo escribes igual, pero si `ci-gate` todavía no ha corrido
nunca, cada PR esperará un check que no existe. Por eso la Práctica 01 crea `ci-gate` antes de
que la Práctica 02 lo exija.

_Verificado con la API REST de rulesets (2022-11-28), gh 2.104.0 y ubuntu-24.04, noviembre de 2026._

## 3. Cómo se usa

### El ruleset como código

`tablero` guarda su ruleset en `ops/github/ruleset-main.yaml`. YAML porque admite comentarios, y
los comentarios son el porqué de cada parámetro. La API quiere JSON: `yq -o=json` hace la
conversión en el momento de aplicarlo. Sin la regla de la cola, que añade la Práctica 03:

```yaml
name: main
target: branch
enforcement: active
conditions:
  ref_name:
    include: ["~DEFAULT_BRANCH"]
    exclude: []
# Nadie se salta el ruleset, tampoco el admin: si ci-gate se rompe, se arregla con otro PR.
bypass_actors: []
rules:
  - type: deletion
  - type: non_fast_forward
  - type: pull_request
    parameters:
      # Trabajas solo y no puedes aprobar tus PR. En un equipo: 1, con code owners y last push.
      required_approving_review_count: 0
      dismiss_stale_reviews_on_push: false
      require_code_owner_review: false
      require_last_push_approval: false
      required_review_thread_resolution: true
      allowed_merge_methods: [squash]
  - type: required_status_checks
    parameters:
      # La merge queue ya prueba cada PR sobre el main real: strict solo añadiría esperas.
      strict_required_status_checks_policy: false
      do_not_enforce_on_create: false
      required_status_checks:
        # 15368 es GitHub Actions: un status con el mismo nombre desde otra app no cuenta.
        - context: ci-gate
          integration_id: 15368
```

### Aplicarlo y cambiarlo

La primera vez se crea con `POST`; la respuesta trae el `id`:

```bash
yq -o=json ops/github/ruleset-main.yaml \
  | gh api -X POST 'repos/{owner}/{repo}/rulesets' --input - --jq .id
# 4815162
```

Para cambiarlo, el mismo comando con `PUT` sobre ese `id`. Un segundo `POST` no actualiza nada:
crea otro ruleset con el mismo nombre, y los dos se suman.

```bash
id=$(gh api 'repos/{owner}/{repo}/rulesets' --jq '.[] | select(.name == "main") | .id')
yq -o=json ops/github/ruleset-main.yaml \
  | gh api -X PUT "repos/{owner}/{repo}/rulesets/$id" --input - --jq .updated_at
```

La API guarda además el historial de versiones en `rulesets/<id>/history`.

### Dos mayúsculas que muerden

`allowed_merge_methods` va en minúsculas (`squash`). El `merge_method` de la regla `merge_queue`
va en mayúsculas (`SQUASH`). Son enumerados distintos y la API valida cada uno: si los cruzas,
el `POST` o el `PUT` falla y el ruleset no cambia.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Check obligatorio sin `integration_id` | Un status creado a mano con ese nombre lo satisface | `integration_id: 15368` para GitHub Actions |
| Exigir cada check del CI por separado | Cada nombre nuevo o renombrado obliga a tocar el ruleset, y los saltados por `paths` bloquean (archivo 03) | Un solo `ci-gate` |
| `strict: true` con merge queue | Dos esperas para la misma garantía | `false` y la cola |
| `update` para cerrar el push directo | Sin bypass congela la rama, PR incluidos | `pull_request` |
| Repetir `POST` para "actualizar" | Dos rulesets iguales que se suman y se desincronizan | `PUT` sobre el `id` |
| Los tres métodos de merge permitidos | Commits de merge y rebase mezclados; release-please lee mensajes que no esperas | `[squash]` |

## 5. Trucos

- **Del ruleset de la UI a un archivo**: `gh api repos/{owner}/{repo}/rulesets/<id> --jq '{name, target, enforcement, conditions, bypass_actors, rules}' | yq -P`
  te da un YAML con la forma exacta que acepta el `PUT`.
- **El `id` de cualquier app**: `gh api apps/<slug> --jq .id`. Te sirve si algún día exiges un
  check que publica otra app y no GitHub Actions.
- **Quién cambió el ruleset y cuándo**: `gh api repos/{owner}/{repo}/rulesets/<id>/history` lista
  sus versiones; si no casan con los commits de `ops/github/`, alguien lo tocó desde la UI.

## 📚 Recursos Adicionales

- [GitHub Docs: Available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [GitHub Docs: Create a repository ruleset (REST)](https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset)
- [GitHub Docs: Troubleshooting required status checks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks)
- [yq: output formats](https://mikefarah.gitbook.io/yq/usage/output-format)

## ✅ Checklist de Verificación

- [ ] Sé qué regla cierra el borrado, el force push, el push directo y el PR en rojo
- [ ] Sé qué hace cada parámetro de `pull_request` y por qué `tablero` usa squash
- [ ] Sé por qué `ci-gate` va con `integration_id: 15368`
- [ ] Sé qué hace `strict_required_status_checks_policy` y por qué no compensa con cola
- [ ] Sé aplicar el ruleset con `POST` y cambiarlo con `PUT` sin duplicarlo
- [ ] Sé qué parámetro va en minúsculas y cuál en mayúsculas

---

| ← Anterior | Siguiente → |
|:---|---:|
| [De ramas protegidas a rulesets](01-de-ramas-protegidas-a-rulesets.md) | [Checks obligatorios y el job puerta](03-checks-obligatorios-y-el-job-puerta.md) |
