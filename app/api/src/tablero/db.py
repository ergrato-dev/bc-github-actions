"""Acceso a PostgreSQL con psycopg. Un repositorio mínimo, sin ORM."""

from collections.abc import Iterator
from typing import Any, Protocol

import psycopg
from psycopg.rows import dict_row

from tablero.settings import database_url

Task = dict[str, Any]


class TaskRepository(Protocol):
    def list(self) -> list[Task]: ...
    def create(self, title: str) -> Task: ...
    def set_done(self, task_id: int, done: bool) -> Task | None: ...
    def delete(self, task_id: int) -> bool: ...


class PostgresTasks:
    def __init__(self, conn: psycopg.Connection) -> None:
        self.conn = conn

    def list(self) -> list[Task]:
        return self.conn.execute(
            "SELECT id, title, done, created_at FROM tasks ORDER BY id"
        ).fetchall()

    def create(self, title: str) -> Task:
        return self.conn.execute(
            "INSERT INTO tasks (title) VALUES (%s) RETURNING id, title, done, created_at",
            (title,),
        ).fetchone()

    def set_done(self, task_id: int, done: bool) -> Task | None:
        return self.conn.execute(
            "UPDATE tasks SET done = %s WHERE id = %s RETURNING id, title, done, created_at",
            (done, task_id),
        ).fetchone()

    def delete(self, task_id: int) -> bool:
        return self.conn.execute("DELETE FROM tasks WHERE id = %s", (task_id,)).rowcount == 1


def get_tasks() -> Iterator[TaskRepository]:
    """Dependencia de FastAPI: una conexión por petición, commit al terminar."""
    with psycopg.connect(database_url(), row_factory=dict_row) as conn:
        yield PostgresTasks(conn)
