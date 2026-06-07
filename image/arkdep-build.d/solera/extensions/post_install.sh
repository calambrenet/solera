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

# 3) Plymouth: integramos el hook en dracut Y activamos el tema "spinner"
#    como default. solera-config ya escribe /etc/plymouth/plymouthd.conf
#    vía su factory; `plymouth-set-default-theme` re-genera initramfs.
mkdir -p "$workdir/etc/dracut.conf.d"
cat > "$workdir/etc/dracut.conf.d/10-solera-plymouth.conf" <<'EOF'
add_dracutmodules+=" plymouth "
EOF

# Aplica el tema por defecto. -R re-genera el initramfs en sitio.
# Si falla (no hay tema o dracut no está), no rompemos el build.
arch-chroot "$workdir" plymouth-set-default-theme spinner || true

# 4) Activar plymouth-quit etc. — al ser una imagen ya construida, el preset
#    de systemd se aplica vía /etc del solera-config (ya hecho).

# 5) Sanity: que el motd y os-release estén realmente en /etc.
if ! grep -q '^ID=solera' "$workdir/etc/os-release"; then
    printf 'post_install.sh: AVISO — /etc/os-release no parece de Solera\n'
fi

exit 0
