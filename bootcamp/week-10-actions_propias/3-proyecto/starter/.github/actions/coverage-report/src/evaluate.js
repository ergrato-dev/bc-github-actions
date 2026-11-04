// evaluate.js — capa 10 de tablero. Cópialo a .github/actions/coverage-report/src/evaluate.js.
// Decide si la cobertura de líneas llega al mínimo. Pura (sin E/S) para poder probarla con node --test.
export function evaluate(total, minimum) {
  // TODO 5: devuelve { percent, ok } con percent = total.lines.pct y ok = percent >= minimum;
  // si total.lines.pct no es un número, lanza un Error que mencione total.lines.pct.
  throw new Error(`evaluate sin implementar (${JSON.stringify(total)}, ${minimum})`);
}
