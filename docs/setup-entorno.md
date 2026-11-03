# 🛠️ Preparar el entorno

Necesitas Linux, o Windows con WSL2, y estas herramientas: gh, git, jq, yq, actionlint, zizmor, uv,
pnpm y Docker. Las de las semanas 08 y 16 (act, kind, kubectl, Helm) se instalan en su semana. Las
versiones exactas están en [`stack-versions.md`](stack-versions.md).

Esta guía instala en `~/.local/bin`, así que no hace falta `sudo`, y **comprueba el checksum de todo
lo que descarga**.

> [!WARNING]
> No instales nada con `curl ... | bash` ni con `curl ... | sh`. Ese patrón ejecuta lo que el
> servidor te mande ese día, sin que lo veas. Aquí se descarga primero, se verifica el checksum y
> solo después se instala.

## 0. Lo que ya tienes: git y gh

```bash
git --version
# git version 2.56.0
gh --version | head -1
# gh version 2.103.3 (2026-10-26)
```

Si te falta `gh`, sigue la guía oficial de tu distro en <https://github.com/cli/cli#installation>
(paquete del repositorio de GitHub CLI, firmado). Después inicia sesión con el scope `workflow`,
que hace falta para subir archivos a `.github/workflows/`:

```bash
gh auth login --scopes workflow
gh auth status
# ✓ Logged in to github.com account <tu-usuario> ...
# - Token scopes: 'gist', 'read:org', 'repo', 'workflow'
```

## 1. Cómo se verifica una descarga en este bootcamp

Cada release de GitHub publica el **digest SHA-256 de cada archivo** en su API. Lo descargas con
`gh release download` y comparas su hash con el que dice GitHub. Esta función hace las dos cosas;
pégala en tu terminal (o en `~/.bashrc` / `~/.zshrc`):

```bash
# download_verified <owner/repo> <tag> <file>
download_verified() {
  local repo="$1" tag="$2" file="$3" expected
  expected=$(gh api "repos/$repo/releases/tags/$tag" \
    --jq ".assets[] | select(.name == \"$file\") | .digest" | sed 's/^sha256://')
  [[ -n "$expected" ]] || { echo "Sin digest para $file en $repo@$tag" >&2; return 1; }
  gh release download "$tag" --repo "$repo" --pattern "$file" --clobber
  echo "$expected  $file" | sha256sum -c
}
```

Si el hash no coincide, `sha256sum -c` dice `FAILED` y sale con error: **no instales ese archivo**.

```bash
mkdir -p ~/.local/bin && cd "$(mktemp -d)"
```

Todos los pasos siguientes se ejecutan en ese directorio temporal.

## 2. jq y yq

`jq` viene de tu distro. `yq` tiene que ser **el de mikefarah (Go, v4)**, no el paquete de Python
que se llama igual: su sintaxis es distinta y los `checks.json` usan la de mikefarah.

```bash
sudo apt install jq              # Debian/Ubuntu (Fedora: sudo dnf install jq)

download_verified mikefarah/yq v4.54.1 yq_linux_amd64
# yq_linux_amd64: OK
install -m 0755 yq_linux_amd64 ~/.local/bin/yq
yq --version
# yq (https://github.com/mikefarah/yq/) version v4.54.1
```

## 3. actionlint

```bash
download_verified rhysd/actionlint v1.7.12 actionlint_1.7.12_linux_amd64.tar.gz
# actionlint_1.7.12_linux_amd64.tar.gz: OK
tar -xzf actionlint_1.7.12_linux_amd64.tar.gz actionlint
install -m 0755 actionlint ~/.local/bin/actionlint
actionlint -version | head -1
# 1.7.12
```

## 4. uv, y zizmor con uv

```bash
download_verified astral-sh/uv 0.13.6 uv-x86_64-unknown-linux-gnu.tar.gz
# uv-x86_64-unknown-linux-gnu.tar.gz: OK
tar -xzf uv-x86_64-unknown-linux-gnu.tar.gz
install -m 0755 uv-x86_64-unknown-linux-gnu/uv uv-x86_64-unknown-linux-gnu/uvx ~/.local/bin/
uv --version
# uv 0.13.6 (x86_64-unknown-linux-gnu)
```

zizmor es una herramienta de Python: se instala **con uv**, en su propio entorno aislado y con la
versión fijada.

```bash
uv tool install zizmor==1.31.1
zizmor --version
# zizmor 1.31.1
```

uv también instala Python: no necesitas el de tu distro. La versión del proyecto la fija
`.python-version` y uv la descarga sola la primera vez que la necesita.

## 5. Node y pnpm

pnpm se distribuye como ejecutable autónomo que ya incluye Node, así que no necesitas npm para
instalarlo:

```bash
download_verified pnpm/pnpm v12.16.1 pnpm-linux-x64.tar.gz
# pnpm-linux-x64.tar.gz: OK
mkdir -p ~/.local/share/pnpm-standalone
tar -xzf pnpm-linux-x64.tar.gz -C ~/.local/share/pnpm-standalone
ln -sf ~/.local/share/pnpm-standalone/pnpm ~/.local/bin/pnpm
pnpm --version
# 12.16.1
```

El Node con el que se ejecutan los tests del frontend también lo instala pnpm. Su directorio de
binarios globales tiene que estar en el `PATH`, o pnpm se niega a instalar nada global:

```bash
echo 'export PATH="$HOME/.local/share/pnpm/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc   # o ~/.bashrc
pnpm runtime set node 26 --global
# + node 26.13.0
node --version
# v26.13.0
```

`pnpm env use` es la forma antigua: en pnpm 12 está deprecado en favor de `pnpm runtime`
(verificado con pnpm 12.16.1, noviembre de 2026).

> [!NOTE]
> Desde Node 25, corepack ya no viene incluido con Node: por eso aquí no se usa `corepack enable`.
> En CI, pnpm lo instala `pnpm/action-setup`, que verás en la Semana 04.

## 6. Docker y el plugin Compose

Lo necesitas desde la Semana 05. Instala Docker Engine con el repositorio oficial de tu distro
(<https://docs.docker.com/engine/install/>) o Docker Desktop con integración WSL2. Comprueba que
tienes Compose como plugin de Docker, que se invoca como `docker compose` (con espacio). El
binario antiguo `docker-compose` (v1, con guion) está retirado: <!-- antipatron -->

```bash
docker version --format '{{.Server.Version}}'
# 29.9.2
docker compose version
# Docker Compose version v5.6.1
```

### WSL2: memoria

WSL2 usa por defecto la mitad de la RAM de Windows. Hasta la Semana 15 te sobra. Desde la 16, kind
con ARC y los despliegues de `tablero` necesitan más. Desde PowerShell, crea
`%UserProfile%\.wslconfig`:

```ini
[wsl2]
memory=10GB
processors=4
```

Después ejecuta `wsl --shutdown` y vuelve a abrir la terminal.

## 7. PATH

Si `~/.local/bin` no está en tu `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc   # o ~/.bashrc
```

## 8. Comprobar

```bash
./scripts/check-week.sh --doctor
# Herramientas (versiones en docs/stack-versions.md):
#   ✅ gh               gh version 2.103.3 (2026-10-26)
#   ✅ git              git version 2.56.0
#   ...
#   ⏳ act              se instala en la Semana 08
```

`--doctor` también comprueba `~/.bc-github-actions`, que creas en la Semana 01 junto con tu repo
`<tu-org>/tablero`. Hasta entonces esa línea sale en rojo y es lo esperado.

En ARM64 (Apple Silicon con Linux, Raspberry Pi), cambia `amd64`/`x86_64`/`x64` por
`arm64`/`aarch64` en los nombres de archivo: cada release publica los dos.

---

| ← Anterior | Siguiente → |
|:---|---:|
| [Documentación transversal](README.md) | [Autograding](autograding.md) |
