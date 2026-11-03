"""API HTTP de tablero."""

from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Response
from pydantic import BaseModel, Field

from tablero.db import Task, TaskRepository, get_tasks
from tablero.settings import app_version

app = FastAPI(title="tablero", version=app_version())

Tasks = Annotated[TaskRepository, Depends(get_tasks)]


class TaskIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)


class TaskPatch(BaseModel):
    done: bool


@app.get("/api/health")
def health() -> dict[str, str]:
    # No toca la base: el healthcheck dice si el proceso vive, no si PostgreSQL responde.
    return {"status": "ok", "version": app_version()}


@app.get("/api/tasks")
def list_tasks(tasks: Tasks) -> list[Task]:
    return tasks.list()


@app.post("/api/tasks", status_code=201)
def create_task(body: TaskIn, tasks: Tasks) -> Task:
    return tasks.create(body.title.strip())


@app.patch("/api/tasks/{task_id}")
def update_task(task_id: int, body: TaskPatch, tasks: Tasks) -> Task:
    task = tasks.set_done(task_id, body.done)
    if task is None:
        raise HTTPException(status_code=404, detail="Tarea no encontrada")
    return task


@app.delete("/api/tasks/{task_id}", status_code=204)
def delete_task(task_id: int, tasks: Tasks) -> Response:
    if not tasks.delete(task_id):
        raise HTTPException(status_code=404, detail="Tarea no encontrada")
    return Response(status_code=204)
