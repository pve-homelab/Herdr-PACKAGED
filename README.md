# Herdr air-gapped Ubuntu x86_64 package

This repository is prepared to hold an offline build bundle for the official Herdr project:

- Upstream: https://github.com/herdrdev/herdr
- Upstream branch: `master`
- Rust toolchain pinned upstream: `1.96.1`
- Target: Ubuntu Linux x86_64 (`x86_64-unknown-linux-gnu`)

## Create the bundle on an internet-connected Ubuntu x86_64 staging host

Run:

```bash
bash packaging/airgap/build-online.sh
```

The script clones the current upstream `master`, vendors the complete Cargo dependency graph, downloads the pinned Rust toolchain and required Ubuntu build packages, and creates `herdr-airgap-ubuntu-x86_64.tar.zst`.

Transfer that archive to the air-gapped host, extract it, and run:

```bash
sudo bash packaging/airgap/install-offline.sh
```

The offline host must be the same Ubuntu release family as the staging host. Native Ubuntu packages are release-specific; Cargo vendoring alone cannot replace system headers, libc, the linker, or the Rust compiler.

## Offline build

```bash
cd /opt/herdr-airgap/source
cargo build --release --locked --offline
```

The checked-in `.cargo/config.toml` redirects crates.io to the bundled `vendor/` directory and enables Cargo offline mode.
