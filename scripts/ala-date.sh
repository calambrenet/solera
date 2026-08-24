#!/usr/bin/env bash
#
# ala-date.sh — resuelve SOLERA_ALA_DATE (fecha YYYY/MM/DD del snapshot del
# Arch Linux Archive). Se sourcea desde los scripts de build; no se ejecuta
# directamente.
#
# Si SOLERA_ALA_DATE ya está puesta en el entorno, se respeta y se valida
# contra el archive. Si no, se busca el snapshot más reciente caminando hacia
# atrás desde ayer (el archive no publica snapshot todos los días).
#
# Uso:
#   source "$(dirname "$0")/ala-date.sh"
#   resolve_ala_date || exit 1
#
# Tras llamar a resolve_ala_date, SOLERA_ALA_DATE queda exportada y validada.
# Esto garantiza que la imagen del sistema (image/build.sh) y la ISO
# (scripts/ci-build.sh / scripts/build-iso-local.sh) se anclen a la misma
# fecha del archive y, por tanto, al mismo kernel.

find_latest_ala_date() {
    local day url code
    for offset in $(seq 1 60); do
        day=$(date -d "today - ${offset} day" '+%Y/%m/%d' 2>/dev/null) || continue
        url="https://archive.archlinux.org/repos/${day}/core/os/x86_64/core.db"
        code=$(curl -s -o /dev/null -w '%{http_code}' --head "$url" 2>/dev/null)
        if [[ "$code" == 200 ]]; then
            printf '%s\n' "$day"
            return 0
        fi
    done
    return 1
}

validate_ala_date() {
    local url
    url="https://archive.archlinux.org/repos/${SOLERA_ALA_DATE}/core/os/x86_64/core.db"
    curl -sfL -o /dev/null --head "$url"
}

resolve_ala_date() {
    if [[ -z "${SOLERA_ALA_DATE:-}" ]]; then
        printf 'ala-date: buscando snapshot del Arch Linux Archive...\n' >&2
        if ! SOLERA_ALA_DATE=$(find_latest_ala_date); then
            printf 'ERROR: no encontré snapshot del archive en los últimos 60 días.\n' >&2
            return 1
        fi
    else
        if ! validate_ala_date; then
            printf 'ERROR: SOLERA_ALA_DATE=%s no existe en el archive.\n' "$SOLERA_ALA_DATE" >&2
            return 1
        fi
    fi
    export SOLERA_ALA_DATE
    printf 'ala-date: SOLERA_ALA_DATE=%s\n' "$SOLERA_ALA_DATE" >&2
}
