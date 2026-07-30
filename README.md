# Solera Linux

**An immutable, atomic Arch-based Linux distribution with GNOME.**

🌐 English · [Español](README.es.md)

Solera ships the operating system as a versioned, reproducible image rather than a machine you configure by hand. The root filesystem is read-only, updates are transactional with free rollback, and everything that defines the system lives in this Git repository.

It uses [`arkdep`](https://github.com/arkanelinux/arkdep) as the deployment engine (Btrfs subvolume images, the same engine behind Arkane Linux) and follows an image-based flow: the entire distribution is defined in this repository, built with the public scripts it contains on infrastructure controlled by the project, and published as a signed, versioned artifact. Every release is pinned to a dated [Arch Linux Archive](https://archive.archlinux.org/) snapshot, so its build inputs are immutable and anyone can independently rebuild and verify it — see [REPRODUCING.md](REPRODUCING.md).

> **Status: alpha.** Solera boots, installs and runs, and is used daily by its maintainer. Images are built and signed from the public build scripts and published at [repo.soleralinux.org](https://repo.soleralinux.org) with checksums and signatures; system updates are delivered through the public channel via `solera update`. Not recommended for production machines yet — try it in a VM or on a spare machine first.

## Features

- **Immutable root** — `/usr` is read-only; the system can't drift out of a known state.
- **Atomic updates with rollback** — an update deploys a new Btrfs subvolume and switches to it on reboot. The previous deployment stays on disk; rolling back is picking the old entry in the boot menu.
- **Verifiable releases** — every release builds against a pinned [Arch Linux Archive](https://archive.archlinux.org/) snapshot; anyone can rebuild a release from its Git tag and verify the published artifacts (see [REPRODUCING.md](REPRODUCING.md)).
- **GNOME desktop** with dash-to-dock, blur-my-shell and magic-lamp enabled by default.
- **systemd-boot** (UEFI only), Btrfs with zstd compression, zram swap.
- **PipeWire** audio, **Plymouth** boot splash.

## Software model

The root image stays minimal and identical across machines. Software lives in layers depending on its nature:

| Layer | Tool | For |
|---|---|---|
| Base system | the image | kernel, GNOME, services — changes only with a full update + reboot |
| GUI apps | **Flatpak** (Flathub preconfigured) | browsers, editors, end-user apps |
| Dev environments & CLI | **Distrobox** + **Homebrew** | compilers, runtimes, command-line tools, in user space |
| Host-level escape hatch | `solera layer` | drivers, kernel modules, corporate VPN clients |

## Installation

1. Download the latest ISO (see [Releases](https://github.com/calambrenet/solera/releases)).
2. Flash it to a USB drive (`dd`, GNOME Disks, Ventoy, etc.).
3. Boot in **UEFI mode** (Solera is UEFI-only; in VirtualBox enable EFI in Settings → System → Motherboard).
4. The live session launches the installer (`os-installer`), which partitions the disk and deploys the system image via `arkdep`.
5. On first boot, `gnome-initial-setup` creates your user.

## Updating

Solera is managed with the `solera` command, a small front-end over the
`arkdep` deployment engine. Updates are downloaded from the public channel,
verified (GPG signature + SHA256) and deployed atomically:

```bash
sudo solera update   # deploys the latest image as a separate subvolume
sudo reboot          # boot into it; the old deployment stays for rollback
```

Other commands: `solera layer <pkg>` adds native packages onto the image,
`solera list` shows the available images, `solera cleanup` removes old
deployments. Run `solera help` for the full list.

GUI apps update independently through Flatpak; user CLI tools through Homebrew.

## Building from source

The whole distribution — packages, system image and installer ISO — builds locally without any cloud infrastructure. The build runs inside a podman container (defined in [`build/Containerfile`](build/Containerfile)), so the host distribution doesn't matter:

```bash
bash build/run-full-build.sh   # builds the own packages, the image and the ISO
```

Artifacts land in `out-full/`. Then test in QEMU:

```bash
qemu-system-x86_64 -enable-kvm -m 4G -smp 4 \
    -bios /usr/share/edk2/x64/OVMF.4m.fd \
    -drive file=out-full/solera-*.iso,format=raw,media=cdrom \
    -drive file=test.qcow2,if=virtio
```

See [`image/README.md`](image/README.md) and [`iso/README.md`](iso/README.md) for the build internals.

## Releases and verification

Solera does not depend on third-party cloud CI: images are built on infrastructure controlled by the project, from the exact scripts published in this repository. Trust does not come from watching a hosted pipeline run — it comes from independent verification:

- **Versioned releases.** Each release is tagged in Git and listed on the [Releases page](https://github.com/calambrenet/solera/releases) with its changelog and the checksums of the published artifacts.
- **Pinned inputs.** Every release builds against a fixed, dated Arch Linux Archive snapshot, recorded at the release tag in [`image/arkdep-build.d/solera/pacman.conf`](image/arkdep-build.d/solera/pacman.conf), so the package inputs are immutable and public.
- **Rebuildable output.** Anyone can rebuild a release from its tag against the same pinned snapshot and compare the result — [REPRODUCING.md](REPRODUCING.md) documents the exact procedure and its current scope.
- **Signed artifacts.** Published images ship with a SHA256 checksum and a detached GPG signature. The release public key lives in this repository at [`keys/solera-release.pub`](keys/solera-release.pub) (fingerprint `2A6B 615A 08E0 0125 0DAC 48BE DCDA 556A 3BC6 04A8`).

Artifacts are served from [repo.soleralinux.org](https://repo.soleralinux.org):

```
https://repo.soleralinux.org/stable/iso/solera-latest-x86_64.iso
https://repo.soleralinux.org/stable/iso/solera-latest-x86_64.iso.sha256
https://repo.soleralinux.org/stable/iso/solera-latest-x86_64.iso.sig
```

## Repository layout

```
solera/
├── packages/                 Own packages (published to Solera's pacman repo)
│   ├── solera-meta/          Meta-package: declares every dependency of Solera
│   ├── solera-config/        Branding, dconf defaults, /etc/skel, services
│   ├── solera-keyring/       PGP keyring for the Solera pacman repo
│   ├── arkdep/               Deployment engine (mirror of upstream)
│   ├── os-installer/         Installer (mirror of p3732/os-installer)
│   ├── os-installer-config-solera/   Installer flow for arkdep
│   └── gnome-shell-extension-*/      Bundled GNOME extensions
├── image/                    arkdep-build recipe for the system image
├── iso/                      archiso profile for the installer ISO
├── build/                    Containerized build environment (Containerfile + runners)
├── scripts/                  Build orchestration (runs inside the container)
├── keys/                     Release signing public key
└── .github/workflows/        Experimental CI (not used for releases)
```

## Versioning

Releases use `YY.MM` (e.g. `26.04`). The internal build id is separate and appears in the image name (`solera-26.04-build-20260607-180000`). Each release is pinned to an Arch Linux Archive snapshot for reproducibility.

## Contributing

Solera is open source and contributions are welcome — bug reports, feature
requests and pull requests. See [CONTRIBUTING.md](CONTRIBUTING.md) for the
workflow and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community standards.
Security issues: see [SECURITY.md](SECURITY.md) (report privately, not in a
public issue).

Website: [www.soleralinux.org](https://www.soleralinux.org) · [Changelog](CHANGELOG.md)

## Maintainer

Maintained by **José Luis Castro** (<info@soleralinux.org>). Supported by
[HappyAndroids](https://happyandroids.com). See [AUTHORS](AUTHORS).

## License

[GPL-3.0-or-later](LICENSE), matching upstream Arch / Arkane.
