#!/usr/bin/env bash
# post_install hook del smoketest. Mínimo: solo asegura que /etc/os-release
# identifica al sistema como Solera (no Arch), para que al primer login se
# vea claramente que el deploy desde bundle funcionó.
set -o pipefail

# Sobreescribir /etc/os-release con identidad Solera Smoketest.
cat > "$workdir/etc/os-release" <<'EOF'
NAME="Solera Linux (smoketest)"
PRETTY_NAME="Solera Linux Smoketest"
ID=solera
ID_LIKE=arch
VARIANT="smoketest"
VARIANT_ID=smoketest
BUILD_ID=smoketest
ANSI_COLOR="38;5;130"
HOME_URL="https://github.com/calambrenet/solera"
EOF

# Asegurar NetworkManager activo al arrancar.
arch-chroot "$workdir" systemctl enable NetworkManager.service || true

# Root password = "solera". SOLO smoketest: la imagen real con GNOME se
# entrega con root bloqueado y el usuario primario lo crea
# gnome-initial-setup al primer arranque. Aquí lo abrimos por dos motivos:
# 1) el initramfs se genera con este shadow, así que la Dracut Emergency
#    Shell será utilizable si algo se rompe;
# 2) permite login en getty para validar el smoketest sin necesidad de
#    que el instalador modifique el shadow del deployment.
printf 'root:solera' | arch-chroot "$workdir" chpasswd || true

exit 0
