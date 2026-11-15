"""Tests de integración: la purga contra un PostgreSQL real (DATABASE_URL)."""

import os
from datetime import UTC, datetime, timedelta

import psycopg
import pytest

from tablero_worker.migrate import migrate
from tablero_worker.purge import purge

pytestmark = pytest.mark.integration

if not os.environ.get("DATABASE_URL"):
    pytest.skip("necesita DATABASE_URL apuntando a PostgreSQL", allow_module_level=True)


@pytest.fixture(scope="module", autouse=True)
def schema():
    migrate()


@pytest.fixture
def conn():
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        conn.execute("TRUNCATE tasks RESTART IDENTITY")
        yield conn


def add(conn, title, done, age_days):
    created = datetime.now(UTC) - timedelta(days=age_days)
    conn.execute(
        "INSERT INTO tasks (title, done, created_at) VALUES (%s, %s, %s)", (title, done, created)
    )


def test_purges_only_old_done_tasks(conn):
    add(conn, "vieja y hecha", True, 40)
    add(conn, "vieja sin hacer", False, 40)
    add(conn, "reciente y hecha", True, 2)

    deleted = purge(conn, datetime.now(UTC) - timedelta(days=30))

    titles = [row[0] for row in conn.execute("SELECT title FROM tasks ORDER BY id")]
    assert deleted == 1
    assert titles == ["vieja sin hacer", "reciente y hecha"]
