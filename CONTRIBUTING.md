# Contributing to Solera Linux

Thanks for your interest in Solera. This document explains how to report issues
and submit changes.

Solera is **declarative**: the entire distribution is defined in this repository.
There is no "configure a running machine" step — every change to the system is a
change to a file here, built reproducibly. Keep that in mind when contributing:
if a tweak isn't in the repo, it isn't part of Solera.

## Ways to contribute

- **Report a bug** — open an issue using the bug report template.
- **Request a feature** — open an issue using the feature request template.
- **Submit a fix or improvement** — open a pull request (see below).
- **Improve documentation** — README, build docs, comments. PRs welcome.

## Repository layout

| Path | What it is | When to touch it |
|---|---|---|
| `packages/solera-meta/` | Meta-package listing every dependency of Solera | Add/remove software from the distro |
| `packages/solera-config/` | dconf defaults, `/etc/skel`, branding, services | Change default behaviour or look |
| `packages/solera-keyring/` | PGP keyring for the Solera pacman repo | Only when rotating the signing key |
| `packages/arkdep/`, `packages/os-installer/` | Upstream mirrors | Bump when a new upstream tag lands |
| `packages/os-installer-config-solera/` | Installer flow (partitioning, deploy) | Changes to how Solera installs |
| `image/` | `arkdep-build` recipe for the system image | Image composition |
| `iso/` | `archiso` profile for the installer ISO | Live medium / installer |

## Building and testing locally

You don't need any cloud infrastructure. The full build runs on a local Arch
host:

```bash
bash scripts/build-iso-local.sh
```

Then boot the result in QEMU (UEFI required):

```bash
qemu-system-x86_64 -enable-kvm -m 4G -smp 4 \
    -bios /usr/share/edk2/x64/OVMF.4m.fd \
    -drive file=out/solera-*.iso,format=raw,media=cdrom \
    -drive file=test.qcow2,if=virtio
```

See [`image/README.md`](image/README.md) and [`iso/README.md`](iso/README.md)
for details.

**Test before you submit.** A change that touches the image, a package or the
installer should be built and booted in a VM before opening the PR.

## Pull request process

1. **Fork** the repository and create a branch from `main`
   (`git checkout -b fix/short-description`).
2. **Make focused changes.** One logical change per PR. Don't mix a bugfix with
   unrelated refactors.
3. **Bump `pkgrel`** in the relevant `PKGBUILD` when you change a package's
   contents, so the build picks it up.
4. **Match the surrounding style.** Comments in packages are written to explain
   *why*, not *what*. Keep that density and tone.
5. **Write a clear PR description**: what changed, why, and how you tested it
   (which VM, what you verified).
6. **Open the PR** against `main`. Reference any related issue.

Commits use imperative mood in English, one or two descriptive sentences.

## Decisions already made

Some architectural decisions are settled. Please don't reopen them in a PR
without a strong reason and a separate issue to discuss first:

- **systemd-boot**, not GRUB.
- **arkdep** as the deployment engine (Btrfs subvolume exports), not bootc.
- **PipeWire** for audio (no native PulseAudio).
- **Flatpak** for GUI apps, **Distrobox** + **Homebrew** for dev/CLI,
  `arkdep layer` as the host escape hatch.
- Releases pinned to a fixed **Arch Linux Archive** snapshot for reproducibility.

## Reporting security issues

Do **not** open a public issue for security vulnerabilities. See
[`SECURITY.md`](SECURITY.md).

## License

By contributing, you agree that your contributions are licensed under the
[GPL-3.0-or-later](LICENSE), the same license as the project.
