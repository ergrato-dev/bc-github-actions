# 📚 eBooks y material gratuito — Semana 15

Guías largas y gratuitas para profundizar en lo que la teoría resume. Ninguna es obligatoria. Las
de contenedores se leen mejor con el `docker run` de `jit-runner.sh` abierto al lado, opción por
opción.

| Recurso | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [NIST SP 800-190: Application Container Security Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf) — NIST | La guía de referencia sobre qué aísla un contenedor y qué no: el kernel compartido, los privilegios y el demonio, el fondo de la teoría 05 | 2026-11-13 |
| [Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html) — OWASP | Las reglas que aplica `jit-runner.sh` en una lista: no exponer el socket, quitar capacidades, `no-new-privileges`, límites de recursos | 2026-11-13 |
| [CICD-SEC-7: Insecure System Configuration](https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-07-Insecure-System-Configuration) — OWASP | El riesgo de CI/CD que cubre un runner mal configurado: máquinas compartidas, privilegios de más y falta de aislamiento | 2026-11-13 |
| [CICD-SEC-4: Poisoned Pipeline Execution](https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-04-Poisoned-Pipeline-Execution) — OWASP | El ataque de la teoría 07 con nombre propio: traer tu propio workflow en un PR para que corra en la infraestructura del proyecto | 2026-11-13 |
| [capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html) — Linux man-pages | Qué permite cada capacidad que quitas con `--cap-drop ALL`; útil cuando un job falla y quieres saber cuál echaba de menos | 2026-11-13 |
| [No New Privileges Flag](https://docs.kernel.org/userspace-api/no_new_privs.html) — documentación del kernel Linux | Qué hace de verdad `no-new-privileges` y por qué bloquea `sudo` aunque el usuario esté en el grupo `sudo` (práctica 03 paso 3) | 2026-11-13 |
| [actions/runner](https://github.com/actions/runner) — GitHub | El código del listener y del worker: aquí comprobarás cualquier flag de `config.sh` o `run.sh` antes de fiarte de un tutorial | 2026-11-13 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Rúbrica de evaluación](../../rubrica-evaluacion.md) | [Videografía](../videografia/README.md) |
