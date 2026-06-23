#!/usr/bin/env bash
#
# ci-build-packages.sh — Construye los paquetes propios de Solera DENTRO del
# contenedor de build (build/Containerfile). Semilla del futuro ci-build.sh
# (que además hará imagen e ISO).
#
# Lee las fuentes de $SRC (el repo montado, read-only), construye en un
# workdir propio del builder y deja los .pkg.tar.zst en $OUT.
#
#     SRC=/src OUT=/out bash scripts/ci-build-packages.sh
#
# Replica exactamente el paso [1/4] de rebuild-solera.sh:
#     makepkg --noconfirm --skippgpcheck --skipchecksums --force --nodeps
# (--nodeps salta también las makedepends; por eso la imagen del contenedor
# las trae ya instaladas — ver build/Containerfile.)

set -euo pipefail

SRC="${SRC:-/src}"
OUT="${OUT:-/out}"
WORK="${WORK:-$HOME/build}"

# El orden no importa: las deps se resuelven al generar el .db, no aquí.
PACKAGES=(
    solera-keyring
    arkdep
    os-installer
    os-installer-config-solera
    libnss-extrausers
    gnome-shell-extension-dash-to-dock
    gnome-shell-extension-blur-my-shell
    gnome-shell-extension-compiz-alike-magic-lamp-effect
    gnome-shell-extension-solera-update
    zsh-theme-powerlevel10k
    solera-config
    solera-meta
)

log() { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
die() { printf '\e[1;31m==>\e[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]]          || die 'makepkg rehúsa correr como root; lanza el contenedor como el usuario builder.'
[[ -d "$SRC/packages" ]]   || die "No existe $SRC/packages (¿montaste el repo en $SRC?)"
mkdir -p "$OUT" "$WORK"

built=0
for pkg in "${PACKAGES[@]}"; do
    [[ -d "$SRC/packages/$pkg" ]] || die "No existe packages/$pkg en el repo montado"
    log "[$((built + 1))/${#PACKAGES[@]}] $pkg"
    # Copiamos a un workdir escribible (el repo está montado read-only).
    rm -rf "${WORK:?}/$pkg"
    cp -a "$SRC/packages/$pkg" "$WORK/$pkg"

    # Purga de leftovers de makepkg para un build limpio y reproducible.
    # (a) Borra las entradas GITIGNORADAS del paquete: pkg/, el src/ de build,
    #     tarballs descargados y working copies VCS. Distinguir por gitignore
    #     es clave: en paquetes como os-installer-config-solera, src/ es
    #     PAYLOAD trackeado (config.yaml, scripts del instalador) y se conserva;
    #     en os-installer, src/ es leftover de build (gitignorado) y se borra.
    if git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1; then
        while IFS= read -r rel; do
            [[ -n "$rel" ]] || continue
            rm -rf "$WORK/$pkg/${rel#packages/$pkg/}"
        done < <(git -C "$SRC" -c safe.directory='*' ls-files \
                     --others --ignored --exclude-standard --directory \
                     -- "packages/$pkg/")
    fi
    # (b) Borra clones git bare TRACKEADOS con rutas absolutas obsoletas: este
    #     repo tiene COMMITEADO un mirror (packages/os-installer/os-installer/)
    #     con paths de otra máquina; borrarlo fuerza a makepkg a re-clonar desde
    #     la URL upstream. Se detectan por (HEAD + objects/).
    for d in "$WORK/$pkg"/*/; do
        [[ -e "${d}HEAD" && -d "${d}objects" ]] && rm -rf "$d"
    done
    (
        cd "$WORK/$pkg"
        rm -f ./*.pkg.tar.zst ./*.pkg.tar.zst.sig
        makepkg --noconfirm --skippgpcheck --skipchecksums --force --nodeps
    ) || die "makepkg falló para $pkg"

    shopt -s nullglob
    files=("$WORK/$pkg"/*.pkg.tar.zst)
    shopt -u nullglob
    [[ ${#files[@]} -gt 0 ]] || die "$pkg no produjo .pkg.tar.zst"
    cp -v "${files[@]}" "$OUT/"
    built=$((built + 1))
done

log "OK: $built/${#PACKAGES[@]} paquetes construidos"
ls -lh "$OUT"/*.pkg.tar.zst
