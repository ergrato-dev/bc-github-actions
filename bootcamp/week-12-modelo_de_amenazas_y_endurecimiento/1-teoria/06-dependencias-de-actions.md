# Dependencias de actions

> Cada `uses:` ejecuta código de otro repo dentro de tu job, con tu token. Fijarlo por SHA
> decide qué código corre; mantenerlo al día sin bajar la guardia es el trabajo de Dependabot.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué garantiza un SHA de 40 caracteres y qué no garantiza
- Describir un commit impostor y por qué un SHA de un fork puede colarse
- Configurar Dependabot para `github-actions`, `uv` y pnpm con cooldown y grupos
- Leer un PR de Dependabot que actualiza una action fijada por SHA
- Situar las releases inmutables de la Semana 11 en este modelo
- Saber qué son los lockfiles de workflows y por qué `tablero` no los usa

## 1. Qué problema resuelve

La cuarta frontera del archivo 01 son **las referencias externas**. En `tablero` hay unas
cuantas: `actions/checkout`, `actions/upload-artifact`, `astral-sh/setup-uv`,
`github/codeql-action`, `actions/labeler` y el repo central `<tu-org>/actions-tablero`. Cada
una corre dentro de un job con el token de ese job.

Dos riesgos, opuestos:

- **Que cambie sin que lo sepas.** Un tag se puede mover. Es lo que pasó con
  `tj-actions/changed-files` en marzo de 2025 (archivo 01).
- **Que no cambie nunca.** Un SHA fijado y olvidado sigue ejecutando una versión con fallos
  conocidos, o un runtime de Node retirado, años después.

El SHA resuelve el primero y crea el segundo. Dependabot resuelve el segundo sin deshacer el
primero.

## 2. Cómo funciona

### Qué garantiza el SHA

```yaml
      # ❌ El mantenedor (o quien robe su cuenta) decide qué commit es v7
      - uses: actions/checkout@v7  # antipatron
      # ✅ Siempre este commit; el comentario dice qué versión es para las personas
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
```

Un SHA identifica el contenido: si el commit cambia, cambia el SHA. Nadie puede mover tu
referencia. Lo que **no** garantiza:

- **Que el código sea bueno.** Fijas lo que había, sea lo que sea. Por eso cada actualización
  es un PR que revisas.
- **Que la action no descargue otra cosa.** Una action composite puede llamar a otras por
  tag; una de Docker puede usar `image: …:latest`; una de JavaScript puede bajar un binario. El
  SHA cubre el primer nivel.
- **Que el commit sea del repo que crees.** Lo ves ahora.

### Commits impostores

GitHub guarda los objetos de un repo y de todos sus forks en la misma red. Un commit que solo
existe en un fork de `actions/checkout` puede resolverse también como
`actions/checkout@<ese-sha>`. Un atacante abre un fork, sube un commit malicioso y propone un
PR a tu repo que "actualiza" el SHA de `actions/checkout`. El prefijo `actions/checkout`
parece de fiar; el código es suyo.

Dos defensas:

- **Nunca copies un SHA** de un PR, de un blog o de otro repo. La regla 1 del bootcamp te
  pide resolverlo con `scripts/resolve-sha.sh`, que pregunta al repo oficial por un tag.
- **La auditoría `impostor-commit` de zizmor** comprueba que cada SHA pertenece a una rama o a
  un tag del repo nombrado, no solo de su red de forks. Es una auditoría online: necesita
  `GH_TOKEN` (archivo 07).

Las otras auditorías online de zizmor vigilan la misma frontera: `ref-confusion` (una rama y un
tag con el mismo nombre), `ref-version-mismatch` (el comentario `# vX` no corresponde al SHA),
`stale-action-refs`, `known-vulnerable-actions` y `archived-uses`.

_Verificado con zizmor 1.31.1 y ubuntu-24.04, noviembre de 2026._

### Releases inmutables

En la Semana 11 publicaste `v1.0.0` de `<tu-org>/actions-tablero` como release inmutable: el
tag ya no se puede mover ni borrar, y `gh release verify` lo comprueba. Es la otra mitad del
problema, vista desde el mantenedor: **tú como autor** garantizas que el tag no cambia. Como
consumidor sigues fijando por SHA, porque no controlas si las actions de terceros publican
releases inmutables.

## 3. Cómo se usa

### Dependabot para tablero

`.github/dependabot.yml` no es un workflow: lo lee Dependabot, no el runner. Abre PRs con las
actualizaciones según el ecosistema y el directorio:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    cooldown:
      default-days: 7
    groups:
      actions:
        patterns: ["*"]
  - package-ecosystem: uv
    directory: /api
    schedule:
      interval: weekly
    cooldown:
      default-days: 7
  # "npm" es el nombre del ecosistema; Dependabot lo usa también para pnpm-lock.yaml.
  - package-ecosystem: npm
    directory: /web
    schedule:
      interval: weekly
    cooldown:
      default-days: 7
```

Tres decisiones:

- **`package-ecosystem: npm` para `web`.** Es el nombre del ecosistema, no el CLI: Dependabot
  lo usa también para proyectos con `pnpm-lock.yaml` y actualiza ese lockfile. Es la única
  aparición de `npm` que admite el bootcamp.
- **`cooldown.default-days: 7`.** Dependabot no propone una versión hasta que lleva 7 días
  publicada. Una release comprometida suele detectarse y retirarse en ese plazo; con cooldown,
  ni te llega. Es el mismo criterio que hizo que el bootcamp siguiera en `codeql-action`
  v4.39.1 cuando salió la v4.39.2 el 2026-11-03. Además de `default-days` existen
  `semver-major-days`, `semver-minor-days` y `semver-patch-days`, e `include` y `exclude` para
  aplicarlo a unas dependencias sí y a otras no. Solo afecta a las version updates, no a las
  security updates.
- **`groups` con `patterns: ["*"]` en `github-actions`.** Un solo PR con todas las actions de
  la semana en lugar de uno por action.

Sin `cooldown`, Dependabot aplica 3 días. zizmor (`dependabot-cooldown`) avisa con 3 o 4 días
y calla con 7.

_Verificado con la referencia de opciones de Dependabot, zizmor 1.31.1 y ubuntu-24.04,
noviembre de 2026._

`schedule.interval` admite `daily`, `weekly`, `monthly`, `quarterly`, `semiannually`, `yearly`
y `cron`. Semanal es suficiente para `tablero`.

### Un PR de Dependabot que actualiza una action

Dependabot entiende el pinning por SHA. Si encuentra:

```yaml
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
```

y sale una versión nueva, propone **otro SHA y reescribe el comentario** con el tag nuevo. Tú
revisas tres cosas en el PR: que el SHA pertenece al repo oficial (`impostor-commit` en el CI
lo comprueba), las notas de la release y que el CI pasa.

Listas solo esos PR con `gh pr list --app dependabot`.

### Lockfiles de workflows

GitHub tiene una forma de fijar todo de una vez: un `.github/workflows/actions.lock` que
registra, por cada `uses:`, el ref, el commit, el `owner_id` y el `repo_id`. Lo genera la
extensión `gh extension install github/gh-actions-lock` con `gh actions-lock`, y
`gh actions-lock --verify` comprueba que los workflows coinciden con el lockfile. Registrar
`owner_id` y `repo_id` cierra también el caso de un repo borrado y recreado con el mismo nombre.

Dos límites: **no cubre las llamadas a reutilizables**, y está documentado para GitHub
Enterprise Cloud. En una org gratuita no se practica, así que `tablero` sigue con SHA y
Dependabot. Si llegas a una empresa que lo usa, el modelo es el mismo: la referencia apunta a
un contenido concreto y cada cambio pasa por un PR.

_Verificado con la documentación de GitHub y ubuntu-24.04, noviembre de 2026._

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `uses: owner/repo@v7` o `@main` | El commit lo decide otro, en cualquier momento | SHA de 40 caracteres y tag en comentario |
| Copiar un SHA de un PR o de otro repo | Puede ser un commit impostor de un fork | `scripts/resolve-sha.sh` |
| SHA fijado sin Dependabot | Fallos conocidos y runtimes retirados para siempre | `package-ecosystem: github-actions` |
| Fusionar PRs de Dependabot sin leerlos | El cooldown reduce el riesgo, no lo elimina | Notas de la release y CI en verde |
| Sin `cooldown` | Te llega una release comprometida el primer día | `default-days: 7` |
| Confiar en el comentario `# vX` | Es texto: nadie obliga a que coincida | `ref-version-mismatch` en zizmor online |
| Pensar que el SHA cubre lo que la action descarga | Composite y Docker pueden tirar de tags | Revisar el `action.yml` en ese SHA |

## 5. Trucos

- **Qué tag corresponde a un SHA** del repo oficial:
  `gh api repos/actions/checkout/git/matching-refs/tags/v7 --jq '.[] | [.ref, .object.sha] | @tsv'`.
  Si el SHA de tu `uses:` no aparece, desconfía.
- **Qué hay dentro de una action antes de añadirla**:
  `gh api 'repos/actions/labeler/contents/action.yml?ref=<sha>' --jq .content | base64 -d`. Mira
  `runs.using` y si llama a otras actions.
- **Cuenta las referencias externas de un repo**:
  `grep -hoE 'uses: [^.][^ ]+' .github/workflows/*.yml | sort | uniq -c`. Cuantas menos, menos
  frontera.

## 📚 Recursos Adicionales

- [GitHub Docs: Dependabot options reference](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference)
- [GitHub Docs: Secure use reference, third-party actions](https://docs.github.com/en/actions/reference/security/secure-use)
- [zizmor: impostor-commit](https://docs.zizmor.sh/audits/#impostor-commit)
- [github/gh-actions-lock](https://github.com/github/gh-actions-lock)

## ✅ Checklist de Verificación

- [ ] Sé qué garantiza un SHA y tres cosas que no garantiza
- [ ] Sé explicar un commit impostor y cómo lo detecta zizmor
- [ ] Sé escribir `dependabot.yml` para `github-actions`, `uv` y pnpm
- [ ] Sé por qué el ecosistema de pnpm se llama `npm` en Dependabot
- [ ] Sé para qué sirve `cooldown` y qué valor usa `tablero`
- [ ] Sé qué cambia Dependabot en un `uses:` fijado por SHA
- [ ] Sé qué es `actions.lock` y por qué no se practica en una org gratuita

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Caché y artefactos envenenados](05-cache-y-artefactos-envenenados.md) | [Análisis estático: zizmor y CodeQL](07-analisis-estatico-zizmor-y-codeql.md) |
