#!/usr/bin/env bash
#
# image/build.sh — wrapper alrededor de arkdep-build para construir la
# imagen del sistema de Solera anclada a un snapshot del Arch Linux Archive.
#
# Uso:
#   SOLERA_ALA_DATE=2026/04/30 \
#   SOLERA_RELEASE=26.04 \
#   SOLERA_BUILD=20260517-180000 \
#   SOLERA_REPO_URL='file:///var/cache/pacman/pkg/solera-localrepo' \
#       sudo -E ./image/build.sh
#
# Variables:
#   SOLERA_ALA_DATE   Fecha YYYY/MM/DD del Arch Linux Archive (default último
#                     día del mes anterior, p. ej. 2026/04/30 si hoy es mayo).
#   SOLERA_RELEASE    Release semestral en formato YY.MM (default 26.04).
#   SOLERA_BUILD      Identificador interno de build (default timestamp).
#   SOLERA_REPO_URL   URL base del repo pacman de Solera. Para build local
#                     debe vivir bajo /var/cache/pacman/pkg/ — es el único
#                     directorio del host que arkdep-build hace visible
#                     dentro del chroot de la segunda fase. En CI será
#                     https://${SOLERA_CDN}/repo.
#   SOLERA_OUT        Donde se depositan los artefactos (default ./target).
#
# Requisitos:
#   - sudo / root (arkdep-build crea subvolúmenes Btrfs en /var/tmp)
#   - btrfs-progs, pacstrap, arkdep instalado en el host

set -euo pipefail

# ---- Defaults ---------------------------------------------------------------
# Encuentra la fecha YYYY/MM/DD más reciente con snapshot en el Arch Linux
# Archive. El archive no tiene snapshot todos los días, así que probamos
# hacia atrás desde "ayer" hasta encontrar una válida.
find_latest_ala_date() {
    local day url code
    for offset in $(seq 1 60); do
        day=$(date -d "today - ${offset} day" '+%Y/%m/%d' 2>/dev/null) || continue
        url="https://archive.archlinux.org/repos/${day}/core/os/x86_64/core.db"
        code=$(curl -s -o /dev/null -w '%{http_code}' --head "$url" 2>/dev/null)
        if [[ "$code" == "200" ]]; then
            printf '%s\n' "$day"
            return 0
        fi
    done
    return 1
}

: "${SOLERA_RELEASE:=26.04}"
: "${SOLERA_BUILD:=$(date +%Y%m%d-%H%M%S)}"
: "${SOLERA_REPO_URL:?ERROR: SOLERA_REPO_URL no definido (URL del repo pacman de Solera)}"
# SOLERA_OUT relativo al root del repo (no al cwd). Antes default era
# $(pwd)/target, lo que dejaba el tarball en el dir desde el que se lanzase
# el script — sorpresa cuando se ejecutaba desde packages/<algo>/.
: "${SOLERA_OUT:=$(cd "$(dirname "$0")/.." && pwd)/target}"

if [[ -z "${SOLERA_ALA_DATE:-}" ]]; then
    printf 'build.sh: buscando snapshot del Arch Linux Archive...\n' >&2
    if ! SOLERA_ALA_DATE=$(find_latest_ala_date); then
        printf 'ERROR: no encontré snapshot del archive en los últimos 60 días.\n' >&2
        exit 1
    fi
else
    ala_url="https://archive.archlinux.org/repos/${SOLERA_ALA_DATE}/core/os/x86_64/core.db"
    if ! curl -sfL -o /dev/null --head "$ala_url"; then
        printf 'ERROR: SOLERA_ALA_DATE=%s no existe en el archive.\n' "$SOLERA_ALA_DATE" >&2
        exit 1
    fi
fi

# ---- Genera pacman.conf con los valores reales ------------------------------
scriptdir="$(cd "$(dirname "$0")" && pwd)"
variantdir="$scriptdir/arkdep-build.d/solera"
template="$variantdir/pacman.conf.template"
real="$variantdir/pacman.conf"

# SigLevel del repo [solera]: confianza ciega en builds locales (file://),
# firma obligatoria en builds publicados (https://).
if [[ "$SOLERA_REPO_URL" == file://* ]]; then
    SOLERA_SIGLEVEL='Optional TrustAll'
else
    SOLERA_SIGLEVEL='Required'
fi

sed -e "s#@ALA_DATE@#${SOLERA_ALA_DATE}#g" \
    -e "s#@SOLERA_REPO@#${SOLERA_REPO_URL}#g" \
    -e "s#@SOLERA_SIGLEVEL@#${SOLERA_SIGLEVEL}#g" \
    "$template" > "$real"

# ---- Invoca arkdep-build ----------------------------------------------------
export SOLERA_RELEASE SOLERA_BUILD
export ARKDEP_CONFIGS="$scriptdir/arkdep-build.d"
export ARKDEP_OUTPUT_TARGET="$SOLERA_OUT"

mkdir -p "$SOLERA_OUT"

printf '==> Building Solera image\n'
printf '    Release:   %s\n' "$SOLERA_RELEASE"
printf '    Build:     %s\n' "$SOLERA_BUILD"
printf '    ALA date:  %s\n' "$SOLERA_ALA_DATE"
printf '    Repo URL:  %s\n' "$SOLERA_REPO_URL"
printf '    Output:    %s\n' "$SOLERA_OUT"

exec arkdep-build solera
