# Stellar

Stellar is a native mail and messaging app for people who want email and secure
chat in one calm timeline. It keeps your conversations arranged by person or
group, shows which transport each message used, and makes email an explicit
choice instead of an invisible fallback.

Stellar is early software. The repository currently builds native macOS, Linux,
Android, and iOS targets, with Android direct distribution as the simplest
mobile path.

## Theurgy Status

Stellar now carries a first-phase Theurgy project contract in
`theurgy.project.toml`.

- The durable truth remains file-first.
- The current backend remains `scripts/stellar-backend.sh`.
- Theurgy is the contract and runtime-staging boundary, not a mandate to rewrite
  the whole backend at once.
- The repo now also carries typed runtime contracts for snapshot, status,
  settings controls, and long-running transport operations in:
  - `app-blueprint/product.ir.json`
  - `app-blueprint/desktop.surface.ir.json`
  - `app-blueprint/runtime.manifest.json`
  - `scripts/stellar-runtime-*.sh`

## What Stellar Does

- Shows email and SimpleX-style secure messages in the same contact timeline.
- Keeps Inbox, People, Groups, Favorites, Archive, and New Senders as first-class
  views.
- Prefers secure SimpleX sending when a contact has a SimpleX path.
- Marks email as an open-lock transport and requires explicitly choosing it.
- Stores mail and messaging data under a local mail root, defaulting to
  `~/mail`.
- Presents remote mail server setup flows when a compatible mail engine is
  configured.

## Getting Stellar

Release builds are produced by GitHub Actions and attached to tagged
[GitHub releases](https://github.com/andersaamodt/stellar/releases):

- macOS: `Stellar-macOS`
- Linux: `stellar-linux-x86_64`
- Android: `stellar-android-debug-apk` for sideloading, plus a release AAB
- iOS: generated Xcode project and unsigned simulator app

Android is direct-distribution first and does not require Google Play Services.
iPhone installation still requires normal Apple signing through TestFlight, ad
hoc, enterprise, or another signed distribution path.

## Data and Transports

Stellar defaults to `~/mail` and keeps SimpleX-related files under:

```text
~/mail/.stellar/simplex/
~/mail/.system/simplex/
~/mail/.transport/simplex/
```

The local SimpleX hook is `scripts/stellar-simplex-local-hook.sh`. Stellar can also sync
with a remote Secure Chat daemon over SSH through
`scripts/stellar-secure-chat-hook.sh`; hosts and remote commands must be configured
explicitly and are not baked into the repository.

### Built-in email server

Stellar reads the file-first mail corpus directly, so an existing `~/mail`
archive remains browsable even while its server is stopped. This repository
includes the Rust mail engine, its daemon, its Postfix adapter, and remote
installer under `mail-engine/`. Desktop releases bundle the compiled engine and
the source needed to build it for a different server architecture.

For a single-user server:

1. Save the email domain.
2. Create receiving addresses such as `me`, `work`, or `receipts`.
3. Optionally add forwarding destinations.
4. Configure the SSH server and deploy it.
5. Complete the displayed DNS and TLS checks.

Every enabled address delivers to the same Stellar inbox. `postmaster` is
always present, catch-all receiving is off by default, and unknown addresses
are rejected. Address changes can be applied to an already-deployed server
without rebuilding it.

`doctor` runs the bundled engine's read-only `health` action. An explicit
`STELLAR_MAIL_BACKEND` remains available for development overrides, but Stellar
does not search sibling repositories.

## For Developers

Stellar is not a WebView app. The desktop UI is generated from
`app-blueprint/app.ir.yaml`; the mobile workspace is in `stellar-mobile` and is generated from
`stellar-mobile/app-blueprint/mobile.ir.yaml`.

Generate and validate desktop targets:

```sh
sh scripts/render-native-desktop.sh
sh scripts/validate-native-desktop-ir.sh
```

Desktop generated native host output is operator-local build material and now
lives under `${XDG_STATE_HOME:-$HOME/.local/state}/stellar/generated`, not in
repo-local `generated/`.

Generate and validate mobile targets:

```sh
cd stellar-mobile
sh scripts/render-native-mobile.sh
sh scripts/validate-native-mobile-ir.sh
```

Run the native contract tests:

```sh
sh .tests/native/run.sh
```

GitHub Actions builds macOS, Linux, Android, and iOS artifacts in
`.github/workflows/native-release.yml`. See `docs/release.md` for release
details.

## License

Stellar is dual-licensed under `OWL 3.1 OR AGPL-3.0-or-later`. AGPL use includes
the additional terms in `WIZARDRY_ADDENDUM.md`.
