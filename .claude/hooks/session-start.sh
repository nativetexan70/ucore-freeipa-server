#!/bin/bash
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Install shellcheck and shfmt via apt
apt-get install -y -qq shellcheck shfmt

# Install just from GitHub releases (Ubuntu 24.04 ships 1.21 which lacks
# [group()] attribute support; we need >= 1.23)
JUST_VERSION="1.40.0"
if ! just --version 2>/dev/null | grep -q "^just ${JUST_VERSION}$"; then
  curl -sSL "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /usr/local/bin just
fi
