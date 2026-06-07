#!/usr/bin/env bash
# 10-locale.sh — locale, zona horaria y keymap del deployment.
#
# Patrón Arkane: estos archivos viven en el subvol rootfs/etc del deployment
# (que es rw). En el futuro, cuando soportemos múltiples deploys con
# persistencia, moveremos esto a /arkdep/overlay/etc/ y re-correremos
# arkdep deploy para que se aplique.

set -o pipefail

declare -r deployment=$(sudo find "$workdir/arkdep/deployments" -maxdepth 1 -mindepth 1 -type d | head -1)
[[ -n "$deployment" ]] || quit_on_err 'No se encontró deployment recién creado'
declare -r rootfs="$deployment/rootfs"

# locale.conf
if [[ -n "${OSI_LOCALE:-}" ]]; then
    echo "LANG=$OSI_LOCALE" | sudo tee "$rootfs/etc/locale.conf" >/dev/null
fi

# vconsole.conf (keymap de TTY)
if [[ -n "${OSI_KEYBOARD_LAYOUT:-}" ]]; then
    echo "KEYMAP=$OSI_KEYBOARD_LAYOUT" | sudo tee "$rootfs/etc/vconsole.conf" >/dev/null
fi

# Zona horaria
if [[ -n "${OSI_TIMEZONE:-}" ]]; then
    sudo ln -sf "/usr/share/zoneinfo/$OSI_TIMEZONE" "$rootfs/etc/localtime" || true
fi
