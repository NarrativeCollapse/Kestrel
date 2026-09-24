#!/usr/bin/env bash
# Claude Desktop (Chat, Cowork, Code) from Anthropic's official Linux build.
# Anthropic only publishes a .deb (Ubuntu/Debian), so this downloads the newest one from
# their apt repository, verifies it against the repository's signed index, and unpacks it
# into /usr. Maintainer scripts are not run. The weekly rebuild picks up new versions.
# Fedora/RHEL aren't officially supported by Anthropic yet; see README.

set -xeuo pipefail

REPO="https://downloads.claude.ai/claude-desktop/apt/stable"
KEY_URL="https://downloads.claude.ai/claude-desktop/key.asc"
KEY_FPR="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
ARCH="amd64"

# ar/tar to unpack the .deb, gpg to verify the repository signature.
dnf install -y binutils gnupg2 xz zstd

WORK="$(mktemp -d)"
export GNUPGHOME="${WORK}/gnupg"
mkdir -m 0700 "${GNUPGHOME}"

# --- Verify: signing key -> InRelease -> Packages -> .deb ---
curl -fsSL --retry 3 -o "${WORK}/key.asc" "${KEY_URL}"
gpg --batch --import "${WORK}/key.asc"
gpg --batch --with-colons --fingerprint | grep "^fpr:::::::::${KEY_FPR}:$" >/dev/null

curl -fsSL --retry 3 -o "${WORK}/InRelease" "${REPO}/dists/stable/InRelease"
gpg --batch --status-fd 1 --verify "${WORK}/InRelease" | grep "VALIDSIG ${KEY_FPR}" >/dev/null
gpg --batch --decrypt "${WORK}/InRelease" > "${WORK}/Release"

PKGS_PATH="main/binary-${ARCH}/Packages"
curl -fsSL --retry 3 -o "${WORK}/Packages" "${REPO}/dists/stable/${PKGS_PATH}"
PKGS_SHA="$(awk -v f="${PKGS_PATH}" '/^SHA256:/{s=1;next} /^[^ ]/{s=0} s && $3==f {print $1}' "${WORK}/Release")"
echo "${PKGS_SHA}  ${WORK}/Packages" | sha256sum -c -

# Newest claude-desktop entry: its Filename and SHA256.
read -r DEB_FILE DEB_SHA < <(awk '
    /^Package: /  { pkg=$2 }
    /^Version: /  { ver=$2 }
    /^Filename: / { file=$2 }
    /^SHA256: /   { sha=$2 }
    /^$/ { if (pkg=="claude-desktop") print ver, file, sha; pkg="" }
    END  { if (pkg=="claude-desktop") print ver, file, sha }
' "${WORK}/Packages" | sort -V | tail -n 1 | cut -d' ' -f2-)
test -n "${DEB_FILE}"

curl -fsSL --retry 3 -o "${WORK}/claude-desktop.deb" "${REPO}/${DEB_FILE}"
echo "${DEB_SHA}  ${WORK}/claude-desktop.deb" | sha256sum -c -

# --- Unpack ---
mkdir "${WORK}/deb" "${WORK}/root"
(cd "${WORK}/deb" && ar x ../claude-desktop.deb)
tar -xf "${WORK}"/deb/data.tar.* -C "${WORK}/root"
tar -xOf "${WORK}"/deb/control.tar.* ./control | grep -E '^(Version|Depends|Recommends):' || true

ROOT="${WORK}/root"

# Debian-only bits: apt repo registration, update cron jobs, apt defaults.
rm -rf "${ROOT}/etc/apt" "${ROOT}"/etc/cron.* "${ROOT}/etc/default"

# /opt is /var/opt on bootc systems (not part of the image), so move anything the
# package puts under /opt into /usr/lib and repoint links and launchers.
if [[ -d "${ROOT}/opt" ]]; then
    for dir in "${ROOT}"/opt/*; do
        name="$(basename "${dir}")"
        mkdir -p "${ROOT}/usr/lib"
        mv "${dir}" "${ROOT}/usr/lib/${name}"
        while IFS= read -r -d '' link; do
            ln -sfn "$(readlink "${link}" | sed "s|^/opt/${name}|/usr/lib/${name}|")" "${link}"
        done < <(find "${ROOT}" -type l -lname "/opt/${name}*" -print0)
        grep -rlZ "/opt/${name}" "${ROOT}/usr/share/applications" "${ROOT}/usr/bin" 2>/dev/null \
            | xargs -0 -r sed -i "s|/opt/${name}|/usr/lib/${name}|g" || true
    done
    rmdir "${ROOT}/opt"
fi

# EL's /bin, /sbin and /lib are symlinks into /usr; merge so cp doesn't collide with them.
for d in bin sbin lib lib64; do
    if [[ -d "${ROOT}/${d}" && ! -L "${ROOT}/${d}" ]]; then
        mkdir -p "${ROOT}/usr/${d}"
        cp -a "${ROOT}/${d}/." "${ROOT}/usr/${d}/"
        rm -rf "${ROOT:?}/${d}"
    fi
done

cp -a "${ROOT}/." /

# Electron's setuid sandbox helper, if the package ships one.
find /usr/lib /usr/share -ipath '*claude*' -name chrome-sandbox -type f -exec chmod 4755 {} +

test -x /usr/bin/claude-desktop

# --- Libraries: install whatever EL10 package provides each missing .so ---
# The Electron app directory is the one holding resources/app.asar.
ASAR="$(find /usr/lib /usr/share -ipath '*claude*' -path '*/resources/app.asar' -print -quit)"
if [[ -n "${ASAR}" ]]; then
    APP_DIR="$(dirname "$(dirname "${ASAR}")")"
else
    APP_DIR="$(dirname "$(readlink -f /usr/bin/claude-desktop)")"
fi
echo "Claude Desktop app directory: ${APP_DIR}"
missing_libs() {
    find "${APP_DIR}" -maxdepth 1 -type f \( -perm -u+x -o -name '*.so*' \) -print0 \
        | xargs -0 -r ldd 2>/dev/null | awk '/=> not found/ {print $1}' | sort -u \
        | grep -vxF -f <(find "${APP_DIR}" -maxdepth 1 -name '*.so*' -printf '%f\n') || true
}
MISSING="$(missing_libs)"
if [[ -n "${MISSING}" ]]; then
    # shellcheck disable=SC2046
    dnf install -y --setopt=strict=False $(printf '%s()(64bit) ' ${MISSING})
    MISSING="$(missing_libs)"
    if [[ -n "${MISSING}" ]]; then
        echo "::error::Claude Desktop needs libraries EL10 doesn't provide: ${MISSING}"
        exit 1
    fi
fi

# --- Cowork: runs tasks in a QEMU/KVM virtual machine ---
dnf install -y qemu-kvm-core edk2-ovmf virtiofsd

# The app expects Debian's QEMU and OVMF paths; point them at EL10's.
if [[ ! -e /usr/bin/qemu-system-x86_64 ]]; then
    ln -s /usr/libexec/qemu-kvm /usr/bin/qemu-system-x86_64
fi
if [[ ! -e /usr/share/OVMF ]]; then
    mkdir -p /usr/share/OVMF
    for fd in OVMF_CODE OVMF_VARS; do
        ln -s "../edk2/ovmf/${fd}.fd" "/usr/share/OVMF/${fd}.fd"
        ln -s "../edk2/ovmf/${fd}.fd" "/usr/share/OVMF/${fd}_4M.fd"
    done
fi
# /usr/lib/modules-load.d/kestrel-cowork.conf loads vhost_vsock;
# /usr/lib/udev/rules.d/71-kestrel-cowork.rules gives the desktop user /dev/kvm and /dev/vhost-vsock.

rm -rf "${WORK}"
