# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **bootc (bootable container) image** repository for building a custom [Universal Blue](https://universal-blue.org/) OS image, published to GitHub Container Registry (GHCR) and optionally distributed as ISO/QCOW2/RAW disk images. The project name `ucore-freeipa-server` suggests it builds on a uCore base with FreeIPA server capabilities.

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

1. **`Containerfile`** — Defines the container image, using `ghcr.io/ublue-os/bazzite:stable` as the base. This is where packages and system configurations are layered.
2. **`build_files/build.sh`** — Shell script that runs *inside* the container during build to install packages and configure services. Currently installs `tmux` and enables `podman.socket`.
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

- Change the base image in `Containerfile` (first `FROM` line)
- Add packages/services in `build_files/build.sh`
- Adjust disk layout in `disk_config/disk.toml`
- Modify workflow triggers or registry in `.github/workflows/build.yml`
