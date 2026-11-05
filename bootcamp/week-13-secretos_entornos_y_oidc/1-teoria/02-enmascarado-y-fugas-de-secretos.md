# Enmascarado y fugas de secretos

> El runner tapa con `***` los secretos que reconoce en el log. Los que no reconoce los imprime
> tal cual, y reconoce menos de lo que parece.

## 🎯 Objetivos

Al terminar este archivo eres capaz de:

- Explicar cómo decide el runner qué texto sustituir por `***`
- Enumerar las formas en que un secreto llega al log sin que el runner lo tape
- Enmascarar un valor derivado con `::add-mask::` antes de que aparezca
- Diseñar los secretos para que la redacción funcione: valores simples, no JSON
- Reconocer los caminos de fuga que no pasan por el log: artefactos, cachés, procesos hijos
- Seguir el procedimiento correcto cuando un secreto se ha filtrado

## 1. Qué problema resuelve

El log de un run de `tablero` es **público**: el repo lo es, y cualquiera puede abrir la pestaña
Actions. Lo que aparezca en él lo puede leer cualquiera, ahora y durante los 90 días que GitHub
conserva los logs por defecto, y lo puede copiar antes de que lo borres.

GitHub mitiga esto redactando los secretos: si un paso imprime el valor de
`secrets.DATABASE_PASSWORD`, el log muestra `***`. La documentación lo dice con cuidado:

> GitHub Actions automatically redacts the contents of all GitHub secrets that are printed to
> workflow logs.

Y unas líneas después:

> Because there are multiple ways a secret value can be transformed, this redaction is not
> guaranteed.

_Verificado con la referencia de secretos de GitHub Actions, noviembre de 2026._

Este archivo trata de esa segunda frase: dónde deja de funcionar la redacción y qué haces tú
para que no dependa de ella.

## 2. Cómo funciona

### Qué hace el runner

Al empezar un job, el runner recibe los secretos que el job referencia y los registra como
**máscaras**: cadenas exactas que buscará en cada línea que escriba en el log. Si una línea
contiene una de ellas, la sustituye por `***` antes de enviarla a GitHub.

De ahí salen sus límites:

| Caso | ¿Se redacta? | Por qué |
|---|:--:|---|
| `echo "$DB_PASSWORD"` | Sí | El valor exacto aparece en la línea |
| `echo "$DB_PASSWORD" \| base64` | Sí | El runner registra también el base64 del secreto (y sus variantes desplazadas) |
| `echo "${DB_PASSWORD:0:8}"` | No | Una subcadena no es la máscara |
| URL con la contraseña codificada (`%40` en lugar de `@`) | Sí | El runner registra la versión codificada para URL, JSON y XML |
| `echo "$DB_PASSWORD" \| rev` o un `sha256sum` | No | Una transformación que el runner no conoce da otra cadena |
| Un secreto JSON y un paso que imprime un campo | No | La máscara es el JSON entero, no cada valor |
| Un valor que otra herramienta genera (un token que devuelve una API) | No | El runner no sabe que es secreto |
| El mismo secreto impreso en otro job que no lo referencia | No | "The runner can only redact secrets used within the current job" |
| Un secreto de un solo carácter o muy corto | Mal | Taparía media salida; no lo uses |

La última fila de la documentación es la más sutil: si el job A usa el secreto y el job B recibe
el valor por un artefacto o un archivo, **B no lo tapa**. Un output de job que contiene un
secreto sí lo frena el runner, que no lo envía al siguiente job; un artefacto, no.

### `::add-mask::`

Para los valores que el runner no conoce, existe el comando de workflow `::add-mask::` (Semana
08). Registra una máscara nueva desde ese punto del job en adelante:

```bash
PASSWORD_HEX=$(printf '%s' "$DB_PASSWORD" | od -An -tx1 | tr -d ' \n')
echo "::add-mask::$PASSWORD_HEX"
```

Dos condiciones para que sirva:

1. **Antes** de que el valor aparezca en ninguna línea. Lo que ya se imprimió no se tapa
   después.
2. El propio `echo "::add-mask::..."` no se imprime: el runner lo intercepta. Pero con `set -x`
   el shell escribe antes la traza `+ echo '::add-mask::<valor>'`, que no empieza por `::` y
   llega al log en claro. Enmascara valores que ya estén en una variable, sin `set -x`.

### Fugas que no pasan por el log

La redacción solo mira el log. Un secreto sale del job también por:

- **Artefactos**: un `upload-artifact` de un directorio que contiene un `.env` o un archivo de
  configuración generado.
- **Caché**: lo mismo con `actions/cache`; además, la caché la leen otros runs (Semana 12).
- **Imágenes Docker**: un `ARG` o un `COPY` de un archivo con el secreto queda en una capa
  publicada en GHCR.
- **`.git/config`**: el `GITHUB_TOKEN` de un `checkout` sin `persist-credentials: false`.
- **Procesos del job**: cualquier paso posterior, incluida cualquier action de terceros, puede
  leer las variables de entorno y los archivos del runner. Un secreto en `env:` a nivel de job
  lo ven todos los pasos; en `env:` de un paso, solo ese.
- **Resumen del job** (`$GITHUB_STEP_SUMMARY`): pasa por la redacción, con los mismos límites.

## 3. Cómo se usa

### Reglas para que la redacción ayude

**Un valor por secreto.** Si guardas `{"user":"tablero","password":"..."}` como un secreto, la
máscara es el JSON entero. En cuanto `jq -r .password` saca el campo, ese campo se imprime sin
tapar. Guarda `DATABASE_USER` y `DATABASE_PASSWORD` por separado. La documentación lo pide
expresamente: no uses datos estructurados como valor de un secreto.

**El secreto en el `env:` más estrecho posible.** Si solo un paso lo necesita, va en el `env:`
de ese paso:

```yaml
name: masked-example
on:
  workflow_dispatch:
permissions: {}
jobs:
  report:
    runs-on: ubuntu-24.04
    timeout-minutes: 5
    environment: staging
    permissions: {}
    steps:
      - name: Contraseña en hexadecimal para una herramienta que la pide así
        env:
          DB_PASSWORD: ${{ secrets.DATABASE_PASSWORD }}
        run: |
          encoded=$(printf '%s' "$DB_PASSWORD" | od -An -tx1 | tr -d ' \n')
          # Máscara antes de cualquier uso: el runner conoce el base64 del secreto, el hexadecimal no.
          echo "::add-mask::$encoded"
          echo "DB_PASSWORD_HEX=$encoded" >> "$GITHUB_ENV"
      - name: Este paso solo ve el valor codificado, ya enmascarado
        run: test -n "$DB_PASSWORD_HEX"
```

**No compruebes un secreto imprimiéndolo.** Comprueba que no está vacío (`test -n`), su
longitud (`${#DB_PASSWORD}`) o que coincide con otro sin mostrar ninguno:

```bash
if [ "$SHADOW_DEMO" = "nivel-staging" ]; then echo "llegó el de staging"; fi
```

Así es como la práctica 01 comprueba la precedencia sin poner ningún valor en el log.

### Qué ves cuando funciona y cuándo no

Con un valor de prueba **no sensible** (nunca uno real), la diferencia se ve así en el log:

```text
llegó: ***
base64: ***
rev: gnigats-levin
```

Las dos primeras líneas están tapadas: el runner conoce el base64 de cada secreto. La tercera
no, y cualquiera puede darle la vuelta con `rev`. Es
exactamente el experimento de la práctica 01, con el valor `nivel-staging`.

### Si un secreto se filtra

Un secreto en un log público se considera **comprometido**, aunque lo veas a los dos minutos:

1. **Rota el valor** primero: genera uno nuevo y cárgalo con `gh secret set`. En el caso de una
   contraseña de base de datos, cámbiala también en la base. Borrar el log no la desfiltra.
2. **Revoca** la credencial antigua en el servicio que la emitió, si es un token o una clave.
3. **Borra los logs** del run afectado: `gh run delete <run-id>` o "Delete all logs" en la UI.
4. **Revisa** el uso de la credencial durante la ventana en la que fue pública.
5. **Arregla la causa** en el workflow antes de volver a ejecutarlo.

El orden importa: borrar primero da sensación de seguridad mientras la credencial sigue viva.

Esto es lo que la rúbrica penaliza con el Producto a 0: un secreto real comiteado o en un log,
hasta que se rota y se retira.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `echo "$SECRET"` "para comprobar que llega" | Depende de la redacción, que no está garantizada | `test -n`, la longitud o una comparación |
| Un secreto JSON con varios campos | La máscara es el JSON; un campo extraído se imprime en claro | Un secreto por valor |
| `::add-mask::` después de imprimir | Lo ya impreso no se tapa | Enmascara antes del primer uso |
| `set -x` en un paso con secretos | Imprime cada comando expandido, también derivados | Quitar `set -x` o aislar el paso |
| Secreto en `env:` del job o del workflow | Lo ven todos los pasos y todas las actions del job | `env:` del paso que lo usa |
| Pasar un secreto a otro job por artefacto | El otro job no lo enmascara | Que cada job lea el secreto él mismo |
| Borrar el log y seguir | La credencial sigue siendo válida | Rotar, revocar, borrar, revisar |
| Usar valores reales para probar la redacción | Si falla, has filtrado una credencial | Valores de prueba como `nivel-staging` |

## 5. Trucos

- **Busca fugas en tus logs antes que nadie**:
  `gh run view <run-id> --log | grep -E '[A-Za-z0-9+/]{40,}={0,2}'` encuentra cadenas largas
  con pinta de base64. No es exhaustivo, pero caza el caso típico.
- **Cuántos caracteres tiene sin verlo**: `echo "longitud: ${#DB_PASSWORD}"`. Un 0 delata un
  secreto que no existe en ese nivel; un 48, el `openssl rand -hex 24`.
- **Borra los logs de un run sin borrar el run**: `gh api -X DELETE
  "repos/{owner}/{repo}/actions/runs/<run-id>/logs"`.

## 📚 Recursos Adicionales

- [GitHub Docs: Secrets reference, redaction](https://docs.github.com/en/actions/reference/security/secrets)
- [GitHub Docs: Workflow commands, masking a value](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#masking-a-value-in-a-log)
- [GitHub Docs: Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)

## ✅ Checklist de Verificación

- [ ] Sé que el runner busca la cadena exacta y por qué un derivado se le escapa
- [ ] Sé que un job no tapa un secreto que no usa
- [ ] Sé usar `::add-mask::` antes del primer uso de un valor derivado
- [ ] Sé por qué un secreto JSON es mala idea
- [ ] Sé comprobar un secreto sin imprimirlo
- [ ] Sé por dónde sale un secreto sin pasar por el log
- [ ] Sé el orden correcto ante una fuga: rotar, revocar, borrar, revisar

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Secretos de repo, environment y org](01-secretos-de-repo-environment-y-org.md) | [Environments y reglas de protección](03-environments-y-reglas-de-proteccion.md) |
