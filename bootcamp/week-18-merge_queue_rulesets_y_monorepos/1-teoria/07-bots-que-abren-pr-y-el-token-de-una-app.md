# Bots que abren PR y el token de una App

> Con `main` cerrado a todo lo que no sea un PR con `ci-gate` en verde, el PR de release de
> release-please también tiene que pasar `ci-gate`. Con `GITHUB_TOKEN` no lo consigue solo.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué runs crea un PR que abre o actualiza `GITHUB_TOKEN`, y por qué
- Comparar las salidas: aprobar a mano, un PAT o el token de una GitHub App
- Generar un token de instalación con `actions/create-github-app-token` y pasárselo a una action
- Guardar la clave privada de la App donde solo la vea el job que la necesita
- Explicar por qué "Allow GitHub Actions to create and approve pull requests" vuelve a `false`

## 1. Qué problema resuelve

Desde la [Semana 14](../../week-14-releases_cadena_de_suministro_y_attestations/1-teoria/01-versionado-semantico-y-release-please.md),
release-please abre y mantiene el PR de release con `GITHUB_TOKEN`. Para dejarle crear PR
activaste `can_approve_pull_request_reviews=true` en la org y en el repo.

Hasta ahora daba igual que el CI no corriera en ese PR: lo fusionabas igual. Con el ruleset de
esta semana, no. El PR de release necesita `ci-gate` en verde y pasar por la cola como
cualquier otro. Y `ci-gate` no aparece.

## 2. Cómo funciona

### Los eventos de `GITHUB_TOKEN` no crean runs

Ya lo viste en la Semana 14 y en la 17: "events triggered by the `GITHUB_TOKEN` will not create a
new workflow run". Es la protección de GitHub contra los bucles: un workflow que hace push no
dispara otro que hace push, y así sin fin. Las excepciones eran `workflow_dispatch` y
`repository_dispatch`, que "always create workflow runs".

### La excepción nueva: runs que esperan aprobación

La documentación del token tiene una tercera excepción, más reciente: "`pull_request` events with
the `opened`, `synchronize`, or `reopened` activity types: when a workflow using `GITHUB_TOKEN`
creates or updates a pull request, the resulting `pull_request` event creates workflow runs in an
**approval-required** state." Y sigue: "a user with write access to the repository can start the
runs by selecting **Approve workflows to run**."

Así que el run de `ci` del PR de release sí se crea, pero se queda parado. Para que `ci-gate`
llegue, tienes que entrar en el PR y pulsar el botón. Y release-please actualiza su PR en cada
push a `main`: cada `feat` o `fix` que fusionas lo vuelve a dejar parado.

| Quién abre o actualiza el PR | Runs de `pull_request` | `ci-gate` |
|---|---|---|
| Tú, con tu cuenta | Se crean y corren | Llega solo |
| Un workflow con `GITHUB_TOKEN` | Se crean en **approval-required** | Solo si alguien con escritura aprueba |
| Un workflow con el token de una App | Se crean y corren, como los de una persona | Llega solo |

### Tres salidas

| Salida | Problema |
|---|---|
| Aprobar los runs a mano cada vez | Trabajo repetido; y aprobar sin mirar enseña a aprobar sin mirar |
| Un PAT de tu cuenta | Credencial de larga vida, con tus permisos en todos tus repos y atada a una persona |
| El token de una GitHub App | Ninguno de los dos: dura una hora como mucho, solo para los repos donde está instalada y solo con los permisos que pides |

Ya creaste una App en la
[Semana 16](../../week-16-actions_runner_controller_en_kind/1-teoria/04-autenticar-arc-con-una-github-app.md)
para que ARC registrara runners. La idea es la misma: una identidad propia, no humana, con
permisos acotados. Esta App es otra, `tablero-release`, con otros permisos: una App, un trabajo.

### Del par de claves al token

Una App tiene un `client-id` público y una clave privada. Con la clave se firma un JWT que
identifica a la App; con el JWT se pide a la API un **token de instalación** para un repo
concreto. Ese token es el que hace el trabajo.

`actions/create-github-app-token` hace los dos pasos en un step:

| Input | Para qué |
|---|---|
| `client-id` | Identifica la App. Sustituye a `app-id`, que está deprecado |
| `private-key` | La clave privada, obligatoria. Desde un secreto |
| `owner`, `repositories` | Para pedir el token sobre otros repos. Sin ellos, el token vale solo para el repo actual |
| `permission-<nombre>` | Pide solo ese permiso, con `read` o `write`. Hay uno por permiso de App |
| `skip-token-revoke` | Para no revocar el token al terminar. No lo quieres |

Devuelve `token`, `installation-id` y `app-slug`. Y tiene un paso `post`: al acabar el job,
**revoca el token**. Aunque alguien lo sacara del runner, dejaría de valer en cuanto termina el job;
por la misma razón no se puede pasar a otro job.

`permission-contents: write` y `permission-pull-requests: write` piden menos de lo que la App
tiene instalado: el token lleva solo lo que el step declara. Si un día la App gana permisos para
otro uso, este token no los hereda.

Es una action de `actions/*`: la política de la org de la Semana 11 (`github_owned_allowed=true`)
ya la permite sin tocar la lista de actions seleccionadas.

_Verificado con actions/create-github-app-token@v3.3.0, googleapis/release-please-action@v5.0.0 y ubuntu-24.04, noviembre de 2026._

## 3. Cómo se usa

### El job `release-please`

```yaml
  release-please:
    name: Release PR o release
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    # Todo lo escribe el token de la App: GITHUB_TOKEN no necesita nada.
    permissions: {}
    # La clave privada de la App solo existe en este environment, limitado a main.
    environment: release
    outputs:
      created: ${{ steps.release.outputs.release_created }}
      version: ${{ steps.release.outputs.version }}
      tag: ${{ steps.release.outputs.tag_name }}
    steps:
      - name: Token de la GitHub App tablero-release
        id: app-token
        uses: actions/create-github-app-token@64ab729a6294000f5aa4a4bc0b73d1f32bc45510 # v3.3.0
        with:
          client-id: ${{ vars.RELEASE_APP_CLIENT_ID }}
          private-key: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
          permission-contents: write
          # release-please etiqueta su PR con "autorelease: pending/tagged".
          permission-pull-requests: write
      - name: Preparar PR de release o publicar la release
        id: release
        uses: googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0
        with:
          token: ${{ steps.app-token.outputs.token }}
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json
```

Tres cambios respecto a la Semana 14:

- **`permissions: {}`**: `GITHUB_TOKEN` ya no escribe nada en este job. El input `token` de
  release-please vale `github.token` por defecto; al pasarle el de la App, el `GITHUB_TOKEN` no
  se usa.
- **`environment: release`**: la clave privada es un secreto del environment, no del repo. Como
  el environment solo admite `main`, un workflow lanzado desde otra rama no la ve. El
  `client-id` no es secreto: va como variable del environment.
- **El token de la App**: el PR de release lo abre `tablero-release[bot]`. Sus runs de
  `pull_request` corren solos, `ci-gate` llega, y el PR entra por la cola como cualquier otro.

El resto de `release.yml` no cambia. Las imágenes y el lanzamiento de `deploy.yml` siguen con
`GITHUB_TOKEN`: publicar en GHCR y lanzar un `workflow_dispatch` no necesitan disparar nada
por evento.

### La App, mínima

| Ajuste | Valor | Por qué |
|---|---|---|
| Webhook | Desactivado | La App no escucha eventos; solo emite tokens |
| Repository permissions | Contents y Pull requests, `Read and write` | Lo que necesita release-please |
| Dónde se puede instalar | Only on this account | Nadie fuera de tu org puede instalarla |
| Instalación | Only select repositories: `tablero` | El token nunca vale para otro repo |

### Cerrar la puerta que abrió la Semana 14

Con la App abriendo el PR, `GITHUB_TOKEN` ya no necesita crear PR. Y el ajuste que se lo dejaba
hacer es el mismo que le deja **aprobarlos**: la API lo describe como "Whether GitHub Actions can
approve pull requests. Enabling this can be a security risk." Un workflow comprometido con ese
ajuste podría abrir un PR y aprobarlo él mismo: en un equipo con revisión obligatoria (archivo
06), eso es saltarse la revisión.

```bash
gh api -X PUT 'orgs/<tu-org>/actions/permissions/workflow' \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
gh api -X PUT 'repos/<tu-org>/tablero/actions/permissions/workflow' \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
gh api 'repos/<tu-org>/tablero/actions/permissions/workflow' --jq .can_approve_pull_request_reviews
# false
```

Con eso, la comprobación `org-default-token-read` de la Semana 11, que la capa 14 había puesto en
rojo, vuelve a verde.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Aprobar los runs del PR de release cada vez | Trabajo en cada push a `main`; acabas aprobando sin mirar | Token de una App |
| Un PAT clásico como `token` de release-please | Credencial de larga vida con tus permisos en todo | Token de instalación de una App |
| Instalar la App en todos los repos de la org | El token podría pedirse sobre repos que no la necesitan | Solo `tablero` |
| La clave privada como secreto del repo | Cualquier workflow de cualquier rama puede leerla | Secreto del environment `release`, limitado a `main` |
| Sin `permission-*` en el step | Según el README de la action, el token hereda todos los permisos de la instalación | Pedir solo `contents` y `pull-requests` |
| `skip-token-revoke: true` | El token vive hasta caducar, aunque el job haya terminado | Dejar que el `post` lo revoque |
| Dejar `can_approve_pull_request_reviews=true` | Un workflow puede aprobar PR | `false` en org y repo |

## 5. Trucos

- **Quién abrió un PR**: `gh pr view <n> --json author --jq .author.login` devuelve
  `app/<slug-de-tu-app>` para la App (por ejemplo `app/tablero-release`) y `app/github-actions` para `GITHUB_TOKEN`.
- **Qué permisos tiene la instalación**: en los ajustes de la org, entre las GitHub Apps instaladas, `tablero-release` →
  Configure. Ahí ves también en qué repos está instalada.
- **Runs esperando aprobación**: `gh run list --status action_required` lista los runs parados
  que nadie ha aprobado; si aparece el PR de release, algo sigue usando `GITHUB_TOKEN`.

## 📚 Recursos Adicionales

- [GitHub Docs: GITHUB_TOKEN](https://docs.github.com/en/actions/concepts/security/github_token)
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
- [GitHub Docs: Managing GitHub Actions settings for a repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository)
- [GitHub Docs: REST API endpoints for GitHub Actions permissions](https://docs.github.com/en/rest/actions/permissions)

## ✅ Checklist de Verificación

- [ ] Sé qué runs crea un PR abierto o actualizado por `GITHUB_TOKEN`
- [ ] Sé por qué el PR de release no pasaba `ci-gate` solo
- [ ] Sé qué ventajas tiene el token de una App frente a un PAT
- [ ] Sé qué inputs y outputs usa `create-github-app-token` en `release.yml` y qué hace su `post`
- [ ] Sé dónde vive la clave privada y por qué en un environment
- [ ] Sé por qué `can_approve_pull_request_reviews` vuelve a `false` y qué check de la Semana 11 se arregla

---

| ← Anterior | Siguiente → |
|:---|---:|
| [CODEOWNERS y revisión en equipo](06-codeowners-y-revision-en-equipo.md) | [Un solo check para un monorepo](../2-practicas/01-un-solo-check-para-un-monorepo.md) |
