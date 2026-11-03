---
name: verify-workflows
description: Comprueba que los workflows, action.yml, inputs de actions, SHA y comandos gh citados en el material existen, están fijados correctamente y hacen lo que dice el texto. Úsalo SIEMPRE después de escribir teoría, prácticas o starters con YAML o comandos, y antes de dar por cerrada una semana.
allowed-tools: Bash(actionlint *) Bash(zizmor *) Bash(uvx *) Bash(gh api *) Bash(gh * --help) Bash(yq *) Bash(jq *) Bash(grep *) Bash(find *) Bash(base64 *) Bash(./scripts/resolve-sha.sh *) Read Grep Glob
---

# Verificar workflows y comandos

En este repositorio el fallo más probable no es un enlace roto: es **un input de action que parece correcto pero no existe**, un SHA que no corresponde a su tag o un flag de `gh` inventado. Pasa la revisión a ojo y revienta cuando el alumno sube el workflow. Este skill lo detecta.

## 1. Extraer los workflows

- Los `.yml` de `3-proyecto/starter/` de la semana.
- Los bloques ```` ```yaml ```` de teoría y prácticas que contengan `jobs:` (workflow) o `runs:` (action). Extráelos a un directorio temporal, un archivo por bloque, en `.github/workflows/` para que actionlint los trate como workflows.
- Ignora los bloques cuya línea relevante lleve `# antipatron`: son ejemplos de lo que no se hace.

## 2. Validación estática

```bash
actionlint <dir>/.github/workflows/*.yml
uvx zizmor@<versión de docs/stack-versions.md> --offline <dir>/.github/workflows/
```

- actionlint valida sintaxis, expresiones, contextos, `needs`, tipos de inputs de las actions conocidas y pasa shellcheck por cada `run:`.
- zizmor detecta inyección de plantillas, permisos excesivos, `persist-credentials`, `pull_request_target` peligroso y `uses:` sin fijar. Antes de la Semana 12, un hallazgo de severidad baja se puede tolerar si el texto lo anota; desde la 12, ninguno.

## 3. SHA contra tag

Por cada `uses: owner/repo@<sha> # vX.Y.Z`:

```bash
./scripts/resolve-sha.sh owner/repo vX.Y.Z
```

La salida tiene que coincidir exactamente con la línea del material, y el tag con el de `docs/stack-versions.md`.

## 4. Inputs y outputs de cada action

Por cada `with:` de una action remota, el input tiene que existir en su `action.yml` **en ese SHA**:

```bash
gh api "repos/<owner>/<repo>/contents/action.yml?ref=<sha>" --jq .content | base64 -d | yq '.inputs | keys'
```

Igual con `.outputs` para cada `steps.<id>.outputs.<x>` que se use. Algunas actions tienen el archivo como `action.yaml`; prueba los dos.

## 5. Comandos `gh` citados en la prosa

Todo subcomando y flag de `gh` se comprueba con `gh <subcomando> --help`. Trampas habituales:

| Escrito | Real |
|---|---|
| `gh run list --status failed` | El valor es `failure` |
| `gh workflow run ci.yml -f x=1` en un workflow sin `workflow_dispatch` | Falla: el workflow tiene que declarar `workflow_dispatch` |
| `gh run watch` sin ID fuera de una TTY | Pide elegir un run; en scripts pasa el ID |

## 6. Patrones prohibidos

```bash
grep -rnE 'ubuntu-latest|::set-output|::save-state|upload-artifact@v[1-3]\b|toJSON\(secrets\)|docker-compose|pip install|npm (i|install|ci|run)\b|\bnpx\b' bootcamp/week-NN-* | grep -v antipatron
grep -rnE 'run:.*\$\{\{ *(github\.event\.|github\.head_ref|inputs\.)' bootcamp/week-NN-* | grep -v antipatron
```

Cada resultado es un error. `pull_request_target` antes de la Semana 12 también.

## 7. Los comandos de `checks.json`

Ejecuta cada `cmd` a mano en el repo de pruebas del autor, con `GH_REPO` exportado, y comprueba que el `assert` se cumple con la capa resuelta y falla con el starter.

## 8. Informe

```
ruta:línea: 🔴 <uses/input/flag/workflow>: <qué falla y salida exacta del validador>. <corrección>.
```

Si no hay hallazgos, lista qué archivos validaste y con qué versiones de actionlint y zizmor.
