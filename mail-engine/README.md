# Stellar Mail Engine

This directory is the server component shipped with Stellar. It contains:

- The Rust `owl` and `owl-daemon` binaries used for file-first mail processing.
- The Postfix receiving bridge and server deployment adapter.
- Service helpers used on the installed server.

`owl` remains the internal binary and crate name to preserve the tested storage
format and upgrade path. It is not a separately discovered dependency: Stellar
builds and packages it from this directory.

Build and test without creating repository-local state:

```sh
OWL_BUILD_STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/stellar/mail-engine" \
  sh scripts/owl-cargo test
```

Receiving-address configuration belongs to the user's mail root at
`~/mail/.stellar/mail-addresses.json`. It is managed through
`../scripts/stellar-mail-backend.sh`, not by editing Postfix files manually.

The imported engine was originally developed as Owl and remains available under
the permissive terms in `LICENSE`.
