# Solera Linux

**Una distribución Linux inmutable y atómica basada en Arch, con GNOME.**

🌐 [English](README.md) · Español

Solera entrega el sistema operativo como una imagen versionada y reproducible, no como una máquina que configuras a mano. El sistema raíz es de solo lectura, las actualizaciones son transaccionales con rollback gratuito, y todo lo que define el sistema vive en este repositorio Git.

Usa [`arkdep`](https://github.com/arkanelinux/arkdep) como motor de despliegue (imágenes de subvolúmenes Btrfs, el mismo motor de Arkane Linux) y sigue un flujo basado en imagen: la distribución completa se define en este repositorio, se construye con los scripts públicos que contiene sobre infraestructura controlada por el proyecto, y se publica como un artefacto firmado y versionado. Cada release se ancla a un snapshot datado del [Arch Linux Archive](https://archive.archlinux.org/), de modo que sus inputs de construcción son inmutables y cualquiera puede reconstruirla y verificarla de forma independiente — ver [REPRODUCING.md](REPRODUCING.md).

> **Estado: alpha.** Solera arranca, se instala y funciona, y su mantenedor la usa a diario. Las imágenes se construyen y firman con los scripts públicos de build y se publican en [repo.soleralinux.org](https://repo.soleralinux.org) con checksums y firmas; las actualizaciones del sistema llegan por el canal público vía `solera update`. Aún no se recomienda para máquinas de producción — pruébala antes en una VM o en una máquina secundaria.

## Características

- **Raíz inmutable** — `/usr` es de solo lectura; el sistema no puede derivar fuera de un estado conocido.
- **Actualizaciones atómicas con rollback** — una actualización despliega un nuevo subvolumen Btrfs y cambia a él al reiniciar. El despliegue anterior permanece en disco; volver atrás es elegir la entrada antigua en el menú de arranque.
- **Releases verificables** — cada release se construye contra un snapshot fijo del [Arch Linux Archive](https://archive.archlinux.org/); cualquiera puede reconstruir una release desde su tag de Git y verificar los artefactos publicados (ver [REPRODUCING.md](REPRODUCING.md)).
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
despliegue `arkdep`. Las actualizaciones se descargan del canal público,
se verifican (firma GPG + SHA256) y se despliegan de forma atómica:

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

La distribución completa — paquetes, imagen del sistema e ISO instaladora — se construye localmente sin infraestructura en la nube. El build corre dentro de un contenedor podman (definido en [`build/Containerfile`](build/Containerfile)), así que la distro del host no importa:

```bash
bash build/run-full-build.sh   # construye los paquetes propios, la imagen y la ISO
```

Los artefactos quedan en `out-full/`. Después prueba en QEMU:

```bash
qemu-system-x86_64 -enable-kvm -m 4G -smp 4 \
    -bios /usr/share/edk2/x64/OVMF.4m.fd \
    -drive file=out-full/solera-*.iso,format=raw,media=cdrom \
    -drive file=test.qcow2,if=virtio
```

Ver [`image/README.md`](image/README.md) y [`iso/README.md`](iso/README.md) para los detalles de construcción.

## Releases y verificación

Solera no depende de CI en nubes de terceros: las imágenes se construyen en infraestructura controlada por el proyecto, con exactamente los scripts publicados en este repositorio. La confianza no viene de ver correr un pipeline alojado — viene de la verificación independiente:

- **Releases versionadas.** Cada release se etiqueta en Git y aparece en la [página de Releases](https://github.com/calambrenet/solera/releases) con su changelog y los checksums de los artefactos publicados.
- **Inputs anclados.** Cada release se construye contra un snapshot fijo y datado del Arch Linux Archive, registrado en el tag de la release en [`image/arkdep-build.d/solera/pacman.conf`](image/arkdep-build.d/solera/pacman.conf), de modo que los inputs de paquetes son inmutables y públicos.
- **Salida reconstruible.** Cualquiera puede reconstruir una release desde su tag contra el mismo snapshot anclado y comparar el resultado — [REPRODUCING.md](REPRODUCING.md) documenta el procedimiento exacto y su alcance actual.
- **Artefactos firmados.** Las imágenes publicadas llevan checksum SHA256 y firma GPG separada. La clave pública de release vive en este repositorio en [`keys/solera-release.pub`](keys/solera-release.pub) (huella `2A6B 615A 08E0 0125 0DAC 48BE DCDA 556A 3BC6 04A8`).

Los artefactos se sirven desde [repo.soleralinux.org](https://repo.soleralinux.org):

```
https://repo.soleralinux.org/stable/iso/solera-latest-x86_64.iso
https://repo.soleralinux.org/stable/iso/solera-latest-x86_64.iso.sha256
https://repo.soleralinux.org/stable/iso/solera-latest-x86_64.iso.sig
```

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
├── build/                    Entorno de build en contenedor (Containerfile + runners)
├── scripts/                  Orquestación del build (corre dentro del contenedor)
├── keys/                     Clave pública de firma de releases
└── .github/workflows/        CI experimental (no se usa para releases)
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

## Mantenedor

Mantenido por **José Luis Castro** (<info@soleralinux.org>). Con el apoyo de
[HappyAndroids](https://happyandroids.com). Ver [AUTHORS](AUTHORS).

## Licencia

[GPL-3.0-or-later](LICENSE), en coherencia con upstream Arch / Arkane.
