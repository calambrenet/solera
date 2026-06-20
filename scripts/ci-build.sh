#!/usr/bin/env bash
#
# ci-build.sh — Build COMPLETO de Solera DENTRO del contenedor de build:
#   paquetes propios → localrepo → imagen (arkdep-build) → ISO (mkarchiso).
#
# Mirror de rebuild-solera.sh, pero:
#   - asume la toolchain ya instalada (build/Containerfile), así que NO hace
#     el `pacman -S` de host-deps (eso es justo lo que falla en el host Solera
#     read-only);
#   - trabaja sobre una COPIA writable del repo (el montaje /src es read-only);
#   - deja todos los artefactos en $OUT (montado del host).
#
# Pensado para correr como usuario `builder` (makepkg rehúsa root); las etapas
# que necesitan privilegios (arkdep-build: loop/btrfs/pacstrap/chroot;
# mkarchiso: loop/squashfs) se invocan vía sudo. Por eso el contenedor se
# lanza --privileged (ver build/run-full-build.sh).
#
#   SRC=/src OUT=/out bash scripts/ci-build.sh
#
# Gate de etapas (todas 'yes' por default):
#   DO_PACKAGES=yes|no   construir paquetes + localrepo
#   DO_IMAGE=yes|no      construir la imagen del sistema
#   DO_ISO=yes|no        construir la ISO instaladora
#
# Variables de release (heredadas por image/build.sh y name.sh):
#   SOLERA_RELEASE  (default 26.04)
#   SOLERA_BUILD    (default timestamp con guiones — el id NO puede tener puntos)
#   SOLERA_ALA_DATE (opcional; si no, build.sh busca el último snapshot ALA)

set -euo pipefail

SRC="${SRC:-/src}"
OUT="${OUT:-/out}"
WORK="${WORK:-$HOME/build}"
SRCDIR="$WORK/solera"
# Ruta FIJA: arkdep-build la bind-montea en el chroot y iso/pacman.conf ya
# apunta aquí. No cambiar sin tocar iso/pacman.conf.
LOCALREPO="${LOCALREPO:-/var/cache/pacman/pkg/solera-localrepo}"
ARCH=x86_64

DO_PACKAGES="${DO_PACKAGES:-yes}"
DO_IMAGE="${DO_IMAGE:-yes}"
DO_ISO="${DO_ISO:-yes}"

: "${SOLERA_RELEASE:=26.04}"
: "${SOLERA_BUILD:=$(date +%Y%m%d-%H%M%S)}"
export SOLERA_RELEASE SOLERA_BUILD
[[ -n "${SOLERA_ALA_DATE:-}" ]] && export SOLERA_ALA_DATE

PACKAGES=(
    solera-keyring
    arkdep
    os-installer
    os-installer-config-solera
    libnss-extrausers
    gnome-shell-extension-dash-to-dock
    gnome-shell-extension-blur-my-shell
    gnome-shell-extension-compiz-alike-magic-lamp-effect
    zsh-theme-powerlevel10k
    solera-config
    solera-meta
)

log() { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
die() { printf '\e[1;31m==>\e[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]]        || die 'No correr como root: makepkg lo rehúsa. El contenedor corre como builder y usa sudo donde hace falta.'
[[ -d "$SRC/packages" ]] || die "No existe $SRC/packages (¿montaste el repo en $SRC?)"
mkdir -p "$OUT"

# ---------------------------------------------------------------------------
# Copia writable del repo (el montaje /src es read-only) + purga de leftovers.
# ---------------------------------------------------------------------------
log "Preparando copia writable del repo en $SRCDIR"
rm -rf "$SRCDIR"; mkdir -p "$SRCDIR"
cp -a "$SRC/." "$SRCDIR/"
rm -rf "$SRCDIR/.git"   # no necesitamos la historia en la copia de build

# (a) Borra entradas gitignoradas (pkg/, src/ de build, tarballs, target/,
#     work/, out/…). Distinguir por gitignore preserva los src/ que son PAYLOAD
#     trackeado (p.ej. os-installer-config-solera).
if git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1; then
    while IFS= read -r rel; do
        [[ -n "$rel" ]] && rm -rf "$SRCDIR/$rel"
    done < <(git -C "$SRC" -c safe.directory='*' ls-files \
                 --others --ignored --exclude-standard --directory)
fi
# (b) Borra clones git bare TRACKEADOS con rutas absolutas obsoletas (el mirror
#     commiteado packages/os-installer/os-installer/). makepkg re-clona desde
#     la URL upstream.
while IFS= read -r headf; do
    d=$(dirname "$headf")
    [[ -d "$d/objects" ]] && rm -rf "$d"
done < <(find "$SRCDIR" -type f -name HEAD 2>/dev/null)

cd "$SRCDIR"

# ---------------------------------------------------------------------------
# [1/4]+[2/4] Paquetes propios + localrepo
# ---------------------------------------------------------------------------
if [[ "$DO_PACKAGES" == yes ]]; then
    log "[1/4] Construyendo ${#PACKAGES[@]} paquetes propios"
    for pkg in "${PACKAGES[@]}"; do
        [[ -d "packages/$pkg" ]] || die "No existe packages/$pkg"
        log "    -> $pkg"
        (
            cd "packages/$pkg"
            rm -f ./*.pkg.tar.zst ./*.pkg.tar.zst.sig
            makepkg --noconfirm --skippgpcheck --skipchecksums --force --nodeps
        ) || die "makepkg falló para $pkg"
    done

    log "[2/4] Reset del localrepo: $LOCALREPO/$ARCH"
    sudo rm -rf "$LOCALREPO"
    sudo install -d -o "$(id -un)" -g "$(id -gn)" "$LOCALREPO/$ARCH"
    for pkg in "${PACKAGES[@]}"; do
        shopt -s nullglob; files=("packages/$pkg"/*.pkg.tar.zst); shopt -u nullglob
        [[ ${#files[@]} -gt 0 ]] || die "$pkg no produjo .pkg.tar.zst"
        cp "${files[@]}" "$LOCALREPO/$ARCH/"
        cp "${files[@]}" "$OUT/"
    done
    ( cd "$LOCALREPO/$ARCH" && repo-add solera.db.tar.gz ./*.pkg.tar.zst )
else
    log "[1-2/4] DO_PACKAGES=no — reutilizando localrepo en $LOCALREPO/$ARCH"
    [[ -d "$LOCALREPO/$ARCH" ]] || die "DO_PACKAGES=no pero no existe el localrepo"
fi

# ---------------------------------------------------------------------------
# [3/4] Imagen del sistema (arkdep-build)
# ---------------------------------------------------------------------------
if [[ "$DO_IMAGE" == yes ]]; then
    log "[3/4] Imagen del sistema — release=$SOLERA_RELEASE build=$SOLERA_BUILD"
    # arkdep-build no está en repos Arch: instálalo desde el localrepo.
    if ! command -v arkdep-build >/dev/null; then
        sudo pacman -U --noconfirm "$LOCALREPO/$ARCH"/arkdep-*.pkg.tar.zst
    fi
    rm -rf target; mkdir -p target
    SOLERA_REPO_URL="file://$LOCALREPO" SOLERA_OUT="$SRCDIR/target" \
        sudo -E bash image/build.sh || die 'image/build.sh falló'
    cp -v target/solera-*.tar.zst "$OUT/" 2>/dev/null || true
    cp -v target/solera-*.pkgs    "$OUT/" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# [4/4] ISO instaladora (mkarchiso)
# ---------------------------------------------------------------------------
if [[ "$DO_ISO" == yes ]]; then
    log "[4/4] ISO instaladora (mkarchiso)"
    # iso/pacman.conf ya apunta a file://$LOCALREPO/$ARCH; no hay que reescribir.
    bundle_src=$(ls -t target/solera-*.tar.zst 2>/dev/null | head -1 || true)
    [[ -n "$bundle_src" ]] || die 'No hay imagen en target/ para bundlear (¿corriste con DO_IMAGE=yes?)'
    log "    Bundle: $(basename "$bundle_src") ($(du -h "$bundle_src" | cut -f1))"
    BUNDLE_DST="iso/airootfs/var/lib/solera-bundle"
    sudo rm -rf "$BUNDLE_DST"; mkdir -p "$BUNDLE_DST"
    cp "$bundle_src" "$BUNDLE_DST/"

    # work/ de mkarchiso en /var/tmp (volumen real montado), no en el overlay.
    sudo rm -rf /var/tmp/archiso-work; mkdir -p out
    sudo mkarchiso -v -w /var/tmp/archiso-work -o out iso/ || die 'mkarchiso falló'
    cp -v out/solera-*.iso "$OUT/" || true
fi

log "OK. Artefactos en $OUT:"
ls -lh "$OUT"
