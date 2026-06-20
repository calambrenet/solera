#!/usr/bin/env bash
#
# run-build-test.sh — Prueba mínima del contenedor de build.
#
# Construye los 11 paquetes propios de Solera dentro del contenedor, SIN tocar
# el host (que es Solera, read-only). Valida el flujo antes de meter imagen e
# ISO en el contenedor.
#
#     bash build/run-build-test.sh
#
# Variables:
#     IMAGE_REBUILD=yes   fuerza reconstruir la imagen del contenedor
#     OUT=/ruta           dónde dejar los .pkg.tar.zst (default: solera/out-pkgs)

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # .../solera
IMAGE="${IMAGE:-solera-build:test}"
OUT="${OUT:-$REPO/out-pkgs}"

mkdir -p "$OUT"

# 1) Imagen del contenedor (build solo si falta o IMAGE_REBUILD=yes).
if [[ "${IMAGE_REBUILD:-no}" == "yes" ]] || ! podman image exists "$IMAGE"; then
    echo "==> Construyendo imagen del contenedor: $IMAGE"
    podman build -t "$IMAGE" -f "$REPO/build/Containerfile" "$REPO"
fi

# 2) Build de paquetes dentro del contenedor.
#    --userns=keep-id: builder (uid 1000) mapea al usuario del host, así los
#    artefactos en $OUT salen con tu propiedad (no de un subuid).
echo "==> Lanzando build de paquetes en el contenedor"
podman run --rm \
    --userns=keep-id \
    -v "$REPO":/src:ro \
    -v "$OUT":/out \
    -e SRC=/src -e OUT=/out -e WORK=/home/builder/build \
    "$IMAGE" \
    bash /src/scripts/ci-build-packages.sh

echo "==> Artefactos en: $OUT"
