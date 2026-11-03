export interface Task {
  id: number;
  title: string;
  done: boolean;
  created_at: string;
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(path, {
    ...init,
    headers: { "Content-Type": "application/json", ...init?.headers },
  });
  if (!response.ok) {
    throw new Error(`${init?.method ?? "GET"} ${path}: ${response.status}`);
  }
  return response.status === 204 ? (undefined as T) : response.json();
}

export const api = {
  list: () => request<Task[]>("/api/tasks"),
  create: (title: string) =>
    request<Task>("/api/tasks", { method: "POST", body: JSON.stringify({ title }) }),
  setDone: (id: number, done: boolean) =>
    request<Task>(`/api/tasks/${id}`, { method: "PATCH", body: JSON.stringify({ done }) }),
  remove: (id: number) => request<void>(`/api/tasks/${id}`, { method: "DELETE" }),
};

export function pendingCount(tasks: Task[]): number {
  return tasks.filter((task) => !task.done).length;
}
