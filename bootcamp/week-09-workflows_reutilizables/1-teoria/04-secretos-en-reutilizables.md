# Secretos en reutilizables

> Un reutilizable no ve los secretos de quien lo llama salvo que se los pasen. Esa frontera es una
> defensa: decide qué credenciales entran, una a una, y no la abras con `secrets: inherit`.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Declarar los secretos que acepta un reutilizable y pasarlos desde el llamador uno a uno
- Explicar qué parte del `GITHUB_TOKEN` llega sola y por qué `tablero` lo pasa igualmente
- Argumentar por qué `secrets: inherit` no es una costumbre aceptable y cómo lo caza zizmor
- Saber que el `env` del llamador no cruza la llamada, y qué usar en su lugar

## 1. Qué problema resuelve

`_image.yml` tiene que iniciar sesión en GHCR para publicar. Necesita una credencial con
`packages: write`, y esa credencial vive en el llamador. Hay dos formas de que llegue:

- **Pasar todo**: el reutilizable recibe todos los secretos del llamador, los necesite o no.
- **Pasar lo justo**: el reutilizable declara "necesito `registry-password`" y el llamador decide
  qué valor le da.

La primera es cómoda hasta que el reutilizable está en otro repo (Semana 11), lo mantiene otro
equipo o tiene un step comprometido. Entonces todo secreto del llamador está al alcance de código
que no escribiste tú. La segunda convierte los secretos en parte del contrato, igual que los
inputs: se leen en la firma, se revisan en el PR y cada llamador ve qué entrega.

## 2. Cómo funciona

### Declarar secretos en el reutilizable

```yaml
on:
  workflow_call:
    secrets:
      registry-password:
        description: Contraseña o token con permiso de escritura en GHCR
        required: true
```

Dentro del reutilizable el secreto se lee como cualquier otro: `secrets.registry-password`. Si
es `required: true` y el llamador no lo pasa, la llamada no valida; actionlint lo detecta con una
referencia `./`:

```text
images.yml:22:11: secret "registry-password" is required by "./.github/workflows/_image.yml" reusable workflow [workflow-call]
```

### Pasarlos desde el llamador

```yaml
secrets:
  registry-password: ${{ secrets.GITHUB_TOKEN }}
```

El nombre de la izquierda es el del reutilizable; la expresión de la derecha, cualquier secreto
del llamador. Así el reutilizable no depende de cómo se llame el secreto en cada repo: hoy es el
`GITHUB_TOKEN`; mañana puede ser un token de otra registry o el de una GitHub App, y
`_image.yml` no cambia.

### El `GITHUB_TOKEN` llega solo

El `GITHUB_TOKEN` del run (archivo 05) está disponible en el reutilizable sin declararlo:
`github.token` y `secrets.GITHUB_TOKEN` funcionan dentro de `_image.yml` aunque nadie los pase.
Entonces, ¿por qué `images.yml` pasa `registry-password: ${{ secrets.GITHUB_TOKEN }}`?

- **Porque el contrato dice qué credencial usa el login.** Quien lee `_image.yml` ve
  `password: ${{ secrets.registry-password }}` y sabe que esa credencial la decide el llamador.
- **Porque el reutilizable no debería saber de dónde sale.** Si un día publicas en otra registry,
  cambias una línea en el llamador y ninguna en el reutilizable.

### `secrets: inherit`

El job que llama admite, en lugar del mapa, `secrets: inherit`: el reutilizable recibe **todos**
los secretos del llamador. Tiene dos restricciones:

- Solo funciona entre llamadores y reutilizables de la **misma organización o enterprise**.
- Pasa los secretos **solo al llamado directo**. Si ese reutilizable llama a otro, el segundo no
  los recibe salvo que el primero se los pase.

La regla de este bootcamp es la de "Lo que no se enseña como vigente" de `CLAUDE.md`: secretos
declarados uno a uno. `inherit` da a código ajeno secretos que no necesita, y desde el llamador no
puedes ver cuáles usa: la firma del reutilizable deja de servir como revisión. zizmor lo marca:

```text
warning[secrets-inherit]: secrets unconditionally inherited by called workflow
  --> .github/workflows/images.yml:23:11
   |
23 |     uses: ./.github/workflows/_image.yml
   |           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ this reusable workflow
...
26 |     secrets: inherit
   |     ---------------- inherits all parent secrets
   |
   = note: audit confidence → High
   = help: audit documentation → https://docs.zizmor.sh/audits/#secrets-inherit
```

Es un `warning` con la persona por defecto, y sin red: la puerta de `lint-workflows` de la
Semana 08 ya lo bloquea. Verificado con zizmor 1.31.1 y ubuntu-24.04, noviembre 2026.

### El `env` no cruza

Las variables de `env:` a nivel de workflow del llamador **no llegan** al reutilizable, y las del
reutilizable no vuelven al llamador. Cada archivo tiene su propio `env`. Si un valor tiene que
cruzar la frontera, hay tres caminos:

| Necesitas | Usa |
|---|---|
| Un dato que decide el llamador | Un input |
| Un dato que devuelve el reutilizable | Un output |
| Una configuración común a todo el repo o la org, que no es secreta | Una variable de repo, de org o de environment (`vars.*`) |

En `tablero`, llamador y reutilizable viven en el mismo repo, así que `vars.*` vale lo mismo a
los dos lados de la llamada.

## 3. Cómo se usa

`_image.yml` usa el secreto solo en el step que lo necesita, y solo cuando va a publicar:

```yaml
- name: Iniciar sesión en GHCR
  if: ${{ inputs.push }}
  uses: docker/login-action@81c6f93d4bc991e510b342a00b419b3bb4efc5c6 # v4.7.0
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.registry-password }}
```

`images.yml` llama dos veces y pasa el secreto en las dos, de forma explícita:

```yaml
name: images

on:
  push:
    branches: [main]
    paths:
      - "api/**"
      - "web/**"
      - ".github/workflows/images.yml"
      - ".github/workflows/_image.yml"
  pull_request:
    paths:
      - "api/**"
      - "web/**"
      - ".github/workflows/images.yml"
      - ".github/workflows/_image.yml"

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  api:
    name: API
    # El reutilizable pide packages: write; si este job no lo concede, el run no arranca.
    permissions:
      contents: read
      packages: write
    uses: ./.github/workflows/_image.yml # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
    with:
      component: api
      push: ${{ github.event_name != 'pull_request' }}
    secrets:
      registry-password: ${{ secrets.GITHUB_TOKEN }}

  web:
    name: Web
    permissions:
      contents: read
      packages: write
    uses: ./.github/workflows/_image.yml # zizmor: ignore[self-repository] actionlint 1.7.12 no admite $/
    with:
      component: web
      push: ${{ github.event_name != 'pull_request' }}
    secrets:
      registry-password: ${{ secrets.GITHUB_TOKEN }}
```

El `permissions` de cada job lo explica el archivo 05: pasar el token como secreto no le da más
permisos de los que el llamador concede.

### Secretos y logs

Lo que entra por `secrets:` se enmascara en el log del reutilizable igual que en el llamador. Las
reglas no cambian: nunca `echo` de un secreto, nunca `toJSON(secrets)`, y si un step necesita la
credencial en el shell, por `env:` y leída como variable. La credencial de PostgreSQL de los tests
(`cambiame`) no es un secreto: es desechable y vive en el YAML a propósito.

### Secretos que bajan más de un nivel

Si `_image.yml` llamara a su vez a otro reutilizable que necesitara la credencial, tendría que
pasarla otra vez, con su propio `secrets:`. Cada nivel decide qué entrega al siguiente. Con
`inherit` en el primer nivel tampoco llegaría: `inherit` no atraviesa más de una llamada.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `secrets: inherit` "para no pensar" | Todo secreto del llamador queda al alcance del reutilizable; zizmor lo bloquea | Un secreto declarado por credencial que se use |
| Leer `secrets.MI_SECRETO` en el reutilizable sin declararlo | Solo funciona por casualidad con `inherit`; la firma no lo cuenta | Declararlo en `workflow_call.secrets` |
| Usar `github.token` a escondidas en el login del reutilizable | El llamador no ve qué credencial se usa ni puede cambiarla | Un secreto declarado, aunque el valor sea el `GITHUB_TOKEN` |
| Pasar un secreto como input (`with: token: ...`) | Los inputs no son secretos: no se tratan como tales | `secrets:` |
| Poner configuración en el `env:` del llamador esperando que llegue | El `env` no cruza: el reutilizable ve la variable vacía | Input, output o `vars` |
| Login a la registry en todos los runs | Una credencial en uso en runs que no publican nada | `if: ${{ inputs.push }}` en el step de login |

## 5. Trucos

- **`yq '.on.workflow_call.secrets | keys'`** sobre un reutilizable te dice qué credenciales pide
  antes de llamarlo: es la lista que revisas en el PR.
- **`grep -nE '^[^#]*secrets: *inherit' .github/workflows/*.yml`** es la comprobación
  `no-secrets-inherit` de esta semana, y vale como hook local antes del push.
- **El nombre del secreto en el reutilizable describe para qué es** (`registry-password`), no de
  dónde sale (`GITHUB_TOKEN`). Así sigue teniendo sentido cuando cambies la fuente.
- **Un `required: false` con un `if:`** te permite un secreto opcional: el step que lo usa corre
  solo `if: ${{ inputs.push }}`, y el llamador que no publica no tiene que pasar nada.

## 📚 Recursos Adicionales

- [GitHub Docs: Reusing workflow configurations, secretos](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations)
- [GitHub Docs: Reuse workflows, pasar secretos](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
- [zizmor: auditoría `secrets-inherit`](https://docs.zizmor.sh/audits/#secrets-inherit)
- [Reglas de seguridad de workflows del bootcamp](../../../docs/reglas-de-seguridad-de-workflows.md)

## ✅ Checklist de Verificación

- [ ] Sé declarar un secreto en `workflow_call.secrets` y pasarlo con `secrets:`
- [ ] Sé que el `GITHUB_TOKEN` llega solo y por qué `tablero` lo pasa como `registry-password`
- [ ] Sé las dos restricciones de `secrets: inherit` y por qué no lo usamos
- [ ] Sé leer el hallazgo `secrets-inherit` de zizmor
- [ ] Sé que el `env` del llamador no llega al reutilizable y qué usar en su lugar
- [ ] Sé que cada nivel de anidamiento pasa sus secretos al siguiente

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Inputs y outputs](03-inputs-y-outputs.md) | [Contexto, permisos y concurrencia](05-contexto-permisos-y-concurrencia.md) |
