# 📚 eBooks y material gratuito — Semana 13

Especificaciones y guías largas y gratuitas para profundizar en lo que la teoría resume. Ninguna
es obligatoria. Las RFC y las especificaciones de OpenID son densas: léelas con el payload de tu
propio token al lado, claim por claim.

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [RFC 7519: JSON Web Token (JWT)](https://www.rfc-editor.org/rfc/rfc7519) — IETF | La definición de los claims registrados (`iss`, `sub`, `aud`, `exp`, `nbf`, `iat`, `jti`) que la teoría 05 lee en el token de GitHub | 2026-11-04 |
| [RFC 8725: JSON Web Token Best Current Practices](https://www.rfc-editor.org/rfc/rfc8725) — IETF | Por qué un verificador fija el algoritmo y no se fía del `alg` de la cabecera, y por qué exige la audiencia: los antipatrones de la teoría 06 explicados por el estándar | 2026-11-04 |
| [RFC 7517: JSON Web Key (JWK)](https://www.rfc-editor.org/rfc/rfc7517) — IETF | El formato del JWKS que publica `token.actions.githubusercontent.com` y el papel del `kid` con el que `oidc-verifier` elige la clave | 2026-11-04 |
| [OpenID Connect Discovery 1.0](https://openid.net/specs/openid-connect-discovery-1_0.html) — OpenID Foundation | El documento `.well-known/openid-configuration`, de donde el verificador saca `jwks_uri`, y por qué el emisor tiene que coincidir con el que lo publica | 2026-11-04 |
| [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html) — OpenID Foundation | La especificación del ID token y de su validación. Contexto: GitHub usa el token de OIDC fuera del flujo de login de la especificación, para federar identidades de workloads | 2026-11-04 |
| [Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) — OWASP | Ciclo de vida de un secreto: generación, rotación, revocación y qué hacer tras una fuga. Amplía la parte de respuesta a incidentes de la teoría 02 | 2026-11-04 |
| [CICD-SEC-6: Insufficient Credential Hygiene](https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-06-Insufficient-Credential-Hygiene) — OWASP | El riesgo de CI/CD que esta semana ataca: credenciales de larga vida, demasiado alcance y secretos en logs o artefactos | 2026-11-04 |
| [Study guide for Exam GH-200: GitHub Actions](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/gh-200) — Microsoft Learn | La guía oficial del examen. Repasa los objetivos de secretos, variables, environments y OIDC con la sección "En el examen" del README | 2026-11-04 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Rúbrica de evaluación](../../rubrica-evaluacion.md) | [Videografía](../videografia/README.md) |
