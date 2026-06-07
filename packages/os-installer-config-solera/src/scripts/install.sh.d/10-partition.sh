#!/usr/bin/env bash
# 10-partition.sh — particiona el disco objetivo y prepara Btrfs.
# Se ejecuta vía `source`, por lo que ${workdir,rootlabel,bootlabel} ya existen.

set -o pipefail

declare -r dev="$OSI_DEVICE_PATH"

# Solera particiona el disco entero. Si os-installer nos pasa una partición
# (porque el selector la ofreció al detectar tabla previa), abortamos: aplicar
# una GPT dentro de una partición acaba en "Re-reading the partition table
# failed: Invalid argument" y nombres de device inválidos tipo /dev/sda21.
if [[ ! -b "$dev" ]]; then
    quit_on_err "Destino '$dev' no es un block device"
fi
dev_type="$(lsblk -no TYPE "$dev" 2>/dev/null | head -n1)"
if [[ "$dev_type" != "disk" ]]; then
    quit_on_err "Solera necesita un disco entero, no '$dev' (tipo detectado: ${dev_type:-desconocido}). Limpia la tabla del disco (wipefs -a / sgdisk -Z) o selecciona el disco completo."
fi

# Convención del kernel para nombres de partición: si el device acaba en
# dígito (nvme0n1, mmcblk0, loop0, md0) la partición lleva 'p' entre nombre
# y número (nvme0n1p1). Si acaba en letra (sda, vda, hda), se concatena el
# número directamente (sda1). Cubre todas las familias, no solo NVMe.
if [[ "$dev" =~ [0-9]$ ]]; then
    declare -r esp="${dev}p1"
    declare -r root_part="${dev}p2"
else
    declare -r esp="${dev}1"
    declare -r root_part="${dev}2"
fi

# 1) Aplica la tabla GPT desde la plantilla.
sudo sfdisk --wipe always --wipe-partitions always "$dev" \
    < "$osidir/bits/part.sfdisk" || quit_on_err 'sfdisk falló'

sudo udevadm settle

# 2) Formatea ESP y root.
sudo mkfs.fat -F32 -n "$bootlabel" "$esp"       || quit_on_err 'mkfs.fat falló'

if [[ "$OSI_USE_ENCRYPTION" -eq 1 ]]; then
    printf '%s' "$OSI_ENCRYPTION_PIN" | \
        sudo cryptsetup luksFormat --type luks2 --label "${rootlabel}_crypt" "$root_part" - \
        || quit_on_err 'luksFormat falló'
    printf '%s' "$OSI_ENCRYPTION_PIN" | \
        sudo cryptsetup open "$root_part" "${rootlabel}_crypt" - \
        || quit_on_err 'luksOpen falló'
    sudo mkfs.btrfs -f -L "$rootlabel" "/dev/mapper/${rootlabel}_crypt" \
        || quit_on_err 'mkfs.btrfs falló'
    declare -r root_blk="/dev/mapper/${rootlabel}_crypt"
else
    sudo mkfs.btrfs -f -L "$rootlabel" "$root_part" \
        || quit_on_err 'mkfs.btrfs falló'
    declare -r root_blk="$root_part"
fi

# 3) Monta el filesystem root y el ESP. La creación de subvolúmenes
#    (/arkdep + /arkdep/shared/{home,root,flatpak} + deployments/cache/...) es
#    responsabilidad de `arkdep init` en 20-arkdep-deploy.sh. Si los creamos
#    aquí, `arkdep init` falla con "File exists" al intentar crear /arkdep.
sudo mount -t btrfs -o compress=zstd "$root_blk" "$workdir" \
    || quit_on_err 'mount root falló'

sudo mkdir -p "$workdir/boot"
sudo mount -o defaults "$esp" "$workdir/boot" || quit_on_err 'mount boot falló'

# 4) Exporta variables para los siguientes scripts.
export root_blk esp
