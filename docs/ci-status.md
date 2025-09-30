# CI Status Verification

This document tracks the local commands that mirror `.github/workflows/ci.yml` and records
whether they completed successfully in this environment.

## Lint job
- ✅ `cargo fmt --all -- --check`
- ✅ `cargo clippy --all-targets --all-features -- -D warnings`

## Test job
- ✅ `cargo test --all --all-features --locked`
- ✅ `cargo install cargo-tarpaulin --locked`
- ✅ `mkdir -p coverage`
- ✅ `cargo tarpaulin --out Xml --output-dir coverage --fail-under 100`

## Build job
- ✅ `cargo install cross --git https://github.com/cross-rs/cross`
- ⚠️ Cross build matrix

  ```bash
  for target in x86_64-unknown-linux-musl aarch64-unknown-linux-musl armv7-unknown-linux-gnueabihf; do
    cross build --release --target "$target"
  done
  ```

  The cross builds require a Docker or Podman engine. The current environment does not
  provide one, so the loop exits with `no container engine found`. Run the build step on a
  machine with Docker or Podman installed to fully exercise the GitHub Actions `build`
  matrix.
