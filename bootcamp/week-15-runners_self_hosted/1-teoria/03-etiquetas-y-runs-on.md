# Etiquetas y `runs-on`

> `runs-on` no nombra una máquina: pide un conjunto de etiquetas, y cualquier runner que las tenga
> todas puede llevarse el job. Elegir bien las etiquetas es elegir quién ejecuta tu código.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Enumerar las etiquetas que recibe un runner propio por defecto
- Explicar cómo casan las etiquetas de `runs-on` con las de un runner
- Usar las tres formas de `runs-on`: cadena, lista y `group` con `labels`
- Elegir una etiqueta propia que identifique un único runner o un único tipo de runner
- Decirle a actionlint qué etiquetas propias existen

## 1. Qué problema resuelve

Con runners alojados, `runs-on: ubuntu-24.04` elige una imagen y ya está: GitHub tiene miles de
máquinas iguales. Con runners propios, lo que haya detrás de una etiqueta depende de ti. Si dos
runners distintos comparten etiqueta, el job puede caer en cualquiera de los dos; si ningún runner
la tiene, el job se queda en cola hasta 24 horas y falla. Y si la etiqueta es demasiado genérica,
un job que no esperabas puede acabar en tu máquina.

## 2. Cómo funciona

### Las etiquetas por defecto

Al registrarse, un runner propio recibe tres etiquetas automáticas:

| Etiqueta | Valor | En `tablero` |
|---|---|---|
| `self-hosted` | Siempre | ✅ |
| Sistema operativo | `linux`, `windows` o `macOS` | `Linux` |
| Arquitectura | `x64`, `ARM` o `ARM64` | `X64` (o `ARM64` si tu máquina lo es) |

La API las devuelve con `type: read-only`: son de solo lectura. A eso se suman las
que pases con `--labels`, que salen con `type: custom`. Con `--no-default-labels`, `config.sh` no
pone ninguna de las tres.

### Cómo casa un job con un runner

Cuando un job pide un runner propio, GitHub busca uno **online y libre** que tenga **todas** las
etiquetas de `runs-on`. Las etiquetas son acumulativas: `[self-hosted, linux, tablero-lab]` exige
las tres. Un runner con más etiquetas que las pedidas también vale; uno al que le falte una, no.

| `runs-on` | Runner con `self-hosted, Linux, X64, tablero-lab` | Runner con `self-hosted, Linux, X64` |
|---|:--:|:--:|
| `self-hosted` | ✅ | ✅ |
| `[self-hosted, linux]` | ✅ | ✅ |
| `[self-hosted, tablero-lab]` | ✅ | ❌ |
| `[self-hosted, tablero-lab, gpu]` | ❌ | ❌ |

Si hay varios candidatos, el job va a uno cualquiera. Si no hay ninguno libre, espera; si ninguno
aparece en 24 horas, falla.

### Las tres formas de `runs-on`

| Forma | Ejemplo | Qué pide |
|---|---|---|
| Cadena | `runs-on: ubuntu-24.04` | Una etiqueta |
| Lista | `runs-on: [self-hosted, tablero-lab]` | Todas las etiquetas |
| Objeto | `runs-on: {group: tablero-runners, labels: [tablero-lab]}` | Un runner del grupo **y** con esas etiquetas |

La forma de objeto solo tiene sentido con runner groups de organización, que verás en el archivo
06. `tablero` usa la lista.

### Las etiquetas de un runner JIT

Un runner JIT (archivo 04) no pasa por `config.sh`: sus etiquetas son **exactamente** las que
envías al pedir la configuración a `generate-jitconfig`, y no se añade ninguna por defecto. Si
quieres que tenga `self-hosted`, la incluyes tú. `tablero` le da dos: `self-hosted` y
`tablero-lab`.

### actionlint y las etiquetas propias

actionlint conoce las etiquetas de los runners alojados y las por defecto de los propios, en
mayúsculas o minúsculas. Cualquier otra la marca como error:

```text
label "tablero-lab" is unknown. available labels are "windows-latest", ..., "self-hosted",
"x64", "arm", "arm64", "linux", "macos", "windows". if it is a custom label for self-hosted
runner, set list of labels in actionlint.yaml config file [runner-label]
```

Es un buen error: atrapa erratas como `tablero-labs`, que dejarían el job en cola un día entero.
Las etiquetas válidas se declaran en `.github/actionlint.yaml`, que actionlint lee solo desde la
raíz del repo:

```yaml
# .github/actionlint.yaml
self-hosted-runner:
  labels:
    - tablero-lab
```

_Verificado con actionlint 1.7.12, actions/runner v2.338.2 y ubuntu-24.04, noviembre de 2026._

## 3. Cómo se usa

### Un job en el runner de `tablero`

```yaml
name: labels-example
on:
  workflow_dispatch:
permissions: {}
jobs:
  where:
    runs-on: [self-hosted, tablero-lab]
    timeout-minutes: 5
    permissions:
      contents: read
    steps:
      - name: Etiquetas y runner que tocaron
        run: |
          echo "Runner: $RUNNER_NAME"
          echo "Sistema: $RUNNER_OS, arquitectura: $RUNNER_ARCH"
```

`RUNNER_OS` y `RUNNER_ARCH` dicen qué etiquetas de sistema y arquitectura tiene la máquina que
recogió el job. Es la comprobación más barata de que el job cayó donde esperabas.

### Alojados y propios en el mismo workflow

`runs-on` es por job. Un mismo workflow puede tener un job en `ubuntu-24.04` y otro en
`[self-hosted, tablero-lab]`, unidos con `needs` como cualquier otro par de jobs. Es la forma de
mandar a tu máquina solo el trabajo que la necesita y dejar el resto en las de GitHub.

### Elegir la etiqueta propia

Una etiqueta propia es un contrato entre el workflow y la máquina. Para `tablero`:

- **Única**: `tablero-lab` no la tiene ningún otro runner del repo. `self-hosted` o `linux`
  solas casarían con cualquiera.
- **Describe capacidad, no persona**: `tablero-lab` dice "el laboratorio de tablero"; `pc-de-ana`
  deja de ser verdad cuando Ana cambia de máquina.
- **Igual en tres sitios**: en `runs-on`, en el script que registra el runner y en
  `actionlint.yaml`. Si una no coincide, el job no arranca o actionlint falla.

### Ver qué runner y etiquetas usó cada job

```bash
gh api "repos/$GH_REPO/actions/runs/<id>/jobs" \
  --jq '.jobs[] | "\(.name): \(.runner_name) [\(.labels | join(","))]"'
# unit: tablero-lab-1763040000 [self-hosted,tablero-lab]
```

`labels` son las que pidió el job en `runs-on`; `runner_name`, el runner que lo recogió. El
`runner_group_name` del mismo objeto dice de qué grupo salió.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `runs-on: self-hosted` a secas | Casa con cualquier runner propio al alcance del repo | Lista con una etiqueta propia única |
| La misma etiqueta en máquinas distintas | El job cae en una u otra al azar y los resultados no se reproducen | Una etiqueta por tipo de máquina |
| Etiqueta con el nombre de una persona o un host | Deja de ser verdad y nadie se atreve a cambiarla | Etiquetas que describen capacidad o propósito |
| Desactivar la regla `runner-label` de actionlint | Pierdes la detección de erratas en `runs-on` | Declarar las etiquetas en `actionlint.yaml` |
| Pedir un JIT sin `self-hosted` y escribirla en `runs-on` | El job no casa nunca: el runner JIT no la tiene | Las etiquetas JIT se pasan todas a mano |

Un ejemplo del primero, para reconocerlo en una revisión:

```yaml
name: too-broad
on:
  workflow_dispatch:
permissions: {}
jobs:
  any:
    runs-on: self-hosted # antipatron
    timeout-minutes: 5
    steps:
      - run: echo "cualquier runner propio vale"
```

## 5. Trucos

- **Comprueba las etiquetas antes de lanzar el job**: `gh api "repos/$GH_REPO/actions/runners"
  --jq '.runners[] | "\(.name): \([.labels[].name] | join(","))"'` y compara con `runs-on`.
- **Un job en cola, por la API**: `gh api "repos/$GH_REPO/actions/runs/<id>/jobs" --jq
  '.jobs[] | select(.status == "queued") | .labels'` enseña qué etiquetas espera. Si ves
  `tablero-labs`, ya sabes.
- **`actionlint -config-file`**: si guardas la configuración fuera de `.github/`, pásala con este
  flag; sin él, actionlint solo busca `.github/actionlint.yaml` o `.github/actionlint.yml`.

## 📚 Recursos Adicionales

- [GitHub Docs: Using self-hosted runners in a workflow](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/use-in-a-workflow)
- [GitHub Docs: Workflow syntax, `jobs.<job_id>.runs-on`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idruns-on)
- [actionlint: configuration](https://github.com/rhysd/actionlint/blob/main/docs/config.md)

## ✅ Checklist de Verificación

- [ ] Sé qué tres etiquetas recibe un runner propio por defecto
- [ ] Sé que un runner tiene que tener todas las etiquetas de `runs-on`
- [ ] Sé usar `runs-on` como cadena, lista y objeto con `group` y `labels`
- [ ] Sé por qué un runner JIT necesita `self-hosted` explícita
- [ ] Sé declarar etiquetas propias en `.github/actionlint.yaml`
- [ ] Sé ver qué runner recogió cada job de un run

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Cómo funciona el runner](02-como-funciona-el-runner.md) | [Runners efímeros y JIT](04-runners-efimeros-y-jit.md) |
