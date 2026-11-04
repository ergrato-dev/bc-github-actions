# Análisis estático: zizmor y CodeQL

> Las seis teorías anteriores son reglas. Un analizador las comprueba en cada PR sin que nadie
> tenga que acordarse: zizmor falla el CI en segundos, y CodeQL sigue el dato hasta donde se usa.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué añaden a zizmor las auditorías online y qué necesitan para correr
- Elegir persona, severidad y formato de salida de zizmor según dónde lo ejecutes
- Silenciar un hallazgo con una excepción justificada, y saber cuándo no hacerlo
- Escribir el workflow `codeql` que analiza los propios workflows
- Consultar las alertas de code scanning con `gh api`
- Decir qué ve cada herramienta y por qué `tablero` usa las dos

## 1. Qué problema resuelve

Desde la Semana 08 `lint-workflows` corre actionlint y zizmor en modo `--offline`. Esta semana
has visto ataques que ese modo no ve del todo:

- Un SHA que no es del repo que dice ser (archivo 06). Para saberlo hay que preguntar a la
  API de GitHub.
- Una inyección que no está en un `run:`, sino dos steps más abajo, tras pasar por un output
  (archivo 03). Para verla hay que seguir el dato.

zizmor online cubre lo primero. CodeQL, lo segundo. Y los dos te dejan un rastro: un check
rojo en el PR o una alerta en la pestaña **Security**.

## 2. Cómo funciona

### zizmor: offline y online

zizmor lee los YAML y aplica auditorías. Unas solo miran el archivo; otras consultan la API
de GitHub:

| Auditoría | Qué detecta | Modo |
|---|---|---|
| `template-injection` | Expresiones peligrosas en `run:` o `script:` | Offline |
| `excessive-permissions` | Permisos de más, o sin declarar | Offline |
| `artipacked` | `checkout` sin `persist-credentials: false` | Offline |
| `dangerous-triggers` | Todo `pull_request_target` y `workflow_run` | Offline |
| `cache-poisoning` | Caché que puede envenenar lo que publicas | Offline |
| `secrets-inherit`, `overprovisioned-secrets` | Más secretos de los que hacen falta | Offline |
| `unpinned-uses` | `uses:` sin SHA | Offline |
| `github-env` | Escrituras peligrosas en `GITHUB_ENV` o `GITHUB_PATH` | Offline |
| `bot-conditions` | `if:` que confían en el nombre de un bot | Offline |
| `self-hosted-runner` | Runners propios al alcance de PRs | Offline |
| `dependabot-cooldown`, `dependabot-execution` | `dependabot.yml` arriesgado | Offline |
| `impostor-commit`, `ref-confusion`, `ref-version-mismatch` | SHA y tags que no son lo que parecen | Online |
| `known-vulnerable-actions`, `stale-action-refs`, `archived-uses` | Actions con fallos, sin tag o archivadas | Online |

Las online se activan solas **si hay un `GH_TOKEN`** en el entorno (o `--gh-token`), y se
desactivan con `--offline` o `--no-online-audits`. Un token de solo lectura basta: solo lee
tags y commits.

_Verificado con zizmor 1.31.1 y ubuntu-24.04, noviembre de 2026._

### Persona, severidad y formato

- `--persona` elige cuánto ruido aceptas: `regular` (por defecto), `pedantic` o `auditor`.
  En CI, `regular`; cuando revisas un repo a fondo, `auditor`.
- `--min-severity` y `--min-confidence` filtran por gravedad y por certeza del hallazgo.
- `--format` cambia la salida: `plain` para leer en la terminal, `github` para que cada
  hallazgo sea una anotación en el PR, `sarif` para subirlo a code scanning, `json` para
  procesarlo.

### CodeQL para Actions

CodeQL tiene un lenguaje `actions` que analiza `.github/workflows/*.yml` y todo `action.yml`.
A diferencia de zizmor, **sigue el flujo del dato**: de un `github.event.*` a un output, de ahí
a un `env:`, de ahí a un `run:`. Algunas de sus consultas:

| Consulta | Severidad |
|---|:--:|
| `actions/untrusted-checkout/critical` | 9.3 |
| `actions/code-injection/critical` | 9.0 |
| `actions/artifact-poisoning/critical` | 9.0 |
| `actions/cache-poisoning/direct-cache` | 7.5 |
| `actions/code-injection/medium` | 5.0 |
| `actions/missing-workflow-permissions` | 5.0 |
| `actions/unpinned-tag` | 5.0 |

Hay variantes `high` y `medium` de las críticas, y consultas para inyección en variables de
entorno y en `PATH`, secretos en artefactos y exposición excesiva de secretos.

No todas corren por defecto. La suite por defecto solo carga las consultas de precisión `high`
y `very-high`; `actions/code-injection/critical` es `very-high`, pero
`actions/code-injection/medium` es de precisión `medium` y solo entra con
`queries: security-extended` en el step `init`. Por eso una inyección en un workflow de
`pull_request` sin permisos (la variante `medium`) no abre alerta con la configuración por
defecto, y zizmor sí la marca: los dos analizadores se complementan.

Los resultados se suben como SARIF y aparecen en **Security → Code scanning** como alertas.
Una alerta tiene historia: se abre en un commit, sigue abierta mientras el problema exista y
se cierra sola cuando un análisis posterior deja de verla.

_Verificado con github/codeql-action@v4.39.1 y ubuntu-24.04, noviembre de 2026._

## 3. Cómo se usa

### zizmor online en lint-workflows

El job `zizmor` de `lint-workflows` pierde el `--offline` y gana un token:

```yaml
name: lint-workflows
on:
  pull_request:
    paths:
      - ".github/**"
permissions: {}
jobs:
  zizmor:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
      - name: Instalar zizmor
        run: uv tool install zizmor==1.31.1
      - name: zizmor
        # Sin --offline: impostor-commit, known-vulnerable-actions y ref-version-mismatch
        # consultan la API de GitHub con este token de solo lectura.
        env:
          GH_TOKEN: ${{ github.token }}
        run: zizmor --format=github .github/
```

Se ejecuta sobre `.github/`, no sobre `.github/workflows/`, para que entre también
`dependabot.yml`. En local, lo mismo con tu token: `GH_TOKEN=$(gh auth token) zizmor -q .github/`.

Un aviso: online, zizmor necesita poder listar los tags de cada repo que aparece en un `uses:`.
Contra una org que no existe falla con `couldn't list tags for <org>/actions-tablero`. Con tu
org, funciona.

### Excepciones justificadas

Hay hallazgos que son correctos y aun así aceptas, como `dangerous-triggers` en `labeler` y
`pr-report` (archivo 04). Se silencian **en la línea exacta**, con el motivo:

```yaml
  workflow_run: # zizmor: ignore[dangerous-triggers] sin checkout, el artefacto se valida
```

Tres reglas para que una excepción no sea un agujero:

1. **Una auditoría por comentario**, la que corresponde. Nunca un `ignore` genérico.
2. **El motivo dice qué control lo hace seguro**, no "falso positivo".
3. **De vez en cuando, revisa sin excepciones**: `zizmor --no-ignores .github/` enseña todo lo
   silenciado. Si un motivo ya no es cierto, el `ignore` sobra.

También existe un archivo de configuración (`-c`), útil para reglas de todo el repo. Para una
excepción concreta, el comentario en la línea es mejor: viaja con el código y se ve en el diff.

### El workflow codeql

```yaml
name: codeql
on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: "17 6 * * 1"
  workflow_dispatch:
permissions: {}
jobs:
  analyze:
    name: CodeQL de workflows
    runs-on: ubuntu-24.04
    timeout-minutes: 15
    permissions:
      contents: read
      # Sube el SARIF a la pestaña Security → Code scanning.
      security-events: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: github/codeql-action/init@9b3254085494b55a0f7c4c2b3d2d52cc712ce370 # v4.39.1
        with:
          languages: actions
      - uses: github/codeql-action/analyze@9b3254085494b55a0f7c4c2b3d2d52cc712ce370 # v4.39.1
        with:
          category: /language:actions
```

- **`security-events: write`** es lo único que necesita además del checkout. Sin él, el
  análisis termina y la subida falla.
- **`languages: actions`**: solo los workflows. `api` y `web` podrían añadirse como `python` y
  `javascript-typescript`, pero esta semana el objetivo es el CI.
- **El `schedule` semanal** recoge consultas nuevas aunque nadie toque los workflows.
- **`pull_request`** enseña en el PR las alertas que ese PR introduce, antes de llegar a `main`.

### Leer las alertas

```bash
gh api 'repos/{owner}/{repo}/code-scanning/alerts?state=open&tool_name=CodeQL' \
  --jq '.[] | [.rule.id, .most_recent_instance.location.path] | @tsv'
```

Si todavía no ha corrido ningún análisis, la API responde `404` con `no analysis found`. Si
responde `403`, `gh` te sugiere el scope `admin:repo_hook`, pero no hace falta: con el scope
`repo` y siendo dueño del repo basta. Mira primero que estás en el repo correcto.

### Qué ve cada uno

| | zizmor | CodeQL |
|---|---|---|
| Dónde corre | `lint-workflows`, y en local | `codeql`, solo en GitHub |
| Tiempo | Segundos | Minutos |
| Cómo falla | Check rojo en el PR | Alerta en Security; check en el PR |
| Sigue el dato entre steps | No | Sí |
| Consulta la API de GitHub | Sí, online | No |
| Revisa `dependabot.yml` | Sí | No |

Se solapan en lo básico, y está bien: **zizmor es la barrera rápida en cada PR, CodeQL es la
segunda opinión que guarda historia**.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Dejar `--offline` en el CI "porque va más rápido" | Pierdes `impostor-commit` y `known-vulnerable-actions` | `GH_TOKEN: ${{ github.token }}` |
| `# zizmor: ignore[...]` sin motivo | Nadie puede revisar la decisión | El control que lo hace seguro, en el comentario |
| Silenciar con `--min-severity high` para que pase | Esconde los avisos medios para siempre | Arreglar o justificar cada uno |
| `codeql` sin `security-events: write` | El análisis corre y no sube nada | Declararlo en el job |
| Cerrar alertas de CodeQL a mano como "won't fix" | Desaparecen del radar sin cambio en el código | Corregir el workflow y dejar que se cierren solas |
| `zizmor --fix` y commit sin mirar | Es experimental | Revisar el diff siempre |

## 5. Trucos

- **`zizmor --fix` corrige algunos hallazgos solo**, como el `persist-credentials` que falta.
  Es experimental y por defecto aplica solo los arreglos `safe`; revisa el diff antes del commit.
- **Lo que zizmor ve en el PR, como anotaciones**: `--format=github` pone cada hallazgo en la
  línea del archivo en la pestaña **Files changed**.
- **Audita un repo ajeno antes de usar sus actions**: clónalo y pasa
  `zizmor --persona=auditor .` por su `action.yml` y sus workflows.

## 📚 Recursos Adicionales

- [zizmor: Usage](https://docs.zizmor.sh/usage/)
- [zizmor: Audit rules](https://docs.zizmor.sh/audits/)
- [GitHub Docs: About code scanning with CodeQL](https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning-with-codeql)
- [github/codeql: lenguaje `actions`](https://github.com/github/codeql/tree/main/actions)

## ✅ Checklist de Verificación

- [ ] Sé qué auditorías de zizmor son online y qué necesitan para correr
- [ ] Sé elegir `--persona` y `--format` según dónde corre zizmor
- [ ] Sé escribir una excepción con la auditoría exacta y el motivo
- [ ] Sé usar `--no-ignores` para revisar lo silenciado
- [ ] Sé escribir `codeql.yml` con los permisos justos
- [ ] Sé consultar las alertas abiertas con `gh api`
- [ ] Sé decir qué detecta CodeQL que zizmor no ve, y al revés

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Dependencias de actions](06-dependencias-de-actions.md) | [Permisos mínimos por job](../2-practicas/01-permisos-minimos-por-job.md) |
