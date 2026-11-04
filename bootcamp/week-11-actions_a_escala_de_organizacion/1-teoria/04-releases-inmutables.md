# Releases inmutables

> Fijar por SHA protege al consumidor de un tag que se mueve. Pero el consumidor resolvió ese
> SHA a partir de un tag, y si el tag se movió antes, fijó lo que no debía. Una release
> inmutable cierra ese hueco desde el lado del autor: una vez publicada, su tag no se mueve.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué bloquea una release inmutable y qué no
- Activar la inmutabilidad en un repo y saber cómo se hace para toda la organización
- Publicar una release en dos tiempos, borrador y publicación, y por qué
- Comprobar una release con `gh release verify` y leer el campo `immutable` de la API
- Explicar por qué un tag mayor flotante no puede ser una release inmutable

## 1. Qué problema resuelve

El archivo 03 terminaba con una comprobación: `commits/v1.0.0` tiene que devolver el SHA que
fijas. Si no lo hace, hay dos explicaciones, y una es grave: alguien movió el tag.

Mover un tag es un `git push --force` de una ref. Lo puede hacer cualquiera con permiso de
escritura sobre el repo, por error ("re-etiqueto para incluir el arreglo") o a propósito. Las
consecuencias para un repo central:

- Los consumidores que resolvieron `v1.0.0` **antes** tienen un SHA; los que lo resuelven
  **después**, otro. Los dos comentarios dicen `# v1.0.0`.
- Si el commit nuevo trae código malicioso, todo consumidor que "fija por SHA" pero resuelve el
  SHA el día equivocado lo ejecuta, convencido de estar en `v1.0.0`.

Fijar por SHA no protege del segundo caso, porque el problema ocurre **antes** de fijar.

## 2. Cómo funciona

### Qué bloquea

Con la inmutabilidad activada en el repo, cuando una release se **publica**:

| Qué | Con release inmutable |
|---|---|
| Su tag de Git | Queda bloqueado en su commit: no se puede mover ni borrar mientras la release exista |
| Sus assets | No se pueden modificar ni borrar |
| Su título y sus notas | Se pueden editar: no forman parte de lo que se consume |
| La release entera | Se puede borrar, y después su tag; pero ese nombre de tag ya no se puede reutilizar |

Y además GitHub genera una **attestation de la release**: una declaración firmada que recoge el
tag, el SHA del commit y el digest de cada asset. Es lo que comprueba `gh release verify`.

Tres detalles que importan:

1. **No es retroactiva.** Solo afecta a las releases publicadas después de activarla. Las
   anteriores siguen siendo mutables.
2. **Solo protege lo publicado.** Mientras la release es un borrador, quien tiene permiso puede
   cambiarla, a ella y a sus assets. La ayuda de `gh release create` lo dice expresamente: las
   protecciones "take effect only when the release is published".
3. **Protege la release, no el repo.** Una rama sigue moviéndose; un tag **sin** release
   inmutable sigue pudiendo moverse. La protección va con la release.

### Por qué en dos tiempos

GitHub recomienda crear la release como **borrador**, adjuntar los assets y entonces publicarla.
La razón es el punto 2: una vez publicada, ya no puedes añadir el asset que olvidaste. Al
publicar se congela todo de una vez, y la attestation recoge exactamente lo que había.

`actions-tablero` no publica assets: lo que consumen los demás es el código del commit. El
borrador previo te da igualmente un momento para revisar el tag, el commit y las notas antes de
que dejen de poder cambiar.

### Cómo se activa

- **En un repo**: Settings → sección "Releases" → "Enable release immutability".
- **En toda la organización**: Settings de la org → Repository → General → Releases, con una
  política para todos los repos ("All repositories") o para algunos ("Selected repositories").

En la práctica 01 lo activas en `actions-tablero`, antes de crear `v1.0.0`. Si lo activas
después, `v1.0.0` ya no se puede proteger: tendrías que publicar `v1.0.1`.

### Lo que dice la API

La API de releases devuelve dos booleanos que bastan para saber en qué estado está una:

```bash
gh api repos/<tu-org>/actions-tablero/releases/latest \
  --jq '"\(.tag_name) immutable=\(.immutable) draft=\(.draft)"'
# v1.0.0 immutable=true draft=false
```

`releases/latest` nunca devuelve un borrador: si acabas de crear la release y la ves aquí con
la versión anterior, es que sigue en borrador.

## 3. Cómo se usa

### Publicar `v1.0.0`

Sobre un commit de `main` con el `ci.yml` del central en verde:

```bash
gh release create v1.0.0 --target main --draft \
  --title "v1.0.0" --notes "Primera versión: setup-tablero, coverage-report, sql-lint, _python, _node, _image"
gh release view v1.0.0 --json tagName,targetCommitish,isDraft,isImmutable
gh release edit v1.0.0 --draft=false
```

Si el tag no existe, `gh release create` lo crea a partir de `--target`. Revisa con
`gh release view` que todo es lo que esperas y solo entonces publica: a partir del `edit`, el
tag `v1.0.0` queda fijo en ese commit.

### Comprobar la release

```bash
gh release verify v1.0.0 -R <tu-org>/actions-tablero
```

La salida tiene esta forma (es la de una release real de `cli/cli`):

```text
Resolved tag v2.103.3 to sha1:63837fb778d6a39f02be0ce76ff89f2bc8d74bdc
Loaded attestation from GitHub API
✓ Release v2.103.3 verified!

Assets
gh_2.103.3_checksums.txt	sha256:f756e...
```

La primera línea es la que te interesa para el repo central: el SHA al que resolvió el tag
según la attestation firmada. Tiene que ser el mismo que fijas en `tablero`. Como
`actions-tablero` no adjunta assets, la lista de `Assets` sale corta o vacía.

`gh release verify-asset <tag> <archivo>` es la pareja para assets: comprueba que un archivo que
tienes en local es el que publicó la release. No vale para los zip y tarball de código fuente que
GitHub genera de cada tag.

### Y el tag mayor flotante

Un tag `v1` que se mueve a cada release es justo lo que una release inmutable impide. Si quieres
ofrecerlo, será un tag **sin** release (y por tanto sin protección). En la organización no hace
falta: los consumidores fijan SHA y en la Semana 12 Dependabot propone las subidas.

### Qué protege y qué no

Pensado como un atacante con permiso de escritura en `actions-tablero` (una cuenta robada, un
token filtrado):

| Lo que intenta | Con release inmutable en `v1.0.0` |
|---|---|
| Mover `v1.0.0` a un commit suyo | Bloqueado: el tag está fijo mientras la release exista |
| Borrar la release y volver a crear `v1.0.0` en otro commit | Bloqueado: ese nombre de tag ya no se puede reutilizar |
| Empujar un commit malicioso a `main` | Posible, pero nadie lo ejecuta: los consumidores fijan el SHA de `v1.0.0` |
| Publicar `v1.0.1` con el commit malicioso | Posible. Solo llega a quien suba, y subir es un PR que alguien revisa |

La última fila es la que queda abierta, y no la cierra la inmutabilidad sino la revisión: el PR
que cambia el SHA en `tablero` enseña qué versión entra, y `compare/v1.0.0...v1.0.1` enseña qué
cambia. Las ramas protegidas del central (Semana 18) y los permisos mínimos (Semana 12) reducen
quién puede llegar a publicar.

### Encaje con lo que viene

La attestation de la release prueba qué commit corresponde a un tag. No prueba **cómo** se
construyó un artefacto, ni con qué workflow: eso son las attestations de build y el SBOM de la
Semana 14, sobre las imágenes de `tablero`.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Activar la inmutabilidad después de publicar | No es retroactiva: esa release sigue siendo mutable | Activarla antes de la primera release |
| Publicar directamente y "ya añadiré el asset" | Publicada, no admite assets nuevos | Borrador, assets, revisión y publicación |
| Mover un tag publicado para incluir un arreglo | Con inmutabilidad, no se puede; sin ella, rompe a los consumidores | Un parche nuevo: `v1.0.1` |
| Dar por buena una release en borrador | Un borrador se puede cambiar, a él y a sus assets | Comprobar `draft=false` e `immutable=true` |
| Creer que la release inmutable protege `main` | Solo protege su tag y sus assets | Reglas sobre ramas (Semana 18) |
| Un `v1` flotante como release | Una release inmutable no puede moverse | Tags completos; `v1`, si acaso, sin release |

## 5. Trucos

- **`gh release verify --format json`** devuelve la attestation completa: útil si quieres
  guardar en un resumen de job el commit firmado de la versión que usas.
- **`gh api repos/<tu-org>/actions-tablero/releases --jq '.[] | "\(.tag_name) \(.immutable)"'`**
  lista todas las releases con su estado: si ves alguna `false`, es anterior a activar la
  inmutabilidad.
- **`--verify-tag` en `gh release create`** aborta si el tag no existe ya en el remoto. Úsalo
  cuando creas el tag tú con `git tag` y quieres que la release no invente uno nuevo por error.

## 📚 Recursos Adicionales

- [GitHub Docs: Immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases)
- [GitHub Docs: Preventing changes to your releases](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/preventing-changes-to-your-releases)
- [GitHub CLI: `gh release verify`](https://cli.github.com/manual/gh_release_verify)

## ✅ Checklist de Verificación

- [ ] Sé qué bloquea una release inmutable y qué se puede seguir editando
- [ ] Sé por qué la inmutabilidad no es retroactiva y cuándo activarla
- [ ] Sé por qué se publica en dos tiempos, borrador y publicación
- [ ] Sé leer `immutable` y `draft` de una release con `gh api`
- [ ] Sé qué comprueba `gh release verify` y qué línea comparar con mi SHA fijado
- [ ] Sé por qué un tag mayor flotante no encaja con una release inmutable

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Versionar actions](03-versionar-actions.md) | [Workflow templates](05-workflow-templates.md) |
