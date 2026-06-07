# `iso/` — perfil `archiso` para construir la ISO instaladora de Solera

La ISO de Solera **no** es Solera. Es un medio live que arranca GNOME mínimo, ejecuta `os-installer` y delega en `arkdep deploy` la instalación real desde el repo pacman de Solera.

## Diseño

| Pieza | Qué hace |
|---|---|
| `profiledef.sh` | Metadatos del medio (nombre, label, version). Solo `systemd-boot`, sin GRUB. |
| `packages.x86_64` | Paquetes del live: base + kernel + GNOME mínimo + Network/BT + `arkdep` + `os-installer` + `os-installer-config-solera` + `solera-keyring`. |
| `pacman.conf` | Mirrors normales de Arch (el live no necesita pinning) **+ el repo de Solera** (donde viven `arkdep`, `solera-keyring` y `os-installer-config-solera`). |
| `airootfs/` | Sobreescritura de `/etc` del rootfs live: hostname, autologin en GDM, motd, dconf con branding Solera, autostart del instalador, etc. |
| `efiboot/loader/` | `systemd-boot`: loader.conf + entradas `solera-x86_64-linux.conf` (normal y nomodeset). |

El instalador, una vez arrancado, sigue el patrón Arkane (heredado del config BSD-licensed) adaptado a Solera:

1. Particiona el disco según `bits/part.sfdisk` (ESP + raíz).
2. Formatea ESP a FAT32 (`solera_boot`) y raíz a Btrfs (`solera_root`).
3. Crea los subvolúmenes `shared/{home,root,flatpak}` bajo `/arkdep/`.
4. `arkdep init` + `arkdep deploy` traen la última imagen desde el repo de Solera (Cloudflare R2).
5. `bootctl install` instala `systemd-boot` en el ESP; `arkdep` ya escribe sus entradas.
6. Configura usuario, locale, zona horaria en el deployment recién instalado.

## Construcción local

Requisitos:

- `archiso` y `pacman` instalados.
- El paquete `os-installer-config-solera` accesible (publicar primero el repo pacman de Solera o usar un repo local file://).
- Sustituir el placeholder de `pacman.conf` (`https://cdn.example.invalid/...`) por una URL real:

```bash
# Build local apuntando a un repo file://
sed -i 's|https://cdn\.example\.invalid/solera/repo/x86_64|file:///srv/solera-localrepo/x86_64|g' pacman.conf

sudo mkarchiso -v -w workdir/ -o out/ .
```

ISO resultante en `out/solera-YYYY.MM.DD-x86_64.iso`.

## Prueba en VM (QEMU)

```bash
qemu-system-x86_64 -enable-kvm -m 4G -smp 4 \
    -bios /usr/share/edk2/x64/OVMF.4m.fd \
    -drive file=out/solera-*.iso,format=raw,media=cdrom \
    -drive file=test.qcow2,if=virtio  # crear antes con: qemu-img create -f qcow2 test.qcow2 40G
```

Si el instalador GTK arranca y completa el flujo hasta `arkdep deploy`, la ISO está validada. En el primer arranque tras instalar, Solera real debería aparecer en el menú de `systemd-boot`.

## Notas

- **mkinitcpio en el live**, **dracut en el sistema instalado**. Son herramientas diferentes para problemas diferentes: el live usa los hooks `archiso*` que solo viven en mkinitcpio; el sistema instalado necesita la integración de dracut con `arkdep`.
- **dconf** del live también está configurado con el branding de Solera (mismo fondo que la imagen final), de modo que el live "se sienta" como Solera aunque no lo sea.
- **El instalador arranca solo** al login del usuario `solera` (autostart en `~/.config/autostart`). El usuario puede cerrarlo si quiere probar GNOME primero.
- **Sin SSH habilitado** en el live por defecto: el medio instalador no necesita acceso remoto. Si se quiere para soporte de empresa, habilitarlo en una variante derivada.
