# CI Status Verification

The local environment exercises the same steps required by the GitHub Actions workflows.

## Results

- `cargo fmt --all -- --check`
- `cargo clippy --all-targets --all-features -- -D warnings`
- `cargo test --all --all-features --locked`
- `cargo build --release`
- `cargo tarpaulin --locked --workspace --all-features --out Xml --timeout 120 --fail-under 100 --skip-clean`

All commands complete successfully, providing confidence that the workflows will pass when
run in GitHub Actions.
