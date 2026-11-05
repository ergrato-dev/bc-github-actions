"""oidc-verifier: lee un token OIDC por stdin, lo verifica e imprime sus claims en Markdown.

El token llega por stdin y nunca por argumento: un argumento queda visible en `ps` y en el
historial del shell. Lo que se imprime son claims, que no son secretos; el token no se imprime.
"""

import argparse
import sys
from pathlib import Path

from oidc_verifier.core import ISSUER, VerificationError, load_jwks, verify

# Los claims que ayudan a entender quién pidió el token; el resto sigue en el token.
SHOWN_CLAIMS = (
    "sub",
    "aud",
    "repository",
    "repository_id",
    "environment",
    "ref",
    "event_name",
    "job_workflow_ref",
    "runner_environment",
)


def _parse_claim(raw: str) -> tuple[str, str]:
    name, sep, value = raw.partition("=")
    if not sep or not name:
        raise argparse.ArgumentTypeError(f"se esperaba CLAIM=VALOR, llegó {raw!r}")
    return name, value


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="oidc-verifier",
        description="Verifica por stdin un token OIDC de GitHub Actions.",
    )
    parser.add_argument("--audience", required=True, help="aud que debe traer el token")
    parser.add_argument("--sub", required=True, help="sub exacto que se acepta")
    parser.add_argument(
        "--claim",
        action="append",
        type=_parse_claim,
        default=[],
        metavar="CLAIM=VALOR",
        help="claim adicional que se exige; repetible",
    )
    parser.add_argument("--issuer", default=ISSUER, help="emisor esperado")
    parser.add_argument("--jwks-file", type=Path, help="claves públicas en un archivo (tests)")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    token = sys.stdin.read().strip()
    if not token:
        print("rechazado: no llegó ningún token por stdin", file=sys.stderr)
        return 1
    try:
        jwks = load_jwks(args.issuer, args.jwks_file)
        payload = verify(
            token,
            jwks=jwks,
            audience=args.audience,
            sub=args.sub,
            claims=dict(args.claim),
            issuer=args.issuer,
        )
    except VerificationError as exc:
        print(f"rechazado: {exc}", file=sys.stderr)
        return 1

    print("| Claim | Valor |")
    print("|---|---|")
    for name in SHOWN_CLAIMS:
        print(f"| `{name}` | `{payload.get(name, '')}` |")
    return 0


if __name__ == "__main__":
    sys.exit(main())
