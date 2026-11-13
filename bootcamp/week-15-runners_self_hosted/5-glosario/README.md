# 📖 Glosario — Semana 15

Términos que introduce esta semana, de la A a la Z. Entre paréntesis, el término original en inglés
cuando se usa en la documentación. Glosario de todas las semanas:
[`docs/glosario.md`](../../../docs/glosario.md).

## A

- **`ACTIONS_RUNNER_INPUT_JITCONFIG`**: variable de entorno por la que `run.sh` recibe la
  configuración JIT en lugar del argumento `--jitconfig`. El runner la lee, la quita de su entorno
  y la enmascara en los logs. `docker inspect` sí la enseña.
- **Actualización del runner** (*runner update*): el runner se actualiza solo por defecto. Con
  `--disableupdate`, o en un contenedor desechable, lo haces tú, y tienes 63 días desde que sale
  una versión nueva antes de que deje de recibir jobs.
- **Aprobación de PR de forks** (*fork pull request workflow approval*): ajuste del repo que hace
  esperar los workflows de un PR de alguien sin permiso de escritura hasta que un mantenedor los
  aprueba. En `tablero`, `approval_policy: all_external_contributors`.

## B

- **Baja del runner** (*runner removal*): quitar un runner de GitHub: con `config.sh remove` y un
  token de baja, con `DELETE .../actions/runners/{id}` o dejando que GitHub lo borre si no se
  conecta (14 días; 1 si es efímero).

## C

- **Capacidades** (*Linux capabilities*): trozos en que Linux divide los privilegios de root.
  `--cap-drop ALL` se los quita todos al contenedor del runner.
- **Cola de 24 horas** (*queue time*): lo máximo que un job de runner propio espera a que un
  runner con sus etiquetas lo recoja. Pasado ese plazo, falla.
- **`config.sh`**: script de `actions/runner` que registra un runner con un token de registro y sus
  opciones (`--labels`, `--ephemeral`, `--no-default-labels`, `--disableupdate`). Un runner JIT no
  lo usa.

## E

- **Etiqueta** (*label*): nombre que tiene un runner y que pide `runs-on`. Un job va a un runner
  que tenga **todas** las etiquetas pedidas.
- **Etiquetas por defecto** (*default labels*): las tres que `config.sh` añade sola:
  `self-hosted`, el sistema operativo y la arquitectura. La API las marca `read-only`; las tuyas,
  `custom`. Un runner JIT no recibe ninguna.
- **`--ephemeral`**: opción de `config.sh` que registra un runner para un solo job. Se da de baja
  el runner, no se limpia la máquina.

## G

- **`generate-jitconfig`**: llamada de la API (`POST repos/{owner}/{repo}/actions/runners/generate-jitconfig`)
  que registra un runner JIT con `name`, `runner_group_id` y `labels`, y devuelve su
  `encoded_jit_config`.
- **Grupo por defecto** (*default runner group*): el runner group que tiene toda organización, con
  id `1`. Es el que usa un runner de repositorio.

## J

- **JIT** (*just-in-time runner*): runner que registra la API desde fuera, recibe una
  configuración de un solo uso y hace como mucho un job. La máquina nunca ve un token de registro.

## L

- **Listener** (`Runner.Listener`): proceso que arranca `run.sh`. Abre conexiones salientes
  HTTPS para preguntar si hay un job y, cuando lo hay, lanza un worker.

## N

- **`no-new-privileges`** (`--security-opt no-new-privileges`): opción de Docker que impide que
  un proceso gane privilegios al ejecutar otro programa. Por eso `sudo` deja de funcionar dentro
  del contenedor del runner.

## P

- **Política de runners de repositorio** (*repository-level self-hosted runners policy*): ajuste de
  la org que dice qué repos pueden tener runners propios: todos, los seleccionados o ninguno. En tu
  org, solo `tablero`.

## R

- **Runner de organización** (*organization-level runner*): runner registrado en la org que
  pueden usar los repos que permita su runner group.
- **Runner de repositorio** (*repository-level runner*): runner registrado en un único repo; ningún
  otro repo puede pedirle jobs. El de `tablero`.
- **Runner efímero** (*ephemeral runner*): runner que acepta un solo job y luego se da de baja,
  registrado con `--ephemeral` o por JIT.
- **Runner group**: conjunto de runners de organización con una lista de repos (y opcionalmente
  de workflows) que pueden usarlos. Grupos adicionales, a partir del plan Team.
- **Runner persistente** (*persistent runner*): runner que acepta jobs uno tras otro hasta que lo
  paras. El siguiente job hereda lo que dejó el anterior.
- **Runner propio** (*self-hosted runner*): runner que corre en una máquina tuya en lugar de en
  la infraestructura de GitHub. Sus minutos no consumen la cuota.
- **`RUNNER_TRACKING_ID`**: variable que el worker pone a los procesos del job para terminarlos al
  acabar (`Cleaning up orphan processes`). Un proceso que la cambia se escapa.

## S

- **`self-hosted-runner`**: clave de `.github/actionlint.yaml` donde se declaran las etiquetas
  propias para que actionlint no las rechace en `runs-on`.
- **Socket de Docker** (*Docker socket*, `/var/run/docker.sock`): el punto por el que se habla con
  el demonio de Docker, que es root en el host. Montarlo en el runner le da root en tu máquina.
- **Sondeo** (*polling*): la forma en que el listener pregunta a GitHub por jobs, siempre
  desde dentro hacia fuera. No hace falta abrir ningún puerto de entrada.

## T

- **Token de baja** (*remove token*): token de un solo uso que pide `config.sh remove` para dar
  de baja un runner.
- **Token de registro** (*registration token*): token que pide `config.sh` para registrar un
  runner. Caduca en una hora. `tablero` no lo usa fuera de la práctica 01.

## W

- **Worker** (`Runner.Worker`): proceso que el listener lanza para cada job. Descarga las
  actions, prepara `_work`, ejecuta los steps y envía los logs.
- **`_work`**: directorio de trabajo del runner, con el checkout, `_actions`, `_tool` y `_temp`.
  En un runner persistente sobrevive entre jobs.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Webgrafía](../4-recursos/webgrafia/README.md) | [Índice del bootcamp](../../README.md) |
