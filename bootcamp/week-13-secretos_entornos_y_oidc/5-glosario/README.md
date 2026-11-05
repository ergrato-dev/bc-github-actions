# 📖 Glosario — Semana 13

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **`ACTIONS_ID_TOKEN_REQUEST_URL` y `ACTIONS_ID_TOKEN_REQUEST_TOKEN`**: variables que el runner
  pone en el entorno de un job con `id-token: write`: la URL del servicio de tokens y el token
  que autentica la petición. Sin el permiso no existen, y `curl` falla con
  `Could not resolve host: &audience=...`.
- **Audiencia** (*audience*, claim `aud`): para quién se pidió el token. Por defecto es la URL
  del propietario del repo, igual para todos los consumidores; `tablero` pide
  `tablero-verifier` y el verificador la exige.

## B

- **Bypass de administradores** (*Allow administrators to bypass configured protection rules*):
  casilla de la UI de un environment que deja a un administrador saltarse sus reglas. En
  `tablero`, desmarcada.

## C

- **Claim**: cada campo del payload de un JWT. Los estándar (`iss`, `sub`, `aud`, `exp`, `iat`,
  `nbf`, `jti`) los define la RFC 7519; GitHub añade los suyos (`repository_id`, `environment`,
  `ref`, `job_workflow_ref`, `runner_environment`…). No son secretos: se leen; el token no se
  enseña.
- **Credencial estática** (*long-lived credential*): clave de acceso guardada como secreto que
  vale meses y desde cualquier sitio. OIDC la sustituye por un token que caduca en minutos.

## D

- **Documento de descubrimiento** (*OpenID Connect discovery*,
  `.well-known/openid-configuration`): JSON que publica el emisor con su `issuer`, su
  `jwks_uri` y los algoritmos y claims que admite. El verificador lo lee para encontrar las
  claves.

## E

- **Emisor** (*issuer*, claim `iss`): quién firma el token. En Actions,
  `https://token.actions.githubusercontent.com`. Un consumidor que no lo exige acepta tokens de
  otro proveedor OIDC.
- **Enmascarado** (*masking*, *redaction*): sustitución por `***` de los secretos que el runner
  encuentra en el log. Cubre el valor exacto, su base64 y sus escapes de URL, JSON y XML; no
  cubre subcadenas, hashes ni otros jobs. La documentación avisa de que no está garantizado.
- **Environment**: destino de despliegue con nombre (`staging`, `production`) que un job declara
  con `environment:`. Tiene sus propios secretos y variables y reglas de protección que se
  evalúan antes de que el job arranque.

## F

- **Federación de identidad** (*workload identity federation*): mecanismo por el que una nube
  acepta un token OIDC de otro emisor y entrega a cambio credenciales de corta vida. Es lo que
  configuran AWS, Entra ID, Google Cloud o PyPI.
- **Formato inmutable** (*immutable subject format*): `sub` que incluye los IDs numéricos del
  propietario y del repo, `repo:OWNER@OWNER-ID/REPO@REPO-ID:...`. Obligatorio en los repos
  creados desde el 15 de julio de 2026; evita que un repo nuevo con el mismo nombre herede tu
  confianza.

## I

- **`id-token: write`**: permiso que deja a un job pedir un token OIDC. Solo admite `write` o
  `none`, no da acceso a nada por sí mismo y en `tablero` solo lo tienen los dos jobs de
  `deploy-gate`.
- **`include_claim_keys`**: lista de claims con la que se construye un `sub` personalizado.
  `tablero` usa `repo`, `context` y `job_workflow_ref`.

## J

- **`job_workflow_ref`**: claim con el workflow que contiene el job, con su ref:
  `<tu-org>/tablero/.github/workflows/deploy-gate.yml@refs/heads/main`. En un reutilizable es el
  reutilizable. Metido en el `sub`, impide que otro workflow del repo se haga pasar por el tuyo.
- **JWKS** (*JSON Web Key Set*): conjunto de claves públicas del emisor, publicado en su
  `jwks_uri`. El verificador busca en él la clave del `kid` de la cabecera; GitHub las rota, así
  que no se copian a mano.
- **JWT** (*JSON Web Token*): token de tres partes en base64url separadas por puntos: cabecera,
  payload con los claims y firma. El token OIDC de GitHub es un JWT firmado con `RS256`.

## K

- **`kid`** (*key ID*): campo de la cabecera del JWT que dice con qué clave del JWKS se firmó.

## O

- **OIDC** (*OpenID Connect*): estándar de identidad sobre OAuth 2.0. En Actions, el job pide un
  token firmado que dice quién es y un consumidor lo verifica contra su política sin que haya un
  secreto compartido.
- **`OIDC_SUB`**: variable de environment de `tablero` con el `sub` exacto que acepta ese
  environment. No es secreta: el `sub` no lo es.

## P

- **Payload**: parte central del JWT, con los claims. Se lee decodificando solo ese segmento,
  sin mostrar el token entero.
- **`pending_deployments`**: endpoint de un run que lista los environments que esperan
  aprobación y permite aprobarlos o rechazarlos con `environment_ids[]`, `state` y un
  `comment` obligatorio.
- **Plantilla del `sub`** (*subject claim customization*): configuración de repo u org que
  cambia qué claims forman el `sub`. Se fija con
  `PUT repos/{owner}/{repo}/actions/oidc/customization/sub`.
- **Política de confianza** (*trust policy*): condiciones del consumidor sobre el token: emisor,
  audiencia, `sub` y otros claims. Con comodines (`repo:<tu-org>/*`) acepta mucho más de lo que
  crees; se escribe con igualdad exacta.
- **Política de ramas de despliegue** (*deployment branch policy*): regla de un environment con
  las ramas o tags que pueden desplegar en él. En `tablero`, solo `main`; una rama no
  permitida hace fallar el job sin recibir secretos.
- **Precedencia de secretos**: si un nombre existe en varios niveles, gana el más bajo:
  environment sobre repo y repo sobre org. Un secreto que no existe llega como cadena vacía.
- **`prevent_self_review`**: opción de los revisores obligatorios que impide aprobar a quien
  lanzó el despliegue. Activada en equipo; desactivada si eres el único revisor.

## R

- **Regla de protección** (*deployment protection rule*): condición que un environment exige
  antes de arrancar el job: revisores obligatorios, wait timer, ramas permitidas o reglas
  personalizadas.
- **Revisor obligatorio** (*required reviewer*): usuario o equipo, hasta seis, que tiene que
  aprobar el job de un environment. Basta con uno. Mientras espera, el job está en `Waiting` y no
  ocupa runner.
- **RS256**: firma RSA con SHA-256, el único algoritmo que publica y usa el emisor de GitHub. El
  verificador lo fija y no acepta el `alg` de la cabecera.
- **`runner_environment`**: claim que dice si el job corrió en un runner de GitHub
  (`github-hosted`) o propio (`self-hosted`).

## S

- **Secreto de environment** (*environment secret*): secreto que solo reciben los jobs que
  declaran ese environment, y no hasta que pasan sus reglas. Donde vive `DATABASE_PASSWORD`.
- **Secreto de org** (*organization secret*): secreto compartido por varios repos según su
  visibilidad: `all`, `private` o `selected`. Para un repo público como `tablero`, `selected`.
- **Secreto de repo** (*repository secret*): secreto que recibe cualquier job del repo que lo
  referencie, sin más condiciones.
- **`sub`** (*subject*): claim que identifica quién pide el token, por ejemplo
  `repo:ORG/REPO:environment:NAME`. Es lo que casi todas las políticas comparan.

## T

- **Trusted publishing**: publicación en PyPI con un token OIDC en lugar de un token de API; PyPI
  comprueba repo, workflow y environment.

## V

- **Variable de configuración** (*configuration variable*, contexto `vars`): valor no secreto de
  org, repo o environment. Se lee en claro en el log; para lo que no es secreto, mejor que un
  secreto.
- **Visibilidad `selected`**: visibilidad de un secreto o variable de org que lo limita a una
  lista explícita de repos.

## W

- **Wait timer**: regla de un environment que retrasa el arranque del job entre 1 y 43.200
  minutos después de la aprobación.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Índice del bootcamp](../../README.md) |
