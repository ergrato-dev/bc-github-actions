# Schedule y cron

> Un CI que solo corre cuando alguien hace push no se entera de que una dependencia nueva rompió
> la imagen base, ni de que un test depende de la fecha. `schedule` corre tu workflow a una hora,
> sin commit, y tiene reglas que no son las de un cron de Linux.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Escribir una expresión cron de cinco campos y leer cualquiera
- Fijar la zona horaria con `timezone` o razonar en UTC
- Explicar por qué un `schedule` solo corre desde la rama por defecto
- Elegir el minuto para reducir los retrasos en horas de carga
- Saber cuándo GitHub desactiva un cron y cómo reactivarlo
- Distinguir dentro del workflow un run programado de uno lanzado a mano

## 1. Qué problema resuelve

El CI de `tablero` responde a cambios **tuyos**. Pero hay cosas que cambian sin que nadie haga
push:

- **La imagen base**: `python:3.15.2-slim-trixie` recibe parches de seguridad; tu imagen no los
  tiene hasta que la reconstruyes.
- **El mundo exterior**: una API de terceros, un certificado que caduca, una versión nueva de una
  action en la que confías.
- **El propio tiempo**: un test que falla en año bisiesto o a fin de mes.

Si `main` lleva tres semanas sin commits, llevas tres semanas sin saber si sigue en verde. Un run
nocturno sobre `main` lo responde cada mañana. Es lo que hace `nightly.yml` en el proyecto de esta
semana.

## 2. Cómo funciona

### Los cinco campos

`17 3 * * *` se lee de izquierda a derecha:

| Posición | Campo | Rango | En `17 3 * * *` |
|:--:|---|---|---|
| 1 | Minuto | 0-59 | `17` |
| 2 | Hora | 0-23 | `3` |
| 3 | Día del mes | 1-31 | `*`, cualquiera |
| 4 | Mes | 1-12 | `*`, cualquiera |
| 5 | Día de la semana | 0-6, 0 = domingo | `*`, cualquiera |

| Operador | Significa | Ejemplo | Cuándo |
|---|---|---|---|
| `*` | Cualquier valor | `17 3 * * *` | Cada día a las 03:17 |
| `,` | Lista | `17 3 * * 1,4` | Lunes y jueves a las 03:17 |
| `-` | Rango | `0 8-18 * * 1-5` | En punto, de 8 a 18, laborables |
| `/` | Paso | `*/30 * * * *` | Cada 30 minutos |

No hay segundos ni un sexto campo de año, y no existen los atajos `@daily` o `@hourly`: actionlint
los rechaza. Si dudas de una expresión, pégala en [crontab.guru](https://crontab.guru/), que usa
la misma sintaxis de cinco campos.

### Zona horaria: UTC salvo que digas otra

Por defecto, la hora del cron es **UTC**. `0 9 * * *` corre a las 09:00 UTC, que en Madrid son
las 10:00 en invierno y las 11:00 en verano. Si te importa la hora local, declara la zona con
`timezone` y un nombre IANA:

```yaml
on:
  schedule:
    - cron: "17 3 * * *"
      timezone: "Europe/Madrid"
```

Con `timezone`, GitHub sigue los cambios de horario por ti. Sin ella, haz la cuenta en UTC y
asume que el run se mueve una hora dos veces al año. Para un nocturno da igual; para "antes de la
reunión de las 9", no.

### Las reglas de GitHub

- **Solo la rama por defecto**. GitHub lee el `schedule` del workflow **tal como está en la rama
  por defecto** y corre sobre su último commit. Un cron añadido en una rama de trabajo no hace
  nada hasta que se fusiona, y ese run tiene `github.ref == 'refs/heads/main'`.
- **Intervalo mínimo de 5 minutos**. `*/1 * * * *` no corre cada minuto.
- **No es puntual**. Con carga alta los runs programados se retrasan, y en el peor caso alguno se
  descarta. El momento de más carga es **el minuto 0** de cada hora, porque es donde casi todo el
  mundo pone su cron.
- **Se desactiva por inactividad**. En un repo público, si no hay actividad en 60 días, GitHub
  desactiva los workflows programados. El workflow sigue ahí; el cron, no.

### Qué trae el evento

En un run programado, `github.event_name` vale `schedule` y `github.event.schedule` trae la
expresión cron que lo disparó. Si declaras varias entradas en `schedule`, esa es la forma de saber
cuál fue:

```yaml
on:
  schedule:
    - cron: "17 3 * * *"
    - cron: "17 12 * * 1"
```

Con `if: ${{ github.event.schedule == '17 12 * * 1' }}` un job corre solo el lunes al mediodía.
Fíjate en que va en un `if:`, no dentro de `run:`: ahí la expresión se evalúa y no llega al shell.

## 3. Cómo se usa

### El esqueleto de `nightly.yml`

```yaml
name: nightly-skeleton

on:
  schedule:
    # Minuto 17 y no 0: en punto se acumulan los cron de medio GitHub.
    - cron: "17 3 * * *"
  # Sin dispatch tendrías que esperar a las 03:17 para probarlo.
  workflow_dispatch:

# Mínimo privilegio: lo verás a fondo en la Semana 12.
permissions:
  contents: read

jobs:
  report:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    steps:
      - name: Quién me ha despertado
        env:
          EVENT: ${{ github.event_name }}
          CRON: ${{ github.event.schedule }}
        run: |
          if [ "$EVENT" = "schedule" ]; then
            echo "Run programado por: $CRON"
          else
            echo "Run lanzado a mano"
          fi
```

Dos decisiones del esqueleto:

- **El minuto 17**. Cualquier minuto que no sea 0, 15, 30 o 45 sirve. No elimina los retrasos,
  los reduce.
- **`workflow_dispatch` al lado**. Un cron sin dispatch es imposible de probar sin esperar. Con los
  dos, la misma lógica corre por la noche y cuando tú la pides. Pero en el run del cron **no hay
  inputs**: cualquier input que leas tiene que tener un valor por defecto en la expresión (lo ves
  en el archivo siguiente y en `nightly.yml`).

### Comprobar que el cron está vivo

```bash
gh workflow list --all --json name,state --jq '.[] | "\(.state)\t\(.name)"'
# active              nightly
# disabled_inactivity ci-legacy
```

`disabled_inactivity` es el estado que deja la regla de los 60 días. Se reactiva con:

```bash
gh workflow enable nightly.yml
gh workflow list --all --json name,state --jq '.[] | select(.name == "nightly") | .state'
# active
```

Y para ver los runs que realmente lanzó el cron, filtra por evento:

```bash
gh run list --workflow nightly.yml --event schedule --limit 3 \
  --json createdAt,conclusion --jq '.[] | "\(.createdAt)\t\(.conclusion)"'
# 2026-11-02T03:24:51Z  success
```

Fíjate en la hora: programado a las 03:17, creado a las 03:24. Esos siete minutos son el retraso
del que habla la sección 2.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `cron: "0 * * * *"` | El minuto de más carga: más retrasos y runs descartados | Un minuto "raro", como `17` |
| Calcular la hora pensando en tu zona sin `timezone` | El run sale una o dos horas desplazado | `timezone` o la cuenta en UTC |
| Probar un cron en una rama de trabajo | No corre: solo se lee de la rama por defecto | `workflow_dispatch` en la rama y fusionar después |
| `*/1 * * * *` para "casi tiempo real" | El mínimo es 5 minutos y el retraso no es acotado | Un evento real (`push`, `repository_dispatch`) |
| Un cron que hace trabajo sin dueño | Falla cada noche y nadie lo mira | Notificar o abrir una issue al fallar |
| Leer `inputs.x` sin valor por defecto en un workflow con cron | En el run programado llega vacío | `inputs.x \|\| 'valor'` |
| Confiar en un cron de un repo sin actividad | A los 60 días deja de correr sin avisar | Revisar `gh workflow list --all` |

## 5. Trucos

- **`gh workflow list --all`** enseña también los workflows desactivados. Sin `--all` no
  aparecen, y un cron muerto pasa desapercibido.
- **`gh run list --event schedule`** separa los runs del cron de los que lanzaste tú. Si la lista
  está vacía tras varios días, el cron no está en la rama por defecto o está desactivado.
- **`github.event.schedule`** distingue entre varias entradas de `schedule` del mismo workflow:
  un único archivo con el nocturno diario y el informe semanal.

Verificado con actionlint 1.7.12 y ubuntu-24.04, noviembre 2026.

## 📚 Recursos Adicionales

- [GitHub Docs: Events that trigger workflows, `schedule`](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)
- [GitHub Docs: Disabling and enabling a workflow](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/disable-and-enable-workflows)
- [crontab.guru](https://crontab.guru/): editor de expresiones cron de cinco campos

## ✅ Checklist de Verificación

- [ ] Sé leer los cinco campos de una expresión cron
- [ ] Sé que la hora es UTC salvo que declare `timezone`
- [ ] Sé que el cron solo corre desde la rama por defecto
- [ ] Sé por qué evito el minuto 0
- [ ] Sé por qué un cron de un repo público deja de correr y cómo reactivarlo
- [ ] Sé distinguir en el workflow un run programado de uno lanzado a mano

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Filtros de rutas](02-filtros-de-rutas.md) | [workflow_dispatch e inputs](04-workflow-dispatch-e-inputs.md) |
