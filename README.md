# Owl

Owl is a file-first email hub designed for Raspberry Pi deployments. This repository contains a Rust implementation that focuses on deterministic behavior, reproducible builds, and complete test coverage.

The full implementation requirements live in [`SPEC.md`](SPEC.md); the codebase and CI are kept in sync with that document.

## Features

- Canonical file layout rooted in `/home/pi/mail` with quarantine, routing lists, drafts, and sent mail directories.
- Pure-Rust pipelines for inbound delivery, outbox queueing, DKIM signing, SMTP dispatch, and retention pruning.
- Deterministic filename generation with ULIDs and Unicode-safe subject slugs.
- Configurable routing through `.rules` files with address, domain, and regex entries.
- YAML sidecar metadata for every message, including attachment tracking, render artifacts, and retry history.
- CLI covering install, maintenance, routing, and export operations with optional JSON output.
- Daemon service providing filesystem watches for quarantine/outbox and periodic retention enforcement.
- Install-time provisioning for Let's Encrypt certificates, Postfix, Rspamd, and chrony markers to satisfy security requirements.
- Structured logging written beneath `/logs` honoring the configured verbosity levels.

## Getting Started

```bash
cargo build
cargo test
```

## Install via curl

Use the installer for a curl-based setup (downloads release binaries or falls back to a source build):

```bash
curl -fsSL https://raw.githubusercontent.com/owl-mail/owl/main/scripts/install.sh | sh
```

Set `OWL_REPO` if you are using a fork:

```bash
curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/scripts/install.sh | OWL_REPO=<owner>/<repo> sh
```

After install, the script can launch the built-in configuration wizard via `owl configure`.

Run the background workers with the companion daemon binary:

```bash
cargo run --bin owl-daemon
```

Pass `--once` to perform a single reconciliation cycle, which is helpful for smoke-testing service installs.

`EnvConfig` supports loading from a `.env` file and falls back to sane defaults that match the starter configuration in [`env.sample`](env.sample).

## Documentation

- [`docs/overview.md`](docs/overview.md): architecture, storage layout, pipelines, and operational notes.
- [`docs/cli.md`](docs/cli.md): CLI reference for `owl` and `owl-daemon` (POSIX-shell friendly).
- [`SPEC.md`](SPEC.md): authoritative implementation requirements and schema definitions.

## Coverage

GitHub Actions enforces `cargo tarpaulin --fail-under 100` alongside linting and multi-target release builds.

Every push uploads a `coverage-report` artifact with the XML output from Tarpaulin so you can inspect detailed coverage data.

Release builds run for each push as well; download the `owl-binaries` artifact from the workflow run to grab the latest `owl-${target}` executables and their accompanying `.sha256` checksums for x86_64, AArch64, and ARMv7.

## License

MIT or Apache-2.0, at your option.
