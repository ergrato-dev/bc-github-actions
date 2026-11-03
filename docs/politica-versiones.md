# 📌 Política de versiones

En GitHub Actions una versión no es solo un número: **es el código que se ejecuta en tu runner con
tu token**. Un tag como `v4` se puede mover a otro commit en cualquier momento. Así se
comprometieron `tj-actions/changed-files` en marzo de 2025 y `trivy-action` el 2026-03-19. Por eso
este bootcamp fija todo por SHA y revisa las versiones con calendario.

## Reglas

1. **Toda action por SHA de 40 caracteres con el tag en comentario**, resuelto con
   `scripts/resolver-sha.sh`. Nunca escrito a mano ni copiado de otro repo.
2. **Toda herramienta por versión exacta y checksum.** Nunca `latest`, nunca una rama, nunca
   `curl | bash`.
3. **Toda imagen con tag completo** (`17.11-alpine`, no `17` ni `latest`). Lo que se despliega,
   desde la Semana 14, por digest.
4. **Una versión se fija cuando se escribe la semana que la usa**, no antes. `stack-versions.md`
   separa las piezas fijadas de las que solo son de referencia.
5. **Seguridad antes que novedad.** Antes de fijar una versión se revisan sus avisos y se anota el
   resultado en la fila.

## Calendario de revisión

| Cuándo | Qué se revisa |
|---|---|
| Cada semana, automático | Dependabot (`.github/dependabot.yml`) propone PRs para las actions del CI propio |
| Al empezar cada tanda de semanas | Toda fila de `stack-versions.md` con más de 3 meses |
| Cuando GitHub anuncia un cambio de imagen de runner o de runtime de actions | `ubuntu-24.04` y el runtime de las actions JavaScript |
| Ante un aviso de seguridad de una pieza del stack | Esa fila, ese mismo día |

## Cómo actualizar una action

1. Comprueba el último release y sus avisos:

   ```bash
   gh api repos/actions/checkout/releases/latest --jq '.tag_name, .published_at'
   gh api repos/actions/checkout/security-advisories --jq '.[].summary'
   ```

2. Resuelve el SHA del tag nuevo:

   ```bash
   ./scripts/resolver-sha.sh actions/checkout v7.0.1
   # uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
   ```

3. Lee qué cambió en los inputs: un input renombrado rompe en silencio.

   ```bash
   gh api "repos/actions/checkout/contents/action.yml?ref=3d3c42e5aac5ba805825da76410c181273ba90b1" \
     --jq .content | base64 -d | yq '.inputs | keys'
   ```

4. Cambia la versión **primero en `stack-versions.md`**. Después en el contenido:

   ```bash
   grep -rl 'actions/checkout@' bootcamp docs app .github \
     | xargs sed -i -E 's|actions/checkout@[0-9a-f]{40} # v[0-9.]+|actions/checkout@<sha-nuevo> # <tag-nuevo>|g'
   ```

5. Pasa `bash scripts/verificar-enlaces.sh` y el skill `verificar-workflows`.

6. Haz un commit por pieza: `chore(stack): bump actions/checkout to v7.0.1`.

## Lo que no se hace

- ❌ Fijar una action por tag (`@v4`) o por rama (`@main`), ni siquiera "solo en el ejemplo".
- ❌ Enseñar como actual una pieza retirada (ver la tabla "Retirado" de `stack-versions.md`).
- ❌ Usar dos herramientas distintas para lo mismo en semanas distintas sin decir por qué.
- ❌ Fijar una versión `rc`, `beta` o `alpha` en un entregable evaluable.

_Última revisión: noviembre de 2026._

---

[← Volver al índice de documentación](README.md)
