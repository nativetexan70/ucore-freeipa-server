#!/bin/bash

set -ouex pipefail

### Install packages

# FreeIPA server with integrated DNS and optional Active Directory trust
dnf5 install -y \
    freeipa-server \
    freeipa-server-dns \
    freeipa-server-trust-ad

### Configure firewall
# freeipa4 service covers tcp/udp 88 (Kerberos), 389/636 (LDAP/S), 464 (kpasswd), 80/443 (HTTP/S)
# dns service covers tcp/udp 53
firewall-offline-cmd --add-service=freeipa4
firewall-offline-cmd --add-service=dns

### Enable services
systemctl enable firewalld.service
# ipa.service orchestrates all FreeIPA components; it requires ipa-server-install to be
# run once after first boot to configure the realm before it will successfully start.
systemctl enable ipa.service

### Clean up repo files
# Remove file:// gpgkey references so bootc container lint doesn't fail on
# missing local paths in the final image.
for f in /etc/yum.repos.d/*.repo /usr/lib/yum.repos.d/*.repo; do
    [[ -f "$f" ]] && sed -i 's|file://[^ ]*gpgkey[^ ]*||g' "$f"
done
