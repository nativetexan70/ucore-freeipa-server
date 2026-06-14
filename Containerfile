# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bluefin:stable

## Other possible base images:
# FROM ghcr.io/ublue-os/bluefin:latest      (latest Fedora Silverblue + GNOME)
# FROM ghcr.io/ublue-os/bluefin-dx:stable   (developer experience variant)
# FROM ghcr.io/ublue-os/aurora:stable       (KDE Plasma variant)
# Universal Blue Images: https://github.com/orgs/ublue-os/packages

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# COPY writes directly to the image layer and is not subject to the bind-mount
# that the OCI runtime places on /etc/hostname during RUN steps. This ships an
# empty /etc/hostname so bootc has no upstream value to merge against, preventing
# it from ever overwriting the locally configured hostname (required for FreeIPA).
COPY --from=ctx /hostname /etc/hostname

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
