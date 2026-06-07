#!/usr/bin/env bash
# os-installer/prepare.sh — comprobaciones previas a la instalación de Solera.

set -o pipefail

# Solera asume que el usuario live tiene sudo (wheel).
for group in $(groups); do
    if [[ "$group" == 'wheel' || "$group" == 'sudo' ]]; then
        exit 0
    fi
done

printf 'El usuario live no es miembro de wheel/sudo; Solera no puede instalar.\n'
exit 1
