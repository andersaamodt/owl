# Owl

Owl is a file-first email hub designed for Raspberry Pi deployments. This repository contains a Rust implementation that focuses on deterministic behavior, reproducible builds, and complete test coverage.

## Features

- Canonical file layout rooted in `/home/pi/mail` with quarantine, routing lists, drafts, and sent mail directories.
- Pure-Rust pipelines for inbound delivery, outbox queueing, and retention pruning.
- Deterministic filename generation with ULIDs and Unicode-safe subject slugs.
- Configurable routing through `.rules` files with address, domain, and regex entries.
- YAML sidecar metadata for every message, including attachment tracking and render options.
- CLI covering install, maintenance, routing, and export operations with optional JSON output.

## Getting Started

```bash
cargo build
cargo test
```

`EnvConfig` supports loading from a `.env` file and falls back to sane defaults that match the starter configuration in [`env.sample`](env.sample).

## Coverage

GitHub Actions enforces `cargo tarpaulin --fail-under 100` alongside linting and multi-target release builds.

## License

MIT or Apache-2.0, at your option.
