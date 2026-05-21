#!/bin/bash

set -ouex pipefail

### Install packages

# FreeIPA server with integrated DNS and optional Active Directory trust
dnf5 install -y \
    freeipa-server \
    freeipa-server-dns \
    freeipa-server-trust-ad

### Configure firewall
# freeipa4 is not a defined firewalld service on Fedora; use the individual
# named services that firewalld ships with instead.
firewall-offline-cmd --add-service=http
firewall-offline-cmd --add-service=https
firewall-offline-cmd --add-service=ldap
firewall-offline-cmd --add-service=ldaps
firewall-offline-cmd --add-service=kerberos
firewall-offline-cmd --add-service=kpasswd
firewall-offline-cmd --add-service=dns
firewall-offline-cmd --add-service=ntp

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
