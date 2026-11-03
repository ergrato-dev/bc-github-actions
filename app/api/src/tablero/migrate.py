"""Aplica en orden las migraciones SQL de migrations/ que aún no se aplicaron.

Uso: uv run python -m tablero.migrate
"""

from pathlib import Path

import psycopg

from tablero.settings import database_url

MIGRATIONS = Path(__file__).resolve().parents[2] / "migrations"


def migrate(url: str | None = None) -> list[str]:
    applied: list[str] = []
    with psycopg.connect(url or database_url()) as conn:
        conn.execute(
            "CREATE TABLE IF NOT EXISTS schema_migrations ("
            " name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())"
        )
        done = {row[0] for row in conn.execute("SELECT name FROM schema_migrations")}
        for sql in sorted(MIGRATIONS.glob("*.sql")):
            if sql.name in done:
                continue
            conn.execute(sql.read_text())
            conn.execute("INSERT INTO schema_migrations (name) VALUES (%s)", (sql.name,))
            applied.append(sql.name)
    return applied


if __name__ == "__main__":
    for name in migrate():
        print(f"aplicada {name}")
