#!/bin/bash

set -ouex pipefail

### Install packages

# FreeIPA server with integrated DNS
# freeipa-server-trust-ad (Samba/AD trust) is omitted: its post-install RPM
# scriptlets require running services and fail in a container build context.
# checkpolicy is needed to compile the custom SELinux policy module below.
dnf5 install -y \
    freeipa-server \
    freeipa-server-dns \
    checkpolicy \
    jq

### Configure firewall
# Use explicit ports instead of service names to avoid dependency on specific
# firewalld service definition files being present in the base image.
firewall-offline-cmd --add-port=80/tcp    # HTTP  (web UI, CA)
firewall-offline-cmd --add-port=443/tcp   # HTTPS (web UI, CA)
firewall-offline-cmd --add-port=389/tcp   # LDAP
firewall-offline-cmd --add-port=636/tcp   # LDAPS
firewall-offline-cmd --add-port=88/tcp    # Kerberos
firewall-offline-cmd --add-port=88/udp    # Kerberos
firewall-offline-cmd --add-port=464/tcp   # kpasswd
firewall-offline-cmd --add-port=464/udp   # kpasswd
firewall-offline-cmd --add-port=53/tcp    # DNS
firewall-offline-cmd --add-port=53/udp    # DNS
firewall-offline-cmd --add-port=123/udp   # NTP

### Enable services
systemctl enable firewalld.service
# ipa.service orchestrates all FreeIPA components; it requires ipa-server-install to be
# run once after first boot to configure the realm before it will successfully start.
systemctl enable ipa.service

### Create tmpfiles.d entries for FreeIPA runtime directories
# In bootc images /var is an empty writable partition on first boot — RPM
# package files under /var do not carry over from the container build.
# systemd-tmpfiles-setup.service reads these configs early in boot and
# creates the directories before ipa-server-install is ever run.
cat > /usr/lib/tmpfiles.d/freeipa-server-bootc.conf << 'EOF'
d /var/log/pki          0755 root   root   -
d /var/log/ipa          0700 root   root   -
d /var/lib/ipa          0755 root   root   -
d /var/lib/ipa/backup   0700 root   root   -
d /var/lib/dirsrv       0700 root   root   -
EOF


# Remove file:// gpgkey references so bootc container lint doesn't fail on
# missing local paths in the final image.
for f in /etc/yum.repos.d/*.repo /usr/lib/yum.repos.d/*.repo; do
    if [[ -f "$f" ]]; then
        sed -i 's|file://[^ ]*gpgkey[^ ]*||g' "$f"
    fi
done

### Install custom SELinux policy for bootc upgrades
# FreeIPA installs sssd-passkey-child and related binaries typed sssd_mfa_exec_t.
# bootc runs as install_t and needs relabelto (plus related file ops) on that
# type to write ostree content objects during upgrades. Without this, bootc
# upgrade fails with "fsetxattr(security.selinux): Permission denied" when
# SELinux is in enforcing mode.
cat > /tmp/bootc-freeipa-selinux.te << 'EOF'
module bootc-freeipa-selinux 1.0;

require {
    type install_t;
    type sssd_mfa_exec_t;
    class file { getattr ioctl link open read relabelto rename setattr write };
}

allow install_t sssd_mfa_exec_t:file { getattr ioctl link open read relabelto rename setattr write };
EOF

checkmodule -M -m -o /tmp/bootc-freeipa-selinux.mod /tmp/bootc-freeipa-selinux.te
semodule_package -o /tmp/bootc-freeipa-selinux.pp -m /tmp/bootc-freeipa-selinux.mod
semodule -i /tmp/bootc-freeipa-selinux.pp
rm -f /tmp/bootc-freeipa-selinux.te /tmp/bootc-freeipa-selinux.mod /tmp/bootc-freeipa-selinux.pp

### Configure image signing verification
# Ships the cosign public key and container policy so bootc upgrade pulls
# as ostree-image-signed instead of ostree-unverified-registry.
install -Dm0644 /ctx/cosign.pub \
    /etc/pki/containers/ghcr.io-nativetexan70-ucore-freeipa-server.pub

# Merge sigstore verification rule into the existing containers policy.
# jq preserves all other rules already present in the base image policy.
jq '.transports.docker["ghcr.io/nativetexan70/ucore-freeipa-server"] = [
  {
    "type": "sigstoreSigned",
    "keyPath": "/etc/pki/containers/ghcr.io-nativetexan70-ucore-freeipa-server.pub",
    "signedIdentity": {"type": "matchRepository"}
  }
]' /etc/containers/policy.json > /tmp/policy.json
mv /tmp/policy.json /etc/containers/policy.json

# Tell the containers runtime to look for sigstore attachments for this image.
cat > /etc/containers/registries.d/ghcr.io-nativetexan70-ucore-freeipa-server.yaml << 'EOF'
docker:
  ghcr.io/nativetexan70/ucore-freeipa-server:
    use-sigstore-attachments: true
EOF
