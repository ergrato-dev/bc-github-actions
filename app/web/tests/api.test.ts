import { describe, expect, it } from "vitest";
import { pendingCount, type Task } from "../src/api";

const task = (id: number, done: boolean): Task => ({
  id,
  title: `t${id}`,
  done,
  created_at: "2026-11-02T00:00:00Z",
});

describe("pendingCount", () => {
  it("cuenta solo las tareas sin terminar", () => {
    expect(pendingCount([task(1, false), task(2, true), task(3, false)])).toBe(2);
  });

  it("es 0 sin tareas", () => {
    expect(pendingCount([])).toBe(0);
  });
});
