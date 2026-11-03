import { type FormEvent, useEffect, useState } from "react";
import { api, pendingCount, type Task } from "./api";

export function App() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [title, setTitle] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.list().then(setTasks, (e: Error) => setError(e.message));
  }, []);

  async function add(event: FormEvent) {
    event.preventDefault();
    if (!title.trim()) return;
    const task = await api.create(title);
    setTasks((current) => [...current, task]);
    setTitle("");
  }

  async function toggle(task: Task) {
    const updated = await api.setDone(task.id, !task.done);
    setTasks((current) => current.map((t) => (t.id === updated.id ? updated : t)));
  }

  async function remove(task: Task) {
    await api.remove(task.id);
    setTasks((current) => current.filter((t) => t.id !== task.id));
  }

  return (
    <main>
      <h1>tablero</h1>
      <p>{pendingCount(tasks)} pendiente(s)</p>
      {error && <p role="alert">{error}</p>}
      <form onSubmit={add}>
        <label htmlFor="title">Nueva tarea</label>
        <input id="title" value={title} onChange={(e) => setTitle(e.target.value)} />
        <button type="submit">Añadir</button>
      </form>
      <ul>
        {tasks.map((task) => (
          <li key={task.id}>
            <label>
              <input type="checkbox" checked={task.done} onChange={() => toggle(task)} />
              {task.title}
            </label>
            <button type="button" onClick={() => remove(task)} aria-label={`Borrar ${task.title}`}>
              ×
            </button>
          </li>
        ))}
      </ul>
    </main>
  );
}
