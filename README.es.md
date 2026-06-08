# Solera Linux

**Una distribución Linux inmutable y atómica basada en Arch, con GNOME.**

🌐 [English](README.md) · Español

Solera entrega el sistema operativo como una imagen versionada y reproducible, no como una máquina que configuras a mano. El sistema raíz es de solo lectura, las actualizaciones son transaccionales con rollback gratuito, y todo lo que define el sistema vive en este repositorio Git.

Usa [`arkdep`](https://github.com/arkanelinux/arkdep) como motor de despliegue (imágenes de subvolúmenes Btrfs, el mismo motor de Arkane Linux) y sigue un flujo de construcción basado en imagen: definir en Git → construir en CI → publicar un artefacto firmado y versionado.

> **Estado: alpha.** Solera arranca, se instala y funciona, pero el canal público de actualizaciones y el pipeline de CI aún se están montando. Todavía no está listo para uso diario.

## Características

- **Raíz inmutable** — `/usr` es de solo lectura; el sistema no puede derivar fuera de un estado conocido.
- **Actualizaciones atómicas con rollback** — una actualización despliega un nuevo subvolumen Btrfs y cambia a él al reiniciar. El despliegue anterior permanece en disco; volver atrás es elegir la entrada antigua en el menú de arranque.
- **Releases reproducibles** — cada release se construye contra un snapshot fijo del [Arch Linux Archive](https://archive.archlinux.org/), de modo que reconstruir una versión produce la misma imagen.
- **Escritorio GNOME** con dash-to-dock, blur-my-shell y magic-lamp activados por defecto.
- **systemd-boot** (solo UEFI), Btrfs con compresión zstd, swap en zram.
- Audio **PipeWire**, splash de arranque **Plymouth**.

## Modelo de software

La imagen raíz se mantiene mínima e idéntica entre máquinas. El software vive en capas según su naturaleza:

| Capa | Herramienta | Para |
|---|---|---|
| Sistema base | la imagen | kernel, GNOME, servicios — solo cambia con una actualización completa + reinicio |
| Apps gráficas | **Flatpak** (Flathub preconfigurado) | navegadores, editores, apps de usuario |
| Entornos de desarrollo y CLI | **Distrobox** + **Homebrew** | compiladores, runtimes, herramientas de línea de comandos, en espacio de usuario |
| Escape al host | `solera layer` | drivers, módulos de kernel, clientes VPN corporativos |

## Instalación

1. Descarga la última ISO (ver [Releases](https://github.com/calambrenet/solera/releases)).
2. Grábala en un USB (`dd`, GNOME Discos, Ventoy, etc.).
3. Arranca en **modo UEFI** (Solera es solo UEFI; en VirtualBox activa EFI en Ajustes → Sistema → Placa base).
4. La sesión live lanza el instalador (`os-installer`), que particiona el disco y despliega la imagen del sistema vía `arkdep`.
5. En el primer arranque, `gnome-initial-setup` crea tu usuario.

## Actualizar

Solera se gestiona con el comando `solera`, un front-end del motor de
despliegue `arkdep`. Cuando el canal público esté activo, actualizar es:

```bash
sudo solera update   # despliega la última imagen como un subvolumen separado
sudo reboot          # arranca en él; el despliegue anterior queda para rollback
```

Otros comandos: `solera layer <pkg>` añade paquetes nativos sobre la imagen,
`solera list` muestra las imágenes disponibles, `solera cleanup` borra
deployments antiguos. Ejecuta `solera help` para la lista completa.

Las apps gráficas se actualizan aparte vía Flatpak; las herramientas CLI de
usuario vía Homebrew.

## Construir desde el código

La distribución completa — paquetes, imagen del sistema e ISO instaladora — se construye localmente sin infraestructura en la nube:

```bash
bash scripts/build-iso-local.sh   # construye los paquetes propios, la imagen y la ISO
```

Después prueba en QEMU:

```bash
qemu-system-x86_64 -enable-kvm -m 4G -smp 4 \
    -bios /usr/share/edk2/x64/OVMF.4m.fd \
    -drive file=out/solera-*.iso,format=raw,media=cdrom \
    -drive file=test.qcow2,if=virtio
```

Ver [`image/README.md`](image/README.md) y [`iso/README.md`](iso/README.md) para los detalles de construcción.

## Estructura del repositorio

```
solera/
├── packages/                 Paquetes propios (se publican en el repo pacman de Solera)
│   ├── solera-meta/          Metapaquete: declara todas las dependencias de Solera
│   ├── solera-config/        Branding, defaults de dconf, /etc/skel, servicios
│   ├── solera-keyring/       Keyring PGP del repo pacman de Solera
│   ├── arkdep/               Motor de despliegue (mirror del upstream)
│   ├── os-installer/         Instalador (mirror de p3732/os-installer)
│   ├── os-installer-config-solera/   Flujo del instalador para arkdep
│   └── gnome-shell-extension-*/      Extensiones GNOME incluidas
├── image/                    Receta arkdep-build de la imagen del sistema
├── iso/                      Perfil archiso de la ISO instaladora
├── scripts/build-iso-local.sh    Construcción local end-to-end
└── .github/workflows/        Pipeline CI/CD
```

## Versionado

Las releases usan `YY.MM` (p. ej. `26.04`). El identificador interno de build es separado y aparece en el nombre de imagen (`solera-26.04-build-20260607-180000`). Cada release se ancla a un snapshot del Arch Linux Archive para reproducibilidad.

## Contribuir

Solera es open source y las contribuciones son bienvenidas — reportes de bugs,
peticiones de funcionalidad y pull requests. Ver [CONTRIBUTING.md](CONTRIBUTING.md)
para el flujo de trabajo y [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) para las
normas de la comunidad. Problemas de seguridad: ver [SECURITY.md](SECURITY.md)
(repórtalos en privado, no en un issue público).

Web: [www.soleralinux.org](https://www.soleralinux.org)

## Licencia

[GPL-3.0-or-later](LICENSE), en coherencia con upstream Arch / Arkane.
