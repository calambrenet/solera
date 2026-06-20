#!/usr/bin/env bash
#
# test-iso-qemu.sh — Arranca la ISO de Solera en QEMU/UEFI (OVMF) dentro de un
# contenedor (el host Solera es inmutable y no trae qemu) y captura
# screenshots del framebuffer para verificar el boot de forma headless.
#
#     bash build/test-iso-qemu.sh [ruta-a-la-iso]
#
# Sin argumento usa la ISO más nueva de out-full/. Las capturas (.ppm/.png)
# y el serial.log quedan en .vmtest/.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${IMAGE:-solera-vmtest:latest}"
ISO="${1:-$(ls -t "$REPO"/out-full/solera-*.iso 2>/dev/null | head -1)}"
WORK="$REPO/.vmtest"
SHOT_TIMES="${SHOT_TIMES:-15 35 60 90 130 170}"

[[ -n "$ISO" && -f "$ISO" ]] || { echo "No encuentro la ISO ($ISO)"; exit 1; }
[[ -c /dev/kvm ]] || { echo "No hay /dev/kvm"; exit 1; }

mkdir -p "$WORK/shots"

if ! podman image exists "$IMAGE"; then
    echo "==> Construyendo imagen de test: $IMAGE"
    podman build -t "$IMAGE" -f "$REPO/build/Containerfile.vmtest" "$REPO"
fi

echo "==> Arrancando ISO en QEMU (headless, KVM): $(basename "$ISO")"
podman run --rm --device /dev/kvm \
    -v "$ISO":/iso/solera.iso:ro \
    -v "$WORK":/work \
    -e SHOT_TIMES="$SHOT_TIMES" \
    "$IMAGE" bash -c '
set -e
OVMF_CODE=$(ls /usr/share/edk2/x64/OVMF_CODE*.fd | head -1)
OVMF_VARS=$(ls /usr/share/edk2/x64/OVMF_VARS*.fd | head -1)
cp "$OVMF_VARS" /work/vars.fd
qemu-img create -f qcow2 /work/test.qcow2 20G >/dev/null
rm -f /work/mon.sock
qemu-system-x86_64 -enable-kvm -m 4096 -smp 4 -machine q35 \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file=/work/vars.fd \
    -drive file=/iso/solera.iso,format=raw,media=cdrom \
    -drive file=/work/test.qcow2,if=virtio \
    -vga std -display none \
    -monitor unix:/work/mon.sock,server,nowait \
    -serial file:/work/serial.log &
QPID=$!
# Espera a que el socket del monitor exista
for i in $(seq 1 50); do [ -S /work/mon.sock ] && break; sleep 0.2; done
prev=0
for t in $SHOT_TIMES; do
    sleep $(( t - prev )); prev=$t
    if kill -0 $QPID 2>/dev/null; then
        echo "screendump /work/shots/shot-${t}s.ppm" | socat - unix-connect:/work/mon.sock >/dev/null 2>&1 || true
        echo "  capturado shot-${t}s a los ${t}s (qemu vivo)"
    else
        echo "  qemu murió antes de ${t}s — ver serial.log"; break
    fi
done
kill $QPID 2>/dev/null || true
wait $QPID 2>/dev/null || true
echo "==> fin"
'

echo "==> Convirtiendo capturas a PNG"
for ppm in "$WORK"/shots/*.ppm; do
    [[ -f "$ppm" ]] && convert "$ppm" "${ppm%.ppm}.png" 2>/dev/null || true
done
echo "==> Capturas en $WORK/shots/ ; serial en $WORK/serial.log"
ls -lh "$WORK"/shots/*.png 2>/dev/null || echo "(sin capturas — revisa serial.log)"
