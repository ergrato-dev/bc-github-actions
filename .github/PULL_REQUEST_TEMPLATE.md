## 📋 Descripción

<!-- Qué cambia y por qué -->

## 🔗 Issue relacionado

Closes #

## 📁 Alcance

- **Semana**: NN <!-- o "docs", "scripts", "app", "CI propio" -->

## 🎯 Tipo de cambio

- [ ] 🐛 Corrección (algo no funcionaba o era incorrecto)
- [ ] ✨ Contenido nuevo
- [ ] 📚 Mejora de una explicación existente
- [ ] 🔧 Versiones, scripts o CI propio

## ✅ Checklist

- [ ] `bash scripts/check-repo.sh` sale en verde
- [ ] Todo workflow que toco pasa `actionlint` y `zizmor --offline`
- [ ] Toda `uses:` nueva está resuelta con `scripts/resolve-sha.sh` (SHA + `# vX.Y.Z`)
- [ ] `permissions:` mínimos, `runs-on: ubuntu-24.04`, datos no confiables por `env:`
- [ ] Si cambia una versión, cambió primero en `docs/stack-versions.md`
- [ ] Prosa con tuteo; Python con uv, Node con pnpm, PostgreSQL, `docker compose`
- [ ] Diagramas en el `0-assets/` de su semana, tema oscuro y enlazados
- [ ] Commits en Conventional Commits (scope `week-NN` si toca una semana)

## 🧪 Cómo se probó

```bash
# Comandos y resultado
```
