# Práctica 04 — Defensa del pipeline

> Un pipeline que solo entiende quien lo escribió deja de mantenerse el día que esa persona se
> va. En esta práctica escribes `docs/pipeline.md`: el mapa, las amenazas, las decisiones, los
> riesgos que aceptas y los runs que lo prueban. Después lo defiendes en voz alta y con reloj.

**Tiempo estimado**: 1 h

## 🎯 Qué vas a conseguir

- `docs/pipeline.md` con las cinco secciones del starter completas (`TODO 8` a `TODO 12`)
- Un modelo de amenazas con al menos el `GITHUB_TOKEN`, las imágenes, el runner propio y el clúster
- Al menos tres runs de `tablero` como evidencia, cada uno con lo que demuestra
- El documento en `main` por la cola y un `ci` completo sobre ese último commit
- Un ensayo cronometrado de la defensa, con la prueba de cada respuesta lanzada en directo

## 📋 Antes de empezar

Terminaste la [práctica 03](03-auditoria-completa.md). Leíste la
[teoría 04](../1-teoria/04-defender-un-pipeline.md): las cinco secciones, la forma de una
decisión y la diferencia entre un riesgo vago y uno concreto. Tienes a mano lo que guardaste en
las prácticas anteriores:

```bash
cd ~/code/tablero
git switch main && git pull --ff-only
export GH_REPO=<tu-org>/tablero
S=~/code/bc-github-actions/bootcamp/week-20-capstone/3-proyecto/starter
wc -l < ~/code/evidencias-20.txt; head -1 ~/code/ajustes-20.txt
# 2
# <fecha>
```

`evidencias-20.txt` tiene el `ci` completo de la práctica 01 y la release de la 02.
`ajustes-20.txt` tiene los ajustes que leíste por API en la 03.

---

## Paso 1: El mapa del pipeline

**Por qué**: quien lee el documento empieza por aquí para orientarse. El mapa responde a dos
preguntas: qué workflow hace qué entre un push y producción, y qué tiene que pasar para que algo
entre en `main`. Si no queda claro que `ci-gate` es el **único** check requerido, todo lo demás
se lee mal. Es el camino de la [teoría 01](../1-teoria/01-que-hace-de-un-pipeline-uno-de-produccion.md),
escrito para alguien que no ha abierto un YAML. Incluye cómo entra el worker sin jobs propios:
es lo que demuestra que el pipeline escala.

**Comando**: copia la plantilla y sustituye el comentario del `TODO 8`:

```bash
git switch -c docs/pipeline-defense
mkdir -p docs && cp "$S/docs/pipeline.md" docs/
```

Una forma que funciona es una lista numerada por el camino de un cambio, un workflow por línea:

```markdown
1. **PR**: `ci.yml` decide qué áreas cambian (`scripts/changed-areas.sh`) y llama solo a sus
   workflows: `ci-api`, `ci-web`, `ci-tools`, `ci-worker`, `smoke` y `lint-workflows`.
   `ci-gate` las espera a todas y es el único check que exige el ruleset de `main`.
2. **Merge queue**: el mismo `ci.yml` corre con `merge_group` sobre `main` + el PR ...
3. ...
```

Llega hasta production: `images.yml`, `release.yml` con Trivy, SBOM y attestations,
`deploy.yml` con verificación, aprobación y rollback, y `ci-metrics.yml` vigilando el p95. Para el
worker, una frase: `ci-worker.yml` solo llama a `_python.yml` del central, e `images.yml` y
`release.yml` lo construyen con lo que ya tenían.

**Verifica**: el hueco está cerrado y el mapa nombra la puerta, el worker y la ruta a producción:

```bash
grep -c "TODO 8" docs/pipeline.md
# 0
for w in ci-gate ci-worker release.yml deploy.yml; do grep -q "$w" docs/pipeline.md && printf '%s ' "$w"; done; echo
# ci-gate ci-worker release.yml deploy.yml
```

---

## Paso 2: El modelo de amenazas

**Por qué**: "es seguro" no es una respuesta, pero "esto es lo que protejo, de esto y así" sí lo
es. La tabla Activo | Amenaza | Defensa viene de la
[Semana 12](../../week-12-modelo_de_amenazas_y_endurecimiento/1-teoria/01-modelo-de-amenazas-de-un-pipeline.md),
y la defensa necesita al menos cuatro activos. Cada defensa tiene que bajar a un archivo, un
ajuste o una regla de tu política. Si escribes "permisos mínimos", alguien te preguntará dónde.
La respuesta es `permissions: {}` en la raíz y la regla `permissions-root`, que lo comprueba en
cada PR.

**Comando**: sustituye el comentario del `TODO 9` por la tabla. Cuatro filas obligatorias, más
las que quieras, como los secretos de environment o el repo central:

```markdown
| Activo | Amenaza | Defensa |
|---|---|---|
| `GITHUB_TOKEN` | ... | ... |
| Imágenes publicadas | ... | ... |
| Runner propio | ... | ... |
| Clúster | ... | ... |
```

Usa tus propias defensas, no las de la teoría copiadas. Si una defensa depende de un ajuste,
cita la línea de `~/code/ajustes-20.txt`: por ejemplo, `production reviewers=1` para el clúster.

**Verifica**: las cuatro filas obligatorias están en la tabla, no en la prosa:

```bash
for a in GITHUB_TOKEN "Imágenes" "Runner" "Clúster"; do grep -qiE "^\| *\`?$a" docs/pipeline.md && printf 'ok ' || printf "falta-$a "; done; echo
# ok ok ok ok
grep -c "TODO 9" docs/pipeline.md
# 0
```

---

## Paso 3: Las evidencias

**Por qué**: cada afirmación fuerte del documento necesita su prueba, y la más barata de
comprobar es un run. Elige runs que demuestren algo concreto y que puedas regenerar, porque un
enlace caduca con la retención de 14 días que pusiste en la Semana 19. Junto a cada enlace va
una frase que diga qué demuestra y cómo se vuelve a lanzar. Los comandos con su salida, como
`gh attestation verify` o `audit-workflows.sh`, y los ajustes con fecha completan la sección.

**Comando**: los dos que guardaste, y los que faltan, sacados con `gh` y sin la UI:

```bash
cat ~/code/evidencias-20.txt
# https://github.com/<tu-org>/tablero/actions/runs/<id>
# https://github.com/<tu-org>/tablero/actions/runs/<id>
gh run list --workflow ci.yml --branch ci/audit-policy --event pull_request --limit 1 \
  --json url,conclusion --jq '.[0] | "\(.url) \(.conclusion)"'
# https://github.com/<tu-org>/tablero/actions/runs/<id> success
gh run list --workflow deploy.yml --limit 1 --json url,conclusion --jq '.[0] | "\(.url) \(.conclusion)"'
# https://github.com/<tu-org>/tablero/actions/runs/<id> success
gh run list --workflow ci-metrics.yml --limit 1 --json url,conclusion --jq '.[0] | "\(.url) \(.conclusion)"'
# https://github.com/<tu-org>/tablero/actions/runs/<id> success
```

Sustituye el comentario del `TODO 12` por una lista. Cada línea lleva el enlace completo y una
frase:

```markdown
- `ci` completo sobre `main`, con los tres jobs del worker en verde:
  https://github.com/<tu-org>/tablero/actions/runs/<id>. Se regenera con `gh workflow run ci.yml --ref main`.
- Release con `tablero-worker` escaneada y firmada: https://github.com/<tu-org>/tablero/actions/runs/<id>.
- La política en el CI, en el PR que la añadió: https://github.com/<tu-org>/tablero/actions/runs/<id>.
- `gh attestation verify oci://ghcr.io/<tu-org>/tablero-worker:<versión> --repo <tu-org>/tablero --signer-workflow <tu-org>/tablero/.github/workflows/release.yml` → `✓ Verification succeeded!`
- Ajustes leídos por API el <fecha>: (las líneas de `~/code/ajustes-20.txt`)
```

Con tu org y tus `<id>` reales: el check cuenta enlaces, no marcadores.

**Verifica**: la orden de `defense-doc`, y que cada enlace que citas terminó en verde:

```bash
f=docs/pipeline.md; printf 'secciones=%s runs=%s\n' "$(grep -cE '^## (Mapa del pipeline|Modelo de amenazas|Decisiones|Riesgos aceptados|Evidencias)$' $f)" "$(grep -oE 'https://github\.com/[^/]+/tablero/actions/runs/[0-9]+' $f | sort -u | wc -l)"
# secciones=5 runs=<3 o más>
grep -oE 'actions/runs/[0-9]+' docs/pipeline.md | sort -u | cut -d/ -f3 \
  | while read -r id; do gh run view "$id" --json conclusion --jq .conclusion; done | sort | uniq -c
#       <n> success
```

Si un run sale `failure`, no es evidencia de nada bueno: cámbialo por uno en verde o explica en
la frase qué demuestra ese fallo. Un rollback de la Semana 17, por ejemplo.

---

## Paso 4: Decisiones y riesgos aceptados

**Por qué**: las decisiones explican por qué el pipeline es así y no de otra forma. Una decisión
sin la alternativa que descartaste es solo una descripción. Los riesgos aceptados son lo que una
defensa honesta enseña sin que se lo pidan. Si la sección está vacía, lo que oyes es "no lo has
mirado". Un riesgo concreto se puede discutir: dice qué falta, por qué lo aceptas y qué lo
cerraría. Esta semana te deja dos riesgos reales. Dependabot no mueve el digest de `postgres` en
el `_python.yml` del central, y el chart no despliega el worker.

**Comando**: sustituye los comentarios de `TODO 10` y `TODO 11`. Tres decisiones con la forma
de la teoría: qué decidiste, por qué y qué descartaste a cambio de qué coste. Candidatas tuyas:
`ci-gate` como único check, reutilizables en un repo central por SHA de release, despliegue por
digest con attestation verificada, runners efímeros de ARC para desplegar. Después, al menos dos
riesgos, una línea cada uno:

```markdown
- **El chart no despliega el worker.** Lo acepto porque ... Lo cerraría un `CronJob` en
  `deploy/k8s` con ...
- **Dependabot no actualiza el digest de `postgres` en `_python.yml`.** Lo reviso a mano en cada
  release del central ...
```

Ya completo, el documento entra por la cola. Ese merge cambia el último commit de `main`, así
que después lanzas el `ci` completo que pide `ci-full-run-green`:

```bash
grep -cE "TODO (8|9|10|11|12)" docs/pipeline.md
# 0
git add docs/pipeline.md
git commit -m "docs: add pipeline defense document"
git push -u origin docs/pipeline-defense
gh pr create --fill
pr=$(gh pr view --json number --jq .number)
gh pr checks "$pr" --watch --required > /dev/null && gh pr merge "$pr"
until [ "$(gh pr view "$pr" --json state --jq .state)" = MERGED ]; do sleep 15; done
git switch main && git pull --ff-only
gh workflow run ci.yml --ref main
sleep 5
gh run watch "$(gh run list --workflow ci.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status > /dev/null && echo ci-completo-ok
# ci-completo-ok
```

**Verifica**: el documento está en `main`, con sus riesgos, y el run completo es del último commit:

```bash
git log -1 --format=%s
# docs: add pipeline defense document (#<n>)
awk '/^## Riesgos aceptados$/{on=1; next} /^## /{on=0} on && /^- /' docs/pipeline.md | wc -l
# 2
gh run list --workflow ci.yml --event workflow_dispatch --commit "$(git rev-parse HEAD)" --json conclusion --jq '.[0].conclusion'
# success
```

El `2` es tu número de riesgos: tiene que ser al menos 2. Si quieres que el enlace del `ci`
completo de tus evidencias sea el de este último commit, cámbialo en otro PR. Ese PR cambia otra
vez el último commit, así que repite después el `gh workflow run`.

---

## Paso 5: Ensayo de la defensa, cronometrado

**Por qué**: un documento que no sabes contar en voz alta no te defiende. La defensa de la
[rúbrica](../rubrica-evaluacion.md) tiene dos partes: diez minutos de exposición sin abrir un
YAML y una ronda de preguntas. Cada respuesta va en dos frases y, si te la piden, con su
prueba. Las preguntas son las de la tabla de la
[teoría 04](../1-teoria/04-defender-un-pipeline.md). Ensayarlas con las pruebas en la terminal
es la diferencia entre "creo que sí" y "míralo". Y "no lo sé, lo compruebo así" sigue siendo una
respuesta válida.

**Comando**: pon un cronómetro y expón el documento en diez minutos, en voz alta. Después,
contesta cada pregunta en voz alta y lanza su prueba. Cada línea de abajo es la prueba de una
pregunta, en el orden de la tabla:

```bash
start=$(date +%s)
gh api 'repos/{owner}/{repo}/rules/branches/main' --jq '[.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context] | join(",")'
# ci-gate
gh api 'repos/{owner}/{repo}/actions/permissions/fork-pr-contributor-approval' --jq .approval_policy
# all_external_contributors
v=$(gh release view --json tagName --jq .tagName); o=${GH_REPO%%/*}
gh attestation verify "oci://ghcr.io/${o,,}/tablero-api:${v#v}" --repo "$GH_REPO" --signer-workflow "$GH_REPO/.github/workflows/release.yml" > /dev/null 2>&1 && echo firmada
# firmada
gh run list --workflow deploy.yml --limit 10 --json conclusion --jq 'group_by(.conclusion) | map("\(.[0].conclusion)=\(length)") | join(" ")'
# success=<n> ...
grep -rhoE 'actions-tablero/[^@ ]+@[0-9a-f]{40}' .github | sed 's/.*@//' | sort -u | wc -l
# 1
gh run list --workflow ci-metrics.yml --limit 1 --json conclusion --jq '.[0].conclusion'
# success
awk '/^## Riesgos aceptados$/{on=1; next} /^## /{on=0} on' docs/pipeline.md | head -3
# ...
echo "ensayo: $(( ($(date +%s) - start) / 60 )) min"
# ensayo: <m> min
```

Apunta cada pregunta en la que tuviste que buscar la prueba en lugar de saberla. Esa parte del
documento está floja: refuérzala antes de la defensa real.

**Verifica**: el ensayo terminó en menos de 25 minutos (10 de exposición y el resto de preguntas)
y la semana está completa:

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 20 | tail -1
# 17/17 comprobaciones superadas.
```

---

## ✅ Resultado

- [ ] `docs/pipeline.md` con las cinco secciones y sin `TODO`
- [ ] Un modelo de amenazas con `GITHUB_TOKEN`, imágenes, runner propio y clúster
- [ ] Al menos tres runs como evidencia, todos en verde, cada uno con lo que demuestra
- [ ] Tres decisiones con su alternativa descartada y al menos dos riesgos concretos
- [ ] El documento en `main` y un `ci` completo sobre ese commit
- [ ] Un ensayo cronometrado con la prueba de cada pregunta lanzada en directo

```bash
cd ~/code/bc-github-actions
./scripts/check-week.sh 20
# ...
#   ✅ El último commit de main pasó un ci completo lanzado a mano, con los tres jobs del worker en verde
#   ✅ docs/pipeline.md tiene las cinco secciones de la defensa y enlaza al menos tres runs como evidencia
# 17/17 comprobaciones superadas.
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `secciones=4` | Cambiaste un título o le añadiste algo detrás (`## Decisiones de diseño`) | Los cinco títulos tal cual vienen en la plantilla |
| `runs=0` aunque hay enlaces | Dejaste `<tu-org>` o `<id>`, o enlazaste un job (`.../job/<id>`) de otro repo | Enlace completo a un run de `<tu-org>/tablero` |
| `ci-full-run-green` en rojo después del paso 4 | El `ci` completo es anterior al último merge | `gh workflow run ci.yml --ref main` después del último merge |
| `gh run view` de una evidencia da `not found` | El run caducó con la retención de 14 días | Regenera el run y cambia el enlace |
| `falta-Clúster` en el paso 2 | La fila empieza por otra palabra (`Kubernetes`) o está en la prosa | La primera celda de la fila nombra el activo |
| El ensayo pasa de 25 minutos | Lees el documento en lugar de contarlo | Vuelve a ensayar con el documento cerrado y solo el mapa delante |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Práctica 03 — Auditoría completa](03-auditoria-completa.md) | [Proyecto: capa 20 de tablero](../3-proyecto/README.md) |
