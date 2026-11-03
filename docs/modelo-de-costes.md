# 💶 Modelo de costes

El bootcamp entero cuesta **0 €** si sigues una regla: **`<tu-org>/tablero` es público**. Esta
página explica qué consume recursos en GitHub, por qué en un repo público no se factura y qué
cambia si decides hacerlo privado.

> [!NOTE]
> Los planes y precios de GitHub cambian. Antes de escribir cada semana se comprueban en la
> documentación de facturación de GitHub y la fecha queda en [`stack-versions.md`](stack-versions.md).
> Si lees esto y algo no cuadra, abre un issue.

## Qué consume recursos

| Recurso | Qué lo consume en el bootcamp | Repo público | Repo privado |
|---|---|---|---|
| Minutos de runners alojados estándar (`ubuntu-24.04`) | Cada job de cada workflow | Gratis | Cupo mensual del plan gratuito; lo que pase de ahí se factura |
| Runners alojados más grandes (larger runners) | Nada: el bootcamp no los usa | De pago | De pago |
| Almacenamiento de artefactos y cachés | `upload-artifact` (S04), `actions/cache` (S03) | Gratis dentro de los límites | Cuenta contra el cupo del plan |
| GHCR (paquetes de contenedor) | Imágenes de `tablero` (S06+) | Gratis si el paquete es público | Cuenta contra el cupo del plan |
| Runners propios (S15+) | Tu máquina | Gratis para GitHub; la luz la pagas tú | Igual |

## Por qué el bootcamp no gasta

- **Todo corre en `ubuntu-24.04` estándar**, en un repo público.
- **Nada usa runners grandes, GPU, macOS ni Windows.** Sí se explican, en la Semana 19.
- **Las cachés y los artefactos tienen retención corta** desde la Semana 04, y la Semana 19 añade
  limpieza programada.
- **Los runners propios y el clúster corren en tu equipo**, no en la nube.

## Si tu repo es privado

Puedes hacerlo, pero entonces sí consumes cupo:

1. Mira tu consumo en `Settings → Billing and licensing` de la organización.
2. Pon un **presupuesto de 0 €** para Actions y Packages. Así, cuando se acabe el cupo los
   workflows se detienen en lugar de facturar.
3. Ten en cuenta que, si se acaba el cupo, el autograding de las semanas siguientes fallará por
   falta de ejecuciones, no por tu trabajo.

## Cómo comprobar que vas a 0 €

En `Settings → Billing and licensing → Usage` de tu organización, el importe de Actions y Packages
tiene que ser 0. Compruébalo al cerrar cada fase.

La Semana 19 profundiza: cómo se mide el tiempo de un run, dónde se va y cómo recortarlo, porque
en una empresa ese tiempo sí se paga.

---

[← Volver al índice de documentación](README.md)
