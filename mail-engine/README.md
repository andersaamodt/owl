# Stellar Mail Engine

This directory is the server component shipped with Stellar. It contains:

- The Rust `owl` and `owl-daemon` binaries used for file-first mail processing.
- The Postfix receiving bridge, authenticated submission service, server-side
  DKIM signer, and server deployment adapter.
- Service helpers used on the installed server.

`owl` remains the internal binary and crate name to preserve the tested storage
format and upgrade path. It is not a separately discovered dependency: Stellar
builds and packages it from this directory.

Desktop releases include a static x86-64 Linux server build, so a normal VPS
does not need a Rust toolchain or matching system libc. The installer builds
this bundled source on the server only for architectures without a packaged
binary.

Build and test without creating repository-local state:

```sh
OWL_BUILD_STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/stellar/mail-engine" \
  sh scripts/owl-cargo test
```

Receiving-address configuration belongs to the user's mail root at
`~/mail/.stellar/mail-addresses.json`. It is managed through
`../scripts/stellar-mail-backend.sh`, not by editing Postfix files manually.
TLS setup keeps Certbot state root-owned and installs a twice-daily renewal
timer that safely releases port 80 for the standalone challenge.

The remote installer configures public receiving on port 25 and
TLS-authenticated client submission on port 587. It uses Cyrus SASL for one
single-user credential and OpenDKIM for one authoritative server key. Private
credentials and keys remain outside the repository; only the public DNS record
values are surfaced to the setup UI.

The imported engine was originally developed as Owl and remains available under
the permissive terms in `LICENSE`.
