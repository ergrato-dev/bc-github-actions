# oidc-verifier

Hace con el token OIDC de un job lo mismo que un proveedor de nube antes de darle credenciales:
comprueba la firma contra las claves públicas de `https://token.actions.githubusercontent.com`, el
emisor, la audiencia, la caducidad y una política de confianza (el `sub` exacto y los claims que
exijas). Llega en la Semana 13 y lo usa `deploy-gate.yml`.

```bash
uv sync --locked
# El token entra por stdin, nunca como argumento.
uv run --no-sync oidc-verifier --audience tablero-verifier \
  --sub "repo:<tu-org>@<id>/tablero@<id>:environment:staging" \
  --claim runner_environment=github-hosted < token.txt
# | Claim | Valor |
# ...
uv run --no-sync pytest tests/unit
```

Sale con código 1 y `rechazado: <motivo>` en stderr si cualquier comprobación falla.
