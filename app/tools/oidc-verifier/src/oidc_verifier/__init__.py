"""Verificador del token OIDC de GitHub Actions: la mitad que, en producción, hace la nube."""

from oidc_verifier.core import ISSUER, VerificationError, load_jwks, verify

__all__ = ["ISSUER", "VerificationError", "load_jwks", "verify"]
