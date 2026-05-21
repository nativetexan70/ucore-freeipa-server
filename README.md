# ucore-freeipa-server

A [bootc](https://github.com/bootc-dev/bootc) container image based on [Universal Blue uCore](https://github.com/ublue-os/ucore) with [FreeIPA server](https://www.freeipa.org/) pre-installed. Deploy it to a machine as an immutable OS, then run a single setup command to stand up a full identity management server with Kerberos, LDAP, DNS, and a web UI.

The image is published automatically to GitHub Container Registry on every push to `main`.

## What's Included

- **Base**: `ghcr.io/ublue-os/ucore:stable` (Fedora CoreOS-based, minimal server image)
- **FreeIPA packages**: `freeipa-server`, `freeipa-server-dns`
- **Firewall**: pre-configured with the `freeipa4` service (Kerberos, LDAP/S, HTTP/S, kpasswd) and `dns` service
- **Services enabled**: `firewalld`, `ipa` (starts automatically after `ipa-server-install` is run)

## Deploying the Image

From any bootc-compatible system (Fedora Atomic, uCore, etc.):

```bash
sudo bootc switch ghcr.io/nativetexan70/ucore-freeipa-server:latest
sudo systemctl reboot
```

> [!NOTE]
> After rebooting into the new image, FreeIPA will **not** be running yet. You must complete the first-boot configuration step below.

## First-Boot: Configuring FreeIPA

After booting into the image, run `ipa-server-install` once to configure the realm. Replace the values below with your actual domain and passwords:

```bash
sudo ipa-server-install \
  --realm=EXAMPLE.COM \
  --domain=example.com \
  --ds-password=<directory-manager-password> \
  --admin-password=<admin-password> \
  --setup-dns \
  --unattended
```

This command sets up the Kerberos realm, 389-DS LDAP directory, Dogtag CA, integrated DNS, and the FreeIPA web UI. It typically takes 5–10 minutes. On completion, `ipa.service` starts and will auto-start on every subsequent reboot.

### Verifying the Installation

```bash
# Check service health
sudo ipactl status

# Obtain an admin Kerberos ticket
kinit admin

# Open the web UI
# https://<your-hostname>/ipa/ui
```

### Adding Active Directory Trust (Optional)

If you need trust with an Active Directory domain, install `freeipa-server-trust-ad` after booting into the image and run:

```bash
sudo dnf install -y freeipa-server-trust-ad
sudo ipa-adtrust-install
```

## Building Locally

Requires [just](https://just.systems/), `podman`, and `shellcheck`/`shfmt` for linting.

```bash
# Build the container image
just build

# Lint all shell scripts
just lint

# Format all shell scripts
just format

# Build a QCOW2 VM image (requires rootful podman)
just build-qcow2

# Run the QCOW2 VM locally
just run-vm-qcow2

# Run using systemd-vmspawn (default: 6G RAM)
just spawn-vm
```

## Building Disk Images (ISO / RAW / QCOW2)

The [build-disk.yml](./.github/workflows/build-disk.yml) workflow can produce bootable disk images for `amd64` and `arm64`. Trigger it manually from the Actions tab, or it runs automatically on changes to `disk_config/`.

To build locally:

```bash
just build-iso     # Anaconda installer ISO
just build-raw     # RAW disk image
just build-qcow2   # QCOW2 VM image
```

Disk images land in `output/` after the build. To optionally upload to an S3 bucket, add the following secrets to your repository (`Settings` → `Secrets and Variables` → `Actions`):

| Secret | Description |
|--------|-------------|
| `S3_PROVIDER` | One of the [rclone S3 providers](https://rclone.org/s3/) |
| `S3_BUCKET_NAME` | Your S3 bucket name |
| `S3_ACCESS_KEY_ID` | S3 access key |
| `S3_SECRET_ACCESS_KEY` | S3 secret key |
| `S3_REGION` | Bucket region (use `auto` if unsure) |
| `S3_ENDPOINT` | Provider-specific endpoint URL |

## Image Signing

Images pushed to GHCR are signed with [cosign](https://docs.sigstore.dev/cosign/overview/). To verify a pulled image:

```bash
cosign verify --key cosign.pub ghcr.io/nativetexan70/ucore-freeipa-server:latest
```

To enable signing in a fork, generate a key pair and add the private key as a repository secret:

```bash
COSIGN_PASSWORD="" cosign generate-key-pair
# Commit cosign.pub; add cosign.key as the SIGNING_SECRET Actions secret
```

> [!WARNING]
> Never commit `cosign.key`. It is listed in `.gitignore`.

## Ports

FreeIPA uses the following ports (pre-configured in firewalld):

| Port | Protocol | Service |
|------|----------|---------|
| 80, 443 | TCP | HTTP/HTTPS (web UI, CA) |
| 389, 636 | TCP | LDAP/LDAPS |
| 88, 464 | TCP/UDP | Kerberos, kpasswd |
| 53 | TCP/UDP | DNS |

## Resources

- [FreeIPA Documentation](https://www.freeipa.org/page/Documentation)
- [Universal Blue uCore](https://github.com/ublue-os/ucore)
- [bootc documentation](https://github.com/bootc-dev/bootc)
- [Universal Blue Community Forums](https://universal-blue.discourse.group/)
