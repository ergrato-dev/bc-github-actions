# 🤝 Guía de Contribución

Gracias por tu interés en mejorar el **Bootcamp GitHub Actions Zero to Advanced**. Esta guía dice cómo proponer cambios. Cómo se escribe el contenido está en [`CLAUDE.md`](CLAUDE.md), que es la fuente única de verdad.

## 📜 Código de Conducta

Al participar aceptas el [Código de Conducta](CODE_OF_CONDUCT.md). Reporta comportamientos inaceptables a [conduct@epti.dev](mailto:conduct@epti.dev).

---

## 🎯 Cómo puedes contribuir

| Qué | Dónde |
|---|---|
| Un error en un workflow, un comando o una explicación | [Issue de bug](https://github.com/ergrato-dev/bc-github-actions/issues/new?template=bug_report.md) |
| Una explicación que se puede mejorar | [Issue de documentación](https://github.com/ergrato-dev/bc-github-actions/issues/new?template=docs_improvement.md) |
| Un tema, ejercicio o diagrama nuevo | [Issue de propuesta](https://github.com/ergrato-dev/bc-github-actions/issues/new?template=feature_request.md) |
| Una vulnerabilidad o un secreto expuesto | **En privado**, ver [SECURITY.md](SECURITY.md) |

Una action que cambió de versión o un input que ya no existe es un bug, no una mejora: el material tiene que funcionar el día que lo lees.

---

## 🛠️ Configuración del entorno

```bash
# Fork del repositorio en GitHub, luego:
git clone https://github.com/<tu-usuario>/bc-github-actions.git
cd bc-github-actions
git remote add upstream https://github.com/ergrato-dev/bc-github-actions.git

# Herramientas: versiones exactas en docs/stack-versions.md
./scripts/check-week.sh --doctor
```

Instalación paso a paso en [`docs/setup-entorno.md`](docs/setup-entorno.md).

---

## 📝 Estilo

Las reglas completas están en [`CLAUDE.md`](CLAUDE.md). Lo que más se rompe:

- **Toda `uses:` fijada por SHA con el tag en comentario.** Resuélvelo con `./scripts/resolve-sha.sh <owner>/<repo> <tag>`; nunca escribas ni copies un SHA a mano.
- **`permissions:` mínimos** en la raíz de todo workflow, `runs-on: ubuntu-24.04` y los datos no confiables por `env:`.
- **Tuteo, nunca voseo.** Python con uv, Node con pnpm, PostgreSQL y `docker compose`.
- **Nomenclatura técnica en inglés, documentación y comentarios en español.** Comentarios solo donde dicen qué, para qué o qué impacto tiene; nunca repetidos (ver `CLAUDE.md`, "Nomenclatura y comentarios").
- **Diagramas en SVG** con tema oscuro y sin degradados. Nunca arte ASCII.

### Nomenclatura

| Elemento | Convención | Ejemplo |
|---|---|---|
| Carpeta de semana | `week-NN-tema_en_snake_case` | `week-05-service_containers_y_postgresql` |
| Archivo de teoría o práctica | `NN-tema-en-kebab-case.md` | `03-service-containers.md` |
| Workflow | kebab-case, inglés | `ci-api.yml` |
| Job y step id | kebab-case, inglés | `integration`, `build-image` |
| SVG | `NN-nombre-descriptivo.svg` | `01-red-de-un-service-container.svg` |

---

## 🔄 Proceso de Pull Request

```bash
git switch main && git pull upstream main
git switch -c fix/week-05-healthcheck-flag
```

Commits con [Conventional Commits](https://www.conventionalcommits.org/es/v1.0.0/) en inglés. El scope de una semana es `week-NN`, nunca el slug completo:

```bash
git commit -m "fix(week-05): use pg_isready in the service healthcheck"
git commit -m "docs(setup): pin actionlint 1.7.12 with checksum"
git commit -m "chore(stack): bump actions/checkout to v7.0.1"
```

Abre el PR con el título en Conventional Commits y rellena la plantilla.

---

## ✅ Checklist antes del PR

- [ ] `bash scripts/check-repo.sh` sale en verde
- [ ] Todo workflow que tocas pasa `actionlint` y `zizmor`
- [ ] Toda `uses:` nueva está resuelta con `scripts/resolve-sha.sh`
- [ ] Si cambia una versión, cambió primero en `docs/stack-versions.md`
- [ ] Los commits siguen Conventional Commits
- [ ] Los diagramas están en el `0-assets/` de su semana y enlazados

---

<p align="center">
  <a href="https://github.com/ergrato-dev/bc-github-actions/issues">Reportar Issue</a> •
  <a href="https://github.com/ergrato-dev/bc-github-actions/discussions">Discusiones</a>
</p>
