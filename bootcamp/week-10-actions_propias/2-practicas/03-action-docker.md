# Práctica 03 — Una action Docker

> Las migraciones de `api/migrations/` son SQL a mano y nadie las revisa antes de que lleguen a
> PostgreSQL. En esta práctica escribes `sql-lint`, una action Docker que lleva dentro sqlfluff
> fijado y anota cada infracción en el diff del PR.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `.github/actions/sql-lint/` con `action.yml`, `Dockerfile` y `entrypoint.sh`
- Una imagen con base de tag completo, uv copiado de su imagen y sqlfluff 4.5.0
- El input con guion `exclude-rules` leído con `printenv`, y el output `files`
- La migración revisada en tu Docker igual que en el runner: cinco avisos LT01 y, con la regla
  excluida, verde

## 📋 Antes de empezar

Terminaste la [práctica 02](02-action-javascript.md): `coverage-report` está comiteada en la
rama `ci/own-actions`.

```bash
cd ~/code/tablero
git branch --show-current
# ci/own-actions
mkdir -p .github/actions/sql-lint
docker info > /dev/null && echo "docker ok"
# docker ok
```

---

## Paso 1: El `action.yml` y la imagen

**Por qué**: con `using: docker` e `image: Dockerfile`, el runner construye la imagen desde la
carpeta de la action **en cada job** que la usa y ejecuta su `ENTRYPOINT` con el workspace
montado ([teoría 06](../1-teoria/06-actions-docker.md)). Lo que hay dentro no depende del
runner: sqlfluff, Python y uv van fijados en la imagen. La base lleva tag completo (regla 10) y
sqlfluff se instala con `uv tool install` a versión exacta, nunca con pip. uv no se descarga con
un script: se copia de su imagen oficial con el mismo tag que usa `setup-uv`.

**Comando**: crea `.github/actions/sql-lint/action.yml`. Los inputs de una action Docker
también son cadenas, con su `default`.

```yaml
name: sql-lint
description: Revisa con sqlfluff los archivos .sql de una carpeta y anota cada infracción en el diff
inputs:
  path:
    description: Carpeta (relativa al workspace) donde buscar archivos .sql
    default: .
  dialect:
    description: Dialecto SQL que entiende sqlfluff
    default: postgres
  exclude-rules:
    description: Reglas de sqlfluff a ignorar, separadas por comas (por ejemplo LT01)
    default: ""
outputs:
  files:
    description: Número de archivos .sql revisados
runs:
  using: docker
  image: Dockerfile
```

Y `.github/actions/sql-lint/Dockerfile`:

```dockerfile
FROM python:3.15.2-slim-trixie

COPY --from=ghcr.io/astral-sh/uv:0.13.6 /uv /usr/local/bin/uv

ENV UV_TOOL_DIR=/opt/uv-tools UV_TOOL_BIN_DIR=/usr/local/bin
RUN uv tool install sqlfluff==4.5.0

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

Las dos variables `UV_TOOL_*` sacan la herramienta del `$HOME` de root: el runner ejecuta el
contenedor con otro `HOME` (`/github/home`), y `sqlfluff` tiene que estar en un `PATH` que no
dependa de él.

**Verifica**: la orden de `sql-lint-docker`.

```bash
cd .github/actions/sql-lint
{ yq '.runs.image' action.yml && grep -E '^FROM ' Dockerfile | head -1 && grep -oE 'uv tool install sqlfluff==[0-9.]+' Dockerfile; } | paste -sd' '
# Dockerfile FROM python:3.15.2-slim-trixie uv tool install sqlfluff==4.5.0
cd ~/code/tablero
```

---

## Paso 2: El entrypoint y el input con guion

**Por qué**: en una action Docker no hay contexto `inputs`: el runner pasa cada input como
variable de entorno `INPUT_<NOMBRE EN MAYÚSCULAS>`, y **conserva el guion**. `INPUT_PATH` se lee
con `$`, pero `INPUT_EXCLUDE-RULES` no es un nombre de variable válido para bash: `$INPUT_EXCLUDE`
se corta en el guion ([teoría 06](../1-teoria/06-actions-docker.md)). Compruébalo antes de
escribir el script:

```bash
env 'INPUT_EXCLUDE-RULES=LT01' bash -c 'echo "con \$: [$INPUT_EXCLUDE-RULES]"; echo "con printenv: [$(printenv "INPUT_EXCLUDE-RULES")]"'
# con $: [-RULES]
# con printenv: [LT01]
```

Con `set -u`, además, bash para con `INPUT_EXCLUDE: unbound variable`. El output se escribe
igual que en un step `run`: una línea `files=N` en `$GITHUB_OUTPUT`, que el runner monta dentro
del contenedor. `--format github-annotation-native` hace que sqlfluff imprima cada infracción
como comando `::warning`, que el runner convierte en una anotación sobre la línea.

**Comando**: crea `.github/actions/sql-lint/entrypoint.sh`.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Docker no tiene "inputs": llegan como INPUT_<NOMBRE>. El guion de "exclude-rules"
# se conserva, así que bash no puede leerlo con $: se pide con printenv.
exclude="$(printenv 'INPUT_EXCLUDE-RULES' || true)"

mapfile -t files < <(find "$INPUT_PATH" -name '*.sql' | sort)
echo "files=${#files[@]}" >> "$GITHUB_OUTPUT"

if [ "${#files[@]}" -eq 0 ]; then
  echo "::warning::No hay archivos .sql en '$INPUT_PATH'"
  exit 0
fi

args=(--dialect "$INPUT_DIALECT" --format github-annotation-native)
if [ -n "$exclude" ]; then args+=(--exclude-rules "$exclude"); fi

sqlfluff lint "${args[@]}" "${files[@]}"
```

```bash
chmod +x .github/actions/sql-lint/entrypoint.sh
```

Sin el bit de ejecución, el `ENTRYPOINT` no arranca. git lo guarda, así que basta con hacerlo
una vez antes del commit.

**Verifica**: la orden de `sql-lint-inputs`.

```bash
cd .github/actions/sql-lint
{ test -x entrypoint.sh && grep -c "printenv 'INPUT_EXCLUDE-RULES'" entrypoint.sh && grep -cE 'files=.*>> *"\$GITHUB_OUTPUT"' entrypoint.sh; } | paste -sd' '
# 1 1
cd ~/code/tablero
```

---

## Paso 3: La migración, revisada en tu Docker

**Por qué**: antes de ponerla en un workflow, la imagen se construye y se ejecuta como lo hace
el runner: el repo montado en `/github/workspace` como directorio de trabajo, los inputs como
`INPUT_*` y un archivo para `GITHUB_OUTPUT`. Si aquí falla, en el runner falla igual, y aquí el
ciclo es de segundos. El tag `dev` es solo para tu máquina: esta imagen no se publica.

**Comando**: construye la imagen y revisa `api/migrations` sin excluir nada.

```bash
docker build -t tablero-sql-lint:dev .github/actions/sql-lint
docker run --rm --entrypoint sqlfluff tablero-sql-lint:dev --version
# sqlfluff, version 4.5.0
out=$(mktemp)
docker run --rm -v "$PWD":/github/workspace -w /github/workspace \
  -v "$out":/github/file_commands/out -e GITHUB_OUTPUT=/github/file_commands/out \
  -e INPUT_PATH=api/migrations -e INPUT_DIALECT=postgres -e 'INPUT_EXCLUDE-RULES=' \
  tablero-sql-lint:dev > /tmp/sql-lint.txt; echo "exit $?"
# exit 1
```

**Verifica**: cinco avisos LT01 y el output escrito aunque el lint haya fallado.

```bash
grep -c '::warning' /tmp/sql-lint.txt
# 5
grep -m1 '::warning' /tmp/sql-lint.txt
# ::warning title=SQLFluff,file=api/migrations/001_tasks.sql,line=2,col=7,endLine=2,endColumn=16::LT01: Expected only single space before 'bigint' keyword. Found '         '. [layout.spacing]
cat "$out"
# files=1
```

Las cinco son la misma: `001_tasks.sql` alinea los tipos y las restricciones en columnas, y
LT01 quiere un solo espacio. `file=` va relativo al workspace, que es lo que necesita GitHub
para dibujar la anotación sobre esa línea del diff.

---

## Paso 4: Excluir LT01, con motivo

**Por qué**: la alineación es intencionada: la tabla se lee de un vistazo. Reescribir una
migración ya aplicada para contentar al linter es peor remedio que la enfermedad, así que la
regla se excluye **desde quien llama**, con un comentario que lo diga
(lo haces en la práctica 04). La action no decide por ti: `exclude-rules` vale `""` por defecto.
Que la regla no se cuele en la imagen ni en el script es lo que permite reutilizar la action en
otro repo con otro estilo.

**Comando**: la misma ejecución, ahora con `INPUT_EXCLUDE-RULES=LT01`, y una carpeta sin SQL.

```bash
: > "$out"
docker run --rm -v "$PWD":/github/workspace -w /github/workspace \
  -v "$out":/github/file_commands/out -e GITHUB_OUTPUT=/github/file_commands/out \
  -e INPUT_PATH=api/migrations -e INPUT_DIALECT=postgres -e 'INPUT_EXCLUDE-RULES=LT01' \
  tablero-sql-lint:dev; echo "exit $?"
# exit 0
cat "$out"
# files=1
: > "$out"
docker run --rm -v "$PWD":/github/workspace -w /github/workspace \
  -v "$out":/github/file_commands/out -e GITHUB_OUTPUT=/github/file_commands/out \
  -e INPUT_PATH=web -e INPUT_DIALECT=postgres -e 'INPUT_EXCLUDE-RULES=' \
  tablero-sql-lint:dev; echo "exit $?"
# ::warning::No hay archivos .sql en 'web'
# exit 0
```

**Verifica**: el output de la carpeta vacía.

```bash
cat "$out"
# files=0
```

---

## Paso 5: El commit y lo que cuesta

**Por qué**: el runner construye esta imagen en cada job, sin caché entre runs: son decenas de
segundos que una action composite o JavaScript no paga. Y una action Docker solo corre en
runners Linux. Por eso `tablero` la usa en un único job, el de SQL, y no en cada paso de cada
pipeline ([teoría 06](../1-teoria/06-actions-docker.md)). El bit de ejecución del entrypoint
tiene que llegar al commit: si no, el contenedor no arranca en el runner aunque en tu máquina
sí.

**Comando**:

```bash
docker image ls tablero-sql-lint --format '{{.Repository}}:{{.Tag}} {{.Size}}'
# tablero-sql-lint:dev 309MB
git add .github/actions/sql-lint
git commit -m "ci: add sql-lint docker action"
rm -f "$out" /tmp/sql-lint.txt
```

**Verifica**: el modo `100755` del entrypoint en el índice de git y los tres archivos de la
action.

```bash
git ls-files -s .github/actions/sql-lint | awk '{print $1, $4}'
# 100644 .github/actions/sql-lint/Dockerfile
# 100644 .github/actions/sql-lint/action.yml
# 100755 .github/actions/sql-lint/entrypoint.sh
```

> ⚠️ La imagen local ocupa unos 300 MB. Cuando termines la semana puedes borrarla con
> `docker image rm tablero-sql-lint:dev`: no guarda nada que no se reconstruya desde la carpeta
> de la action.

---

## ✅ Resultado

- [ ] `sql-lint` es una action Docker con `image: Dockerfile`
- [ ] La imagen parte de `python:3.15.2-slim-trixie` e instala `sqlfluff==4.5.0` con `uv tool install`
- [ ] El entrypoint lee `exclude-rules` con `printenv` y escribe `files` en `$GITHUB_OUTPUT`
- [ ] Viste los cinco avisos LT01 y el verde con la regla excluida
- [ ] El entrypoint está comiteado con modo `100755`

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 10
# ✅ sql-lint se construye desde su Dockerfile, con una imagen base de tag completo y sqlfluff instalado con uv tool install a versión fijada
# ✅ El entrypoint de sql-lint lee el input exclude-rules con printenv y escribe el output files en GITHUB_OUTPUT
# ...
```

Con esto, `action-types` pasa a verde: las tres actions existen. El uso en los workflows y el
run remoto, en la práctica 04.

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `permission denied` al arrancar el contenedor | El entrypoint no tiene bit de ejecución | Paso 2: `chmod +x` y vuelve a construir |
| `INPUT_EXCLUDE: unbound variable` | El script lee `$INPUT_EXCLUDE-RULES` con `set -u` | Paso 2: `printenv 'INPUT_EXCLUDE-RULES'` |
| `sqlfluff: command not found` al ejecutar la imagen | Faltan las variables `UV_TOOL_*` y la herramienta quedó en el `HOME` de root | Paso 1: `ENV UV_TOOL_DIR=... UV_TOOL_BIN_DIR=/usr/local/bin` |
| `files=0` con `api/migrations` | El contenedor no tiene el repo en su directorio de trabajo | Paso 3: `-v "$PWD":/github/workspace -w /github/workspace` |
| Las anotaciones no salen sobre el diff del PR | Falta `--format github-annotation-native` | Paso 2 |
| El job `sql` de `ci` falla con avisos LT01 | El `with:` del job no pasa `exclude-rules` | Práctica 04, paso 1: `exclude-rules: LT01` |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Una action JavaScript](02-action-javascript.md) | [Probar y mantener actions](04-probar-y-mantener-actions.md) |
