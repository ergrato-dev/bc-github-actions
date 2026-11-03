"""Tests de integración: la API contra un PostgreSQL real (DATABASE_URL)."""

import os

import psycopg
import pytest
from fastapi.testclient import TestClient

from tablero.main import app
from tablero.migrate import migrate

pytestmark = pytest.mark.integration

if not os.environ.get("DATABASE_URL"):
    pytest.skip("necesita DATABASE_URL apuntando a PostgreSQL", allow_module_level=True)


@pytest.fixture(scope="module", autouse=True)
def schema():
    migrate()


@pytest.fixture(autouse=True)
def empty_table():
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        conn.execute("TRUNCATE tasks RESTART IDENTITY")


@pytest.fixture
def client():
    return TestClient(app)


def test_migrations_are_idempotent():
    assert migrate() == []


def test_task_roundtrip(client):
    task = client.post("/api/tasks", json={"title": "integrar con PostgreSQL"}).json()
    assert task["id"] == 1
    assert client.patch("/api/tasks/1", json={"done": True}).json()["done"] is True
    assert client.get("/api/tasks").json()[0]["done"] is True
    assert client.delete("/api/tasks/1").status_code == 204
    assert client.get("/api/tasks").json() == []


def test_database_enforces_title_length():
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        with pytest.raises(psycopg.errors.CheckViolation):
            conn.execute("INSERT INTO tasks (title) VALUES ('')")
