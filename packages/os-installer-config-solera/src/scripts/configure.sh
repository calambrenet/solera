#!/usr/bin/env bash
# os-installer/configure.sh — post-install (usuarios, locale, etc.)

set -o pipefail

declare -r workdir='/mnt'
declare -r osidir='/etc/os-installer'
declare -r scriptsdir="$osidir/scripts/configure.sh.d"

# UUID de la partición root, calculado a partir de OSI_DEVICE_PATH.
if [[ "$OSI_DEVICE_IS_PARTITION" -ne 0 ]]; then
    declare -r uuid=$(sudo blkid -o value -s UUID "$OSI_DEVICE_PATH")
elif [[ "$OSI_DEVICE_PATH" == *"nvme"*"n"* ]]; then
    declare -r uuid=$(sudo blkid -o value -s UUID "${OSI_DEVICE_PATH}p2")
else
    declare -r uuid=$(sudo blkid -o value -s UUID "${OSI_DEVICE_PATH}2")
fi

declare firstname=($OSI_USER_NAME)
firstname=${firstname[0]}

export workdir osidir uuid firstname

quit_on_err() {
    [[ -n "$1" ]] && printf '%s\n' "$1"
    sleep 2
    exit 1
}
export -f quit_on_err

declare -r scripts=($(ls "$scriptsdir"))
for script in "${scripts[@]}"; do
    printf 'configure.sh: running %s\n' "$script"
    source "$scriptsdir/$script" || quit_on_err "Fallo en $script"
done

sync
sudo umount -R /mnt || true
exit 0
