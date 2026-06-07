# Security Policy

## Reporting a vulnerability

If you find a security vulnerability in Solera Linux — in the system image, the
installer, the build pipeline, the signing setup, or any of the own packages —
please report it **privately**. Do not open a public issue.

- Preferred: use GitHub's [private vulnerability reporting](https://github.com/calambrenet/solera/security/advisories/new).
- Or email **info@soleralinux.org** with the details.

Please include:

- A description of the issue and its impact.
- Steps to reproduce, or a proof of concept.
- The affected component (package, image, ISO, build script…) and version /
  release (`YY.MM` and build id if known).

You'll get an acknowledgement as soon as possible. Once the issue is confirmed
and fixed, we'll coordinate disclosure with you.

## Supported versions

Solera is in **alpha**. There is no formal support window yet: only the latest
release on the `stable` channel receives fixes. A backport policy for older
releases will arrive together with the enterprise track.

## Signing

Solera signs its packages, system images and ISOs with the project's GPG key
(`Solera Linux <release@soleralinux.org>`). The public key ships in the
`solera-keyring` package. If a signature ever fails to verify, treat the
artifact as untrusted and report it.
