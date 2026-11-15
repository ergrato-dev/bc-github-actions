"""Borra las tareas hechas cuya fecha de creación es anterior a la retención.

Uso: DATABASE_URL=... RETENTION_DAYS=30 uv run tablero-worker
"""

import os
from datetime import UTC, datetime, timedelta

import psycopg


def retention_days(raw: str | None) -> int:
    # Sin valor, 30 días. Un valor inválido o menor que 1 detiene el worker en vez de
    # borrar más de la cuenta: con 0, la purga se llevaría todas las tareas hechas.
    if raw is None or raw == "":
        return 30
    days = int(raw)
    if days < 1:
        raise ValueError(f"RETENTION_DAYS tiene que ser 1 o más, no {days}")
    return days


def cutoff(now: datetime, days: int) -> datetime:
    return now - timedelta(days=days)


def purge(conn: psycopg.Connection, before: datetime) -> int:
    cur = conn.execute("DELETE FROM tasks WHERE done AND created_at < %s", (before,))
    return cur.rowcount


def main() -> None:
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("Falta DATABASE_URL")
    days = retention_days(os.environ.get("RETENTION_DAYS"))
    with psycopg.connect(url) as conn:
        deleted = purge(conn, cutoff(datetime.now(UTC), days))
    print(f"purgadas {deleted} tareas hechas de hace más de {days} días")


if __name__ == "__main__":
    main()
