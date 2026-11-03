# 🌐 Webgrafía — Semana 03

Documentación oficial y artículos de referencia. Las referencias son para consultar, no para leer de
corrido.

## uv

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Using uv in GitHub Actions](https://docs.astral.sh/uv/guides/integration/github/) | La guía oficial de uv en CI: setup-uv, caché, versiones de Python y `--locked`. Compárala con tu `ci-api.yml` | 2026-11-02 |
| [Locking and syncing](https://docs.astral.sh/uv/concepts/projects/sync/) | Qué hacen `uv lock`, `uv sync`, `--locked` y `--frozen`, y cuándo `uv run` sincroniza solo | 2026-11-02 |
| [Caching](https://docs.astral.sh/uv/concepts/cache/) | Qué guarda la caché de uv y por qué `uv cache prune --ci` antes de guardarla en CI | 2026-11-02 |
| [Python versions](https://docs.astral.sh/uv/concepts/python-versions/) | Cómo uv elige y descarga Python a partir de `.python-version` | 2026-11-02 |
| [Project structure and files](https://docs.astral.sh/uv/concepts/projects/layout/) | Qué es cada archivo de un proyecto uv (`pyproject.toml`, `uv.lock`, `.venv`) y cuáles se comitean | 2026-11-02 |
| [astral-sh/setup-uv](https://github.com/astral-sh/setup-uv) | El README de la action: `version`, `enable-cache`, `cache-dependency-glob` y el resto de inputs. Léelo en el SHA que fijas | 2026-11-02 |

## ruff y pytest

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Ruff](https://docs.astral.sh/ruff/) | Reglas, configuración y diferencias entre `ruff check` y `ruff format` | 2026-11-02 |
| [Ruff: integrations](https://docs.astral.sh/ruff/integrations/) | La sección de GitHub Actions explica `--output-format=github` y las anotaciones en el pull request | 2026-11-02 |
| [The Ruff formatter](https://docs.astral.sh/ruff/formatter/) | Qué hace `ruff format --check` y por qué en CI se comprueba en lugar de formatear | 2026-11-02 |
| [How to mark test functions](https://docs.pytest.org/en/stable/how-to/mark.html) — pytest | Los *markers* como `integration`, y cómo seleccionar o excluir tests con ellos | 2026-11-02 |
| [pytest-cov](https://pytest-cov.readthedocs.io/en/latest/) | `--cov`, `--cov-report=term-missing` y `--cov-fail-under` | 2026-11-02 |
| [coverage.py](https://coverage.readthedocs.io/en/latest/) | La herramienta que hay debajo de pytest-cov: qué cuenta como línea cubierta y cómo medir ramas | 2026-11-02 |
| [Testing dependencies with overrides](https://fastapi.tiangolo.com/advanced/testing-dependencies/) — FastAPI | El `dependency_overrides` con el que los tests unitarios de `tablero` sustituyen PostgreSQL | 2026-11-02 |

## Caché en GitHub Actions

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Dependency caching reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching) | Claves, `restore-keys`, ámbito por rama, límite de 10 GB y expulsión a los 7 días sin uso | 2026-11-02 |
| [actions/cache](https://github.com/actions/cache) | El README de la action genérica de caché que comparas con setup-uv en la práctica 03 | 2026-11-02 |
| [actions/cache: tips and workarounds](https://github.com/actions/cache/blob/main/tips-and-workarounds.md) | Casos raros de la caché: ramas, pull requests de forks y cómo forzar una caché nueva | 2026-11-02 |
| [gh cache](https://cli.github.com/manual/gh_cache) | Listar y borrar cachés desde la terminal (`gh cache list`, `gh cache delete`) | 2026-11-02 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
