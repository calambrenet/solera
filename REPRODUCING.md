# Reproducing a Solera release

Solera releases are built from a tagged state of this repository against a
fixed, dated [Arch Linux Archive](https://archive.archlinux.org/) snapshot.
This document describes how to verify a published release and how to rebuild
it independently from the same public, immutable inputs — no trust in the
project's build infrastructure required.

## What "reproducible" means here

Being precise matters more than sounding good, so here is the exact claim:

- **All build inputs are pinned and public.** A release is fully determined by
  (a) the repository at the release tag and (b) a dated Arch Linux Archive
  snapshot recorded in the repository at that tag. Nothing else feeds the
  build.
- **Rebuilding a release from its tag yields an equivalent image**: the same
  package set at the same versions, producing the same system content.
- **Bit-for-bit artifact equality is not claimed yet.** Build timestamps are
  embedded in artifact names and in the ISO/package container metadata, so two
  builds of the same tag currently produce artifacts with different hashes
  even though their system content matches. Normalizing this
  (`SOURCE_DATE_EPOCH` and friends) is a roadmap goal; until then, this
  document does not ask you to compare artifact hashes against the official
  ones — it shows you what you *can* verify today.

What you can verify today:

1. **Authenticity and integrity** of the official artifacts (SHA256 checksum
   plus detached GPG signature) — section 3.
2. **That a release really builds from its public pinned inputs**, by
   rebuilding it yourself and comparing the resulting system content —
   sections 1, 2 and 4.

## Prerequisites

- A Linux host with **podman** and **sudo**. The build runs inside a rootful,
  privileged container defined by [`build/Containerfile`](build/Containerfile)
  (it needs loop devices, `mkfs.btrfs` and chroot, which rootless podman does
  not reliably expose). Your host distribution does not matter; the build
  environment is the container.
- `git`, roughly **40 GB of free disk space** on a real filesystem
  (ext4/btrfs/xfs — not exFAT/NTFS) and **8 GB of RAM** recommended.
- Network access to the Arch Linux Archive, to the source URLs referenced by
  the PKGBUILDs in `packages/`, and to a container registry for the base
  image.

## 1. Check out the release

```bash
git clone https://github.com/calambrenet/solera.git
cd solera
git checkout v26.06.3        # or any release tag from the Releases page
```

Each release tag records its Arch snapshot in
[`image/arkdep-build.d/solera/pacman.conf`](image/arkdep-build.d/solera/pacman.conf):

```
Server = https://archive.archlinux.org/repos/2026/06/17/$repo/os/$arch
```

The date in that URL (`2026/06/17` for `v26.06.3`) is the snapshot the
official release was built against.

## 2. Build

Pass the snapshot date explicitly — without `SOLERA_ALA_DATE` the build
scripts default to the *latest* archive snapshot, which would give you newer
packages than the official release:

```bash
SOLERA_ALA_DATE=2026/06/17 bash build/run-full-build.sh
```

The script builds Solera's own packages, the system image (`arkdep-build`)
and the installer ISO (`mkarchiso`) inside the container, using only the
pinned snapshot as package source. It will ask for your password (rootful
podman). Artifacts land in `out-full/`:

```
out-full/solera-<version>-build-<id>.tar.zst   # system image
out-full/solera-<date>-x86_64.iso              # installer ISO
```

## 3. Verify the official artifacts

All official artifacts are signed with the Solera release key:

- **Key**: `Solera Linux <release@soleralinux.org>`
- **Primary key fingerprint**: `2A6B 615A 08E0 0125 0DAC 48BE DCDA 556A 3BC6 04A8`
- **Signing subkey**: `7DC3 D1F6 DDFF 5A25 2C69 56C6 52BB FC9B 744E DE63`
- **Key file**: [`keys/solera-release.pub`](keys/solera-release.pub) in this
  repository.

Download the latest ISO with its checksum and signature, then verify:

```bash
curl -O https://repo.soleralinux.org/stable/iso/solera-latest-x86_64.iso
curl -O https://repo.soleralinux.org/stable/iso/solera-latest-x86_64.iso.sha256
curl -O https://repo.soleralinux.org/stable/iso/solera-latest-x86_64.iso.sig

sha256sum -c solera-latest-x86_64.iso.sha256

gpg --import keys/solera-release.pub
gpg --verify solera-latest-x86_64.iso.sig solera-latest-x86_64.iso
```

`gpg --verify` must report a good signature from the fingerprint above.

The download mirror keeps only the most recent artifacts; the checksums of
every past release are preserved in its entry on the
[Releases page](https://github.com/calambrenet/solera/releases).

## 4. Compare your rebuild with the official release

Because bit-for-bit equality is not claimed yet (see above), compare content
rather than hashes:

- **Package set**: boot your rebuilt ISO in a VM (or extract the system image
  tarball) and compare `pacman -Q` output with the official image of the same
  release. The package versions must match exactly — both builds drew from
  the same frozen snapshot.
- **Filesystem content**: extract both system image tarballs and diff the
  trees, ignoring timestamps:

  ```bash
  mkdir official rebuilt
  tar --zstd -xf solera-<version>-build-<official-id>.tar.zst -C official
  tar --zstd -xf out-full/solera-<version>-build-<your-id>.tar.zst -C rebuilt
  diff -r --no-dereference official rebuilt
  ```

A divergence in package versions or in system content is treated as a bug —
please [open an issue](https://github.com/calambrenet/solera/issues).

## Scope and known limitations

- Artifact-level (bit-for-bit) reproducibility is not achieved yet: build
  timestamps leak into artifact names, ISO metadata and package archives.
  It is on the roadmap.
- Reproduction is supported for **x86_64** only.
- The download mirror serves only the most recent artifacts; older releases
  are documented (tag, changelog, checksums) on the GitHub Releases page.
- Git tags are currently not GPG-signed; the artifact signatures are the
  trust anchor.

## Reports welcome

If you rebuild a release — successfully or not — please say so in an
[issue](https://github.com/calambrenet/solera/issues). Independent
reproduction reports are one of the most valuable contributions an immutable
distribution can receive.
