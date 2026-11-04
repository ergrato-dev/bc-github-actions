# 📖 Glosario — Semana 11

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **Actions permitidas** (*allowed actions*, `allowed_actions`): política de la organización que
  decide qué actions y reutilizables se ejecutan: `all`, `local_only` (solo los de la propia org;
  bloquea también los de GitHub) o `selected` (los de la org más una lista).
- **Attestation de release** (*release attestation*): declaración firmada que GitHub genera al
  publicar una release inmutable, con el tag, el SHA del commit y el digest de cada asset. La
  comprueba `gh release verify`.

## B

- **Borrador de release** (*draft release*): release sin publicar. Se puede cambiar, ella y sus
  assets: las protecciones de una release inmutable solo aplican al publicarla.

## C

- **Cambio incompatible** (*breaking change*): cambio en la interfaz de una action o de un
  reutilizable que puede pasar a rojo a un consumidor que no toca nada: quitar o renombrar un
  input, hacerlo obligatorio, cambiar un default que altera el resultado o pedir más permisos.
  Sube el número mayor.
- **Contexto `job.workflow_*`**: `job.workflow_ref`, `job.workflow_sha`,
  `job.workflow_repository` y `job.workflow_file_path`. Dentro de un reutilizable apuntan a su
  propio archivo; `github.workflow_sha` apunta al llamador.
- **Creador verificado** (*verified creator*, `verified_allowed`): opción de la política que
  permite todas las actions del Marketplace de creadores verificados. Dice quién es el autor, no
  qué hace cada versión: en `tablero` queda en `false`.

## D

- **`$default-branch`**: marcador de una workflow template que GitHub sustituye por la rama por
  defecto del repo al crear el workflow. Es texto, no una expresión.

## P

- **Patrón de actions permitidas** (*allowed actions pattern*, `patterns_allowed`): entrada de la
  lista de la política `selected`: `owner/repo@*`, `owner/*`, una ruta a un reutilizable o una
  exclusión con `!`. El `PUT` sustituye la lista entera.
- **Permisos por defecto del token** (*default workflow permissions*): permisos del
  `GITHUB_TOKEN` en un workflow sin `permissions:`. En la org de `tablero`, `read` y sin poder
  aprobar pull requests (`can_approve_pull_request_reviews: false`).
- **Pinning obligatorio** (*SHA pinning required*, `sha_pinning_required`): política que solo
  deja ejecutar actions fijadas por SHA de 40 caracteres. `$/` cuenta como fijada; los
  reutilizables pueden seguir referenciándose por tag.
- **Política de actions** (*actions policy*): conjunto de ajustes de Actions de la organización
  (actions permitidas, pinning y token por defecto) que se aplica a todos sus repos. Un repo puede
  restringir más, nunca ampliar.
- **Propiedades de plantilla** (*workflow template properties*, `.properties.json`): metadatos de
  una workflow template: `name` y `description` obligatorias; `iconName`, `categories` y
  `filePatterns` opcionales.

## R

- **Referencia self-repository** (*self-repository reference*, `$/`): `uses:` que empieza por
  `$/` y resuelve al repo del archivo que la contiene, en el commit que está corriendo, sin
  checkout. Es lo que permite a un reutilizable del central usar sus propias actions cuando lo
  llama otro repo.
- **Release inmutable** (*immutable release*): release publicada con la inmutabilidad activada:
  su tag queda fijo en el commit y sus assets no cambian. No es retroactiva, y si se borra, ese
  nombre de tag no se puede reutilizar.
- **Repo `.github` de la organización**: repo con nombre especial del que GitHub lee
  configuración común de la org; en su raíz, `workflow-templates/`. En el plan Free tiene que ser
  público.
- **Repo central de CI**: repo cuyo único producto son las actions y los reutilizables de la
  organización, con su CI y sus releases. En el bootcamp, `<tu-org>/actions-tablero`.
- **Ruleset de organización** (*organization ruleset*): conjunto de reglas sobre ramas o tags de
  varios repos de la org. Exige el plan Team o Enterprise; incluye la regla "Require workflows to
  pass before merging".

## S

- **SemVer** (*Semantic Versioning*): versiones `vMAYOR.MENOR.PARCHE`. Parche: arreglo sin tocar
  la interfaz; menor: algo nuevo y opcional; mayor: cambio incompatible.

## T

- **Tag anotado** (*annotated tag*): tag que apunta a un objeto `tag` con autor, fecha y mensaje,
  que a su vez apunta al commit. Se fija el SHA del commit, no el del objeto.
- **Tag ligero** (*lightweight tag*): tag que apunta directamente al commit.
- **Tag mayor flotante** (*floating major tag*): tag como `v1` que el autor mueve en cada release
  de la serie. No puede ser una release inmutable y en la org no se consume: se fija SHA.

## W

- **Workflow exigido** (*required workflow*): workflow de otro repo que un ruleset de
  organización obliga a pasar antes de fusionar. Necesita `pull_request`, `pull_request_target` o
  `merge_group` en `on:`, y sus filtros se ignoran. La antigua función "required workflows" de
  los ajustes de Actions está retirada.
- **Workflow template** (*workflow template*): workflow de partida que la organización ofrece en
  Actions → New workflow desde `workflow-templates/` de su repo `.github`. Se copia una vez: por
  eso es un llamador fino al reutilizable central fijado por SHA.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Índice del bootcamp](../../README.md) |
