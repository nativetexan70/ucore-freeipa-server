# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **bootc (bootable container) image** repository that builds a [Universal Blue](https://universal-blue.org/) uCore image with FreeIPA server pre-installed. The image is published to GitHub Container Registry (GHCR) and can be distributed as ISO/QCOW2/RAW disk images. After deploying the image, run `ipa-server-install` once to configure the realm before FreeIPA will start.

## Common Commands

All local development commands use the `just` command runner (see `Justfile`):

```bash
just build [target_image] [tag]         # Build container image with Podman
just build-qcow2 [target_image] [tag]   # Build QCOW2 VM image
just build-iso [target_image] [tag]     # Build ISO image
just build-raw [target_image] [tag]     # Build RAW image
just run-vm-qcow2 [target_image] [tag]  # Run QCOW2 VM
just spawn-vm                           # Run VM with systemd-vmspawn (default: 6G RAM)
just lint                               # Run shellcheck on all bash scripts
just format                             # Run shfmt on all bash scripts
just check                              # Check Justfile syntax
just clean                              # Remove build artifacts
```

Default environment variables: `image_name="image-template"`, `default_tag="latest"`, `bib_image` points to `quay.io/centos-bootc/bootc-image-builder:latest`.

## Architecture

### Build Pipeline

1. **`Containerfile`** — Defines the container image, using `ghcr.io/ublue-os/ucore:stable` as the base (Fedora CoreOS-based server image). This is where packages and system configurations are layered.
2. **`build_files/build.sh`** — Shell script that runs *inside* the container during build. Installs `freeipa-server` and `freeipa-server-dns`; pre-configures firewalld ports for FreeIPA; and enables `firewalld` and `ipa.service`. Note: `freeipa-server-trust-ad` is intentionally excluded — its Samba post-install scriptlets fail in a container build context.
3. **`disk_config/`** — TOML configs for `bootc-image-builder` to produce bootable disk images:
   - `disk.toml` — Minimal partition layout (20 GiB minimum)
   - `iso-gnome.toml` / `iso-kde.toml` — Anaconda installer configs for GNOME and KDE desktops

### CI/CD Workflows (`.github/workflows/`)

- **`build.yml`** — Triggers on push to `main`, PRs, daily schedule, and manual dispatch. Builds the container image with `buildah`, signs it with `cosign`, and pushes to GHCR (push only on `main`, not PRs).
- **`build-disk.yml`** — Manual dispatch only (or PR changes to `disk_config/`). Builds QCOW2 and Anaconda ISO images for `amd64`/`arm64`, optionally uploading to S3 via `rclone`.

### Image Signing

Images are signed with `cosign`. The `cosign.pub` key should be committed; `cosign.key` is excluded by `.gitignore` and stored as a GitHub Actions secret (`SIGNING_SECRET`).

### Publishing

Images are published to `ghcr.io/<owner>/<repo>:<tag>`. The `artifacthub-repo.yml` enables optional listing on [ArtifactHub.io](https://artifacthub.io/).

## Customization Points

- Change the uCore variant in `Containerfile` (e.g. `ucore:stable-zfs` for ZFS support)
- Add packages/services in `build_files/build.sh`
- Adjust disk layout in `disk_config/disk.toml`
- Modify workflow triggers or registry in `.github/workflows/build.yml`

## FreeIPA First-Boot Setup

The image ships FreeIPA packages and enabled services but requires a one-time configuration after deployment:

```bash
sudo ipa-server-install \
  --realm=EXAMPLE.COM \
  --domain=example.com \
  --ds-password=<dir-manager-password> \
  --admin-password=<admin-password> \
  --setup-dns \
  --unattended
```

After `ipa-server-install` completes, `ipa.service` will start automatically on future reboots.
