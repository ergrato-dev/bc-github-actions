"""Aplica el esquema de la API antes de los tests de integración del worker.

El esquema es de la API: el worker no tiene migraciones propias y lee las de api/migrations/.
Por eso un cambio en api/migrations/ también tiene que probar el worker.

Uso: uv run python -m tablero_worker.migrate
"""

import os
from pathlib import Path

import psycopg

# worker/src/tablero_worker/migrate.py -> raíz del monorepo
MIGRATIONS = Path(__file__).resolve().parents[3] / "api" / "migrations"


def migrate(url: str | None = None) -> list[str]:
    applied: list[str] = []
    with psycopg.connect(url or os.environ["DATABASE_URL"]) as conn:
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
