"""Tests sin red: un emisor falso con su propia clave RSA firma tokens como lo haría GitHub."""

import io
import json
import time

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from oidc_verifier import ISSUER, VerificationError, load_jwks, verify
from oidc_verifier.cli import main

AUDIENCE = "tablero-verifier"
SUB = "repo:acme@1/tablero@2:environment:staging"


def _key() -> rsa.RSAPrivateKey:
    return rsa.generate_private_key(public_exponent=65537, key_size=2048)


@pytest.fixture(scope="module")
def signing_key() -> rsa.RSAPrivateKey:
    return _key()


@pytest.fixture(scope="module")
def jwks_dict(signing_key: rsa.RSAPrivateKey) -> dict:
    jwk = jwt.algorithms.RSAAlgorithm.to_jwk(signing_key.public_key(), as_dict=True)
    return {"keys": [{**jwk, "kid": "k1", "alg": "RS256", "use": "sig"}]}


@pytest.fixture(scope="module")
def jwks(jwks_dict: dict) -> jwt.PyJWKSet:
    return jwt.PyJWKSet.from_dict(jwks_dict)


def make_token(key: rsa.RSAPrivateKey, kid: str = "k1", **overrides: object) -> str:
    now = int(time.time())
    claims = {
        "iss": ISSUER,
        "aud": AUDIENCE,
        "sub": SUB,
        "iat": now,
        "nbf": now,
        "exp": now + 300,
        "repository": "acme/tablero",
        "environment": "staging",
        "runner_environment": "github-hosted",
    }
    claims.update(overrides)
    return jwt.encode(claims, key, algorithm="RS256", headers={"kid": kid})


def test_valid_token_returns_claims(signing_key, jwks):
    payload = verify(make_token(signing_key), jwks=jwks, audience=AUDIENCE, sub=SUB)
    assert payload["environment"] == "staging"


def test_required_claim_matches(signing_key, jwks):
    token = make_token(signing_key)
    claims = {"runner_environment": "github-hosted", "environment": "staging"}
    assert verify(token, jwks=jwks, audience=AUDIENCE, sub=SUB, claims=claims)


@pytest.mark.parametrize(
    ("overrides", "message"),
    [
        ({"aud": "otra-nube"}, "token inválido"),
        ({"iss": "https://evil.example"}, "token inválido"),
        ({"exp": int(time.time()) - 3600}, "token inválido"),
        ({"sub": "repo:acme@1/tablero@2:environment:production"}, "no es el esperado"),
        ({"sub": "repo:acme@1/tablero@2:pull_request"}, "no es el esperado"),
    ],
)
def test_rejects_bad_claims(signing_key, jwks, overrides, message):
    with pytest.raises(VerificationError, match=message):
        verify(make_token(signing_key, **overrides), jwks=jwks, audience=AUDIENCE, sub=SUB)


def test_rejects_missing_required_claim(signing_key, jwks):
    token = make_token(signing_key)
    with pytest.raises(VerificationError, match="claim runner_environment"):
        verify(
            token,
            jwks=jwks,
            audience=AUDIENCE,
            sub=SUB,
            claims={"runner_environment": "self-hosted"},
        )


def test_rejects_token_signed_by_another_key(jwks):
    # Mismo kid, otra clave: así se ve un token fabricado por quien no es el emisor.
    with pytest.raises(VerificationError, match="token inválido"):
        verify(make_token(_key()), jwks=jwks, audience=AUDIENCE, sub=SUB)


def test_rejects_unknown_kid(signing_key, jwks):
    with pytest.raises(VerificationError, match="ninguna clave"):
        verify(make_token(signing_key, kid="otra"), jwks=jwks, audience=AUDIENCE, sub=SUB)


def test_rejects_unsigned_token(jwks):
    token = jwt.encode({"sub": SUB}, None, algorithm="none", headers={"kid": "k1"})
    with pytest.raises(VerificationError):
        verify(token, jwks=jwks, audience=AUDIENCE, sub=SUB)


def test_load_jwks_rejects_foreign_jwks_uri(monkeypatch):
    monkeypatch.setattr(
        "oidc_verifier.core._get_json", lambda url: {"jwks_uri": "https://evil.example/jwks"}
    )
    with pytest.raises(VerificationError, match="fuera del emisor"):
        load_jwks()


def test_cli_accepts_and_prints_claims(signing_key, jwks_dict, tmp_path, monkeypatch, capsys):
    jwks_file = tmp_path / "jwks.json"
    jwks_file.write_text(json.dumps(jwks_dict))
    token = make_token(signing_key)
    monkeypatch.setattr("sys.stdin", io.StringIO(token + "\n"))
    code = main(["--audience", AUDIENCE, "--sub", SUB, "--jwks-file", str(jwks_file)])
    out = capsys.readouterr().out
    assert code == 0
    assert "| `environment` | `staging` |" in out
    assert token not in out


def test_cli_rejects_wrong_sub(signing_key, jwks_dict, tmp_path, monkeypatch, capsys):
    jwks_file = tmp_path / "jwks.json"
    jwks_file.write_text(json.dumps(jwks_dict))
    monkeypatch.setattr("sys.stdin", io.StringIO(make_token(signing_key)))
    code = main(["--audience", AUDIENCE, "--sub", "repo:x", "--jwks-file", str(jwks_file)])
    assert code == 1
    assert capsys.readouterr().err.startswith("rechazado: sub")


def test_cli_rejects_empty_stdin(monkeypatch, capsys):
    monkeypatch.setattr("sys.stdin", io.StringIO(""))
    assert main(["--audience", AUDIENCE, "--sub", SUB]) == 1
    assert "no llegó ningún token" in capsys.readouterr().err


def test_cli_rejects_malformed_claim(capsys):
    with pytest.raises(SystemExit):
        main(["--audience", AUDIENCE, "--sub", SUB, "--claim", "sin-igual"])
