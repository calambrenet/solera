#!/usr/bin/env bash
# 15-systemd-boot.sh — instala systemd-boot en el ESP del target ANTES de
# correr `arkdep deploy`. arkdep escribe la entrada del kernel en
# $arkdep_boot/loader/entries/...conf y exige que esa ruta ya exista; no
# llama a bootctl ni crea el directorio.
#
# Copiamos systemd-bootx64.efi manualmente en vez de `bootctl install`
# porque bootctl operaría sobre el ESP del live ISO, no sobre $workdir/boot.
# El .efi es self-contained, así que copiarlo basta.

set -o pipefail

sudo mkdir -p \
    "$workdir/boot/EFI/BOOT" \
    "$workdir/boot/EFI/systemd" \
    "$workdir/boot/loader/entries" \
    || quit_on_err 'Failed to create bootloader directories'

sudo cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi "$workdir/boot/EFI/systemd/" \
    || quit_on_err 'Failed to copy systemd-bootx64.efi to EFI/systemd/'

sudo cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi "$workdir/boot/EFI/BOOT/BOOTx64.EFI" \
    || quit_on_err 'Failed to copy systemd-bootx64.efi to EFI/BOOT/BOOTx64.EFI'

sudo tee "$workdir/boot/loader/loader.conf" >/dev/null <<'EOF'
timeout 3
console-mode max
editor yes
default *solera*
EOF
# editor=yes permite pulsar 'e' en el menú de systemd-boot para editar la
# cmdline del kernel. Útil para debug (p.ej. añadir `init=/bin/bash` o
# `systemd.unit=rescue.target`). El riesgo de seguridad es bajo en
# escritorio personal; en CI/empresa lo bloquearíamos.
