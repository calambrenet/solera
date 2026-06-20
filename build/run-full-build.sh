#!/usr/bin/env bash
#
# run-full-build.sh — Build COMPLETO de Solera en el contenedor:
#   paquetes → imagen (arkdep-build) → ISO (mkarchiso).
#
# A diferencia de run-build-test.sh (solo paquetes, rootless), aquí se usa
# podman ROOTFUL (sudo) y --privileged: arkdep-build y mkarchiso necesitan
# loop devices, mkfs.btrfs, mount y chroot, que el podman rootless no expone
# de forma fiable. Por eso este script invoca sudo (te pedirá contraseña).
#
#     bash build/run-full-build.sh                        # todo
#     DO_ISO=no bash build/run-full-build.sh              # paquetes + imagen
#     DO_IMAGE=no DO_ISO=no bash build/run-full-build.sh  # solo paquetes
#
# Variables:
#     IMAGE_REBUILD=yes   fuerza reconstruir la imagen del contenedor
#     OUT=/ruta           artefactos (default: solera/out-full)
#     VARTMP=/ruta        volumen REAL para /var/tmp del contenedor (loop/btrfs/
#                         squashfs NO pueden vivir en el overlay). Default:
#                         solera/.buildwork. Debe estar en un fs real (ext4/
#                         btrfs/xfs), NO en exfat/ntfs.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # .../solera
IMAGE="${IMAGE:-solera-build:full}"
OUT="${OUT:-$REPO/out-full}"
# Scratch dir (volumen /var/tmp del contenedor) FUERA del repo a propósito:
# mkarchiso/arkdep-build dejan aquí ficheros root-owned (archiso-work, loop
# image) que no deben acabar bajo el repo montado en /src.
VARTMP="${VARTMP:-${XDG_CACHE_HOME:-$HOME/.cache}/solera-buildwork}"
RUN_UID="$(id -u)"; RUN_GID="$(id -g)"

mkdir -p "$OUT" "$VARTMP"

# 1) Imagen del contenedor en el storage de ROOT (rootful). Una sola fuente de
#    verdad: evita el podman save|load entre storages.
if [[ "${IMAGE_REBUILD:-no}" == "yes" ]] || ! sudo podman image exists "$IMAGE"; then
    echo "==> Construyendo imagen del contenedor (rootful): $IMAGE"
    sudo podman build -t "$IMAGE" -f "$REPO/build/Containerfile" "$REPO"
fi

# 1b) Loop devices: arkdep-build (mkfs.btrfs sobre loop image) y mkarchiso
#     usan `mount -o loop`. El /dev del contenedor es un tmpfs aislado, así que
#     los nodos /dev/loopN que crea losetup no aparecerían dentro. Solución:
#     cargar el módulo loop en el host (crea /dev/loop*) y exponer el /dev real
#     del host al contenedor con -v /dev:/dev.
echo "==> Asegurando módulo loop en el host"
sudo modprobe loop || true

# 2) Build dentro del contenedor (rootful + privileged).
echo "==> Build completo (privileged): DO_IMAGE=${DO_IMAGE:-yes} DO_ISO=${DO_ISO:-yes}"
sudo podman run --rm --privileged \
    -v /dev:/dev \
    -v "$REPO":/src:ro \
    -v "$OUT":/out \
    -v "$VARTMP":/var/tmp \
    -e SRC=/src -e OUT=/out -e WORK=/home/builder/build \
    -e DO_PACKAGES="${DO_PACKAGES:-yes}" \
    -e DO_IMAGE="${DO_IMAGE:-yes}" \
    -e DO_ISO="${DO_ISO:-yes}" \
    -e SOLERA_RELEASE="${SOLERA_RELEASE:-26.04}" \
    -e SOLERA_BUILD="${SOLERA_BUILD:-}" \
    -e SOLERA_ALA_DATE="${SOLERA_ALA_DATE:-}" \
    "$IMAGE" \
    bash -c 'cd /home/builder && bash /src/scripts/ci-build.sh'

# 3) arkdep-build/mkarchiso escribieron como root (vía sudo dentro del
#    contenedor rootful). Devuelve los artefactos al usuario.
echo "==> Ajustando propiedad de $OUT"
sudo chown -R "$RUN_UID:$RUN_GID" "$OUT"

echo "==> Artefactos en: $OUT"
ls -lh "$OUT"
