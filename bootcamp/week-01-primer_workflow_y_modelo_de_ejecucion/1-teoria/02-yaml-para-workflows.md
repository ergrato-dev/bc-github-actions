# YAML para workflows

> Un workflow es YAML, y la mayoría de los errores del primer día no son de Actions sino de YAML.
> Lo justo para escribirlo sin sorpresas, y las tres trampas que te costarían una tarde.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Leer y escribir mapas, listas y escalares en YAML con la indentación correcta
- Elegir entre comillas, `|` y `>` según lo que contenga el valor
- Explicar por qué `on:` se lee como `true` en algunas herramientas y cuándo te afecta
- Reconocer los errores de YAML más comunes antes de hacer push

---

## 1. Qué problema resuelve

GitHub necesita que describas un árbol: un workflow tiene eventos, jobs, y cada job tiene steps
con claves. YAML es un formato para escribir ese árbol a mano y que se lea como un documento.

El precio es que la estructura la da la **indentación**: un espacio de más cambia el significado
sin dar error. Y algunos valores que parecen texto se convierten en números o booleanos. Si sabes
dónde están esas trampas, YAML deja de ser un problema.

---

## 2. Cómo funciona

### 2.1 Mapas: clave y valor

Un **mapa** es un conjunto de pares `clave: valor`. El espacio después de los dos puntos es
obligatorio. Lo que va indentado debajo de una clave le pertenece:

```yaml
name: ejemplo
jobs:
  build:
    runs-on: ubuntu-24.04
```

`jobs` es un mapa con una clave `build`, que a su vez es un mapa con `runs-on`.

### 2.2 Indentación: solo espacios

- **Solo espacios, nunca tabuladores.** Un tabulador es un error de sintaxis.
- El número de espacios es libre, pero tiene que ser el mismo para todos los hermanos. La
  convención en workflows es **dos espacios**.
- Hermanos alineados, hijos más a la derecha. Nada más.

### 2.3 Listas

Una **lista** es una secuencia de elementos, cada uno con `- ` delante. Los steps son una lista de
mapas:

```yaml
steps:
  - name: Primero
    run: echo uno
  - name: Segundo
    run: echo dos
```

`name` y `run` van alineados porque son claves del mismo mapa, el elemento de la lista. También
hay forma corta, entre corchetes, útil para listas cortas de escalares:

```yaml
branches: [main, release]
```

### 2.4 Escalares y comillas

Un **escalar** es un valor simple: texto, número o booleano. Sin comillas, YAML **adivina el
tipo**:

| Escribes | YAML entiende |
|---|---|
| `hola` | texto |
| `42` | número |
| `3.10` | número 3.1 |
| `true`, `false` | booleano |
| `"3.10"` | texto `3.10` |

Pon comillas cuando el valor sea texto que parece otra cosa (versiones, números de puerto con
ceros, `yes`/`no`) o cuando empiece por un carácter especial: `*`, `&`, `!`, `{`, `[`, `%`, `@`,
`` ` ``. Las comillas dobles admiten escapes como `\n`; las simples, no.

### 2.5 Texto en varias líneas: `|` y `>`

Para un `run:` con varios comandos usas un **bloque literal** con `|`: conserva los saltos de
línea tal cual, así que cada línea es un comando.

```yaml
run: |
  echo "uno"
  echo "dos"
```

El **bloque plegado** `>` une las líneas con espacios. Sirve para un texto largo, no para comandos:
dos comandos plegados se convierten en uno solo.

### 2.6 Comentarios

Todo lo que va detrás de `#` (con un espacio delante, o al principio de la línea) es un
comentario. Dentro de un bloque `|`, en cambio, `#` es parte del texto: en un `run:` lo leerá el
shell como comentario de shell.

---

## 3. Cómo se usa

### 3.1 La trampa de `on:`

En la versión 1.1 de YAML, `on`, `off`, `yes`, `no`, `y` y `n` son **booleanos**. Un parser de
YAML 1.1 como PyYAML lee esto:

```yaml
on:
  push:
```

como un mapa cuya clave es `True`, no `"on"`. Comprobado con PyYAML 6.0.3:

```python
yaml.safe_load("on:\n  push:\n")
# {True: {'push': None}}
```

GitHub Actions lee `on` como la clave `on`, así que tu workflow funciona. El problema llega cuando
otra herramienta lee el mismo archivo:

| Herramienta | Cómo lee `on:` |
|---|---|
| GitHub Actions | La clave `on` |
| actionlint | La clave `on` |
| yq de mikefarah (v4) | La clave `on`: `yq '.on \| keys'` funciona |
| PyYAML y otros parsers YAML 1.1 | El booleano `true` |

Si un script en Python tiene que leer tus workflows, busca la clave `True` o escribe `"on":` entre
comillas en el workflow; GitHub acepta las dos formas. En este bootcamp los `checks.json` usan el
yq de mikefarah, que lee `on` sin problemas: por eso el doctor comprueba que tienes ese yq y no
otro.

### 3.2 La trampa de las versiones

`3.10` sin comillas es el número 3,1. En un workflow, una versión de Python o de Node escrita sin
comillas puede acabar pidiendo otra versión. **Las versiones siempre entre comillas**:
`"3.15"`, `"26"`.

### 3.3 Un ejemplo con todo

```yaml
# Comentario: no afecta al workflow.
name: yaml-tour

on:
  push:
    branches: [main]
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  tour:
    runs-on: ubuntu-24.04
    steps:
      - name: Bloque literal, un comando por línea
        run: |
          echo "versión como texto: 3.10"
          echo "segunda línea, segundo comando"
      - name: Texto con dos puntos, entre comillas
        run: "echo 'clave: valor'"
```

Fíjate en el último `run:`: el valor contiene `: `, que YAML leería como otro mapa. Entre comillas
es solo texto.

### 3.4 Antes de hacer push

`actionlint` lee el archivo como YAML y como workflow: te dice tanto una indentación rota como
una clave inexistente. Lo instalas y usas en
[la práctica 04](../2-practicas/04-actionlint-y-sha.md).

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Mezclar tabuladores y espacios | Error de sintaxis, a veces en una línea lejos del problema | Configura el editor para insertar espacios |
| Versiones sin comillas | `3.10` se convierte en `3.1` | `"3.10"` |
| `>` en un `run:` con varios comandos | Las líneas se unen en un único comando | `\|` para comandos |
| Leer workflows con PyYAML buscando `"on"` | La clave es `True`; el script no encuentra nada | yq de mikefarah, o buscar `True` |
| Copiar YAML de una web con la indentación rota | El step queda dentro de otro y el error confunde | Pégalo y pasa actionlint antes del push |

---

## 5. Trucos

- **`yq -o=json . archivo.yml`** te enseña cómo entiende el parser tu YAML. Si una clave
  aparece donde no esperabas, la indentación está mal.
- **`yq '.jobs | keys' .github/workflows/ci.yml`** lista los jobs de un workflow sin abrirlo.
- **La extensión `redhat.vscode-yaml` de VS Code** marca la indentación rota mientras escribes;
  este repo la recomienda en `.vscode/extensions.json`.

---

## 📚 Recursos Adicionales

- [YAML 1.2.2 specification](https://yaml.org/spec/1.2.2/): la especificación; el capítulo 2 tiene
  ejemplos cortos de cada estructura
- [yq de mikefarah](https://mikefarah.gitbook.io/yq/): la herramienta que usan los checks de este
  bootcamp

---

## ✅ Checklist de Verificación

- [ ] Indento con dos espacios y nunca con tabuladores
- [ ] Sé escribir un mapa, una lista de mapas y una lista corta entre corchetes
- [ ] Pongo comillas a las versiones y a los textos que parecen otra cosa
- [ ] Uso `|` para un `run:` de varios comandos y sé por qué no `>`
- [ ] Sé por qué PyYAML lee `on:` como `true` y qué herramientas no lo hacen
- [ ] Sé ver con `yq -o=json` cómo se ha leído un archivo

_Verificado con PyYAML 6.0.3, yq v4.54.1 y actionlint 1.7.12, noviembre de 2026._

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Qué es GitHub Actions](01-que-es-github-actions.md) | [Anatomía de un workflow](03-anatomia-de-un-workflow.md) |
