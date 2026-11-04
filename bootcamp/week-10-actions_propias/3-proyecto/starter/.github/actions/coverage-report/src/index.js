// index.js — capa 10 de tablero. Cópialo a .github/actions/coverage-report/src/index.js.
import { readFile } from "node:fs/promises";
import * as core from "@actions/core";
import { evaluate } from "./evaluate.js";

async function run() {
  // Estado para el paso post: llega a post.js por $GITHUB_STATE como STATE_started.
  core.saveState("started", String(Date.now()));

  const file = core.getInput("summary-file", { required: true });
  const minimum = Number(core.getInput("minimum"));
  if (!Number.isFinite(minimum)) {
    core.setFailed(`minimum debe ser un número y es '${core.getInput("minimum")}'`);
    return;
  }

  const { total } = JSON.parse(await readFile(file, "utf8"));
  const { percent, ok } = evaluate(total, minimum);

  const head = [{ data: "Métrica", header: true }, { data: "Cobertura", header: true }];
  const rows = ["lines", "statements", "functions", "branches"].map((k) => [k, `${total[k].pct}%`]);
  await core.summary.addHeading("Cobertura de la web", 2).addTable([head, ...rows]).write();

  core.setOutput("percent", String(percent));
  if (!ok) core.setFailed(`Cobertura de líneas ${percent}% por debajo del mínimo ${minimum}%`);
}

run().catch((error) => core.setFailed(error.message));
