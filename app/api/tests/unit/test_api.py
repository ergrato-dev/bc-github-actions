"""Tests unitarios: la API con un repositorio en memoria, sin PostgreSQL."""

from datetime import UTC, datetime

import pytest
from fastapi.testclient import TestClient

from tablero.db import Task, get_tasks
from tablero.main import app


class FakeTasks:
    def __init__(self) -> None:
        self.rows: dict[int, Task] = {}
        self.next_id = 1

    def list(self) -> list[Task]:
        return list(self.rows.values())

    def create(self, title: str) -> Task:
        task = {"id": self.next_id, "title": title, "done": False, "created_at": datetime.now(UTC)}
        self.rows[self.next_id] = task
        self.next_id += 1
        return task

    def set_done(self, task_id: int, done: bool) -> Task | None:
        if task_id not in self.rows:
            return None
        self.rows[task_id]["done"] = done
        return self.rows[task_id]

    def delete(self, task_id: int) -> bool:
        return self.rows.pop(task_id, None) is not None


@pytest.fixture
def client():
    fake = FakeTasks()
    app.dependency_overrides[get_tasks] = lambda: fake
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_health_reports_version(client, monkeypatch):
    monkeypatch.setenv("APP_VERSION", "9.9.9")
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "version": "9.9.9"}


def test_create_and_list(client):
    created = client.post("/api/tasks", json={"title": "  escribir ci.yml  "})
    assert created.status_code == 201
    assert created.json()["title"] == "escribir ci.yml"
    assert [t["title"] for t in client.get("/api/tasks").json()] == ["escribir ci.yml"]


def test_rejects_empty_title(client):
    assert client.post("/api/tasks", json={"title": ""}).status_code == 422


def test_mark_done(client):
    task_id = client.post("/api/tasks", json={"title": "a"}).json()["id"]
    response = client.patch(f"/api/tasks/{task_id}", json={"done": True})
    assert response.status_code == 200
    assert response.json()["done"] is True


def test_missing_task_is_404(client):
    assert client.patch("/api/tasks/999", json={"done": True}).status_code == 404
    assert client.delete("/api/tasks/999").status_code == 404


def test_delete(client):
    task_id = client.post("/api/tasks", json={"title": "a"}).json()["id"]
    assert client.delete(f"/api/tasks/{task_id}").status_code == 204
    assert client.get("/api/tasks").json() == []
