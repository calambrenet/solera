#!/usr/bin/env bash
# os-installer/install.sh — orquesta los scripts /etc/os-installer/install.sh.d.
# os-installer exporta variables OSI_* que los scripts consumen.

set -o pipefail

declare -r workdir='/mnt'
declare -r osidir='/etc/os-installer'
declare -r scriptsdir="$osidir/scripts/install.sh.d"
declare -r rootlabel='solera_root'
declare -r bootlabel='solera_boot'

quit_on_err() {
    [[ -n "$1" ]] && printf '%s\n' "$1"
    sleep 2
    exit 1
}

# Exportamos lo que necesitan los scripts hijos.
export workdir osidir rootlabel bootlabel
export -f quit_on_err

declare -r scripts=($(ls "$scriptsdir"))
for script in "${scripts[@]}"; do
    printf 'install.sh: running %s\n' "$script"
    source "$scriptsdir/$script" || quit_on_err "Fallo en $script"
done

exit 0
