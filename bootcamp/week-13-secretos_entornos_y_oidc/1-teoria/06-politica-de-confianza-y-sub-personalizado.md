# Política de confianza y sub personalizado

> OIDC no es más seguro que una contraseña por sí solo. Lo es si la política del otro lado pide
> exactamente lo que debe pedir. Un comodín de más y cualquier rama de tu repo, o cualquier repo
> de tu org, obtiene el acceso de production.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Escribir las condiciones que una política de confianza debe exigir siempre
- Reconocer los comodines que convierten una política en una puerta abierta
- Personalizar la plantilla del `sub` con `include_claim_keys`, en el repo o en la org
- Explicar por qué `job_workflow_ref` en el `sub` ata el acceso a un workflow concreto
- Describir paso a paso lo que comprueba `oidc-verifier` y por qué en ese orden
- Decidir qué va en el `sub` y qué se comprueba como claim aparte

## 1. Qué problema resuelve

Una **política de confianza** es la regla del lado del consumidor: "acepto tokens de este
emisor, con esta audiencia, cuyo `sub` sea este". En AWS es la trust policy de un rol; en Azure,
una federated credential; en GCP, la condición de un pool; en `tablero`, los argumentos de
`oidc-verifier`.

El fallo típico no está en la firma, que la comprueba una librería, sino en lo que se compara.
Esta condición de una trust policy de AWS parece razonable:

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:<tu-org>/*"
}
```

Y acepta **cualquier job de cualquier repo de la org**: un repo de pruebas, un workflow que
alguien escribió ayer, un PR de un colaborador. Solo con añadir `id-token: write` consiguen el rol
de production.

## 2. Cómo funciona

### Lo que toda política exige

| Comprobación | Si falta |
|---|---|
| Firma con una clave del JWKS del emisor | Cualquiera fabrica un token |
| `iss` = `https://token.actions.githubusercontent.com` | Se aceptan tokens de otro proveedor OIDC |
| `aud` = la audiencia propia del consumidor | Un token pedido para otro servicio sirve aquí |
| `exp`, `iat`, `nbf` | Un token filtrado vale para siempre |
| `sub` **exacto** | Ver la tabla siguiente |

### Los comodines peligrosos

| Condición sobre `sub` | Acepta | Riesgo |
|---|---|---|
| `repo:<tu-org>/*` | Cualquier job de cualquier repo de la org | Total |
| `repo:<tu-org>/tablero:*` | Cualquier rama, tag, PR o environment del repo | Una rama de pruebas obtiene production |
| `repo:<tu-org>/tablero:ref:refs/heads/*` | Cualquier rama del repo | Igual, sin PR |
| `repo:<tu-org>/tablero:environment:production` | Cualquier workflow del repo que declare production | Depende de las reglas del environment |
| `sub` exacto con environment y `job_workflow_ref` | Solo `deploy-gate.yml` desde `main` hacia ese environment | El objetivo de `tablero` |

La cuarta fila es la recomendación habitual, y es razonable **si** el environment tiene regla de
ramas y revisores. Aun así, cualquier otro workflow del repo que escriba
`environment: production` produce el mismo `sub`. La quinta lo cierra.

### Personalizar el `sub`

GitHub deja cambiar qué claims componen el `sub`, a nivel de repo o de org, con una lista
`include_claim_keys`. Las claves documentadas: `repo`, `context`, `environment`,
`job_workflow_ref`, `repository_owner`, `repository_owner_id`, `repository_id`,
`repository_visibility` y `repo_property_*`.

`context` es la parte variable del formato clásico: `environment:NAME`, `ref:...` o
`pull_request`. El ejemplo de la documentación, con `["repo", "context", "job_workflow_ref"]`
y en formato clásico, produce:

```text
repo:ORG/REPO:environment:prod:job_workflow_ref:ORG/AUTOMATION/.github/workflows/oidc.yml@refs/heads/main
```

`job_workflow_ref` es el workflow que contiene el job: en `tablero`,
`<tu-org>/tablero/.github/workflows/deploy-gate.yml@refs/heads/main`. Si el job vive en un
reutilizable, es el reutilizable: así una org dice "solo el workflow de despliegue central puede
asumir este rol", aunque lo llamen muchos repos.

Para `tablero`, que está en formato inmutable, lo que **esperas** ver en el job de staging es:

```text
repo:<tu-org>@<id-org>/tablero@<id-repo>:environment:staging:job_workflow_ref:<tu-org>/tablero/.github/workflows/deploy-gate.yml@refs/heads/main
```

La documentación no publica un ejemplo de plantilla personalizada en formato inmutable: la
práctica 03 lo confirma con tu propio token antes de guardarlo en `OIDC_SUB`.

_Verificado con la referencia de OIDC y la API REST de personalización de OIDC de GitHub,
noviembre de 2026._

### La API

```bash
gh api -X PUT 'repos/{owner}/{repo}/actions/oidc/customization/sub' --input - \
  <<< '{"use_default":false,"include_claim_keys":["repo","context","job_workflow_ref"]}'
gh api 'repos/{owner}/{repo}/actions/oidc/customization/sub'
# {
#   "use_default": false,
#   "include_claim_keys": [
#     "repo",
#     "context",
#     "job_workflow_ref"
#   ]
# }
```

| Cuerpo del `PUT` | Efecto |
|---|---|
| `{"use_default": true}` | Formato por defecto |
| `{"use_default": false}` | Usa la plantilla de la org |
| `{"use_default": false, "include_claim_keys": [...]}` | Plantilla propia del repo |

La org tiene su propio endpoint, `PUT /orgs/{org}/actions/oidc/customization/sub`, con
`include_claim_keys`. El cambio afecta a los tokens **nuevos**: una política escrita para el
formato anterior deja de casar en cuanto lo aplicas, así que se cambian a la vez.

## 3. Cómo se usa

### Qué comprueba `oidc-verifier`

`tools/oidc-verifier` lee el token por stdin y lo verifica en este orden; el primer fallo
termina con código 1 y un mensaje `rechazado: ...` en stderr:

1. **Hay token**. Si stdin está vacío: `rechazado: no llegó ningún token por stdin`.
2. **Clave**. Lee el `kid` de la cabecera, descarga el documento de descubrimiento del emisor,
   exige que `jwks_uri` empiece por el emisor y busca el `kid` en el JWKS. Si no está:
   `rechazado: ninguna clave del emisor firma este token: ...`.
3. **Firma y claims estándar**, con PyJWT: algoritmo `RS256` y ningún otro, `aud`, `iss`, y
   `exp`, `iat`, `nbf`, `iss`, `aud` y `sub` obligatorios, con 30 s de margen de reloj. Un fallo:
   `rechazado: token inválido: <error>`, por ejemplo `Audience doesn't match` o
   `Signature has expired`.
4. **`sub` exacto**, por igualdad, sin comodines:
   `rechazado: sub '<real>' no es el esperado '<esperado>'`.
5. **Claims extra** de cada `--claim K=V`, también exactos:
   `rechazado: claim ref='refs/heads/x', se exige 'refs/heads/main'`.

Si todo pasa, sale con 0 e imprime una tabla Markdown `| Claim | Valor |` con `sub`, `aud`,
`repository`, `repository_id`, `environment`, `ref`, `event_name`, `job_workflow_ref` y
`runner_environment`, que el paso añade al resumen del job.

Por qué la lista de algoritmos va cerrada: si el verificador aceptara el `alg` que dice la
cabecera, un atacante podría pedir `none` o un algoritmo simétrico y saltarse la firma. Por qué
el `jwks_uri` debe empezar por el emisor: si no, un documento de descubrimiento manipulado
podría señalar claves de otro sitio.

### El paso de `deploy-gate`

```yaml
      - name: Token OIDC verificado como lo haría la nube
        working-directory: tools/oidc-verifier
        env:
          AUDIENCE: tablero-verifier
          EXPECTED_SUB: ${{ vars.OIDC_SUB }}
        run: |
          uv sync --locked
          curl -sSf -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
              "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=$AUDIENCE" |
            jq -r .value |
            uv run --no-sync oidc-verifier --audience "$AUDIENCE" --sub "$EXPECTED_SUB" \
              --claim runner_environment=github-hosted --claim ref=refs/heads/main \
              >> "$GITHUB_STEP_SUMMARY"
```

La audiencia sale de una sola variable para la petición y la verificación: si divergen, el
verificador rechaza con `Audience doesn't match`. El `sub` esperado viene de `vars.OIDC_SUB`
del environment del job: staging y production tienen cada uno el suyo, y el de uno no vale en
el otro.

### Qué va en el `sub` y qué aparte

| Va en el `sub` | Se comprueba aparte |
|---|---|
| Repo con sus IDs, environment, workflow | `ref`, porque el environment la sustituye en el `sub` |
| Lo que la nube solo sabe comparar en un campo | `runner_environment`, para no aceptar un runner propio |

Si tu consumidor solo sabe comparar el `sub`, todo lo que importe tiene que ir dentro de la
plantilla; si admite condiciones sobre otros claims, como el verificador, puedes repartirlo.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `StringLike` con `repo:<tu-org>/*` | Cualquier repo de la org consigue el rol | `StringEquals` con el `sub` exacto |
| `repo:<tu-org>/tablero:*` | Cualquier rama o PR del repo consigue el rol | Environment en el `sub` y regla de ramas |
| Solo `environment:production` sin `job_workflow_ref` | Otro workflow del repo produce el mismo `sub` | `job_workflow_ref` en la plantilla |
| Política sin condición sobre `aud` | Un token pedido para otro servicio vale | Exigir la audiencia propia |
| Aceptar el `alg` de la cabecera | Permite `none` o algoritmos simétricos | Lista cerrada: `RS256` |
| Cambiar la plantilla del `sub` sin tocar la política | Todos los despliegues fallan de golpe | Cambiar ambas en la misma ventana |
| Comparar el `sub` con una expresión regular propia | Un `.` o un ancla olvidada abre el patrón | Igualdad exacta |

## 5. Trucos

- **Plantilla actual del repo y de la org**: `gh api 'repos/{owner}/{repo}/actions/oidc/customization/sub'`
  y `gh api 'orgs/<tu-org>/actions/oidc/customization/sub'`. Si el repo dice
  `"use_default": false` sin claves, manda la de la org.
- **Prueba el rechazo antes que el éxito**: lanza el verificador con un `--sub` inventado. Si no
  falla, no está verificando.
- **Un `sub` por environment**: `gh variable list --env staging --json name,value` y lo mismo con
  production. Si los dos son iguales, uno está mal.

## 📚 Recursos Adicionales

- [GitHub Docs: OpenID Connect reference, customizing the token claims](https://docs.github.com/en/actions/reference/security/oidc)
- [GitHub Docs: OIDC with reusable workflows](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-with-reusable-workflows)
- [REST API: GitHub Actions OIDC](https://docs.github.com/en/rest/actions/oidc)
- [GitHub Docs: OIDC in Azure](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-azure)
- [GitHub Docs: OIDC in Google Cloud](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-google-cloud-platform)

## ✅ Checklist de Verificación

- [ ] Sé las cinco comprobaciones que exige toda política
- [ ] Sé qué acepta cada comodín de la tabla
- [ ] Sé personalizar el `sub` con `include_claim_keys` y leer la plantilla vigente
- [ ] Sé qué significa `job_workflow_ref` en un job normal y en un reutilizable
- [ ] Sé qué comprueba `oidc-verifier` y qué mensaje da cada fallo
- [ ] Sé qué va en el `sub` y qué se comprueba como claim aparte

---

| ← Anterior | Siguiente → |
|:---|---:|
| [El token OIDC y sus claims](05-el-token-oidc-y-sus-claims.md) | [Secretos de repo, environment y org](../2-practicas/01-secretos-de-repo-environment-y-org.md) |
