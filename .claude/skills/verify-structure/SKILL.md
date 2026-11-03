---
name: verify-structure
description: Comprueba que una semana del bootcamp GitHub Actions está completa, bien enlazada y verificable antes de marcarla ✅. Úsalo al terminar una semana o antes de un commit que cree, mueva o renombre contenido.
allowed-tools: Bash(bash scripts/check-repo.sh) Bash(./scripts/check-week.sh *) Bash(jq*) Bash(wc *) Bash(actionlint *) Read Grep Glob
---

# Verificar estructura de una semana

## 1. Lo automático primero

```bash
bash scripts/check-repo.sh
./scripts/check-week.sh NN
```

El primer script revisa:

- Nombres `week-NN-slug`.
- Enlaces relativos.
- Navegación en el README y al pie de cada archivo.
- SVG huérfanos.
- `checks.json` válido.
- Cabecera de los `.sh`.
- Teoría de 200-300 líneas.
- Que no exista `solution/`.
- Imágenes sin tag o con `:latest`.
- `uses:` sin SHA, `ubuntu-latest`.
- Voseo, pip, npm, MySQL, `docker-compose`.
- Workflows del starter que no pasan actionlint.

Las reglas de contenido solo se aplican a las semanas marcadas ✅ en `bootcamp/README.md`. Para revisar una semana que aún no está publicada, márcala ✅ en local y córrelo.

`check-week.sh NN` se pasa dos veces contra el repo privado de pruebas del autor (con `REPO` y `APP_DIR` apuntando a él):

- Con la capa **resuelta** subida y su run terminado: todo en verde.
- Con el `starter/` tal como se entrega: al menos un check en rojo.

## 2. Archivos que tienen que existir

```
week-NN-slug/
├── README.md · rubrica-evaluacion.md · checks.json
├── 0-assets/*.svg                       ← todos enlazados, incluido NN-tablero-capa-NN.svg
├── 1-teoria/NN-*.md
├── 2-practicas/NN-*.md                  ← planos, 200-380 líneas
├── 3-proyecto/README.md + starter/
├── 4-recursos/{ebooks-free,videografia,webgrafia}/README.md
└── 5-glosario/README.md
```

## 3. Las 11 secciones del README, en orden

`# Semana NN — Tema` · gancho · 🎯 Objetivos · 📋 Prerrequisitos · 🗂️ Estructura · 📝 Contenidos · ⏱️ Distribución del Tiempo (10 horas) · [una sección temática opcional] · 🎩 Trucos y atajos · 📌 Entregables · ✅ Verificación · 🔗 Navegación.

## 4. Lo que los scripts no ven

- Las horas suman 10 exactas y cuadran con las tablas de Contenidos.
- Cada paso de práctica tiene **Por qué / Comando / Verifica**, con la salida esperada comentada.
- Las prácticas cierran con `## ✅ Resultado` y `## 🧯 Si algo sale mal`.
- No hay `# TODO:` en prácticas. Los `TODO N` del starter están numerados en toda la semana.
- `3-proyecto/README.md` copia literal las `description` de `checks.json`.
- La rúbrica tiene 10 preguntas con `<details>` y la tabla de penalizaciones.
- Los trucos están replicados en `docs/trucos-github-actions.md`.
- Los recursos llevan justificación y fecha de comprobación.
- Cada SVG explica un mecanismo que la prosa no deja ver: ninguno de relleno, ningún mecanismo central sin diagrama.
- Todo YAML pasa el skill `verify-workflows`.

## 5. Informe

Lista de lo que falta, con su ruta. Sin elogios ni contenido propuesto: solo lo que impide marcar la semana ✅.
