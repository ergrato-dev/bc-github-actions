# Por qué un runner propio

> Un runner propio es tu máquina ejecutando los jobs de GitHub. Ganas control sobre el hardware,
> la red y lo que queda instalado; pierdes la máquina limpia que GitHub tira después de cada job.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar qué es un runner propio y en qué se diferencia de uno alojado por GitHub
- Enumerar los motivos reales para tener uno y los que no lo son
- Decir en qué niveles se registra un runner: repositorio, organización y empresa
- Describir qué riesgo compras con él, y por qué crece en un repo público
- Explicar por qué `tablero`, siendo público, tiene un runner propio y con qué condiciones

## 1. Qué problema resuelve

Desde la Semana 01, cada job de `tablero` ha corrido en `ubuntu-24.04`: una máquina virtual que
GitHub crea para ese job, con cientos de herramientas preinstaladas, y que destruye al terminar.
Es cómodo, gratis en un repo público y seguro por diseño: lo que un job deja, el siguiente no lo
ve.

Hay casos en que esa máquina no te vale:

| Necesidad | Por qué no la cubre un runner alojado estándar |
|---|---|
| Hardware concreto | GPU, ARM en casa, mucha memoria, discos rápidos |
| Red privada | El job tiene que llegar a una base de datos o un registro que no está en internet |
| Software de pago o con licencia | Instalarlo en cada job es lento o no está permitido |
| Estado caro de reconstruir | Una caché de varios GB que no quieres subir y bajar en cada job |
| Coste en repos privados | Los minutos de un runner propio no consumen la cuota del plan |

Un **runner propio** (*self-hosted runner*) es el mismo programa que corre dentro de las máquinas
de GitHub, [`actions/runner`](https://github.com/actions/runner), instalado donde tú decides: tu
portátil, una VM, un contenedor o un pod de Kubernetes.

## 2. Cómo funciona

### Qué cambia y qué no

El modelo de ejecución de la Semana 01 sigue igual: un evento dispara un workflow, GitHub crea
los jobs y cada job espera en cola a un runner que case con su `runs-on`. Lo único que cambia es
**quién pone la máquina**.

| | Runner alojado (`ubuntu-24.04`) | Runner propio |
|---|---|---|
| Quién lo crea | GitHub, una VM por job | Tú, cuando registras el runner |
| Estado entre jobs | Ninguno: la VM se destruye | El que dejes: por defecto, todo |
| Software | La imagen de `actions/runner-images` | Lo que instales |
| Red | Internet | La tuya, incluida tu red local |
| Minutos | Cuota del plan (gratis en repos públicos) | Gratis siempre |
| Actualizaciones | GitHub | Tú: el runner, el sistema y las herramientas |
| Si se cae | GitHub lo arregla | El job espera en cola |

La fila del estado es la que más importa. La documentación de GitHub lo dice sin rodeos: un
runner propio *no necesita una instancia limpia en cada ejecución*. Si no haces nada, el segundo
job encuentra los archivos, procesos y credenciales que dejó el primero. Lo ves con tus ojos en
la práctica 01.

### Dónde se registra

Un runner se da de alta en uno de tres niveles, y el nivel decide quién puede usarlo:

| Nivel | Quién puede mandarle jobs | En `tablero` |
|---|---|---|
| Repositorio | Solo ese repo | ✅ Así lo registras |
| Organización | Los repos que permita su runner group | Lo ves en el archivo 06 |
| Empresa | Organizaciones de una cuenta Enterprise | Fuera del alcance del bootcamp |

`tablero` usa un runner **de repositorio**: en una organización Free es el nivel que mejor
limita quién lo usa. El archivo 06 explica por qué.

### Qué riesgo compras

Un job ejecuta código: tus scripts, las actions de terceros y las dependencias que instala. En un
runner alojado, lo peor que puede hacer ese código se queda dentro de una VM que va a desaparecer.
En el tuyo, el código corre **en tu máquina**, con la red de tu máquina, y lo que deje puede
seguir ahí para el siguiente job. La guía de seguridad de GitHub lo resume: un runner propio
*puede quedar comprometido de forma persistente por código no confiable de un workflow*.

Qué puede hacer un job malicioso en un runner persistente sin preparar:

| Lo que hace | Qué consigue |
|---|---|
| Deja un proceso corriendo que esquiva la limpieza del runner | Ve los jobs siguientes, sus variables y sus secretos |
| Cambia una herramienta del `PATH` (`git`, `uv`, `python`) | El siguiente job ejecuta su versión sin saberlo |
| Escribe en la caché o en `_work` | Envenena lo que el siguiente job compila o publica |
| Lee los archivos de la máquina | Claves SSH, tokens de `gh`, credenciales de nube |
| Abre conexiones a tu red local | Llega a servicios que nunca debieron ver internet |

La guía de seguridad añade un detalle fino: algunos jobs pasan secretos como argumentos de línea
de comandos, y otro job que corra en la misma máquina puede verlos.

En un repo **público** el problema es mayor, porque cualquiera puede abrir un pull request desde
un fork. GitHub recomienda usar runners propios solo con repos privados: un fork puede ejecutar
código peligroso en tu máquina con un PR que lo meta en un workflow. El archivo 07 desmonta ese
ataque paso a paso.

## 3. Cómo se usa

### La pregunta antes de registrar nada

Antes de montar un runner propio, contesta por escrito:

1. **¿Qué necesidad de la tabla de arriba cubre?** Si ninguna, quédate con `ubuntu-24.04`.
2. **¿Qué código va a ejecutar?** Solo el de tus ramas, o también el de PR de desconocidos.
3. **¿Qué alcanza desde la máquina?** Tu red local, tus credenciales de nube, el socket de Docker.
4. **¿Qué queda después de un job?** Y quién lo limpia.

### Las respuestas de `tablero`

`tablero` no *necesita* un runner propio: es público y los minutos alojados le salen gratis. Lo
monta para aprender a operarlo antes de la Semana 16, donde lo escalas con ARC en Kubernetes, y
porque en un proyecto real llegará el día del hardware o la red privada. Precisamente porque es
público, lo hace con todas las defensas puestas:

| Pregunta | Respuesta en `tablero` |
|---|---|
| Qué cubre | Los tests unitarios de la API en tu máquina, como laboratorio |
| Qué código ejecuta | Solo `lab.yml`, que se lanza a mano con `workflow_dispatch` |
| Qué alcanza | Un contenedor sin capacidades, sin escalada, con límites y sin socket de Docker |
| Qué queda | Nada: runner JIT, un job, contenedor con `--rm` |

Cada fila tiene su archivo: el 04 explica JIT, el 05 el contenedor, el 06 quién puede usarlo y el
07 por qué solo `workflow_dispatch`.

### Cómo se ve en un workflow

Desde el lado del workflow, un runner propio es solo otra etiqueta en `runs-on`. Este es el
esqueleto del job que `tablero` manda a su runner; el archivo 03 explica las etiquetas y la
práctica 04 lo completa:

```yaml
name: lab
on:
  workflow_dispatch:
permissions: {}
jobs:
  unit:
    runs-on: [self-hosted, tablero-lab]
    timeout-minutes: 15
    permissions:
      contents: read
    steps:
      - name: Quién ejecuta este job
        run: echo "runner=$RUNNER_NAME"
```

Fíjate en lo que **no** tiene: ni `push`, ni `pull_request`, ni secretos. `RUNNER_NAME` es una
variable que el runner pone en el entorno de cada job; con ella compruebas en el log que el job
corrió en tu máquina y no en una de GitHub.

### El coste que no sale en la factura

Lo que GitHub hacía por ti pasa a ser tuyo:

- **Actualizar el runner.** Por defecto se actualiza solo al recibir un job. Si lo apagas con
  `--disableupdate`, tienes 63 días desde que sale una versión nueva; pasado ese plazo deja de
  recibir jobs.
- **Parchear el sistema y las herramientas.** El runner no actualiza el sistema operativo ni lo
  que instalaste.
- **Vigilar el disco y la memoria.** Un runner persistente acumula `_work`, imágenes y cachés
  hasta que algo falla.
- **Mirar los logs.** Viven en tu máquina, no en GitHub.

### Lo mínimo que no cambia

Un runner propio necesita salida **HTTPS por el puerto 443** hacia GitHub: se conecta él para
recibir trabajo y descargar versiones nuevas. Además:

- Un job puede esperar en cola como mucho **24 horas**. Si ningún runner que case aparece, falla.
- Si un runner no recoge en 60 segundos el job que se le asignó, el job vuelve a la cola para
  otro.
- Un runner que no se conecta en más de **14 días** se borra solo; uno efímero, en más de **1 día**.

_Verificado con actions/runner v2.338.2 y ubuntu-24.04, noviembre de 2026._

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Runner propio "porque es más rápido" sin medirlo | Pagas mantenimiento y riesgo por una ganancia que quizá no existe | Mide con los tiempos de la Semana 19 antes de decidir |
| Registrarlo en tu portátil de trabajo, persistente | Un job ve tus claves SSH, tu `~/.config/gh` y tu red | Contenedor desechable o VM dedicada |
| Runner propio en un repo público con `pull_request` | Un fork ejecuta código en tu máquina | Solo eventos de confianza (archivo 07) |
| Registrarlo a nivel de organización "por si acaso" | Cualquier repo de la org puede usarlo | El nivel más estrecho que sirva |
| Olvidarlo encendido y sin actualizar | Deja de recibir jobs y acumula vulnerabilidades | Imagen fijada y vigilada por Dependabot (archivo 05) |

## 5. Trucos

- **Qué máquina corrió un job**: la primera sección del log, *Set up job*, dice `Runner name` y
  `Machine name`. Con la API, `runner_name` en `actions/runs/<id>/jobs`.
- **Qué runner casa sin lanzar nada**: `gh api repos/{owner}/{repo}/actions/runners --jq
  '.runners[] | "\(.name) \(.status) [\([.labels[].name] | join(","))]"'` enseña nombre, estado y
  etiquetas de cada runner del repo; compáralas con tu `runs-on`.
- **Prueba la conectividad antes de culpar al workflow**: `config.sh --check` comprueba que la
  máquina llega a cada servicio de GitHub que el runner necesita y marca cada uno con PASS o
  FAIL.

## 📚 Recursos Adicionales

- [GitHub Docs: Self-hosted runners](https://docs.github.com/en/actions/concepts/runners/self-hosted-runners)
- [GitHub Docs: Self-hosted runners reference](https://docs.github.com/en/actions/reference/runners/self-hosted-runners)
- [GitHub Docs: Secure use reference, hardening self-hosted runners](https://docs.github.com/en/actions/reference/security/secure-use)
- [actions/runner](https://github.com/actions/runner)

## ✅ Checklist de Verificación

- [ ] Sé qué necesidades justifican un runner propio y cuáles no
- [ ] Sé en qué tres niveles se registra un runner y cuál usa `tablero`
- [ ] Sé qué estado sobrevive entre jobs en un runner propio sin preparar
- [ ] Sé por qué GitHub desaconseja runners propios en repos públicos
- [ ] Sé qué pasa con un job que nadie recoge en 24 horas
- [ ] Sé las cuatro defensas que pone `tablero` y en qué archivo se explica cada una

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Semana 15 — Runners propios](../README.md) | [Cómo funciona el runner](02-como-funciona-el-runner.md) |
