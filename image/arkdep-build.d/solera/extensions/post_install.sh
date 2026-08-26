#!/usr/bin/env bash
# post_install hook — corre dentro del entorno arkdep-build, justo después
# de instalar `solera-meta` (segunda fase). $workdir = rootfs del deployment.
#
# Tareas:
#   - Compilar la base de datos de dconf con los overrides de solera-config.
#   - Habilitar systemd-boot como bootloader del deployment.
#   - Ajustar la integración plymouth en dracut.
#   - Asegurar el preset para "ufw enabled" y servicios habilitados.

set -o pipefail

# 1) dconf update — compila /etc/dconf/db/solera.d/* en /etc/dconf/db/solera
arch-chroot "$workdir" dconf update || true

# 1.5) systemd-sysusers — procesa /usr/lib/sysusers.d/* incluyendo nuestro
#      solera-gdm.conf que garantiza el usuario gdm. Sin esto la imagen
#      quedaría sin gdm user (en el snapshot ALA 2026/05/23, gdm.conf de
#      upstream solo declara el grupo) y el greeter correría bajo un UID
#      efímero asignado por nss-systemd, con efecto colateral de
#      user@<UID>.service bloqueando hasta 2 min al apagar.
#      Tiene que correr DENTRO del chroot y ANTES del passwd→/usr/lib move
#      que hace arkdep-build al final del build.
arch-chroot "$workdir" systemd-sysusers || \
    printf 'post_install.sh: AVISO — systemd-sysusers falló dentro del chroot\n'

# 2) systemd-boot: el ESP no está montado durante el build; solo dejamos los
#    binarios en su sitio. En la máquina destino, arkdep + el instalador
#    invocan `bootctl install`.

# 3) Plymouth: integramos el hook en dracut Y activamos el tema "solera"
#    (lo aporta solera-config: copia del spinner con el logo de Solera) como
#    default. solera-config ya escribe /etc/plymouth/plymouthd.conf vía su
#    factory; aquí fijamos el symlink de tema por defecto ANTES de que
#    arkdep-build genere el initramfs con dracut, para que el módulo plymouth
#    empaquete el tema solera (no el spinner de Arch).
mkdir -p "$workdir/etc/dracut.conf.d"
cat > "$workdir/etc/dracut.conf.d/10-solera-plymouth.conf" <<'EOF'
add_dracutmodules+=" plymouth "
EOF

# Fija el tema por defecto (actualiza el symlink default.plymouth + conf).
# Sin -R: el initramfs lo regenera arkdep-build con dracut después, y el
# módulo plymouth lee el tema por defecto en ese momento.
arch-chroot "$workdir" plymouth-set-default-theme solera || true

# 4) Activar plymouth-quit etc. — al ser una imagen ya construida, el preset
#    de systemd se aplica vía /etc del solera-config (ya hecho).

# 5) Sanity: que el motd y os-release estén realmente en /etc.
if ! grep -q '^ID=solera' "$workdir/etc/os-release"; then
    printf 'post_install.sh: AVISO — /etc/os-release no parece de Solera\n'
fi

# 6) Sanity: la clave de firma de Solera debe estar poblada en el keyring de
#    pacman de la imagen (solera-keyring va en bootstrap.list, esto es
#    cinturón y tirantes). Se extrae el fingerprint del propio keyring que
#    instala el paquete, no de nada externo al repo. Aviso, no aborta.
solera_keyring_file="$workdir/usr/share/pacman/keyrings/solera.gpg"
if [[ -s "$solera_keyring_file" ]]; then
    solera_fpr=$(arch-chroot "$workdir" gpg --no-default-keyring \
        --keyring /usr/share/pacman/keyrings/solera.gpg \
        --with-colons --list-keys 2>/dev/null | awk -F: '/^fpr:/ {print $10; exit}')
    if [[ -n "$solera_fpr" ]] && ! arch-chroot "$workdir" pacman-key --list-keys "$solera_fpr" &>/dev/null; then
        printf 'post_install.sh: AVISO — la clave de firma de Solera (%s) no está en el keyring de pacman de la imagen\n' "$solera_fpr"
    fi
else
    printf 'post_install.sh: AVISO — %s no existe (¿solera-keyring instalado en bootstrap?)\n' "$solera_keyring_file"
fi

# 7) Hardening: /usr/bin/ksu (krb5) llega como dependencia transitiva
#    ineliminable (curl, openssh, gnome-online-accounts...), pero su SUID
#    no tiene caso de uso en un escritorio sin infraestructura Kerberos.
if [[ -f "$workdir/usr/bin/ksu" ]]; then
    chmod u-s "$workdir/usr/bin/ksu"
fi

# 8) Guardarraíl: el grupo 'docker' no debe existir en la imagen. Solera
#    ofrece /usr/bin/docker vía podman-docker (shim CLI a podman), no el
#    demonio real; si algún día algo lo introduce (paquete docker real,
#    script de instalación), esto debe frenar el build, no avisar.
if arch-chroot "$workdir" getent group docker >/dev/null 2>&1; then
    printf 'post_install.sh: ERROR — grupo docker presente en la imagen (se esperaba solo podman rootless)\n' >&2
    exit 1
fi

exit 0
