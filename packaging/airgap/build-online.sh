#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Run on a network-connected Ubuntu x86_64 host with the same Ubuntu release as the target.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="${WORK:-$(mktemp -d)}"
UPSTREAM="${WORK}/herdr"
BUNDLE="${ROOT}/herdr-airgap-ubuntu-x86_64"
TOOLCHAIN="1.96.1-x86_64-unknown-linux-gnu"
APT_PACKAGES=(build-essential pkg-config python3 ca-certificates curl git xz-utils zstd)
trap 'rm -rf "${WORK}"' EXIT

[[ "$(uname -m)" == x86_64 ]] || { echo 'This script must run on x86_64.' >&2; exit 1; }
command -v sudo >/dev/null || { echo 'sudo is required.' >&2; exit 1; }
sudo apt-get update
sudo apt-get install -y --no-install-recommends apt-rdepends "${APT_PACKAGES[@]}"

git clone --depth=1 --branch master https://github.com/herdrdev/herdr.git "${UPSTREAM}"
cd "${UPSTREAM}"

if ! command -v rustup >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -fsS https://sh.rustup.rs | sh -s -- -y --profile minimal
fi
export PATH="${HOME}/.cargo/bin:${PATH}"
rustup toolchain install "${TOOLCHAIN}" --profile minimal --component rustfmt --component clippy
cargo +"${TOOLCHAIN}" vendor vendor
mkdir -p .cargo
cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"
[source.vendored-sources]
directory = "vendor"
[net]
offline = true
EOF
cargo +"${TOOLCHAIN}" build --release --locked --offline
rm -rf target

rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/source" "${BUNDLE}/rust/toolchains/${TOOLCHAIN}" "${BUNDLE}/apt"
cp -a . "${BUNDLE}/source/"
cp -a "${HOME}/.rustup/toolchains/${TOOLCHAIN}/." "${BUNDLE}/rust/toolchains/${TOOLCHAIN}/"

# Download every recursively required .deb, including packages already installed locally.
mapfile -t ALL_PACKAGES < <(apt-rdepends "${APT_PACKAGES[@]}" 2>/dev/null | awk '/^[a-zA-Z0-9][a-zA-Z0-9+.-]*(:[^ ]+)?$/ {print}' | sort -u)
sudo apt-get --download-only --reinstall install -y "${ALL_PACKAGES[@]}"
cp -a /var/cache/apt/archives/*.deb "${BUNDLE}/apt/"
printf '%s\n' "${ALL_PACKAGES[@]}" > "${BUNDLE}/apt/packages.txt"
dpkg-query -W -f='${Package} ${Version}\n' > "${BUNDLE}/apt/installed-packages.txt"

rm -f "${ROOT}/herdr-airgap-ubuntu-x86_64.tar.zst" "${ROOT}/herdr-airgap-ubuntu-x86_64.tar.zst.sha256"
tar --zstd -C "${ROOT}" -cf "${ROOT}/herdr-airgap-ubuntu-x86_64.tar.zst" "$(basename "${BUNDLE}")"
sha256sum "${ROOT}/herdr-airgap-ubuntu-x86_64.tar.zst" > "${ROOT}/herdr-airgap-ubuntu-x86_64.tar.zst.sha256"
printf 'Created %s\n' "${ROOT}/herdr-airgap-ubuntu-x86_64.tar.zst"
