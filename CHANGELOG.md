# Changelog

All notable changes to Solera Linux are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to `YY.MM` versioning pinned to an
[Arch Linux Archive](https://archive.archlinux.org/) snapshot.

## [Unreleased]

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

[Unreleased]: https://github.com/calambrenet/solera/compare/v26.06...HEAD
[26.06]: https://github.com/calambrenet/solera/compare/v0.1.0-alpha...v26.06
[26.04]: https://github.com/calambrenet/solera/releases/tag/v0.1.0-alpha
