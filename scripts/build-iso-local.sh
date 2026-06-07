#!/usr/bin/env bash
#
# build-iso-local.sh — construye la ISO de Solera íntegramente en local,
# sin depender de S3 ni de GitHub Actions. Pensado como smoke test del
# perfil archiso y de los paquetes propios.
#
# Lo que hace:
#   1. Comprueba dependencias del host y las instala (sudo) si faltan.
#   2. Construye los 4 paquetes propios necesarios para la ISO:
#         arkdep, solera-keyring, os-installer, os-installer-config-solera
#   3. Monta un repositorio pacman local en /tmp/solera-localrepo/x86_64.
#   4. Genera un iso/pacman.conf temporal apuntando a ese repo local con
#      SigLevel=Optional TrustAll (no firmamos en local).
#   5. Invoca mkarchiso → ./out/solera-*.iso
#
# Uso:
#     scripts/build-iso-local.sh
#
# El script asume que está siendo ejecutado desde el raíz del repo solera/.

set -euo pipefail
shopt -s nullglob

readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Movernos al ROOT del repo en cuanto sepamos la ruta. Evita un fallo de
# mkarchiso si el usuario lanza el script desde un directorio que el script
# mismo borra después (p. ej. /var/cache/pacman/pkg/solera-localrepo/x86_64/,
# que se hace rm -rf en el paso 3). Sin esto, mkarchiso encuentra el inode
# de su CWD borrado y aborta con "OLDPWD: unbound variable".
cd "$ROOT"
# Anidado bajo /var/cache/pacman/pkg/ porque arkdep-build hace
# `mount --bind /var/cache/pacman/pkg $workdir/var/cache/pacman/pkg` antes
# del arch-chroot de la segunda fase (línea 334 de arkdep-build). Ese es
# el único directorio del host que queda visible dentro del chroot, así
# que el repo file:// tiene que vivir dentro de él. Si se pone en /tmp/,
# arch-chroot lo enmascara con un tmpfs limpio y pacman falla con
# "Could not open file" para los .pkg.tar.zst de [solera].
readonly LOCALREPO='/var/cache/pacman/pkg/solera-localrepo'
readonly ARCH='x86_64'
readonly WORKDIR="$ROOT/work"
readonly OUTDIR="$ROOT/out"

log()  { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m==>\e[0m %s\n' "$*" >&2; }
die()  { printf '\e[1;31m==>\e[0m %s\n' "$*" >&2; exit 1; }

# -----------------------------------------------------------------------------
# 1) Sanity checks
# -----------------------------------------------------------------------------
[[ $EUID -ne 0 ]] || die 'Ejecutar como usuario normal; el script invoca sudo solo cuando hace falta. makepkg rehúsa correr como root.'
command -v sudo >/dev/null || die 'sudo no está instalado'
[[ -d "$ROOT/iso" && -f "$ROOT/iso/profiledef.sh" ]] || die "No encuentro iso/profiledef.sh — ¿estás en el repo solera/?"

log "Instalando dependencias del host (puede pedir contraseña)..."
sudo pacman -S --needed --noconfirm \
    archiso arch-install-scripts pacman-contrib base-devel git \
    meson ninja blueprint-compiler gobject-introspection gettext \
    desktop-file-utils appstream-glib gtk4 libadwaita \
    python python-gobject python-yaml glib2 \
    sassc          # build-time dep de gnome-shell-extension-dash-to-dock

# -----------------------------------------------------------------------------
# 2) Construir los paquetes propios
# -----------------------------------------------------------------------------
build_pkg() {
    local name="$1"
    local dir="$ROOT/packages/$name"
    [[ -d "$dir" ]] || die "No existe packages/$name"
    log "Construyendo $name"

    pushd "$dir" >/dev/null
    # --nodeps: las deps de runtime no son necesarias para construir; ya las
    # resolverá mkarchiso. --skippgpcheck: nuestro propio repo aún no tiene
    # firmas locales.
    makepkg --syncdeps --noconfirm --skippgpcheck --skipchecksums --force --nodeps \
        || die "makepkg falló para $name"
    popd >/dev/null
}

# Paquetes que entran en el live ISO (consumidos por mkarchiso).
build_pkg solera-keyring
build_pkg arkdep
build_pkg os-installer
build_pkg os-installer-config-solera

# Paquetes que entran en la imagen del sistema (consumidos por arkdep-build
# vía el [solera] repo, no por mkarchiso). Se generan aquí para que con un
# único comando el localrepo quede listo para `image/build.sh`.
build_pkg libnss-extrausers
build_pkg gnome-shell-extension-dash-to-dock
build_pkg zsh-theme-powerlevel10k
build_pkg solera-config
build_pkg solera-meta

# -----------------------------------------------------------------------------
# 3) Repositorio pacman local
# -----------------------------------------------------------------------------
log "Generando repo local en $LOCALREPO/$ARCH (necesita sudo: bajo /var/cache)"
sudo rm -rf "$LOCALREPO"
sudo install -d -o "$USER" -g "$USER" "$LOCALREPO/$ARCH"

# Copia los .pkg.tar.zst recién construidos al repo local.
for pkg in "$ROOT"/packages/*/*.pkg.tar.zst; do
    cp -v "$pkg" "$LOCALREPO/$ARCH/"
done

# Índice del repo. Sin firma — para smoke test.
( cd "$LOCALREPO/$ARCH" && repo-add solera.db.tar.gz *.pkg.tar.zst )

ls -la "$LOCALREPO/$ARCH/"

# -----------------------------------------------------------------------------
# 4) pacman.conf temporal apuntando al repo local
# -----------------------------------------------------------------------------
log "Adaptando iso/pacman.conf"
cp "$ROOT/iso/pacman.conf" "$ROOT/iso/pacman.conf.bak"

# Sustituye el bloque [solera] entero por uno local-friendly.
python3 - "$ROOT/iso/pacman.conf" "$LOCALREPO/$ARCH" <<'PY'
import re, sys
path, repo = sys.argv[1], sys.argv[2]
with open(path) as f: s = f.read()
new_block = f"""[solera]
SigLevel = Optional TrustAll
Server = file://{repo}
"""
s = re.sub(r'\[solera\][^\[]*', new_block, s, flags=re.DOTALL)
with open(path, 'w') as f: f.write(s)
print(s.split('[solera]')[1].split('[')[0] if '[solera]' in s else 'no [solera] block found')
PY

# -----------------------------------------------------------------------------
# 4.5) Bundle de la imagen del sistema (Fase 2)
# -----------------------------------------------------------------------------
# La ISO necesita el .tar.zst de la imagen Solera dentro para hacer install
# offline. arkdep deploy lo leerá desde $arkdep_dir/cache/ vía "arkdep deploy
# cache <id>" — ver os-installer-config-solera/scripts/install.sh.d/20-...
readonly BUNDLE_DST="$ROOT/iso/airootfs/var/lib/solera-bundle"
log "Buscando imagen del sistema más reciente en target/..."

# Coge el tarball solera-*.tar.zst más nuevo (smoketest o solera real).
bundle_src=$(ls -t "$ROOT/target/"solera-*.tar.zst 2>/dev/null | head -1 || true)
if [[ -z "$bundle_src" ]]; then
    die "No hay imagen del sistema en target/. Constrúyela primero:
        sudo bash image/build-smoketest.sh   (smoke test)
    o
        SOLERA_REPO_URL=... sudo -E bash image/build.sh   (imagen real)"
fi

log "Bundlando imagen: $(basename "$bundle_src") ($(du -h "$bundle_src" | cut -f1))"
sudo rm -rf "$BUNDLE_DST"
mkdir -p "$BUNDLE_DST"
cp "$bundle_src" "$BUNDLE_DST/"

# -----------------------------------------------------------------------------
# 5) mkarchiso
# -----------------------------------------------------------------------------
log "Limpiando WORKDIR previo si existe..."
sudo rm -rf "$WORKDIR"
mkdir -p "$OUTDIR"

log "Lanzando mkarchiso (esto tarda 10-20 min)"
sudo mkarchiso -v -w "$WORKDIR" -o "$OUTDIR" "$ROOT/iso/"

# Restaura pacman.conf
mv "$ROOT/iso/pacman.conf.bak" "$ROOT/iso/pacman.conf"

log "Listo. Artefactos:"
ls -la "$OUTDIR/"
