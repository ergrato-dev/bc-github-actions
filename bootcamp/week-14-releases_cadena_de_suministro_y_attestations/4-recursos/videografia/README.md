# 🎬 Videografía — Semana 14

Casi todos en inglés. Ninguno usa las versiones de `docs/stack-versions.md`, y varios usan
`ubuntu-latest`, fijan actions por tag, instalan herramientas con un script remoto o usan
`trivy-action`, que la teoría 06 descarta tras el compromiso de marzo de 2026: quédate con los
conceptos y escribe los workflows como en la teoría.

| Vídeo | Por qué vale la pena | Comprobado |
|---|---|:--:|
| [Secure your cloud-native deployments with Artifact Attestations](https://www.youtube.com/watch?v=zTIHb-9c868) — GitHub | La presentación oficial de las attestations: firmar en el build y verificar antes de desplegar, lo que harás en la Semana 17 (teoría 05) | 2026-11-13 |
| [Qué son los Artifact Attestations en GitHub](https://www.youtube.com/watch?v=jTrCRGF5-fw) — return(GiS); | En español: qué es una attestation y por qué verificar releases e imágenes de contenedor | 2026-11-13 |
| [Enhancing Artifact Security with GitHub's Build Provenance... - Fredrik Skogman & Radoslav Dimitrov](https://www.youtube.com/watch?v=KDIKj65EB9I) — The Linux Foundation | Charla de un ingeniero de GitHub sobre la procedencia de build y cómo exigirla con políticas: el lado del consumidor | 2026-11-13 |
| [Building SLSA 3 Conforment Attestors for Artifacts Generated on GitHub - Ian Lewis & Asra Ali](https://www.youtube.com/watch?v=Aq3ND6xmkyU) — CNCF | Por qué L3 exige que el build lo haga un reutilizable aislado: la mejora que la teoría 03 deja como criterio opcional | 2026-11-13 |
| [SLSA, SigStore, SBOM and Software Supply Chain Security. What does that all mean really?](https://www.youtube.com/watch?v=COhqkBxJy1k) — Cloud Native Rejekts | Las tres piezas de la semana en una sola charla y cómo encajan: un buen repaso tras la teoría 03 | 2026-11-13 |
| [TGI Kubernetes 179: Project Sigstore](https://www.youtube.com/watch?v=8a97_Y-FObA) — VMware Cloud Native Apps | Sesión larga y práctica con cosign, Fulcio y Rekor: lo que `actions/attest` hace por ti, a mano | 2026-11-13 |
| [Use Release Please for Automated Releases](https://www.youtube.com/watch?v=zFvBT4m-FCU) — Ana's Dev Scribbles | Qué hace release-please: versión, CHANGELOG y release a partir de los commits (teoría 01) | 2026-11-13 |
| [Generating SBOM's using Syft](https://www.youtube.com/watch?v=PiSTpHNM0T0) — Pradeep Loganathan | syft en la terminal sobre una imagen y sus formatos de salida (teoría 04) | 2026-11-13 |
| [Container Image Scanning with Trivy -- Ep. 1 Trivy Overview](https://www.youtube.com/watch?v=-IH5inFyEqU) — Aqua Security Open Source | Visión general de Trivy desde el canal de sus autores: de dónde salen los avisos y qué escanea (teoría 06) | 2026-11-13 |
| [Helps reviewers and contributors understand dependency changes in every PR - GitHub Checkout](https://www.youtube.com/watch?v=4tWglfWd1So) — GitHub | Cómo se ve la revisión de dependencias en un PR, la pieza que la teoría 07 convierte en un check obligatorio | 2026-11-13 |

---

| ← Anterior | Siguiente → |
|:---|---:|
| [eBooks gratuitos](../ebooks-free/README.md) | [Webgrafía](../webgrafia/README.md) |
