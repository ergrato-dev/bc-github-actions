"""Las comprobaciones que hace un proveedor de nube antes de cambiar un token OIDC por credenciales.

Firma contra las claves públicas del emisor, emisor, audiencia, caducidad y, por último, la
política de confianza: el `sub` exacto y los claims que se exijan. Si cualquiera falla, no hay
credenciales.
"""

import json
import urllib.request
from pathlib import Path
from typing import Any

import jwt

ISSUER = "https://token.actions.githubusercontent.com"

# Margen para relojes desajustados entre el runner y quien verifica. Más margen alarga la vida
# útil de un token robado.
LEEWAY_SECONDS = 30


class VerificationError(Exception):
    """El token no supera alguna comprobación: quien lo presenta no recibe nada."""


def _get_json(url: str) -> dict[str, Any]:
    with urllib.request.urlopen(url, timeout=10) as response:
        return json.load(response)


def load_jwks(issuer: str = ISSUER, jwks_file: Path | None = None) -> jwt.PyJWKSet:
    """Claves públicas del emisor: de su discovery document o, en los tests, de un archivo."""
    if jwks_file is not None:
        return jwt.PyJWKSet.from_dict(json.loads(jwks_file.read_text()))
    config = _get_json(f"{issuer}/.well-known/openid-configuration")
    jwks_uri = config.get("jwks_uri", "")
    # Un discovery que apunta a claves de otro dominio dejaría firmar tokens a cualquiera.
    if not jwks_uri.startswith(f"{issuer}/"):
        raise VerificationError(f"jwks_uri fuera del emisor: {jwks_uri!r}")
    return jwt.PyJWKSet.from_dict(_get_json(jwks_uri))


def verify(
    token: str,
    *,
    jwks: jwt.PyJWKSet,
    audience: str,
    sub: str,
    claims: dict[str, str] | None = None,
    issuer: str = ISSUER,
) -> dict[str, Any]:
    """Devuelve los claims del token si pasa todas las comprobaciones; si no, VerificationError."""
    try:
        kid = jwt.get_unverified_header(token).get("kid")
        key = jwks[kid]
    except (jwt.PyJWTError, KeyError) as exc:
        raise VerificationError(f"ninguna clave del emisor firma este token: {exc}") from exc

    try:
        payload = jwt.decode(
            token,
            key=key,
            # Lista cerrada: nunca el alg que dice la cabecera del propio token.
            algorithms=["RS256"],
            audience=audience,
            issuer=issuer,
            leeway=LEEWAY_SECONDS,
            options={"require": ["exp", "iat", "nbf", "iss", "aud", "sub"]},
        )
    except jwt.PyJWTError as exc:
        raise VerificationError(f"token inválido: {exc}") from exc

    # La política de confianza: igualdad exacta, sin comodines.
    if payload["sub"] != sub:
        raise VerificationError(f"sub {payload['sub']!r} no es el esperado {sub!r}")
    for name, expected in (claims or {}).items():
        actual = payload.get(name)
        if str(actual) != expected:
            raise VerificationError(f"claim {name}={actual!r}, se exige {expected!r}")
    return payload
