# bluefin-freeipa

A custom [bootc](https://github.com/bootc-dev/bootc) image layered on [Bluefin](https://github.com/ublue-os/bluefin) (Universal Blue) that ships `freeipa-client` and all required dependencies pre-installed. The image is built and published automatically to GHCR via GitHub Actions and is designed to preserve an existing FreeIPA domain join across `bootc` updates.

Published image: `ghcr.io/nativetexan70/bluefin-freeipa:latest`

---

# Switching to This Image

## From an Existing Bluefin or Universal Blue System

If you are already running a bootc-based system (Bluefin, Bazzite, Aurora, etc.), switching requires a single command and a reboot. No reinstall is needed.

```bash
sudo bootc switch ghcr.io/nativetexan70/bluefin-freeipa:latest
```

`bootc switch` stages the new image. The switch takes effect on the next reboot.

```bash
systemctl reboot
```

After rebooting, confirm you are on the new image:

```bash
sudo bootc status
```

> [!NOTE]
> If your current system is already joined to a FreeIPA domain, the join state is preserved. See [FreeIPA Join Persistence](#freeipa-join-persistence) below for details on how this works.

## From a Non-bootc Fedora or RPM-based System

A fresh install using an ISO is the recommended path. Download or build an ISO from this repository (see [Building Disk Images](#building-disk-images)) and boot from it.

---

# Setting Up FreeIPA Client

The `freeipa-client`, `sssd`, `oddjob`, and `oddjob-mkhomedir` packages are pre-installed in this image. After switching or installing, join the machine to your FreeIPA domain using `ipa-client-install`.

## Prerequisites

- Network access to your FreeIPA server (DNS must be resolvable)
- A one-time password or admin credentials for enrollment

## Joining the Domain

```bash
sudo ipa-client-install \
    --domain=your.domain.example \
    --server=ipa.your.domain.example \
    --realm=YOUR.DOMAIN.EXAMPLE \
    --mkhomedir \
    --no-ntp
```

Key flags:
- `--mkhomedir` — creates home directories on first login via `oddjob-mkhomedir`, which is enabled in this image
- `--no-ntp` — recommended if NTP is already managed by another service (e.g., `systemd-timesyncd` or Chrony on your network)
- `--unattended` — add this flag for scripted/automated enrollment together with `--password`

`ipa-client-install` will write and own `/etc/ipa/default.conf`, `/etc/sssd/sssd.conf`, `/etc/krb5.conf`, and related files. These are treated as local files by bootc and will not be overwritten by image updates.

After the join completes, verify that `sssd` is running:

```bash
systemctl status sssd
```

And test that a domain user can be resolved:

```bash
id <domain-username>
```

## Leaving the Domain

To remove the machine from FreeIPA cleanly:

```bash
sudo ipa-client-install --uninstall
```

---

# FreeIPA Join Persistence

This image is specifically designed so that an existing domain join survives `bootc` updates. Here is how it works.

When `bootc` applies an update it performs a **three-way merge** of `/etc`:

1. It diffs the old image's `/etc` against the new image's `/etc`.
2. It applies that delta to your local `/etc`.

Files that exist locally but are **not present in the image** are treated as local additions and are never touched. This image deliberately ships the directory skeletons `/etc/ipa/` and `/etc/sssd/conf.d/` but ships **no config file content** inside them. Every file that `ipa-client-install` writes — `sssd.conf`, `default.conf`, `krb5.conf`, etc. — is therefore a local addition that bootc will never overwrite.

Runtime state (`/var/lib/sss/`, `/var/log/sssd/`) lives under `/var`, which bootc never modifies.

**In practice:** after a `bootc update` and reboot, `sssd` comes back up reading the same config it had before the update, and domain authentication continues without any intervention.

---

# Changes to the Base Bluefin Image

This image is built on top of `ghcr.io/ublue-os/bluefin:stable` and makes the following deliberate modifications to support FreeIPA client functionality.

## Packages Added

| Package | Purpose |
|---|---|
| `freeipa-client` | Core FreeIPA client tooling (`ipa-client-install`, `ipa` CLI). Also pulls in `sssd`, `krb5-workstation`, `certmonger`, and other required dependencies. |
| `oddjob` | D-Bus service that allows `sssd` to perform privileged operations on behalf of unprivileged processes. |
| `oddjob-mkhomedir` | PAM module and helper that automatically creates a home directory on first login for domain users. |

## Systemd Units Enabled

| Unit | Purpose |
|---|---|
| `sssd` | System Security Services Daemon — handles Kerberos authentication, LDAP user/group lookups, and caching for the FreeIPA domain. |
| `oddjobd` | D-Bus daemon for `oddjob`. Must be running for `pam_oddjob_mkhomedir` to create home directories at login. |
| `podman.socket` | Inherited from the Bluefin base; retained for rootless container support. |

## Homebrew

[Homebrew](https://brew.sh) is installed system-wide at `/home/linuxbrew/.linuxbrew` and is available to every user — including FreeIPA domain users — without any per-user setup.

The brew environment is sourced automatically for all login and interactive shells via `/etc/profile.d/brew.sh`.

### Installing new packages (write access)

Package installation requires write access to the shared prefix. Access is controlled by the `brew` group.

```bash
sudo usermod -aG brew <username>
```

> [!NOTE]
> Users not in the `brew` group can still run any package that is already installed.

## Hostname Preservation

The upstream Bluefin image ships `/etc/hostname` with a default value. This image ships `/etc/hostname` as an **empty file** via a `COPY` instruction in the Containerfile, so bootc has no upstream value to merge against and the hostname set during installation is always preserved across updates.

> [!IMPORTANT]
> Set the correct FQDN hostname **before** running `ipa-client-install`. The hostname is baked into the Kerberos principal and LDAP host entry at join time.
>
> ```bash
> sudo hostnamectl set-hostname myhost.your.domain.example
> ```

---

# Keeping the Image Updated

```bash
sudo bootc upgrade
```

Or enable automatic background updates:

```bash
sudo systemctl enable --now bootc-fetch-apply-updates.timer
```

---

# Building the Image Locally

Requires [just](https://just.systems/) and [podman](https://podman.io/). Both are available by default on all Universal Blue images.

```bash
just build          # Build the container image
just lint           # Run shellcheck on all shell scripts
just format         # Run shfmt on all shell scripts
just check          # Validate Justfile syntax
just clean          # Remove local build artifacts
```

---

# Building Disk Images

```bash
just build-iso-gnome    # Anaconda installer ISO (GNOME desktop)
just build-iso-kde      # Anaconda installer ISO (KDE desktop)
just build-qcow2        # QCOW2 virtual machine image
```

Output is written to `output/`. Run `just clean` to remove all build artifacts.

---

# Image Signing

Images pushed to GHCR are signed with [Cosign](https://github.com/sigstore/cosign). The public key is at [`cosign.pub`](./cosign.pub).

To verify an image locally:

```bash
cosign verify --key cosign.pub ghcr.io/nativetexan70/bluefin-freeipa:latest
```

> [!WARNING]
> Never commit `cosign.key` to the repository. Only `cosign.pub` is safe to commit.

---

# Community

- [Universal Blue Forums](https://universal-blue.discourse.group/)
- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)
- [bootc discussion forums](https://github.com/bootc-dev/bootc/discussions)
