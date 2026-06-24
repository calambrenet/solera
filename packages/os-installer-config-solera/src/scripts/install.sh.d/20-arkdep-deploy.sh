#!/usr/bin/env bash
# 20-arkdep-deploy.sh — instala Solera desde el bundle local de la ISO.
#
# La ISO trae /var/lib/solera-bundle/solera-*.tar.zst, generado por
# arkdep-build. En lugar de descargarla de internet, copiamos el bundle a
# la cache del nuevo sistema y llamamos `arkdep deploy cache <id>`, que
# salta toda la lógica de red, firma GPG y mirror selection.

set -o pipefail

readonly BUNDLE_DIR='/var/lib/solera-bundle'

# 1) Localizar el bundle.
bundle_file=$(ls "$BUNDLE_DIR"/solera-*.tar.zst 2>/dev/null | head -1)
[[ -n "$bundle_file" ]] \
    || quit_on_err "Bundle de Solera no encontrado en $BUNDLE_DIR"

# El deployment_id es el filename sin la extensión .tar.zst — coincide con
# la convención de naming de arkdep-build (variant-build-<timestamp>).
deployment_id=$(basename "$bundle_file" .tar.zst)

# UUIDs para fstab y bootloader:
#   - root_uuid: cmdline `options root=UUID=...` del template systemd-boot
#     y entradas fstab de los subvols btrfs.
#   - boot_uuid: entrada fstab de /boot (ESP). Va con x-systemd.automount
#     (ver overlay_arkdep/etc/fstab) para que arkdep pueda escribir el kernel
#     en el ESP sin bloquear el arranque.
root_uuid=$(sudo blkid -o value -s UUID "$root_blk") \
    || quit_on_err "No se pudo obtener UUID de root ($root_blk)"
[[ -n "$root_uuid" ]] \
    || quit_on_err 'UUID de root vacío tras formatear'
boot_uuid=$(sudo blkid -o value -s UUID "$esp") \
    || quit_on_err "No se pudo obtener UUID de boot ($esp)"
[[ -n "$boot_uuid" ]] \
    || quit_on_err 'UUID de boot vacío tras formatear'

# 2) Inicializar arkdep en el target. Crea /arkdep + subvolúmenes shared
#    (incluido /arkdep/overlay como subvol vacío).
sudo ARKDEP_ROOT="$workdir" arkdep init || quit_on_err 'arkdep init falló'

# 2.1) Sembrar el keyring de verificación de imágenes. arkdep init deja
#      /arkdep/keys/trusted-keys vacío (un `touch`); con gpg_signature_check=2
#      (required, parcheado en el paquete arkdep) `arkdep deploy`/`solera
#      update` aborta si no puede verificar la firma de la imagen. La pubkey
#      de Solera ya está en el live vía solera-keyring; gpgv usa el mismo
#      formato de keyring binario que exporta gpg, así que la copiamos tal
#      cual. /arkdep es subvolumen shared → persiste en el sistema instalado.
readonly SOLERA_PUBKEY='/usr/share/pacman/keyrings/solera.gpg'
if [[ -s "$SOLERA_PUBKEY" ]]; then
    sudo install -d -m755 "$workdir/arkdep/keys"
    sudo install -m644 "$SOLERA_PUBKEY" "$workdir/arkdep/keys/trusted-keys" \
        || quit_on_err 'No se pudo sembrar /arkdep/keys/trusted-keys'
else
    quit_on_err "Pubkey de Solera no encontrada en $SOLERA_PUBKEY (¿solera-keyring instalado en el live?)"
fi

# 2.5) Sobrescribir el template systemd-boot que arkdep init dejó por
#      defecto. Razones:
#      - El default upstream tiene `root="LABEL=arkane_root"` y title
#        "Arkane Linux - Arkdep". Solera escribe root=UUID=<root_uuid>
#        para no depender de /dev/disk/by-label en el primer arranque.
#      - El default incluye `initrd /amd-ucode.img` e `intel-ucode.img`,
#        que el smoketest no instala. arkdep imprime warnings durante el
#        deploy ("No such file or directory") y systemd-boot al arrancar
#        intenta cargarlos. Se quitan; cuando la imagen real incluya
#        amd-ucode / intel-ucode los volvemos a añadir condicionalmente.
sudo tee "$workdir/arkdep/templates/systemd-boot" >/dev/null <<EOF
title Solera Linux
linux /arkdep/%target%/vmlinuz
initrd /arkdep/%target%/initramfs-linux.img
options root="UUID=$root_uuid" rootflags=subvol=/arkdep/deployments/%target%/rootfs rw quiet splash
EOF

# 3) Sembrar /arkdep/overlay con el fstab plantilla. Durante "arkdep deploy"
#    el overlay se copia recursivamente sobre rootfs/ del deployment recién
#    recibido (ver arkdep, "Copying overlay to deployment"), así que el
#    fstab acaba en deployments/<id>/rootfs/etc/fstab. Es el patrón que usa
#    Arkane (configure.sh.d/02-overlay.sh) y persiste en futuros deploys.
sudo install -d -m755 "$workdir/arkdep/overlay/etc"
sed -e "s|@ROOT_UUID@|$root_uuid|g" \
    -e "s|@BOOT_UUID@|$boot_uuid|g" \
    "$osidir/overlay_arkdep/etc/fstab" | \
    sudo tee "$workdir/arkdep/overlay/etc/fstab" >/dev/null \
        || quit_on_err 'No se pudo sembrar fstab en /arkdep/overlay'
sudo chmod 0644 "$workdir/arkdep/overlay/etc/fstab"

# 4) Sembrar la cache del target con el bundle de la ISO.
sudo cp "$bundle_file" "$workdir/arkdep/cache/" \
    || quit_on_err 'No se pudo copiar el bundle a la cache de arkdep'

# 4.5) El bundle de la ISO no va firmado. arkdep init escribió el config con
#      gpg_signature_check=2 (required, parcheado en el paquete arkdep), así
#      que un `deploy cache` aborta pidiendo la firma del bundle. La firma
#      obligatoria protege los UPDATES por red (`solera update`), donde un
#      repo comprometido o un MITM sí son una amenaza; el deploy INICIAL es
#      desde la ISO que el usuario booteó, que es el medio de confianza.
#      Relajamos el check solo para este deploy desde cache y lo restauramos
#      a 2 para que el sistema instalado exija firma en los updates.
sudo sed -i 's/^gpg_signature_check=.*/gpg_signature_check=0/' \
    "$workdir/arkdep/config" \
    || quit_on_err 'No se pudo relajar gpg_signature_check para el deploy inicial'

# 5) Deploy desde cache. Para entonces 15-systemd-boot.sh ya ha poblado
#    $workdir/boot/loader/entries/, que es donde arkdep escribe la entrada
#    del kernel desplegado. arkdep aplicará /arkdep/overlay sobre rootfs/.
sudo ARKDEP_ROOT="$workdir" arkdep deploy cache "$deployment_id" \
    || quit_on_err 'arkdep deploy cache falló'

# 5.5) Restaurar la firma obligatoria para el sistema instalado. /arkdep es
#      subvolumen shared, así que este config persiste y `solera update`
#      rechazará cualquier imagen sin firma válida.
sudo sed -i 's/^gpg_signature_check=.*/gpg_signature_check=2/' \
    "$workdir/arkdep/config" \
    || quit_on_err 'No se pudo restaurar gpg_signature_check a 2'
