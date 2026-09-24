# ba0fde3d-bee7-4307-b97b-17d0d20aff50
# Kestrel — an AlmaLinux Atomic KDE respin tuned for desktop gaming on Intel graphics.

# Homebrew for bootc images (tarball, setup/update services, shell integration) from Universal Blue.
FROM ghcr.io/ublue-os/brew:latest@sha256:e9a72571b7644b6277f0638b6a3c5e497e265e1098ab91224567acbdeb8b74ea AS brew

# Kestrel's signed out-of-tree kernel modules (xpad), built by .github/workflows/build-kmods.yml.
FROM ghcr.io/narrativecollapse/kestrel-kmods:latest AS kmods

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx

COPY files/system /system_files/
COPY --chmod=0755 files/scripts /build_files/
COPY *.pub /keys/
COPY --from=brew /system_files /brew_files/
COPY --from=kmods /kmods /kmods/

# Base Image: AlmaLinux Atomic Desktop, KDE Plasma variant.
# Tip: pin a digest (":10@sha256:...") once the first CI build succeeds; Dependabot will keep it fresh.
FROM quay.io/almalinuxorg/atomic-desktop-kde:10

ARG IMAGE_NAME
ARG IMAGE_REGISTRY
ARG VARIANT

RUN --mount=type=tmpfs,dst=/opt \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/build_files/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
