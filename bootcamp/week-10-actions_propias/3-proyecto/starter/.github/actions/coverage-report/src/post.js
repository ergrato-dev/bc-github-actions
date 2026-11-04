// post.js — capa 10 de tablero. Cópialo a .github/actions/coverage-report/src/post.js.
import * as core from "@actions/core";

// Corre al final del job aunque main haya fallado (post-if por defecto: always()).
// TODO 6: lee con core.getState el estado started que guarda index.js y escribe con core.info
// cuántos milisegundos han pasado desde entonces.
core.info("coverage-report: post sin implementar");
