#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Run this on a network-connected Ubuntu x86_64 machine matching the offline host.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="${WORK:-$(mktemp -d)}"
UPSTREAM="${WORK}/herdr"
BUNDLE="${ROOT}/herdr-airgap-ubuntu-x86_64"
TOOLCHAIN="1.96.1-x86_64-unknown-linux-gnu"
trap 'rm -rf "${WORK}"' EXIT

sudo apt-get update
sudo apt-get install -y --no-install-recommends ca-certificates curl git build-essential pkg-config python3 xz-utils zstd

git clone --depth=1 --branch master https://github.com/herdrdev/herdr.git "${UPSTREAM}"
cd "${UPSTREAM}"

# Install the exact toolchain selected by rust-toolchain.toml, including tools used by the repo.
if ! command -v rustup >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -fsS https://sh.rustup.rs | sh -s -- -y --profile minimal
  export PATH="${HOME}/.cargo/bin:${PATH}"
fi
rustup toolchain install "${TOOLCHAIN}" --component rustfmt --component clippy
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

rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/source" "${BUNDLE}/rustup" "${BUNDLE}/apt"
cp -a . "${BUNDLE}/source/"
cp -a "${HOME}/.rustup/toolchains/${TOOLCHAIN}" "${BUNDLE}/rustup/"
cp -a "${HOME}/.rustup/toolchains/${TOOLCHAIN}" "${BUNDLE}/rustup/"

# Capture native package archives and the package manifest. apt-get resolves dependencies.
sudo apt-get -y --download-only --reinstall install build-essential pkg-config python3 ca-certificates curl git xz-utils zstd
cp -a /var/cache/apt/archives/*.deb "${BUNDLE}/apt/" 2>/dev/null || true
apt-mark showmanual > "${BUNDLE}/apt/manual-packages.txt"

tar --zstd -C "${ROOT}" -cf "${ROOT}/herdr-airgap-ubuntu-x86_64.tar.zst" "$(basename "${BUNDLE}")"
sha256sum "${ROOT}/herdr-airgap-ubuntu-x86_64.tar.zst" > "${ROOT}/herdr-airgap-ubuntu-x86_64.tar.zst.sha256"
printf 'Created %s\n' "${ROOT}/herdr-airgap-ubuntu-x86_64.tar.zst"
