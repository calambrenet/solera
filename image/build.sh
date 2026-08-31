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
#   SOLERA_ALA_DATE   Fecha YYYY/MM/DD del Arch Linux Archive (default: el
#                     snapshot más reciente disponible en el archive).
#   SOLERA_RELEASE    Release en formato YY.MM (default: derivada de
#                     SOLERA_ALA_DATE, p.ej. 2026/08/30 -> 26.08).
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
: "${SOLERA_BUILD:=$(date +%Y%m%d-%H%M%S)}"
: "${SOLERA_REPO_URL:?ERROR: SOLERA_REPO_URL no definido (URL del repo pacman de Solera)}"
# SOLERA_OUT relativo al root del repo (no al cwd). Antes default era
# $(pwd)/target, lo que dejaba el tarball en el dir desde el que se lanzase
# el script — sorpresa cuando se ejecutaba desde packages/<algo>/.
: "${SOLERA_OUT:=$(cd "$(dirname "$0")/.." && pwd)/target}"

# Resuelve SOLERA_ALA_DATE (snapshot ALA) y SOLERA_RELEASE (YY.MM, derivada
# de esa fecha si no se pasó explícita). Compartido con scripts/ci-build.sh
# para que ambos caminos de build calculen la release igual.
source "$(cd "$(dirname "$0")/.." && pwd)/scripts/ala-date.sh"
resolve_ala_date || exit 1
resolve_release || exit 1

# ---- Genera pacman.conf con los valores reales ------------------------------
scriptdir="$(cd "$(dirname "$0")" && pwd)"
variantdir="$scriptdir/arkdep-build.d/solera"
template="$variantdir/pacman.conf.template"
real="$variantdir/pacman.conf"

# SigLevel del repo [solera]: confianza ciega en builds locales (file://),
# firma obligatoria en builds publicados (https://). "DatabaseOptional"
# iguala el SigLevel del repo [solera] al de [core]/[extra]/[multilib]
# (línea global de [options]): exige firma de paquete, no exige firma de
# la base de datos del repo (no generamos repo-add -s todavía).
if [[ "$SOLERA_REPO_URL" == file://* ]]; then
    SOLERA_SIGLEVEL='Optional TrustAll'
else
    SOLERA_SIGLEVEL='Required DatabaseOptional'
fi

sed -e "s#@ALA_DATE@#${SOLERA_ALA_DATE}#g" \
    -e "s#@SOLERA_REPO@#${SOLERA_REPO_URL}#g" \
    -e "s#@SOLERA_SIGLEVEL@#${SOLERA_SIGLEVEL}#g" \
    "$template" > "$real"

# Guardarraíl: un build de producción (repo no-file://) nunca debe llevar
# TrustAll en pacman.conf. Si aparece (inyectado a mano, plantilla rota,
# variable mal exportada), abortamos en vez de construir una imagen que
# aceptaría paquetes sin firmar. Se mira solo líneas SigLevel reales, no
# comentarios: la propia plantilla explica el token @SOLERA_SIGLEVEL@
# mencionando "TrustAll" en prosa, y eso no cuenta como directiva.
if [[ "$SOLERA_REPO_URL" != file://* ]] && grep -Eq '^[[:space:]]*SigLevel[[:space:]]*=.*TrustAll' "$real"; then
    printf 'ERROR: build de producción con TrustAll en pacman.conf (%s) — abortando.\n' "$real" >&2
    exit 1
fi

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
