"""Configuración por variables de entorno. Nada de valores secretos por defecto."""

import os
from importlib.metadata import version


def database_url() -> str:
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise RuntimeError("Falta DATABASE_URL (ver .env.example)")
    return url


def app_version() -> str:
    # APP_VERSION la fija la imagen al construirse (Semana 06); en local, la del paquete.
    return os.environ.get("APP_VERSION") or version("tablero")
