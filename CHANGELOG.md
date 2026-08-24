# Changelog

All notable changes to Solera Linux are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to `YY.MM` versioning pinned to an
[Arch Linux Archive](https://archive.archlinux.org/) snapshot.

## [Unreleased]

## [26.08] — 2026-08-24

Maintenance release. Tag: `v26.08`. ISO: `solera-<TODO>-x86_64.iso` (~<TODO> GB).
Image: `solera-26-04-build-<TODO>.tar.zst` (~<TODO> GB).

### Changed

- `iso/pacman.conf` now renders from `iso/pacman.conf.template` at build time,
  anchored to the same Arch Linux Archive snapshot (`SOLERA_ALA_DATE`) as the
  system image — the live ISO's kernel now matches the installed image's
  kernel exactly, instead of tracking whatever Arch mirrors serve "today".
- `solera-welcome` now launches manually from the app menu instead of
  autostarting on first login; shebang pinned to `/usr/bin/python3` so it
  always uses Arch's interpreter, not a Homebrew/pyenv/conda one missing
  PyGObject (`solera-config` 26.04-37).
- Documented the release verification model: rewritten README/README.es,
  new `REPRODUCING.md`, published signing pubkey (`keys/solera-release.pub`).

### Fixed

- zsh command history now persists across reboots — `/etc/skel/.zshrc` was
  missing `HISTFILE`/`SAVEHIST`, so history was lost on every login.

### Package highlights

| Component | Version |
|---|---|
| Linux kernel | TODO — fill in after the build |
| GNOME (Shell / Mutter) | TODO |
| Mesa | TODO |
| systemd | TODO |
| glibc | TODO |
| NetworkManager | TODO |

## [26.06.3] — 2026-06-26

Feature release. Tag: `v26.06.3`. ISO: `solera-2026.06.26-x86_64.iso` (~4.1 GB).
Image: `solera-26-04-build-20260626-152035.tar.zst` (~2.0 GB).

### Added

- Plymouth boot splash branded with the Solera logo. `solera-config` now ships a
  custom `solera` Plymouth theme — a clone of Arch's `spinner` with the Solera sun
  logo as the watermark, rasterized from the same `solera-logo.svg` used by GDM —
  sets `Theme=solera` in `plymouthd.conf`, and runs `plymouth-set-default-theme
  solera` before dracut packages the initramfs. The installer now writes
  `rw quiet splash` on the kernel command line so Plymouth starts in graphical
  mode. Boot and login logos now match. (New installations only; already-installed
  systems need a one-line template patch — see `docs/STATUS.md`.)
- `gnome-shell-extension-solera-update` v0.1.1 — gates the first update check on
  network connectivity, avoiding a spurious "no updates" notification on first
  boot before the network is up.

### Changed

- ALA snapshot bumped forward, pulling `linux` 7.0.12.arch1 → 7.0.13.arch1 and
  `systemd` 260.2 → 261, plus minor upstream refreshes.
- `solera-config` 26.04-36 (Plymouth theme), `solera-meta` 26.04-18.

### Package highlights

| Component | Version |
|---|---|
| Linux kernel | 7.0.13.arch1 |
| GNOME (Shell / Mutter) | 50.2 |
| Mesa | 26.1.3 |
| systemd | 261 |
| glibc | 2.43 |
| NetworkManager | 1.56.1 |
| PipeWire / WirePlumber | 1.6.7 / 0.5.15 |
| Podman | 5.8.3 |
| Flatpak | 1.18.0 |
| GTK | 4.22.4 |
| rclone | 1.74.3 |
| github-cli | 2.95.0 |
| Solera Update extension | 0.1.1 |

935 packages in the image.

## [26.06.2] — 2026-06-23

Feature release. Tag: `v26.06.2`. ISO: `solera-2026.06.23-x86_64.iso` (~4.1 GB).
Image: `solera-26-04-build-20260623-153431.tar.zst` (~2.0 GB).

### Added

- `gnome-shell-extension-solera-update` (v0.1.0) — top-bar indicator that checks
  for new Solera images via `arkdep`, notifies the user, launches the deployment
  through a `pkexec` polkit dialog, animates the icon while deploying, and offers
  to reboot when finished. Installed system-wide and enabled by default via a
  `solera-config` dconf override (`enabled-extensions`).
- `gnome-shell-extension-solera-update` added to the build package list of
  `scripts/ci-build.sh` (and `rebuild-solera.sh`) so the containerized build
  pipeline produces and publishes it to the localrepo.

### Changed

- ALA snapshot bumped from `2026/06/15` to `2026/06/22`, pulling in minor
  upstream package refreshes (Mesa, PipeWire, WirePlumber, …).

### Package highlights

| Component | Version |
|---|---|
| Linux kernel | 7.0.12.arch1 |
| GNOME (Shell / Mutter) | 50.2 |
| Mesa | 26.1.3 |
| systemd | 260.2 |
| glibc | 2.43 |
| NetworkManager | 1.56.1 |
| PipeWire / WirePlumber | 1.6.7 / 0.5.15 |
| Podman | 5.8.3 |
| Flatpak | 1.18.0 |
| GTK | 4.22.4 |
| rclone | 1.74.3 |
| github-cli | 2.95.0 |
| Solera Update extension | 0.1.0 |

935 packages in the image.

## [26.06.1] — 2026-06-20

Maintenance release. Tag: `v26.06.1`. ISO: `solera-2026.06.20-x86_64.iso` (~4.1 GB).
Image: `solera-26-04-build-20260620-075443.tar.zst` (~2.0 GB).

### Added

- `rclone` — cloud storage sync, added to the default package set (`solera-meta`).
- `github-cli` (`gh`) — official GitHub CLI, added to the default package set.
- Containerized build pipeline (`build/Containerfile`, `scripts/ci-build.sh`,
  `build/run-build-test.sh`, `build/run-full-build.sh`): builds packages, image
  and ISO in a privileged podman container, since the host now runs Solera
  (immutable, read-only) and can no longer host the build toolchain. Supersedes
  host-based `rebuild-solera.sh`.
- `build/test-iso-qemu.sh` — headless QEMU/UEFI boot-test harness for the ISO.

### Fixed

- Container build copies only git-tracked files (avoids permission errors from
  root-owned scratch left by previous builds) and exposes the host `/dev` so the
  loop mounts of `arkdep-build`/`mkarchiso` work under `--privileged`.

### Package highlights

| Component | Version |
|---|---|
| Linux kernel | 7.0.12.arch1 |
| GNOME (Shell / Mutter) | 50.2 |
| Mesa | 26.1.2 |
| systemd | 260.2 |
| glibc | 2.43 |
| NetworkManager | 1.56.1 |
| PipeWire / WirePlumber | 1.6.6 / 0.5.14 |
| Podman | 5.8.3 |
| Flatpak | 1.18.0 |
| GTK | 4.22.4 |
| rclone | 1.74.3 |
| github-cli | 2.95.0 |

934 packages in the image.

## [26.06] — 2026-06-16

Second alpha. Tag: `v26.06`. ISO: `solera-2026.06.16-x86_64.iso` (~4.0 GB).
Image: `solera-26-04-build-20260616-211400.tar.zst` (~2.0 GB).

### Added

- Screenfetch with the Solera sun logo and branded distro name.
- `CODEOWNERS` so PRs auto-request review from the maintainer.
- `AUTHORS` file and maintainer section in README.
- Open-source community files (`CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `LICENSE`).
- `solera` CLI wrapper over `arkdep` (`solera update`, `solera layer`, `solera list`).
- Mandatory GPG signature check on `solera update` via `arkdep` defaults.
- `os-installer-config-solera`: deploy bundle from ISO cache, seed `trusted-keys` for signature verification, persist `/arkdep/config` with `gpg_signature_check=2`.
- `packages/gnome-shell-extension-blur-my-shell` (v72).
- `packages/gnome-shell-extension-compiz-alike-magic-lamp-effect` (v24).
- `packages/gnome-shell-extension-dash-to-dock` (v105).
- `packages/libnss-extrausers` (v0.6) — system user database merged into `/usr/lib`.
- `packages/zsh-theme-powerlevel10k` (v1.20.0) — with pre-built `gitstatusd` binary.
- `gamemode` and `lib32-gamemode` for gaming support.
- `solera-meta`: full GNOME desktop, PipeWire audio stack, Flatpak/Flathub, Podman/Distrobox/Homebrew, zsh+p10k, programming fonts, enterprise packages (SSSD, Samba, CUPS, WireGuard).
- `solera-config`: dconf overrides (keyboard, dash-to-dock, shell, background, color-scheme, WM, console, blur-my-shell), GDM greeter branding, `/etc/skel` (`.bashrc`, `.zshrc`, `.p10k.zsh`), `solera-first-boot` (Flatpak preinstall), zram swap service, `solera-welcome` GTK4 app, factory pattern for `/etc` overrides, sysctl tweaks, systemd timeout reduction, `ufw` enabled by default, `NetworkManager-wait-online` masked, `malcontent-timer` masked.
- `solera-keyring` with real GPG signing key (RSA 4096-bit, `release@soleralinux.org`).
- `image/arkdep-build.d/solera/`: reproducible image recipe pinned to Arch Linux Archive via `pacman.conf.template`, dracut with plymouth integration, `systemd-sysusers` for gdm user, `nsswitch.conf` with `extrausers`.
- `iso/`: archiso profile with systemd-boot (UEFI-only), GNOME live session, `os-installer` integration, branded boot entries.
- `scripts/build-iso-local.sh`: end-to-end local ISO build.
- `scripts-privados/publish-repo.sh`, `publish-image.sh`, `publish-finalize.sh`: manual publish pipeline to Cloudflare R2.
- Documentation: `solera-diseno-tecnico.md`, `docs-privados/STATUS.md`, `docs-privados/INFRA.md`, `docs-privados/ciclo-desarrollo-release.md`, `docs-privados/inventario-maquina.md`.

### Changed

- `arkdep` defaults patched to point at `repo.soleralinux.org/stable/images` with `gpg_signature_check=2`.
- `os-installer-config-solera` fstab uses `x-systemd.automount` for ESP.
- `solera-meta` now excludes `gnome-tour` from the default install.

### Fixed

- ESP mounted via automount so `solera update` can write kernel images without blocking boot.
- GPG signature check relaxed to `0` during initial cache deploy from ISO (trusted medium), restored to `2` for updates over the network.

## [26.04] — 2026-06-07

Initial public alpha. Tag: `v0.1.0-alpha`. First commit with project skeleton.

### Added

- Project skeleton: `packages/`, `image/`, `iso/`, `solera-diseno-tecnico.md`.
- `packages/solera-meta`: meta-package declaring all Solera dependencies.
- `packages/solera-config`: branding, dconf defaults, systemd units.
- `packages/solera-keyring`: PGP keyring for Solera's pacman repository.
- `packages/arkdep`: mirror of upstream Arkane Linux toolkit.
- `packages/os-installer`: mirror of upstream p3732/os-installer.
- `packages/os-installer-config-solera`: installer scripts for Solera deployment.
- `image/arkdep-build.d/solera/`: arkdep image recipe.
- `iso/`: archiso installer profile.
- `.github/workflows/build.yml`: CI/CD pipeline skeleton (S3+CloudFront, not yet active).
- `solera-diseno-tecnico.md`: authoritative technical design document.
- `docs-privados/inventario-maquina.md`: package inventory from the developer's machine.

[Unreleased]: https://github.com/calambrenet/solera/compare/v26.06.1...HEAD
[26.06.1]: https://github.com/calambrenet/solera/compare/v26.06...v26.06.1
[26.06]: https://github.com/calambrenet/solera/compare/v0.1.0-alpha...v26.06
[26.04]: https://github.com/calambrenet/solera/releases/tag/v0.1.0-alpha
