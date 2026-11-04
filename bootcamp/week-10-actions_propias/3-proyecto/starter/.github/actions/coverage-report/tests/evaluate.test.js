// evaluate.test.js — capa 10 de tablero. Cópialo a .github/actions/coverage-report/tests/evaluate.test.js.
import assert from "node:assert/strict";
import { test } from "node:test";
import { evaluate } from "../src/evaluate.js";

test("pasa cuando llega al mínimo", () => {
  assert.deepEqual(evaluate({ lines: { pct: 60 } }, 60), { percent: 60, ok: true });
});

test("falla por debajo del mínimo", () => {
  assert.equal(evaluate({ lines: { pct: 59.9 } }, 60).ok, false);
});

test("rechaza un resumen sin total.lines.pct", () => {
  assert.throws(() => evaluate({}, 60), /total\.lines\.pct/);
});
