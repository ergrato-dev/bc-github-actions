# ADR: Organización gratuita, repo público y coste cero

**Estado:** aceptada. El spike de validación de la plataforma está pendiente (ver abajo).
**Fecha:** 2026-11-02

## Contexto

GitHub Actions no se aprende en local: un workflow solo se ejecuta desde `.github/workflows/` en la
raíz de un repo de GitHub. El laboratorio tiene que cumplir tres condiciones:

- **Que cueste 0 €** durante las 20 semanas.
- **Que permita practicar lo que es de organización**: políticas de actions, runner groups,
  workflow templates, rulesets de organización, merge queue y repos centrales de CI.
- **Que no enseñe malos hábitos de seguridad** por comodidad, sobre todo con runners propios.

## Decisión

1. **Cada alumno crea una organización gratuita `<tu-org>`** en la Semana 01 y dentro el **repo
   público `<tu-org>/tablero`**. Una cuenta personal no tiene políticas de actions, runner groups
   ni rulesets de organización: las semanas 11, 15 y 18 se quedarían sin práctica.
2. **El repo es público.** Los runners alojados estándar son gratuitos e ilimitados en repos
   públicos, y GHCR no cobra por paquetes públicos. Ver [`modelo-de-costes.md`](modelo-de-costes.md).
3. **El alumno no trabaja en un fork del bootcamp.** Los workflows del bootcamp y los suyos se
   mezclarían, y los forks tienen Actions deshabilitado por defecto.
4. **El despliegue va a kind en la máquina del alumno** (S16-20), con runners de ARC dentro del
   mismo clúster. Sin cuenta en la nube y sin tarjeta.
5. **OIDC se practica con el emisor real de GitHub** (`https://token.actions.githubusercontent.com`)
   y un verificador propio (`tools/oidc-verifier/`, S13). La federación con AWS, GCP y Azure va en
   un anexo opcional.
6. **Runner propio blindado.** GitHub desaconseja runners propios en repos públicos porque un PR
   desde un fork podría ejecutar código en tu máquina. Se mitiga con cuatro medidas obligatorias:
   - Runner **efímero** (JIT o ARC): un job, un runner, y se destruye.
   - **Runner group** restringido al repo `tablero` y a workflows concretos.
   - Jobs `self-hosted` **solo** en `push` a `main`, `workflow_dispatch` o un environment
     protegido. Nunca en `pull_request`.
   - **Aprobación obligatoria** de workflows para todos los contribuidores externos.

## Spike pendiente

Se valida en una org de pruebas antes de escribir la semana indicada. Si algo no está disponible en
el plan gratuito con repo público, se ajusta esa semana antes de escribirla y se anota aquí.

| Qué | Antes de | Resultado |
|---|:--:|---|
| Scopes de `gh` necesarios para leer políticas de actions, runner groups y rulesets de la org | S11 | ⏳ |
| Política "Require actions to be pinned to a full-length commit SHA" en una org gratuita | S11 | ⏳ |
| Rulesets de organización que exigen workflows, en el plan gratuito | S11 | ⏳ |
| Revisores obligatorios en environments de un repo público de org gratuita | S13 | ⏳ |
| Attestations (`actions/attest`) y `gh attestation verify` en un repo público | S14 | ⏳ |
| Runner JIT en contenedor en WSL2 | S15 | ⏳ |
| ARC con GitHub App en kind, en WSL2 con 8 GB y con 16 GB | S16 | ⏳ |
| Merge queue en un repo público de org gratuita | S18 | ⏳ |
| act con la imagen equivalente a `ubuntu-24.04` | S08 | ⏳ |

## Validado

| Prueba | Resultado |
|---|---|
| `scripts/resolve-sha.sh` contra tags ligeros y anotados | ✅ `actions/checkout v7.0.1` resuelve al mismo SHA que fija bc-makefile |
| Descarga con el digest de la API de releases (`gh release download` + `sha256sum -c`) | ✅ yq, actionlint, uv y pnpm (2026-11-02) |
| pnpm autónomo + `pnpm runtime set node 26 -g` sin npm | ✅ Node 26.13.0 en un `HOME` aislado |
| `zizmor --offline` sobre el CI propio | ✅ sin hallazgos |
| `app/scripts/check.sh` completo: uv, pnpm, imágenes, `docker compose up --wait` y smoke test | ✅ en WSL2 con Docker 29.9.2 (2026-11-02) |
| Tests de integración de la API contra `postgres:17.11-alpine` | ✅ 9 tests, cobertura 96% |
| Imágenes sin root | ✅ API con UID 10001, web con UID 101 |
| `gh run list --commit <sha>` para filtrar por el SHA de `origin/main` en `checks.json` | ✅ existe en gh 2.103.3 |

## Consecuencias

- El alumno necesita crear una organización en la Semana 01. Es gratuita y se hace en dos minutos,
  pero es un paso más que en otros bootcamps.
- Todo lo que el alumno publica es visible. El material insiste desde la S01 en que ningún secreto
  real entra al repo, y en la S13 en cómo rotar uno si pasa.
- `checks.json` necesita leer GitHub además de los archivos: `check-week.sh` exporta
  `GH_REPO` (ver [`autograding.md`](autograding.md)).

---

[← Volver al índice de documentación](README.md)
