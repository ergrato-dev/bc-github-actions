import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { App } from "../src/App";

function mockFetch(responses: unknown[]) {
  const queue = [...responses];
  return vi.fn(async () => new Response(JSON.stringify(queue.shift()), { status: 200 }));
}

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe("App", () => {
  it("muestra las tareas y cuántas quedan pendientes", async () => {
    vi.stubGlobal(
      "fetch",
      mockFetch([[{ id: 1, title: "escribir ci.yml", done: false, created_at: "" }]]),
    );
    render(<App />);
    expect(await screen.findByText("escribir ci.yml")).toBeDefined();
    expect(screen.getByText("1 pendiente(s)")).toBeDefined();
  });

  it("añade una tarea nueva", async () => {
    vi.stubGlobal(
      "fetch",
      mockFetch([[], { id: 7, title: "publicar imagen", done: false, created_at: "" }]),
    );
    render(<App />);
    fireEvent.change(screen.getByLabelText("Nueva tarea"), {
      target: { value: "publicar imagen" },
    });
    fireEvent.click(screen.getByText("Añadir"));
    expect(await screen.findByText("publicar imagen")).toBeDefined();
  });
});
