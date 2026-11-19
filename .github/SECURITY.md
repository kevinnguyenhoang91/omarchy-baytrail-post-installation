# Security Policy

`omarchy-baytrail-postinstall.sh` runs as **root** inside the installer chroot and is
usually piped straight from `curl` into `bash`, so security issues here matter.

## Supported versions

Only the `main` branch is supported. The README one-liner always fetches the script
from `main`, so fixes ship there.

## Reporting a vulnerability

**Do not open a public issue.** Report it privately through
[GitHub private vulnerability reporting](https://github.com/kevinnguyenhoang91/omarchy-baytrail-post-installation/security/advisories/new).

Please include:

- what an attacker could do (e.g. code execution, boot or data-loss risk, LUKS key exposure)
- the affected line(s) of the script or README command
- steps to reproduce and your device / Omarchy version

This is a single-maintainer project; reports are handled on a best-effort basis.
Once a fix lands on `main`, the advisory is published with credit unless you
prefer to stay anonymous.

## Scope

In scope: the post-install script, the commands documented in the README, and this
repository's GitHub Actions workflows.

Out of scope: Omarchy, Arch Linux, GRUB, and kernel packages themselves. Report those
upstream.
