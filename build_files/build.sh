#!/bin/bash

set -ouex pipefail

### Install packages

# FreeIPA server with integrated DNS
# freeipa-server-trust-ad (Samba/AD trust) is omitted: its post-install RPM
# scriptlets require running services and fail in a container build context.
dnf5 install -y \
    freeipa-server \
    freeipa-server-dns

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

### Clean up repo files
# Remove file:// gpgkey references so bootc container lint doesn't fail on
# missing local paths in the final image.
for f in /etc/yum.repos.d/*.repo /usr/lib/yum.repos.d/*.repo; do
    if [[ -f "$f" ]]; then
        sed -i 's|file://[^ ]*gpgkey[^ ]*||g' "$f"
    fi
done
