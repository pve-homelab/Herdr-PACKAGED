#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ARCHIVE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCHIVE="${1:-${ARCHIVE_DIR}/herdr-airgap-ubuntu-x86_64.tar.zst}"
DEST=/opt/herdr-airgap

[[ $EUID -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }
[[ -f "$ARCHIVE" ]] || { echo "Bundle not found: $ARCHIVE" >&2; exit 1; }
mkdir -p "$DEST"
tar --zstd -xf "$ARCHIVE" -C "$DEST" --strip-components=1

# Install only from the transferred .deb cache; no apt network access is used.
if compgen -G "$DEST/apt/*.deb" >/dev/null; then
  dpkg --unpack "$DEST"/apt/*.deb || true
  apt-get -f install --no-download -y
fi

# Use the bundled Rust sysroot without rustup downloading anything.
mkdir -p /opt/herdr-airgap/rustup/toolchains
export RUSTUP_HOME=/opt/herdr-airgap/rustup
export CARGO_HOME=/opt/herdr-airgap/cargo
export PATH="$RUSTUP_HOME/toolchains/1.96.1-x86_64-unknown-linux-gnu/bin:$PATH"
export RUSTFLAGS="${RUSTFLAGS:-}"
cd "$DEST/source"
cargo build --release --locked --offline
printf '\nBuilt: %s\n' "$DEST/source/target/release/herdr"
