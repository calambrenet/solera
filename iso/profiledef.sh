#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# archiso profile definition for the Solera Linux installer ISO.
# Mantiene el patrón del perfil 'releng' upstream, con branding Solera y
# arranque exclusivamente por systemd-boot (no GRUB).

iso_name="solera"
iso_label="SOLERA_$(date +%Y%m)"
iso_publisher="Solera Linux <https://github.com/calambrenet/solera>"
iso_application="Solera Linux Live / Installer"
iso_version="$(date +%Y.%m.%d)"
install_dir="solera"
buildmodes=('iso')

# Solo systemd-boot, no syslinux/GRUB.
# archiso renombró 'uefi-x64.systemd-boot.{esp,eltorito}' → un único
# 'uefi.systemd-boot' que cubre ambos artefactos. Migración pendiente —
# requiere reescribir las 4 líneas en una sola y validar contra docs.
# Mientras tanto los nombres viejos siguen funcionando con warning.
bootmodes=(
    'uefi-ia32.systemd-boot.esp'
    'uefi-x64.systemd-boot.esp'
    'uefi-ia32.systemd-boot.eltorito'
    'uefi-x64.systemd-boot.eltorito'
)

arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')

file_permissions=(
    ["/etc/shadow"]="0:0:400"
    ["/etc/gshadow"]="0:0:400"
    ["/etc/sudoers"]="0:0:400"
    ["/root"]="0:0:750"
    # Wrapper de screenfetch (sale de airootfs/, por eso el modo va aquí).
    ["/usr/local/bin/screenfetch"]="0:0:755"
    # Los scripts de /etc/os-installer los aporta el paquete
    # os-installer-config-solera (ya con -m755 en el PKGBUILD), no airootfs/.
    # No los listamos aquí: mkarchiso solo acepta paths que existan en
    # airootfs/ del perfil.
)
