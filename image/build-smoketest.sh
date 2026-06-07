#!/usr/bin/env bash
#
# image/build-smoketest.sh — wrapper que invoca arkdep-build sobre la receta
# `solera-smoketest`. Construye una imagen mínima arrancable para validar
# offline install. No es Solera real: ver image/arkdep-build.d/solera-smoketest.
#
# Uso:
#   sudo ./image/build-smoketest.sh
#
# Variables (todas opcionales):
#   SOLERA_ALA_DATE   YYYY/MM/DD del Arch Linux Archive (default último día
#                     del mes anterior).
#   SOLERA_BUILD      identificador interno de build (default timestamp).
#   SOLERA_OUT        directorio de salida (default ./target).

set -euo pipefail

# Encuentra la fecha YYYY/MM/DD más reciente con snapshot en el Arch Linux
# Archive, probando hacia atrás desde "ayer". El archive no tiene snapshot
# todos los días, así que hace falta buscar.
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

: "${SOLERA_BUILD:=$(date +%Y%m%d-%H%M%S)}"
: "${SOLERA_OUT:=$(pwd)/target}"

if [[ -z "${SOLERA_ALA_DATE:-}" ]]; then
    printf 'build-smoketest.sh: buscando snapshot del Arch Linux Archive...\n' >&2
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

scriptdir="$(cd "$(dirname "$0")" && pwd)"
variantdir="$scriptdir/arkdep-build.d/solera-smoketest"
template="$variantdir/pacman.conf.template"
real="$variantdir/pacman.conf"

sed -e "s#@ALA_DATE@#${SOLERA_ALA_DATE}#g" "$template" > "$real"

export SOLERA_BUILD
export ARKDEP_CONFIGS="$scriptdir/arkdep-build.d"
export ARKDEP_OUTPUT_TARGET="$SOLERA_OUT"

mkdir -p "$SOLERA_OUT"

printf '==> Building Solera smoketest image\n'
printf '    Build:     %s\n' "$SOLERA_BUILD"
printf '    ALA date:  %s\n' "$SOLERA_ALA_DATE"
printf '    Output:    %s\n' "$SOLERA_OUT"

exec arkdep-build solera-smoketest
